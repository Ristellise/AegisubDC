Logger = require "l0.DependencyControl.Logger"
ffi = require "ffi"
json = require "json"
DownloadManager = require "DM.DownloadManager"

class ScriptUpdateRecord
    platform = "#{ffi.os}-#{ffi.arch}"
    msgs = {
        errors: {
            noActiveChannel: "No active channel."
        }
        changelog: {
            header:      "Changelog for %s v%s (released %s):"
            verTemplate: "v %s:"
            msgTemplate: "  • %s"
        }
    }
    @logger = Logger fileBaseName: @@__name

    new: (@namespace, @data, @config = {c:{}}, isModule, autoChannel = true, @@logger = @@logger) =>
        @moduleName = isModule and @namespace
        @[k] = v for k, v in pairs data
        @setChannel! if autoChannel


    getChannels: =>
        channels, default = {}
        for name, channel in pairs @data.channels
            channels[#channels+1] = name
            if channel.default and not default
                default = name

        return channels, default

    setChannel: (channelName = @config.c.activeChannel) =>
        with @config.c
            .channels, default = @getChannels!
            .lastChannel or= channelName or default
            channelData = @data.channels[.lastChannel]
            @activeChannel = .lastChannel
            return false, @activeChannel unless channelData
            @[k] = v for k, v in pairs channelData

        @files = @files and [file for file in *@files when not file.platform or file.platform == platform] or {}
        return true, @activeChannel

    checkPlatform: =>
        @@logger\assert @activeChannel, msgs.errors.noActiveChannel
        return not @platforms or ({p,true for p in *@platforms})[platform], platform

    getChangelog: (versionRecord, minVer = 0) =>
        return "" unless "table" == type @changelog
        maxVer = versionRecord\getVersionNumber @version
        minVer = versionRecord\getVersionNumber minVer

        changelog = {}
        for ver, entry in pairs @changelog
            ver = versionRecord\getVersionNumber ver
            verStr = versionRecord\getVersionString ver
            if ver >= minVer and ver <= maxVer
                changelog[#changelog+1] = {ver, verStr, entry}

        return "" if #changelog == 0
        table.sort changelog, (a,b) -> a[1]>b[1]

        msg = {msgs.changelog.header\format @name, versionRecord\getVersionString(@version), @released or "<no date>"}
        for chg in *changelog
            chg[3] = {chg[3]} if type(chg[3]) ~= "table"
            if #chg[3] > 0
                msg[#msg+1] = @@logger\format msgs.changelog.verTemplate, 1, chg[2]
                msg[#msg+1] = @@logger\format(msgs.changelog.msgTemplate, 1, entry) for entry in *chg[3]

        return table.concat msg, "\n"

class UpdateFeed
    templateData = {
        maxDepth: 7,
        templates: {
            feedName:      {depth: 1, order: 1, key: "name"                                                  }
            baseUrl:       {depth: 1, order: 2, key: "baseUrl"                                               }
            feed:          {depth: 1, order: 3, key: "knownFeeds", isHashTable: true                         }
            namespace:     {depth: 3, order: 1, parentKeys: {macros:true, modules:true}                      }
            namespacePath: {depth: 3, order: 2, parentKeys: {macros:true, modules:true}, repl:"%.", to: "/"  }
            scriptName:    {depth: 3, order: 3, key: "name"                                                  }
            channel:       {depth: 5, order: 1, parentKeys: {channels:true}                                  }
            version:       {depth: 5, order: 2, key: "version"                                               }
            platform:      {depth: 7, order: 1, key: "platform"                                              }
            fileName:      {depth: 7, order: 2, key: "name"                                                  }
            -- rolling templates
            fileBaseUrl:   {key: "fileBaseUrl", rolling: true                                                }
        }
        sourceAt: {}
    }

    msgs = {
        trace: {
            usingCached: "Using cached feed."
            downloaded:  "Downloaded feed to %s."
        }
        errors: {
            downloadAdd:     "Couldn't initiate download of %s to %s (%s)."
            downloadFailed:  "Download of feed %s to %s failed (%s)."
            cantOpen:        "Can't open downloaded feed for reading (%s)."
            parse:           "Error parsing feed."
        }
    }

    -- default settings
    @logger = Logger fileBaseName: @@__name
    @downloadPath = aegisub.decode_path "?temp/l0.#{@@__name}_feedCache"
    @fileBaseName = "l0.#{@@__name}_"
    @fileMatchTemplate = "l0.#{@@__name}_%x%x%x%x.*%.json"
    @dumpExpanded = false

    @cache = {}
    dlm = DownloadManager aegisub.decode_path @downloadPath
    feedsHaveBeenTrimmed = false

    -- precalculate some tables for the templater
    templateData.rolling = {n, true for n,t in pairs templateData.templates when t.rolling}
    templateData.sourceKeys = {t.key, t.depth for n,t in pairs templateData.templates when t.key}
    with templateData
        for i=1,.maxDepth
            .sourceAt[i], j = {}, 1
            for name, tmpl in pairs .templates
                if tmpl.depth==i and not tmpl.rolling
                    .sourceAt[i][j] = name
                    j += 1
            table.sort .sourceAt[i], (a,b) -> return .templates[a].order < .templates[b].order

    new: (@url, autoFetch = true, fileName) =>
        -- delete old feeds
        feedsHaveBeenTrimmed or= Logger(fileMatchTemplate: @@fileMatchTemplate, logDir: @@downloadPath, maxFiles: 20)\trimFiles!

        @fileName = fileName or table.concat {@@downloadPath, @@fileBaseName, "%04X"\format(math.random 0, 16^4-1), ".json"}
        if @@cache[@url]
            @@logger\trace msgs.trace.usingCached
            @data = @@cache[@url]
        elseif autoFetch
            @fetch!

    getKnownFeeds: =>
        return {} unless @data
        return [url for _, url in pairs @data.knownFeeds]
        -- TODO: maybe also search all requirements for feed URLs

    fetch: (fileName) =>
        @fileName = fileName if fileName

        dl, err = dlm\addDownload @url, @fileName
        unless dl
            return false, msgs.errors.downloadAdd\format @url, @fileName, err

        dlm\waitForFinish -> true
        if dl.error
            return false,  msgs.errors.downloadFailed\format @url, @fileName, dl.error

        @@logger\trace msgs.trace.downloaded, @fileName

        handle, err = io.open @fileName
        unless handle
            return false, msgs.errors.cantOpen\format err

        decoded, data = pcall json.decode, handle\read "*a"
        unless decoded and data
            -- luajson errors are useless dumps of whatever, no use to pass them on to the user
            return false, msgs.errors.parse

        data[key] = {} for key in *{"macros", "modules", "knownFeeds"} when not data[key]
        @data, @@cache[@url] = data, data
        @expand!
        return @data

    expand: =>
        {:templates, :maxDepth, :sourceAt, :rolling, :sourceKeys} = templateData
        vars, rvars = {}, {i, {} for i=0, maxDepth}

        expandTemplates = (val, depth, rOff=0) ->
            return switch type val
                when "string"
                    val = val\gsub "@{(.-):(.-)}", (name, key) ->
                        if type(vars[name]) == "table" or type(rvars[depth+rOff]) == "table"
                            vars[name][key] or rvars[depth+rOff][name][key]
                    val\gsub "@{(.-)}", (name) -> vars[name] or rvars[depth+rOff][name]
                when "table"
                    {k, expandTemplates v, depth, rOff for k, v in pairs val}
                else val


        recurse = (obj, depth = 1, parentKey = "", upKey = "") ->
            -- collect regular template variables first
            for name in *sourceAt[depth]
                with templates[name]
                    if not .key
                         -- template variables are not expanded if they are keys
                        vars[name] = parentKey if .parentKeys[upKey]
                    elseif .key and obj[.key]
                        -- expand other templates used in template variable
                        obj[.key] = expandTemplates obj[.key], depth
                        vars[name] = obj[.key]
                    vars[name] = vars[name]\gsub(.repl, .to) if .repl

            -- update rolling template variables last
            for name,_ in pairs rolling
                rvars[depth][name] = obj[templates[name].key] or rvars[depth-1][name] or ""
                rvars[depth][name] = expandTemplates rvars[depth][name], depth, -1
                obj[templates[name].key] and= rvars[depth][name]

            -- expand variables in non-template strings and recurse tables
            for k,v in pairs obj
                if sourceKeys[k] ~= depth and not rolling[k]
                    switch type v
                        when "string"
                            obj[k] = expandTemplates obj[k], depth
                        when "table"
                            recurse v, depth+1, k, parentKey
                            -- invalidate template variables created at depth+1
                            vars[name] = nil for name in *sourceAt[depth+1]
                            rvars[depth+1] = {}

        recurse @data

        if @@dumpExpanded
            handle = io.open @fileName\gsub(".json$", ".exp.json"), "w"
            handle\write(json.encode @data)
            handle\close!

        return @data

    getScript: (namespace, isModule, config, autoChannel) =>
        section = isModule and "modules" or "macros"
        scriptData = @data[section][namespace]
        return false unless scriptData
        ScriptUpdateRecord namespace, scriptData, config, isModule, autoChannel

    getMacro: (namespace, config, autoChannel) =>
        @getScript namespace, false, config, autoChannel

    getModule: (namespace, config, autoChannel) =>
        @getScript namespace, true, config, autoChannel