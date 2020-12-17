json = require "json"
lfs = require "lfs"
re = require "aegisub.re"
ffi = require "ffi"
Logger = require "l0.DependencyControl.Logger"
UpdateFeed = require "l0.DependencyControl.UpdateFeed"
ConfigHandler = require "l0.DependencyControl.ConfigHandler"
fileOps = require "l0.DependencyControl.FileOps"
Updater = require "l0.DependencyControl.Updater"
UnitTestSuite = require "l0.DependencyControl.UnitTestSuite"
DownloadManager = require "DM.DownloadManager"
PreciseTimer = require "PT.PreciseTimer"


class DependencyControl
    semParts = {{"major", 16}, {"minor", 8}, {"patch", 0}}
    namespaceValidation = re.compile "^(?:[-\\w]+\\.)+[-\\w]+$"
    msgs = {
        checkOptionalModules: {
            downloadHint: "Please download the modules in question manually, put them in your %s folder and reload your automation scripts."
            missing: "Error: a %s feature you're trying to use requires additional modules that were not found on your system:\n%s\n%s"
        }
        formatVersionErrorTemplate: {
            missing: "— %s %s%s\n—— Reason: %s"
            outdated: "— %s (Installed: v%s; Required: v%s)%s\n—— Reason: %s"
        }
        getVersionNumber: {
            badString: "Can't parse version string '%s'. Make sure it conforms to semantic versioning standards."
            badType: "Argument had the wrong type: expected a string or number, got a %s. Content %s"
            overflow: "Error: %s version must be an integer < 255, got %s."
        }
        loadModules: {
            missing: "Error: one or more of the modules required by %s could not be found on your system:\n%s\n%s"
            missingRecord: "Error: module '%s' is missing a version record."
            moduleError: "Error in required module %s:\n%s"
            outdated: [[Error: one or more of the modules required by %s are outdated on your system:
%s\nPlease update the modules in question manually and reload your automation scripts.]]
        }
        new: {
             badRecordError: "Error: Bad #{@@__name} record (%s)."
            badRecord: {
                noUnmanagedMacros: "Creating unmanaged version records for macros is not allowed"
                missingNamespace: "No namespace defined"
                badVersion: "Couldn't parse version number: %s"
                badNamespace: "Namespace '%s' failed validation. Namespace rules: must contain 1+ single dots, but not start or end with a dot; all other characters must be in [A-Za-z0-9-_]."
                badModuleTable: "Invalid required module table #%d (%s)."
            }
            timer: "DependencyControl initialization took %f seconds so far..."
        }
        uninstall: {
            noVirtualOrUnmanaged: "Can't uninstall %s %s '%s'. (Only installed scripts managed by #{@@__name} can be uninstalled)."
        }
        writeConfig: {
            error: "An error occured while writing the #{@@__name} config file: %s"
            writingLocal: "Writing updated %s data to config file..."
        }
    }

    depConf = {
        file: aegisub.decode_path "?user/config/l0.#{@@__name}.json",
        scriptFields: {"author", "configFile", "feed", "moduleName", "name", "namespace", "url",
                       "requiredModules", "version", "unmanaged"},
        globalDefaults: {updaterEnabled:true, updateInterval:302400, traceLevel:3, extraFeeds:{},
                         tryAllFeeds:false, dumpFeeds:true, configDir:"?user/config",
                         logMaxFiles: 200, logMaxAge: 604800, logMaxSize:10*(10^6),
                         updateWaitTimeout: 60, updateOrphanTimeout: 600,
                         logDir: "?user/log", writeLogs: true}
    }

    dlm = DownloadManager!
    platform, logsHaveBeenTrimmed, scheduledRemovalHasRun = "#{ffi.os}-#{ffi.arch}"
    cumInitTime = 0
    fileOps.mkdir depConf.file, true

    @ConfigHandler = ConfigHandler
    @UpdateFeed = UpdateFeed
    @Logger = Logger
    @Updater = Updater
    @UnitTestSuite = UnitTestSuite
    @FileOps = fileOps

    automationDir: {macros:  aegisub.decode_path("?user/automation/autoload"),
                    modules: aegisub.decode_path("?user/automation/include")}

    new: (args) =>
        timer = PreciseTimer!
        -- defaults
        args[k] = v for k, v in pairs {
            readGlobalScriptVars: true
            saveRecordToConfig: true
        } when args[k] == nil

        {@requiredModules, moduleName:@moduleName, configFile:configFile, virtual:@virtual, :name,
         description:@description, url:@url, feed:@feed, unmanaged:@unmanaged, :namespace,
         author:@author, :version, configFile:@configFile,
         :readGlobalScriptVars, :saveRecordToConfig} = args

        -- also support name key (as used in configuration) for required modules
        @requiredModules or= args.requiredModules

        if @moduleName
            @namespace = @moduleName
            @name = name or @moduleName
            @type = "modules"
            @createDummyRef! unless @virtual or @unmanaged

        else
            if @virtual or not readGlobalScriptVars
                @name = name or namespace
                @namespace = namespace
                version or= 0
            else
                @name = name or script_name
                @description or= script_description
                @author or= script_author
                version or= script_version

            @namespace = namespace or script_namespace
            assert not @unmanaged, msgs.new.badRecordError\format msgs.new.badRecord.noUnmanagedMacros
            assert @namespace, msgs.new.badRecordError\format msgs.new.badRecord.missingNamespace
            @type = "macros"

        -- if the hosting macro doesn't have a namespace defined, define it for
        -- the first DepCtrled module loaded by the macro or its required modules
        unless script_namespace
            export script_namespace = @namespace

        -- non-depctrl record don't need to conform to namespace rules
        assert @virtual or @unmanaged or @validateNamespace!, msgs.new.badRecord.badNamespace\format @namespace

        @configFile = configFile or "#{@namespace}.json"
        @automationDir = @@automationDir[@type]
        @testDir = UnitTestSuite.testDir[@type]
        @version, err = @getVersionNumber version
        assert @version, msgs.new.badRecordError\format msgs.new.badRecord.badVersion\format err

        @requiredModules or= {}
        -- normalize short format module tables
        for i, mdl in pairs @requiredModules
            switch type mdl
                when "table"
                    mdl.moduleName or= mdl[1]
                    mdl[1] = nil
                when "string"
                    @requiredModules[i] = {moduleName: mdl}
                else error msgs.new.badRecordError\format msgs.new.badRecord.badModuleTable\format i, tostring mdl

        shouldWriteConfig = @loadConfig!

        @@logger or= Logger { fileBaseName: "DepCtrl", fileSubName: script_namespace, prefix: "[#{@@__name}] ",
                              toFile: @@config.c.writeLogs, defaultLevel: @@config.c.traceLevel,
                              maxAge: @@config.c.logMaxAge,maxSize: @@config.c.logMaxSize, maxFiles: @@config.c.logMaxFiles,
                              logDir: @@config.c.logDir }

        -- attach our logger to the required objects and classes
        obj.logger = @@logger for obj in *{@@config, @config, UpdateFeed, fileOps}

        -- set UpdateFeed settings
        if @@config.c.dumpFeeds
            UpdateFeed.downloadPath = aegisub.decode_path "?user/feedDump/"
            UpdateFeed.dumpExpanded = true

        -- create an updater unless one already exists
        @@updater or= Updater script_namespace, @@config, @@logger


        -- write config file if contents are missing or are out of sync with the script version record
        -- ramp up the random wait time on first initialization (many scripts may want to write configuration data)
        -- we can't really profit from write concerting here because we don't know which module loads last

        @configDir = @@config.c.configDir
        @writeConfig shouldWriteConfig and saveRecordToConfig, false, false

        fileOps.mkdir aegisub.decode_path @configDir
        logsHaveBeenTrimmed or= @@logger\trimFiles!
        scheduledRemovalHasRun or= fileOps.runScheduledRemoval @configDir

        cumInitTime += timer\timeElapsed!
        @@logger\trace msgs.new.timer, cumInitTime

    createDummyRef: =>
        return nil unless @moduleName
        -- global module registry allows for circular dependencies:
        -- set a dummy reference to this module since this module is not ready
        -- when the other one tries to load it (and vice versa)
        export LOADED_MODULES = {} unless LOADED_MODULES
        unless LOADED_MODULES[@moduleName]
            @ref = {}
            LOADED_MODULES[@moduleName] = setmetatable {__depCtrlDummy: true, version: @}, @ref
            return true
        return false

    removeDummyRef: =>
        return nil unless @moduleName
        if LOADED_MODULES[@moduleName] and LOADED_MODULES[@moduleName].__depCtrlDummy
            LOADED_MODULES[@moduleName] = nil
            return true
        return  false

    loadConfig: (importRecord = false, forceReloadGlobal = false) =>
        -- load global config
        @@config\load! if forceReloadGlobal and @@config
        @@config or= ConfigHandler depConf.file, depConf.globalDefaults, {"config"}

        -- load per-script config
        -- virtual modules are not yet present on the user's system and have no persistent configuration
        @config or= ConfigHandler not @virtual and depConf.file, {}, {@type, @namespace}, true

        -- import and overwrites version record from the configuration
        if importRecord
            -- check if a module that was previously virtual was installed in the meantime
            -- TODO: prevent issues caused by orphaned config entries
            haveConfig = false
            if @virtual
                @config\setFile depConf.file
                if @config\load!
                    haveConfig, @virtual = true, false
                else @config\unsetFile!
            else
                haveConfig = @config\load!

            -- only need to refresh data if the record was changed by an update
            if haveConfig
                @[key] = @config.c[key] for key in *depConf.scriptFields

        elseif not @virtual
            --  copy script information to the config
            @config\load!
            shouldWriteConfig = @config\import @, depConf.scriptFields, false, true
            return shouldWriteConfig

        return false

    writeConfig: (writeLocal = true, writeGlobal = true, concert = false) =>
        success, errMsg = true
        unless @virtual or @config.file
            @config\setFile depConf.file

        if concert
            success, errMsg = @@config\write true
        else
            if writeGlobal
                success, errMsg = @@config\write false
            if writeLocal and (success or not writeGlobal)
                @@logger\trace msgs.writeConfig.writingLocal, @moduleName and "module" or "macro"
                @config\import @, depConf.scriptFields, false, true
                success, errMsg = @config\write false

        assert success, msgs.writeConfig.error\format errMsg

    getVersionNumber: (value) =>
        switch type value
            when "number" then return math.max value, 0
            when "nil" then return 0
            when "string"
                matches = {value\match "^(%d+).(%d+).(%d+)$"}
                if #matches!=3
                    return false, msgs.getVersionNumber.badString\format value

                version = 0
                for i, part in ipairs semParts
                    value = tonumber(matches[i])
                    if type(value) != "number" or value>256
                        return false, msgs.getVersionNumber.overflow\format part[1], tostring value
                    version += bit.lshift value, part[2]
                return version

            else return false, msgs.getVersionNumber.badType\format type(value), @@logger\dumpToString value

    getVersionString: (version = @version, precision = "patch") =>
        if type(version) == "string"
            version = @getVersionNumber version
        parts = {0, 0, 0}
        for i, part in ipairs semParts
            parts[i] = bit.rshift(version, part[2])%256
            break if precision == part[1]

        return "%d.%d.%d"\format unpack parts

    getConfigFileName: () =>
        return aegisub.decode_path "#{@@config.c.configDir}/#{@configFile}"

    getConfigHandler: (defaults, section, noLoad) =>
        return ConfigHandler @getConfigFileName!, defaults, section, noLoad

    getLogger: (args = {}) =>
        args.fileBaseName or= @namespace
        args.toFile = @config.c.logToFile if args.toFile == nil
        args.defaultLevel or= @config.c.logLevel
        args.prefix or= @moduleName and "[#{@name}]"

        return Logger args

    checkVersion: (value, precision = "patch") =>
        if type(value) == "table" and value.__class == @@
            value = value.version
        if type(value) != "number"
            value, err = @getVersionNumber value
            return nil, err unless value
        mask = 0
        for part in *semParts
            mask += 0xFF * 2^part[2]
            break if precision == part[1]

        value = bit.band value, mask
        return @version >= value, value

    checkOptionalModules: (modules) =>
        modules = type(modules)=="string" and {[modules]:true} or {mdl,true for mdl in *modules}
        missing = [@formatVersionErrorTemplate mdl.moduleName, mdl.version, msl.url, mdl._reason for mdl in *@requiredModules when mdl.optional and mdl._missing and modules[mdl.name]]

        if #missing>0
            downloadHint = msgs.checkOptionalModules.downloadHint\format @@automationDir.modules
            errorMsg = msgs.checkOptionalModules.missing\format @name, table.concat(missing, "\n"), downloadHint
            return false, errorMsg
        return true

    getSubmodules: =>
        return nil if @virtual or @unmanaged or not @moduleName
        mdlConfig = @@config\getSectionHandler "modules"
        pattern = "^#{@moduleName}."\gsub "%.", "%%."
        return [mdl for mdl, _ in pairs mdlConfig.c when mdl\match pattern], mdlConfig

    loadModule: (mdl, usePrivate, reload) =>
        runInitializer = (ref) ->
            return unless type(ref) == "table" and ref.__depCtrlInit
            -- Note to future self: don't change this to a class check! When DepCtrl self-updates
            -- any managed module initialized before will still use the same instance
            if type(ref.version) != "table" or ref.version.__name != @@__name
                ref.__depCtrlInit @@

        with mdl
            ._missing, ._error = nil

            moduleName = usePrivate and "#{@namespace}.#{mdl.moduleName}" or .moduleName
            name = "#{mdl.name or mdl.moduleName}#{usePrivate and ' (Private Copy)' or ''}"

            if .outdated or reload
                -- clear old references
                package.loaded[moduleName], LOADED_MODULES[moduleName] = nil
            elseif ._ref = LOADED_MODULES[moduleName]
                -- module is already loaded, however it may or may not have been loaded by DepCtrl
                -- so we have to call any DepCtrl initializer if it hasn't been called yet
                runInitializer ._ref
                return ._ref

            loaded, res = xpcall require, debug.traceback, moduleName
            unless loaded
                LOADED_MODULES[moduleName] = nil
                res or= "unknown error"
                ._missing = res\match "module '.+' not found:"
                ._error = res unless ._missing
                return nil

            -- set new references
            if reload and ._ref and ._ref.__depCtrlDummy
                setmetatable ._ref, res
            ._ref, LOADED_MODULES[moduleName] = res, res

            -- run DepCtrl initializer if one was specified
            runInitializer res

        return mdl._ref  -- having this in the with block breaks moonscript

    requireModules: (modules = @requiredModules, addFeeds = {@feed}) =>
        success, err = @loadModules modules, addFeeds
        @@updater\releaseLock!
        unless success
            -- if we failed loading our required modules
            -- then that means we also failed to load
            LOADED_MODULES[@namespace] = nil
            @@logger\error err
        return unpack [mdl._ref for mdl in *modules]

    loadModules: (modules, addFeeds = {@feed}, skip = @moduleName and {[@moduleName]: true} or {}) =>
        for mdl in *modules
            continue if skip[mdl]
            with mdl
                ._ref, ._updated, ._missing, ._outdated, ._reason, ._error = nil

                -- try to load private copies of required modules first
                @loadModule mdl, true
                @loadModule mdl unless ._ref

                -- try to fetch and load a missing module from the web
                if ._missing
                    record = @@{moduleName:.moduleName, name:.name or .moduleName,
                                version:-1, url:.url, feed:.feed, virtual:true}
                    ._ref, code, extErr = @@updater\require record, .version, addFeeds, .optional
                    if ._ref or .optional
                        ._updated, ._missing = true, false
                    else
                        ._reason = @@updater\getUpdaterErrorMsg code, .name or .moduleName, true, true, extErr
                        -- nuke dummy reference for circular dependencies
                        LOADED_MODULES[.moduleName] = nil

                -- check if the version requirements are satisfied
                -- which is guaranteed for modules updated with \require, so we don't need to check again
                if .version and ._ref and not ._updated
                    record = ._ref.version
                    unless record
                        ._error = msgs.loadModules.missingRecord\format .moduleName
                        continue

                    if type(record) != "table" or record.__class != @@
                        record = @@ moduleName:.moduleName, version:record, unmanaged:true

                    -- force an update for outdated modules
                    if not record\checkVersion .version
                        ref, code, extErr = @@updater\require record, .version, addFeeds
                        if ref
                            ._ref = ref
                        elseif not .optional
                            ._outdated = true
                            ._reason = @@updater\getUpdaterErrorMsg code, .name or .moduleName, true, false, extErr
                    else
                        -- perform regular update check if we can get a lock without waiting
                        -- right now we don't care about the result and don't reload the module
                        -- so the update will not be effective until the user restarts Aegisub
                        -- or reloads the script
                        @@updater\scheduleUpdate record

        missing, outdated, moduleError = {}, {}, {}
        for mdl in *modules
            with mdl
                name = .name or .moduleName
                if ._missing
                    missing[#missing+1] = @formatVersionErrorTemplate name, .version, .url, ._reason
                elseif ._outdated
                    outdated[#outdated+1] = @formatVersionErrorTemplate name, .version, .url, ._reason, ._ref
                elseif ._error
                    moduleError[#moduleError+1] = msgs.loadModules.moduleError\format name, ._error

        errorMsg = {}
        if #moduleError > 0
            errorMsg[1] = table.concat moduleError, "\n"
        if #outdated > 0
            errorMsg[#errorMsg+1] = msgs.loadModules.outdated\format @name, table.concat outdated, "\n"
        if #missing > 0
            errorMsg[#errorMsg+1] = msgs.loadModules.missing\format @name, table.concat(missing, "\n"), downloadHint

        return #errorMsg == 0, table.concat(errorMsg, "\n\n")

    -- TODO: make this private
    formatVersionErrorTemplate: (name, reqVersion, url, reason, ref) =>
        url = url and ": #{url}" or ""
        if ref
            version = type(ref.version) == "table" and ref.version.__class == @@ and ref.version\getVersionString! or @getVersionString ref.version
            return msgs.formatVersionErrorTemplate.outdated\format name, version, reqVersion, url, reason
        else
            reqVersion = reqVersion and " (v#{reqVersion})" or ""
            return msgs.formatVersionErrorTemplate.missing\format name, reqVersion, url, reason

    registerTests: (...) =>
        -- load external tests
        haveTests, tests = pcall require, "DepUnit.#{@type}.#{@namespace}"

        if haveTests and not @testsLoaded
            @tests, tests.name = tests, @name
            modules =  table.pack @requireModules!
            if @moduleName
                @tests\import @ref, modules, ...
            else @tests\import modules, ...

            @tests\registerMacros!
            @testsLoaded = true

    register: (selfRef, ...) =>
        -- replace dummy refs with real refs to own module
        @ref.__index, @ref, LOADED_MODULES[@moduleName] = selfRef, selfRef, selfRef
        @registerTests selfRef, ...
        return selfRef

    registerMacro: (name=@name, description=@description, process, validate, isActive, submenu) =>
        -- alternative signature takes name and description from script
        if type(name)=="function"
            process, validate, isActive, submenu = name, description, process, validate
            name, description = @name, @description

        -- use automation script name for submenu by default
        submenu = @name if submenu == true

        menuName = { @config.c.customMenu }
        menuName[#menuName+1] = submenu if submenu
        menuName[#menuName+1] = name

        -- check for updates before running a macro
        processHooked = (sub, sel, act) ->
            @@updater\scheduleUpdate @
            @@updater\releaseLock!
            return process sub, sel, act

        aegisub.register_macro table.concat(menuName, "/"), description, processHooked, validate, isActive

    registerMacros: (macros = {}, submenuDefault = true) =>
        for macro in *macros
            -- allow macro table to omit name and description
            submenuIdx = type(macro[1])=="function" and 4 or 6
            macro[submenuIdx] = submenuDefault if macro[submenuIdx] == nil
            @registerMacro unpack(macro, 1, 6)

    setVersion: (version) =>
        version, err = @getVersionNumber version
        if version
            @version = version
            return version
        else return nil, err

    validateNamespace: (namespace = @namespace, isVirtual = @virtual) =>
        return isVirtual or namespaceValidation\match @namespace

    uninstall: (removeConfig = true) =>
        if @virtual or @unmanaged
            return nil, msgs.uninstall.noVirtualOrUnmanaged\format @virtual and "virtual" or "unmanaged",
                                                                   @moduleName and "module" or "macro",
                                                                   @name
        @config\delete!
        subModules, mdlConfig = @getSubmodules!
        -- uninstalling a module also removes all submodules
        if subModules and #subModules > 0
            mdlConfig.c[mdl] = nil for mdl in *subModules
            mdlConfig\write!

        toRemove, pattern, dir = {}
        if @moduleName
            nsp, name = @namespace\match "(.+)%.(.+)"
            pattern = "^#{name}"
            dir = "#{@automationDir}/#{nsp\gsub '%.', '/'}"
        else
            pattern = "^#{@namespace}"\gsub "%.", "%%."
            dir = @automationDir

        lfs.chdir dir
        for file in lfs.dir dir
            mode, path = fileOps.attributes file, "mode"
            -- parent level module files must be <last part of namespace>.ext
            currPattern = @moduleName and mode == "file" and pattern.."%." or pattern
            -- automation scripts don't use any subdirectories
            if (@moduleName or mode == "file") and file\match currPattern
                toRemove[#toRemove+1] = path
        return fileOps.remove toRemove, true, true

rec = DependencyControl{
    name: "DependencyControl",
    version: "0.6.4",
    description: "Provides script management and auto-updating for Aegisub macros and modules.",
    author: "line0",
    url: "http://github.com/TypesettingTools/DependencyControl",
    moduleName: "l0.DependencyControl",
    feed: "https://raw.githubusercontent.com/TypesettingTools/DependencyControl/master/DependencyControl.json",
    {
        {"DM.DownloadManager", version: "0.3.1", feed: "https://raw.githubusercontent.com/torque/ffi-experiments/master/DependencyControl.json"},
        {"BM.BadMutex", version: "0.1.3", feed: "https://raw.githubusercontent.com/torque/ffi-experiments/master/DependencyControl.json"},
        {"PT.PreciseTimer", version: "0.1.5", feed: "https://raw.githubusercontent.com/torque/ffi-experiments/master/DependencyControl.json"},
        {"requireffi.requireffi", version: "0.1.1", feed: "https://raw.githubusercontent.com/torque/ffi-experiments/master/DependencyControl.json"},
    }
}
DependencyControl.__class.version = rec
LOADED_MODULES[rec.moduleName], package.loaded[rec.moduleName] = DependencyControl, DependencyControl
DependencyControl.updater\scheduleUpdate rec
rec\requireModules!

return DependencyControl