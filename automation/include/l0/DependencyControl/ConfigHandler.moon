util = require "aegisub.util"
json = require "json"
PreciseTimer = require "PT.PreciseTimer"
Logger = require "l0.DependencyControl.Logger"
fileOps = require "l0.DependencyControl.FileOps"
mutex = require "BM.BadMutex"

class ConfigHandler
    @handlers = {}
    errors = {
        jsonDecode: "JSON parse error: %s"
        configCorrupted: [[An error occured while parsing the JSON config file.
A backup of the corrupted configuration has been written to '%s'.
Reload your automation scripts to generate a new configuration file.]]
        badKey: "Can't %s section because the key #%d (%s) leads to a %s."
        jsonRoot: "JSON root element must be an array or a hashtable, got a %s."
        noFile: "No config file defined."
        failedLock: "Failed to lock config file for %s: %s"
        waitLockFailed: "Error waiting for existing lock to be released: %s"
        forceReleaseFailed: "Failed to force-release existing lock after timeout had passed (%s)"
        noLock: "#{@@__name} doesn't have a lock"
        writeFailedRead: "Failed reading config file: %s."
        lockTimeout: "Timeout reached while waiting for write lock."
    }
    traceMsgs = {
        -- waitingLockPre: "Waiting %d ms before trying to get a lock..."
        waitingLock: "Waiting for config file lock to be released (%d ms passed)... "
        waitingLockFinished: "Lock was released after %d ms."
        mergeSectionStart: "Merging own section into configuration. Own Section: %s\nConfiguration: %s"
        mergeSectionResult: "Merge completed with result: %s"
        fileNotFound: "Couldn't find config file '%s'."
        fileCreate: "Config file '%s' doesn't exist, yet. Will write a fresh copy containing the current configuration section."
        writing: "Writing config file '%s'..."
        -- waitingLockTimeout: "Timeout was reached after %d seconds, force-releasing lock..."
    }

    new: (@file, defaults, @section, noLoad, @logger = Logger fileBaseName: @@__name) =>
        @section = {@section} if "table" != type @section
        @defaults = defaults and util.deep_copy(defaults) or {}
        -- register all handlers for concerted writing
        @setFile @file

        -- set up user configuration and make defaults accessible
        @userConfig = {}
        @config = setmetatable {}, {
            __index: (_, k) ->
                if @userConfig and @userConfig[k] ~= nil
                    return @userConfig[k]
                else return @defaults[k]
            __newindex: (_, k, v) ->
                @userConfig or= {}
                @userConfig[k] = v
            __len: (tbl) -> return 0
            __ipairs: (tbl) -> error "numerically indexed config hive keys are not supported"
            __pairs: (tbl) ->
                merged = util.copy @defaults
                merged[k] = v for k, v in pairs @userConfig
                return next, merged
        }
        @c = @config -- shortcut

        -- rig defaults in a way that writing to contained tables deep-copies the whole default
        -- into the user configuration and sets the requested property there
        recurse = (tbl) ->
            for k,v in pairs tbl
                continue if type(v)~="table" or type(k)=="string" and k\match "^__"
                -- replace every table reference with an empty proxy table
                -- this ensures all writes to the table get intercepted
                tbl[k] = setmetatable {__key: k, __parent: tbl, __tbl: v}, {
                    -- make the original table the index of the proxy so that defaults can be read
                    __index: v
                    __len: (tbl) -> return #tbl.__tbl
                    __newindex: (tbl, k, v) ->
                        upKeys, parent = {}, tbl.__parent
                        -- trace back to defaults entry, pick up the keys along the path
                        while parent.__parent
                            tbl = parent
                            upKeys[#upKeys+1] = tbl.__key
                            parent = tbl.__parent

                        -- deep copy the whole defaults node into the user configuration
                        -- (util.deep_copy does not copy attached metatable references)
                        -- make sure we copy the actual table, not the proxy
                        @userConfig or= {}
                        @userConfig[tbl.__key] = util.deep_copy @defaults[tbl.__key].__tbl
                        -- finally perform requested write on userdata
                        tbl = @userConfig[tbl.__key]
                        for i = #upKeys-1, 1, -1
                            tbl = tbl[upKeys[i]]
                        tbl[k] = v
                    __pairs: (tbl) -> return next, tbl.__tbl
                    __ipairs: (tbl) ->
                        i, n, orgTbl = 0, #tbl.__tbl, tbl.__tbl
                        ->
                            i += 1
                            return i, orgTbl[i] if i <= n
                }
                recurse tbl[k]

        recurse @defaults
        @load! unless noLoad

    setFile: (path) =>
        return false unless path
        if @@handlers[path]
            table.insert @@handlers[path], @
        else @@handlers[path] = {@}
        path, err = fileOps.validateFullPath path, true
        return nil, err unless path
        @file = path
        return true

    unsetFile: =>
        handlers = @@handlers[@file]
        if handlers and #handlers>1
            @@handlers[@file] = [handler for handler in *handlers when handler != @]
        else @@handlers[@file] = nil
        @file = nil
        return true

    readFile: (file = @file, useLock = true, waitLockTime) =>
        if useLock
            time, err = @getLock waitLockTime
            unless time
                -- handle\close!
                return false, errors.failedLock\format "reading", err

        mode, file = fileOps.attributes file, "mode"
        if mode == nil
            @releaseLock! if useLock
            return false, file
        elseif not mode
            @releaseLock! if useLock
            @logger\trace traceMsgs.fileNotFound, @file
            return nil

        handle, err = io.open file, "r"
        unless handle
            @releaseLock! if useLock
            return false, err

        data = handle\read "*a"
        success, result = pcall json.decode, data
        unless success
            handle\close!
            -- JSON parse error usually points to a corrupted config file
            -- Rename the broken file to allow generating a new one
            -- so the user can continue his work
            @logger\trace errors.jsonDecode, result
            backup = @file .. ".corrupted"
            fileOps.copy @file, backup
            fileOps.remove @file, false, true

            @releaseLock! if useLock
            return false, errors.configCorrupted\format backup

        handle\close!
        @releaseLock! if useLock

        if "table" != type result
            return false, errors.jsonRoot\format type result

        return result

    load: =>
        return false, errors.noFile unless @file

        config, err = @readFile!
        return config, err unless config

        sectionExists = true
        for i=1, #@section
            config = config[@section[i]]
            switch type config
                when "table" continue
                when "nil"
                    config, sectionExists = {}, false
                    break
                else return false, errors.badKey\format "retrive", i, tostring(@section[i]),type config

        @userConfig or= {}
        @userConfig[k] = v for k,v in pairs config
        return sectionExists

    mergeSection: (config) =>
        --@logger\trace traceMsgs.mergeSectionStart, @logger\dumpToString(@section),
        --                                           @logger\dumpToString config

        section, sectionExists = config, true
        -- create missing parent sections
        for i=1, #@section
            childSection = section[@section[i]]
            if childSection == nil
                -- don't create parent sections if this section is going to be deleted
                unless @userConfig
                    sectionExists = false
                    break
                section[@section[i]] = {}
                childSection = section[@section[i]]
            elseif "table" != type childSection
                return false, errors.badKey\format "update", i, tostring(@section[i]),type childSection
            section = childSection if @userConfig or i < #@section
        -- merge our values into our section
        if @userConfig
            section[k] = v for k,v in pairs @userConfig
        elseif sectionExists
            section[@section[#@section]] = nil

        -- @logger\trace traceMsgs.mergeSectionResult, @logger\dumpToString config
        return config

    delete: (concertWrite, waitLockTime) =>
        @userConfig = nil
        return @write concertWrite, waitLockTime

    write: (concertWrite, waitLockTime) =>
        return false, errors.noFile unless @file

        -- get a lock to avoid concurrent config file access
        time, err = @getLock waitLockTime
        unless time
            return false, errors.failedLock\format "writing", err

        -- read the config file
        config, err = @readFile @file, false
        if config == false
            @releaseLock!
            return false, errors.writeFailedRead\format err
        @logger\trace traceMsgs.fileCreate, @file unless config
        config or= {}

        -- merge in our section
        -- concerted writing allows us to update a configuration file
        -- shared by multiple handlers in the lua environment
        handlers = concertWrite and @@handlers[@file] or {@}
        for handler in *handlers
            config, err = handler\mergeSection config
            unless config
                @releaseLock!
                return false, err

        -- create JSON
        success, res = pcall json.encode, config
        unless success
            @releaseLock!
            return false, res

        -- write the whole config file in one go
        handle, err = io.open(@file, "w")
        unless handle
            @releaseLock!
            return false, err

        @logger\trace traceMsgs.writing, @file
        handle\setvbuf "full", 10e6
        handle\write res
        handle\flush!
        handle\close!
        @releaseLock!

        return true

    getLock: (waitTimeout = 5000, checkInterval = 50) =>
        return 0 if @hasLock
        success = mutex.tryLock!
        if success
            @hasLock = true
            return 0

        timeout, timePassed = waitTimeout, 0
        while not success and timeout > 0
            PreciseTimer.sleep checkInterval
            success = mutex.tryLock!
            timeout -= checkInterval
            timePassed = waitTimeout - timeout
            if timePassed % (checkInterval*5) == 0
                @logger\trace traceMsgs.waitingLock, timePassed

        if success
            @logger\trace traceMsgs.waitingLockFinished, timePassed
            @hasLock = true
            return timePassed
        else
            -- @logger\trace traceMsgs.waitingLockTimeout, waitTimeout/1000
            -- success, err = @releaseLock true
            -- unless success
                -- return false, errors.forceReleaseFailed\format err
            -- @hasLock = true
            --return waitTimeout
            return false, errors.lockTimeout

    getSectionHandler: (section, defaults, noLoad) =>
        return @@ @file, defaults, section, noLoad, @logger

    releaseLock: (force) =>
        if @hasLock or force
            @hasLock = false
            mutex.unlock!
            return true
        return false, errors.noLock

    -- copied from Aegisub util.moon, adjusted to skip private keys
    deepCopy: (tbl) =>
        seen = {}
        copy = (val) ->
            return val if type(val) != 'table'
            return seen[val] if seen[val]
            seen[val] = val
            {k, copy(v) for k, v in pairs val when type(k) != "string" or k\sub(1,1) != "_"}
        copy tbl

    import: (tbl = {}, keys, updateOnly, skipSameLengthTables) =>
        tbl = tbl.userConfig if tbl.__class == @@
        changesMade = false
        @userConfig or= {}
        keys = {key, true for key in *keys} if keys

        for k,v in pairs tbl
            continue if keys and not keys[k] or @userConfig[k] == v
            continue if updateOnly and @c[k] == nil
            -- TODO: deep-compare tables
            isTable = type(v) == "table"
            if isTable and skipSameLengthTables and type(@userConfig[k]) == "table" and #v == #@userConfig[k]
                continue
            continue if type(k) == "string" and k\sub(1,1) == "_"
            @userConfig[k] = isTable and @deepCopy(v) or v
            changesMade = true

        return changesMade