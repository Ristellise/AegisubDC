PreciseTimer = require "PT.PreciseTimer"
lfs = require "lfs"

class Logger
    levels = {"fatal", "error", "warning", "hint", "debug", "trace"}
    defaultLevel: 2
    maxToFileLevel: 5
    fileBaseName: script_namespace or "UNKNOWN"
    fileSubName: ""
    logDir: "?user/log"
    fileTemplate: "%s/%s-%04x_%s_%s.log"
    fileMatchTemplate: "%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%x%x%x%x_@{fileBaseName}_?.*%.log$"
    prefix: ""
    toFile: false, toWindow: true
    indent: 0
    usePrefixFile: true
    usePrefixWindow: true
    indentStr: "—"
    maxFiles: 200, maxAge: 604800, maxSize:10*(10^6)

    timer, seeded = PreciseTimer!, false

    new: (args) =>
        if args
            @[k] = v for k, v in pairs args
            if args.usePrefix ~= nil
                @usePrefixFile, @usePrefixWindow = args.usePrefix

        -- scripts are loaded simultaneously, so we need to avoid seeding the rng with the same time
        unless seeded
            timer.sleep 10 for i=1,50
            math.randomseed(timer\timeElapsed!*1000000)
            math.random, math.random, math.random
            seeded = true
            -- timer gets freed on garbage collection
            timer = nil

        @lastHadLineFeed = true
        escaped = @fileBaseName\gsub("([%%%(%)%[%]%.%*%-%+%?%$%^])","%%%1")
        @fileMatch = @fileMatchTemplate\gsub "@{fileBaseName}", escaped
        @fileName = @fileTemplate\format aegisub.decode_path(@logDir), os.date("%Y-%m-%d-%H-%M-%S"),
                                          math.random(0, 16^4-1), @fileBaseName, @fileSubName

    logEx: (level = @defaultLevel, msg = "", insertLineFeed = true, prefix = @prefix, indent = @indent, ...) =>
        return false if msg == ""

        prefixWin = @usePrefixWindow and prefix or ""
        lineFeed = insertLineFeed and "\n" or ""
        indentStr = indent==0 and "" or @indentStr\rep(indent) .. " "
        
        msg = if @lastHadLineFeed
            @format msg, indent, ...
        elseif 0 < select "#", ...
            msg\format ...

        show = aegisub.log and @toWindow
        if @toFile and level <= @maxToFileLevel
            @handle = io.open(@fileName, "a") unless @handle
            linePre = @lastHadLineFeed and "#{indentStr}[#{levels[level+1]\upper!}] #{os.date '%H:%M:%S'} #{show and '+' or '•'} " or ""
            line = table.concat({linePre, @usePrefixFile and prefix or "", msg, lineFeed})
            @handle\write(line)
            @handle\flush!

        -- for some reason the stack trace gets swallowed when not doing the replace
        assert level > 1,"#{indentStr}Error: #{prefixWin}#{msg\gsub ':', ': '}"
        if show
            aegisub.log level, table.concat({indentStr, prefixWin, msg, lineFeed})

        @lastHadLineFeed = insertLineFeed
        return true

    format: (msg, indent, ...) =>
        if type(msg) == "table"
            msg = table.concat msg, "\n"
        
        if 0 < select "#", ...
            msg = msg\format ...

        return msg unless indent>0

        indentRep = @indentStr\rep(indent)
        indentStr = indentRep .. " "
         -- indent after line breaks and connect indentation supplied in the user message
        return msg\gsub("\n", "\n"..indentStr)\gsub "\n#{indentStr}(#{@indentStr})", "\n#{indentRep}%1"

    log: (level, msg, ...) =>
        return false unless level or msg

        if "number" != type level
            return @logEx @defaultLevel, level, true, nil, nil, msg, ...
        else return @logEx level, msg, true, nil, nil, ...

    fatal: (...) => @log 0, ...
    error: (...) => @log 1, ...
    warn: (...) => @log 2, ...
    hint: (...) => @log 3, ...
    debug: (...) => @log 4, ...
    trace: (...) => @log 5, ...

    assert: (cond, ...) =>
        if not cond
            @log 1, ...
        else return cond

    progress: (progress=false, msg = "", ...) =>
        if @progressStep and not progress
            @logEx nil, "■"\rep(10-@progressStep).."]", true, ""
            @progressStep = nil
        elseif progress
            unless @progressStep
                @progressStep = 0
                msg ..= " " if #msg>0
                @logEx nil, "#{msg}[", false, nil, nil, ...
            step = math.floor(progress * 0.01 + 0.5) / 0.1
            @logEx nil, "■"\rep(step-@progressStep), false, ""
            @progressStep = step

    -- taken from https://github.com/TypesettingCartel/Aegisub-Motion/blob/master/src/Log.moon
    dump: ( item, ignore, level = @defaultLevel ) =>
        @log level, @dumpToString item, ignore

    dumpToString: ( item, ignore ) =>
        if "table" != type item
            return tostring item

        count, tablecount = 1, 1

        result = { "{ @#{tablecount}" }
        seen   = { [item]: tablecount }
        recurse = ( item, space ) ->
            for key, value in pairs item
                unless key == ignore
                    if "number" == type key
                        key = "##{key}"
                    if "table" == type value
                        unless seen[value]
                            tablecount += 1
                            seen[value] = tablecount
                            count += 1
                            result[count] = space .. "#{key}: { @#{tablecount}"
                            recurse value, space .. "    "
                            count += 1
                            result[count] = space .. "}"
                        else
                            count += 1
                            result[count] = space .. "#{key}: @#{seen[value]}"

                    else
                        if "string" == type value
                            value = ("%q")\format value

                        count += 1
                        result[count] = space .. "#{key}: #{value}"

        recurse item, "    "
        result[count+1] = "}"

        return table.concat(result, "\n")\gsub "%%", "%%%%"

    windowError: ( errorMessage ) ->
        aegisub.dialog.display { { class: "label", label: errorMessage } }, { "&Close" }, { cancel: "&Close" }
        aegisub.cancel!


    trimFiles: (doWipe, maxAge = @maxAge, maxSize = @maxSize, maxFiles = @maxFiles) =>
        files, totalSize, deletedSize, now, f = {}, 0, 0, os.time!, 0

        dir = aegisub.decode_path @logDir
        lfs.chdir dir
        for file in lfs.dir dir
            attr = lfs.attributes file
            if type(attr) == "table" and attr.mode == "file" and file\find @fileMatch
                f += 1
                files[f] = {name:file, modified:attr.modification, size:attr.size}

        table.sort files, (a,b) -> a.modified > b.modified
        total, kept = #files, 0

        for i, file in ipairs files
            totalSize += file.size
            if doWipe or kept > maxFiles or totalSize > maxSize or file.modified+maxAge < now
                deletedSize += file.size
                os.remove file.name
            else
                kept += 1
        return total-kept, deletedSize, total, totalSize
