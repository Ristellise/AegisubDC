ffi = require "ffi"
re =  require "aegisub.re"
lfs = require "lfs"

Logger = require "l0.DependencyControl.Logger"
local ConfigHandler

class FileOps
    msgs = {
            generic: {
                deletionRescheduled: "Another deletion attempt has been rescheduled for the next restart."
            }
            attributes: {
                badPath: "Path failed verification: %s."
                genericError: "Can't retrieve attributes: %s."
                noAttribute: "Can't find attriubte with name '%s'."
            }

            mkdir: {
                createError: "Error creating directory: %s."
                otherExists: "Couldn't create directory because a %s of the same name is already present."
            }
            copy: {
                targetExists: "Target file '%s' already exists"
                genericError: "An error occured while copying file '%s' to '%s':\n%s"
                dirCopyUnsupported: "Copying directories is currently not supported."
                missingSource: "Couldn't find source file '%s'."
                openError: "Couldn't open %s file '%s' for reading: \n%s"
            }
            move: {
                inUseTryingRename: "Target file '%s' already exists and appears to be in use. Trying to rename and delete existing file..."
                renamedDeletionFailed: "The existing file was successfully renamed to '%s', but couldn't be deleted (%s).\n%s"
                overwritingFile: "File '%s' already exists, overwriting..."
                createdDir: "Created target directory '%s'."
                exists: "Couldn't move file '%s' to '%s' because a %s of the same name is already present."
                genericError: "An error occured while moving file '%s' to '%s':\n%s"
                createDirError: "Moving '%s' to '%s' failed (%s)."
                cantRemove: "Couldn't overwrite file '%s': %s. Attempts at renaming the existing target file failed."
                cantRenameTryingCopy: "Move operation failed to rename '%s' to '%s' (%s), trying copy+remove instead..."
                couldntRemoveFiles: "Move operation suceeded to copied the file(s) to the target location, but some of the source files couldn't be removed:\n%s\n%s"
                cantCopy: "Move operation failed to copy '%s' to '%s' (%s) after a failed rename attempt (%s)."
            }
            rmdir: {
                emptyPath: "Argument #1 (path) must not be an empty string."
                couldntRemoveFiles: "Some of the files and folders in the specified directory couldn't be removed:\n%s"
                couldntRemoveDir: "Error removing empty directory: %s."

            }
            validateFullPath: {
                badType: "Argument #1 (path) had the wrong type. Expected 'string', got '%s'."
                tooLong: "The specified path exceeded the maximum length limit (%d > %d)."
                invalidChars: "The specifed path contains one or more invalid characters: '%s'."
                reservedNames: "The specified path contains reserved path or file names: '%s'."
                parentPath: "Accessing parent directories is not allowed."
                notFullPath: "The specified path is not a valid full path."
                missingExt: "The specified path is missing a file extension."
        }
    }

    devPattern = ffi.os == "Windows" and "[A-Za-z]:" or "/[^\\\\/]+"
    pathMatch = {
        sep: ffi.os == "Windows" and "\\" or "/"
        pattern: re.compile "^(#{devPattern})((?:[\\\\/][^\\\\/]*[^\\\\/\\s\\.])*)[\\\\/]([^\\\\/]*[^\\\\/\\s\\.])?$"
        invalidChars: '[<>:"|%?%*%z%c;]'
        reservedNames: re.compile "[\\\\/](CON|COM[1-9]|PRN|AUX|NUL|LPT[1-9])(?:[\\\\/].*?)?$", re.ICASE
        maxLen: 255
    }
    @logger = Logger!

    createConfig = (noLoad, configDir) ->
        FileOps.configDir = configDir if configDir
        ConfigHandler or= require "l0.DependencyControl.ConfigHandler"
        FileOps.config or= ConfigHandler "#{FileOps.configDir}/l0.#{FileOps.__name}.json",
                           {toRemove: {}}, nil, noLoad, FileOps.logger
        return FileOps.config

    remove: (paths, recurse, reSchedule) ->
        config = createConfig true
        configLoaded, overallSuccess, details, firstErr = false, true, {}
        paths = {paths} unless type(paths) == "table"

        for path in *paths
            mode, path = FileOps.attributes path, "mode"
            if mode
                rmFunc = mode == "file" and os.remove or FileOps.rmdir
                res, err = rmFunc path, recurse
                unless res
                    firstErr or= err
                    unless reSchedule -- delete operation failed entirely
                        details[path] = {nil, err}
                        overallSuccess = nil
                        continue

                    -- load the FileOps configuration file and reschedule deletions
                    unless configLoaded
                        FileOps.config\load!
                        configLoaded = true
                    config.c.toRemove[path] = os.time!
                    -- mark the operations as failed "for now", indicating a second attempt has been scheduled
                    details[path] = {false, err}
                    overallSuccess = false

                -- delete operation succeeded
                else details[path] = {true}
            -- file not found or permission issue
            else details[path] = {nil, path}

        config\write! if configLoaded
        return overallSuccess, details, firstErr

    runScheduledRemoval: (configDir) ->
        config = createConfig false, configDir
        paths = [path for path, _ in pairs config.c.toRemove]
        if #paths > 0
            -- rescheduled removals will not be rescheduled another time
            FileOps.remove paths, true
            config.c.toRemove = {}
            config\write!
        return true

    copy: ( source, target ) ->
        -- source check
        mode, sourceFullPath, _, _, fileName = FileOps.attributes source, "mode"
        switch mode
            when "directory"
                return false, msgs.copy.dirCopyUnsupported
            when nil
                return false, msgs.copy.genericError\format source, target, sourceFullPath
            when false
                return false, msgs.copy.missingSource\format source

        -- target check
        checkTarget = (target) ->
            mode, targetFullPath = FileOps.attributes target, "mode"
            switch mode
                when "file"
                    return false, msgs.copy.targetExists\format target
                when nil
                    return false, msgs.copy.genericError\format source, target, targetFullPath
                when "directory"
                    target ..= "/#{fileName}"
                    return checkTarget target
            return true, targetFullPath

        success, targetFullPath = checkTarget target
        return false, targetFullPath unless success

        input, msg = io.open sourceFullPath, "rb"
        unless input
            return false, msgs.copy.openError\format "source", sourceFullPath, msg

        output, msg = io.open targetFullPath, "wb"
        unless output
            input\close!
            return false, msgs.copy.openError\format "target", targetFullPath, msg

        success, msg = output\write input\read "*a"
        input\close!
        output\close!

        if success
            return true
        else
            return false, msgs.copy.genericError\format sourceFullPath, targetFullPath, msg


    move: (source, target, overwrite) ->
        mode, err = FileOps.attributes target, "mode"
        if mode == "file"
            unless overwrite
                return false, msgs.move.exists\format source, target, mode
            FileOps.logger\trace msgs.move.overwritingFile, target
            res, _, err = FileOps.remove target
            unless res
                -- can't remove old target file, probably in use or lack of permissions
                -- try to rename and then delete it
                FileOps.logger\debug msgs.move.inUseTryingRename, target
                junkName = "#{target}.depCtrlRemoved"
                -- There might be an old removed file we couldn't delete before
                FileOps.remove junkName
                res = os.rename target, junkName
                unless res
                    return false, msgs.move.cantRemove\format target, err
                -- rename succeeded, now clean up after ourselves
                res, _, err = FileOps.remove junkName, false, true
                unless res
                    FileOps.logger\debug msgs.move.renamedDeletionFailed, junkName, err, msgs.generic.deletionRescheduled

        elseif mode -- a directory (or something else) of the same name as the target file is already present
            return false, msgs.move.exists\format source, target, mode
        elseif mode == nil  -- if retrieving the attributes of a file fails, something is probably wrong
            return false, msgs.move.genericError\format source, target, err

        else -- target file not found, check directory
            res, dir = FileOps.mkdir target, true
            if res == nil
                return false, msgs.move.createDirError\format source, target, err
            elseif res
                FileOps.logger\trace msgs.move.createdDir, dir

        -- at this point the target directory exists and the target file doesn't, move the file
        res, err = os.rename source, target
        unless res
            -- renaming the file failed, could be because of a permission issue
            -- but me might a well be trying to rename over file system boundaries on *nix
            -- so we should try copy + remove before giving up
            FileOps.logger\debug msgs.move.cantRenameTryingCopy, source, target, err
            renErr, res, err = err, FileOps.copy source, target
            unless res
                return false, msgs.move.cantCopy\format source, target, err, renErr
            res, details = FileOps.remove source, false, true  -- TODO: also support directories/recursion, but also require copy to support it

            unless res
                fileList = table.concat ["#{path}: #{res[2]}" for path, res in pairs details when not res[1]], "\n"
                FileOps.logger\debug msgs.move.couldntRemoveFiles, fileList, msgs.generic.deletionRescheduled

        return true

    rmdir: (path, recurse = true) ->
        return nil, msgs.rmdir.emptyPath if path == ""
        mode, path = FileOps.attributes path, "mode"
        return nil, msgs.rmdir.notPath unless mode == "directory"

        if recurse
            -- recursively remove contained files and directories
            toRemove = ["#{path}/#{file}" for file in lfs.dir path]
            res, details = FileOps.remove toRemove, true
            unless res
                fileList = table.concat ["#{path}: #{res[2]}" for path, res in pairs details when not res[1]], "\n"
                return nil, msgs.rmdir.couldntRemoveFiles\format fileList

        -- remove empty directory
        success, err = lfs.rmdir path
        unless success
            return nil, msgs.rmdir.couldntRemoveDir\format err

        return true

    mkdir: (path, isFile) ->
        mode, fullPath, dev, dir, file = FileOps.attributes path, "mode"
        dir = isFile and table.concat({dev,dir or file}) or fullPath

        if mode == nil
            return nil, msgs.attributes.genericError\format fullPath
        elseif not mode
            res, err = lfs.mkdir dir
            if err -- can't create directory (possibly a permission error)
                return nil, msgs.mkdir.createError\format err
            return true, dir
        elseif isFile and mode == "file" -- if the file already exists, so does the directory
            return false, dir
        elseif mode != "directory" -- a file of the same name as the target directory is already present
            return nil, msgs.mkdir.otherExists\format mode
        return false, dir

    attributes: (path, key) ->
        fullPath, dev, dir, file = FileOps.validateFullPath path
        unless fullPath
            path = "#{lfs.currentdir!}/#{path}"
            fullPath, dev, dir, file = FileOps.validateFullPath path
            unless fullPath
                return nil, msgs.attributes.badPath\format dev

        attr, err = lfs.attributes fullPath, key
        if err
            return nil, msgs.attributes.genericError\format err
        elseif not attr
            return false, fullPath, dev, dir, file

        return attr, fullPath, dev, dir, file

    validateFullPath: (path, checkFileExt) ->
        if type(path) != "string"
            return nil, msgs.validateFullPath.badType\format type(path)
        -- expand aegisub path specifiers
        path = aegisub.decode_path path
        -- expand home directory on linux
        homeDir = os.getenv "HOME"
        path = path\gsub "^~", "{#homeDir}/" if homeDir
        -- use single native path separators
        path = path\gsub "[\\/]+", pathMatch.sep
        -- check length
        if #path > pathMatch.maxLen
            return false, msgs.validateFullPath.tooLong\format #path, pathMatch.maxLen
        -- check for invalid characters
        invChar = path\match pathMatch.invalidChars, ffi.os == "Windows" and 3 or nil
        if invChar
            return false, msgs.validateFullPath.invalidChars\format invChar
        -- check for reserved file names
        reserved = pathMatch.reservedNames\match path
        if reserved
            return false, msgs.validateFullPath.reservedNames\format reserved[2].str
        -- check for path escalation
        if path\match "%.%."
            return false, msgs.validateFullPath.parentPath

        -- check if we got a valid full path
        matches = pathMatch.pattern\match path
        dev, dir, file = matches[2].str, matches[3].str, matches[4].str if matches
        unless dev
            return false, msgs.validateFullPath.notFullPath
        if checkFileExt and not (file and file\match ".+%.+")
            return false, msgs.validateFullPath.missingExt

        path = table.concat({dev, dir, file and pathMatch.sep, file})

        return path, dev, dir, file