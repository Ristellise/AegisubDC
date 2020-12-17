export script_name = "DependencyControl Toolbox"
export script_description = "Provides DependencyControl maintenance and configuration tools."
export script_version = "0.1.3"
export script_author = "line0"
export script_namespace = "l0.DependencyControl.Toolbox"

DepCtrl = require "l0.DependencyControl"
depRec = DepCtrl feed: "https://raw.githubusercontent.com/TypesettingTools/DependencyControl/master/DependencyControl.json"
logger = DepCtrl.logger
logger.usePrefixWindow = false

msgs = {
    install: {
        scanning: "Scanning %d available feeds..."
    }
    uninstall: {
        running: "Uninstalling %s '%s'..."
        success: "%s '%s' was removed sucessfully. Reload your automation scripts or restart Aegisub for the changes to take effect."
        lockedFiles: "%s Some script files are still in use and will be deleted during the next restart/reload:\n%s"
        error: "Error: %s"
    }
    macroConfig: {
        hints: {
            customMenu: "Lets you sort your automation macros into submenus. Use / to denote submenu levels."
            userFeed: "When set the updater will use this feed exclusively to update the script in question."
        }
    }
}

-- Shared Functions

buildInstalledDlgList = (scriptType, config, isUninstall) ->
    list, map, protectedModules = {}, {}, {}
    if isUninstall
        protectedModules[mdl.moduleName] = true for mdl in *DepCtrl.version.requiredModules
        protectedModules[DepCtrl.version.moduleName] = true

    for namespace, script in pairs config.c[scriptType]
        continue if protectedModules[namespace]
        item = "%s v%s%s"\format script.name, depRec\getVersionString(script.version),
                                 script.activeChannel and " [#{script.activeChannel}]" or ""
        list[#list+1] = item
        table.sort list, (a, b) -> a\lower! < b\lower!
        map[item] = script
    return list, map

getConfig = (section) ->
    config = DepCtrl.config\getSectionHandler section
    config.c.macros or= {} if not section or #section == 0
    return config

getKnownFeeds = (config) ->
    getScriptFeeds = (t) -> [v.userFeed or v.feed for _,v in pairs config.c[t] when v.feed or v.userFeed]

    -- fetch all feeds and look for further known feeds
    recurse = (feeds, knownFeeds = {}, feedList = {}) ->
        for url in *feeds
            feed = DepCtrl.UpdateFeed url
            continue if knownFeeds[url] or not feed.data
            feedList[#feedList+1], knownFeeds[url] = feed, true
            recurse feed\getKnownFeeds!, knownFeeds, feedList
        return knownFeeds, feedList

    -- get additional feeds added by the user
    knownFeeds, feedList = recurse DepCtrl.config.c.extraFeeds
    -- collect feeds from all installed automation scripts and modules
    recurse getScriptFeeds("modules"), knownFeeds, feedList
    recurse getScriptFeeds("macros"), knownFeeds, feedList

    return feedList

getScriptListDlg = (macros, modules) ->
    {
        {label: "Automation Scripts: ", class: "label",    x: 0, y: 0, width: 1,  height: 1                               },
        {name:  "macro",                class: "dropdown", x: 1, y: 0, width: 1,  height: 1, items: macros, value: ""     },
        {label: "Modules: ",            class: "label",    x: 0, y: 1, width: 1,  height: 1                               },
        {name:  "module",               class: "dropdown", x: 1, y: 1, width: 1,  height: 1, items: modules, value: ""    }
    }

runUpdaterTask = (scriptData, exhaustive) ->
    return unless scriptData
    task, err = DepCtrl.updater\addTask scriptData, nil, nil, exhaustive, scriptData.channel
    if task then task\run!
    else logger\log err


-- Macros

install = ->
    config = getConfig!

    addAvailableToInstall = (tbl, feed, scriptType) ->
        for namespace, data in pairs feed.data[scriptType]
            scriptData = feed\getScript namespace, scriptType == "modules", nil, false
            channels, defaultChannel = scriptData\getChannels!
            tbl[namespace] or= {}
            for channel in *channels
                record = scriptData.data.channels[channel]
                verNum = depRec\getVersionNumber record.version
                unless config.c[scriptType][namespace] or (tbl[namespace][channel] and verNum < tbl[namespace][channel].verNum)
                    tbl[namespace][channel] = { name: scriptData.name, version: record.version, verNum: verNum, feed: feed.url,
                                                default: defaultChannel == channel, moduleName: scriptType == "modules" and namespace }
        return tbl

    buildDlgList = (tbl) ->
        list, map = {}, {}
        for namespace, channels in pairs tbl
            for channel, rec in pairs channels
                item = "%s v%s%s"\format rec.name, rec.version, rec.default and "" or " [#{channel}]"
                list[#list+1] = item
                table.sort list, (a, b) -> a\lower! < b\lower!
                map[item] = { :namespace, :channel, feed: rec.feed, name: rec.name, virtual: true,
                              moduleName: rec.moduleName }

        return list, map

    -- get a list of the highest versions of automation scripts and modules
    -- we can install but wich are not yet installed
    macros, modules, feeds = {}, {}, getKnownFeeds config

    logger\log msgs.install.scanning, #feeds
    for feed in *feeds
        macros = addAvailableToInstall macros, feed, "macros"
        modules = addAvailableToInstall modules, feed, "modules"

    -- build macro and module lists as well as reverse mappings
    moduleList, moduleMap = buildDlgList modules
    macroList, macroMap = buildDlgList macros

    btn, res = aegisub.dialog.display getScriptListDlg macroList, moduleList
    return unless btn

    -- create and run the update tasks
    macro, mdl = macroMap[res.macro], moduleMap[res.module]
    runUpdaterTask mdl, false
    runUpdaterTask macro, false

uninstall = ->
    doUninstall = (script) ->
        return unless script
        scriptType = script.moduleName and "Module" or "Macro"
        logger\log msgs.uninstall.running, scriptType, script.name
        success, details = DepCtrl(script)\uninstall!
        if success == nil
            if "table" == type details
                -- error may be a string or a file list
                details = table.concat ["#{path}: #{res[2]}" for path, res in pairs details when res[1] == nil], "\n"
            logger\log msgs.uninstall.error, details
        else
            msg = msgs.uninstall.success\format scriptType, script.name
            logger\log if success
                msg
            else
                fileList = table.concat ["#{path} (#{res[2]})" for path, res in pairs details when res[1] != true], "\n"
                msgs.uninstall.lockedFiles\format msg, fileList

        return success

    config = getConfig!

    -- build macro and module lists as well as reverse mappings
    moduleList, moduleMap = buildInstalledDlgList "modules", config, true
    macroList, macroMap = buildInstalledDlgList "macros", config, true

    btn, res = aegisub.dialog.display getScriptListDlg macroList, moduleList
    return unless btn

    macro, mdl = macroMap[res.macro], moduleMap[res.module]
    doUninstall mdl
    doUninstall macro

update = ->
    config = getConfig!

    -- build macro and module lists as well as reverse mappings
    moduleList, moduleMap = buildInstalledDlgList "modules", config
    macroList, macroMap = buildInstalledDlgList "macros", config

    dlg = getScriptListDlg macroList, moduleList
    dlg[5] = {name: "exhaustive", label: "Exhaustive Mode", class: "checkbox", x: 0, y: 2, width: 1, height: 1}
    btn, res = aegisub.dialog.display dlg
    return unless btn

    -- create and run the update tasks
    macro, mdl = macroMap[res.macro], moduleMap[res.module]
    runUpdaterTask mdl, res.exhaustive
    runUpdaterTask macro, res.exhaustive

macroConfig = ->
    config = getConfig "macros"

    dlg, i = {}, 1
    for nsp, macro in pairs config.userConfig
        dlg[i*5+t-1] = tbl for t, tbl in ipairs {
            {label: macro.name,              class: "label",  x: 0, y: i, width: 1,  height: 1  },
            {label: "Menu Group: ",          class: "label",  x: 1, y: i, width: 1,  height: 1  },
            {name:  "#{nsp}.customMenu",     class: "edit",   x: 2, y: i, width: 1,  height: 1,
             text: macro.customMenu or "",    hint: msgs.macroConfig.hints.customMenu           },
            {label: "Custom Update Feed: ",  class: "label",  x: 3, y: i, width: 1,  height: 1  },
            {name:  "#{nsp}.userFeed",       class: "edit",   x: 4, y: i, width: 1,  height: 1,
             text: macro.userFeed or "",      hint: msgs.macroConfig.hints.userFeed             }
        }
        i += 1
    btn, res = aegisub.dialog.display dlg
    return unless btn

    for k, v in pairs res
        nsp, prop = k\match "(.+)%.(.+)"
        if config.c[nsp][prop] and v == ""
            config.c[nsp][prop] = nil
        elseif v != ""
            config.c[nsp][prop] = v

    config\write!

depRec\registerMacros{
    {"Install Script", "Installs an automation script or module on your system.", install},
    {"Update Script", "Manually check and perform updates to any installed script.", update},
    {"Uninstall Script", "Removes an automation script or module from your system.", uninstall},
    {"Macro Configuration", "Lets you change per-automation script settings.", macroConfig},
}, "DependencyControl"