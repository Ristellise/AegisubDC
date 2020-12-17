local _ = [[---------- Usage ----------

1. Create a DownloadManager:

	manager = DownloadManager!

	You can supply a single library search path or a table of search paths for the DownloadManager library.
	On Aegisub, this will default to the system and user DownloadManager module directories.
	Otherwise the default library search path will be used.

2. Add some downloads:

	manager\addDownload "https://a.real.website", "out3"

	If you have a SHA-1 hash to check the downloaded file against, use:
		manager\addDownload "https://a.real.website", "out2", "b52854d1f79de5ebeebf0160447a09c7a8c2cde4"

	You may want to keep a reference of your download to check its result later:
		myDownload = manager\addDownload "https://a.real.website", "out2",

	Downloads will start immediately. Do whatever you want here while downloads happen in the background.
	The output file must contain a full path and file name. There is no working directory and automatic file naming is unsupported.

3. Wait for downloads to finish:

	Call manager\waitForFinish(cb) to loop until remaining downloads finish.
	The progress callback can call manager\cancel! or manager\clear! to interrupt and break open connections.

	The current overall progress will be passed to the provided callback as a number in range 0-100:
		manager\waitForFinish ( progress ) ->
			print tostring progress

4. Check for download errors:

	Check a specific download:
		error dl.error if dl.error

	Print all failed downloads:
		for dl in *manager.failedDownloads
			print "Download ##{dl.id} error: #{dl.error}"

	Get a descriptive overall error message:
		error = table.concat ["#{dl.url}: #{dl.error}" for dl in *manager.failedDownloads], "\n"

5. Clear all downloads:

	manager\clear!

	Removes all downloads from the downloader and resets all counters.


Error Handling:
	Errors are handled in typical Lua fashion.
	DownloadManager will only throw an error in case the library failed to load.
	Errors will also be thrown if the wrong type is passed in to certain functions to avoid
	missing incorrect usage.
	If any other error is encountered the script will return nil along with an error message.

]]
local havelfs, lfs = pcall(require, "lfs")
local ffi = require("ffi")
local requireffi = require("requireffi.requireffi")
ffi.cdef([[struct CDlM;
typedef struct CDlM CDlM;
typedef unsigned int uint;
 CDlM* CDlM_new ( void );
 uint CDlM_addDownload ( CDlM *mgr, const char *url,
                                   const char *outputFile, const char *expectedHash,
                                   const char *expectedETag );
 double CDlM_progress ( CDlM *mgr );
 int CDlM_busy ( CDlM *mgr );
 int CDlM_checkDownload ( CDlM *mgr, uint i );
 const char* CDlM_getError ( CDlM *mgr, uint i );
 _Bool CDlM_fileWasCached ( CDlM *mgr, uint i );
 const char* CDlM_getETag ( CDlM *mgr, uint i );
 void CDlM_terminate ( CDlM *mgr );
 void CDlM_clear ( CDlM *mgr );
 const char* CDlM_getFileSHA1 ( const char *filename );
 const char* CDlM_getStringSHA1 ( const char *string );
 uint CDlM_version ( void );
 void CDlM_freeDM ( CDlM *mgr );
 _Bool CDlM_isInternetConnected( void );
int usleep(unsigned int);
void Sleep(unsigned long);
]])
local DMVersion = 0x000400
local DM, loadedLibraryPath = requireffi("DM.DownloadManager.DownloadManager")
local libVer = DM.CDlM_version()
if libVer < DMVersion or math.floor(libVer / 65536 % 256) > math.floor(DMVersion / 65536 % 256) then
  error("Library version mismatch. Wanted " .. tostring(DMVersion) .. ", got " .. tostring(libVer) .. ".")
end
local sleep = ffi.os == "Windows" and (function(ms)
  if ms == nil then
    ms = 100
  end
  return ffi.C.Sleep(ms)
end) or (function(ms)
  if ms == nil then
    ms = 100
  end
  return ffi.C.usleep(ms * 1000)
end)
local msgs = {
  notInitialized = "%s not initialized.",
  addMissingArgs = "Required arguments #1 (url) or #2 (outfile) had the wrong type. Expected string, got '%s' and '%s'.",
  getMissingArg = "Required argument (filename) was either absent or the wrong type. Expected string, got '%s'.",
  checkMissingArgs = "Required arguments #1 (filename/string) and #2 (expected) or the wrong type. Expected string, got '%s' and '%s'.",
  outNoFullPath = "Argument #2 (outfile) must contain a full path (relative paths not supported), got %s.",
  outNoFile = "Argument #2 (outfile) must contain a full path with file name, got %s.",
  failedToOpen = "Could not open file %s.",
  hashMismatch = "Hash mismatch. Got %s, expected %s.",
  horriblyWrong = "Something has gone horribly wrong???",
  cacheFailure = "Couldn't use cache. Message: %s",
  failedToAdd = "Could not add download for some reason."
}
local sanitizeFile
sanitizeFile = function(filename, acceptDir)
  do
    local homeDir = os.getenv("HOME")
    if homeDir then
      filename = filename:gsub("^~/", homeDir .. "/")
    end
  end
  local dev, dir, file = filename:match("^(" .. tostring(ffi.os == 'Windows' and '%a:[/\\]' or '/') .. ")(.*[/\\])(.*)$")
  if not dev or #dir < 1 then
    return nil, msgs.outNoFullPath:format(filename)
  elseif not acceptDir and #file < 1 then
    return nil, msgs.outNoFile:format(filename)
  end
  dir = dev .. dir
  if havelfs then
    local mode, err = lfs.attributes(dir, "mode")
    if mode ~= "directory" then
      if err then
        return nil, err
      end
      local res
      res, err = lfs.mkdir(dir)
      if err then
        return nil, err
      end
    end
  else
    os.execute("mkdir " .. tostring(ffi.os == 'Windows' and '' or '-p ') .. "\"" .. tostring(dir) .. "\"")
  end
  return dir .. file
end
local ETagCache
do
  local _class_0
  local copyFile
  local _base_0 = {
    cachedFile = function(self, cacheName)
      return self.cacheDir .. cacheName
    end,
    cachedFileExists = function(self, cacheName)
      if cacheName == nil then
        return false
      end
      local file = io.open(self:cachedFile(cacheName), 'rb')
      if file == nil then
        return false
      end
      file:close()
      return true
    end,
    useCache = function(self, download)
      local err, msg = copyFile(self:cachedFile(download.etag), download.outfile)
      if err == nil then
        return err, msg
      end
      return true
    end,
    cache = function(self, download)
      local err, msg = copyFile(download.outfile, self:cachedFile(download.etag))
      if err == nil then
        return err, msg
      end
      return true
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, cacheDir)
      self.cacheDir = cacheDir
    end,
    __base = _base_0,
    __name = "ETagCache"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  copyFile = function(source, target)
    local input, msg = io.open(source, 'rb')
    if input == nil then
      return input, msg
    end
    local output
    output, msg = io.open(target, 'wb')
    if output == nil then
      input:close()
      return output, msg
    end
    local err
    err, msg = output:write(input:read('*a'))
    if err == nil then
      input:close()
      output:close()
      return err, msg
    end
    input:close()
    output:close()
    return true
  end
  ETagCache = _class_0
end
local DownloadManager
do
  local _class_0
  local freeManager
  local _base_0 = {
    loadedLibraryPath = loadedLibraryPath,
    addDownload = function(self, url, outfile, sha1, etag)
      if not (DM) then
        return nil, msgs.notInitialized:format(self.__name)
      end
      local urlType, outfileType = type(url), type(outfile)
      if urlType ~= "string" or outfileType ~= "string" then
        return nil, msgs.addMissingArgs:format(urlType, outfileType)
      end
      local msg
      outfile, msg = sanitizeFile(outfile)
      if outfile == nil then
        return outfile, msg
      end
      if "string" == type(sha1) then
        sha1 = sha1:lower()
      else
        sha1 = nil
      end
      if etag and "string" ~= type(etag) then
        etag = nil
      end
      if etag and self.cache and not self.cache:cachedFileExists(etag) then
        etag = nil
      end
      local id = DM.CDlM_addDownload(self.manager, url, outfile, sha1, etag)
      if id == 0 then
        return nil, msgs.failedToAdd
      end
      local download = {
        id = id,
        url = url,
        outfile = outfile,
        sha1 = sha1,
        etag = etag
      }
      table.insert(self.downloads, download)
      return download
    end,
    progress = function(self)
      if not (DM) then
        return nil, msgs.notInitialized:format(self.__name)
      end
      return math.floor(100 * DM.CDlM_progress(self.manager))
    end,
    cancel = function(self)
      if not (DM) then
        return nil, msgs.notInitialized:format(self.__name)
      end
      return DM.CDlM_terminate(self.manager)
    end,
    clear = function(self)
      if not (DM) then
        return nil, msgs.notInitialized:format(self.__name)
      end
      DM.CDlM_clear(self.manager)
      self.downloads = { }
      self.failedDownloads = { }
    end,
    waitForFinish = function(self, callback)
      if not (DM) then
        return nil, msgs.notInitialized:format(self.__name)
      end
      while 0 ~= DM.CDlM_busy(self.manager) do
        if callback and not callback(self:progress()) then
          return 
        end
        sleep()
      end
      local pushFailed
      pushFailed = function(download, message)
        download.failed = true
        download.error = message
        return table.insert(self.failedDownloads, download)
      end
      local _list_0 = self.downloads
      for _index_0 = 1, #_list_0 do
        local download = _list_0[_index_0]
        local err = DM.CDlM_getError(self.manager, download.id)
        if err ~= nil then
          pushFailed(download, ffi.string(err))
        end
        if self.cache then
          if DM.CDlM_fileWasCached(self.manager, download.id) then
            local msg
            err, msg = self.cache:useCache(download)
            if err == nil then
              pushFailed(download, msgs.cacheFailure:format(msg))
            end
          else
            local newETag = DM.CDlM_getETag(self.manager, download.id)
            if newETag ~= nil then
              download.etag = ffi.string(newETag)
              self.cache:cache(download)
            end
          end
        end
        if "function" == type(download.callback) then
          download:callback(self)
        end
      end
    end,
    getFileSHA1 = function(self, filename)
      local filenameType = type(filename)
      if filenameType ~= "string" then
        return nil, msgs.getMissingArg:format(filenameType)
      end
      local result = DM.CDlM_getFileSHA1(filename)
      if result == nil then
        return nil, msgs.failedToOpen:format(filename)
      else
        result = ffi.string(result)
      end
      return result
    end,
    checkFileSHA1 = function(self, filename, expected)
      local filenameType, expectedType = type(filename), type(expected)
      if filenameType ~= "string" or expectedType ~= "string" then
        return nil, msgs.checkMissingArgs:format(filenameType, expectedType)
      end
      local result, msg = self:getFileSHA1(filename)
      if result == nil then
        return result, msg
      elseif result == expected:lower() then
        return true
      else
        return false, msgs.hashMismatch:format(result, expected)
      end
    end,
    checkStringSHA1 = function(self, string, expected)
      local stringType, expectedType = type(string), type(expected)
      if stringType ~= "string" or expectedType ~= "string" then
        msgs.checkMissingArgs:format(stringType, expectedType)
      end
      local result = DM.CDlM_getStringSHA1(string)
      if result == nil then
        return nil, msgs.horriblyWrong
      else
        result = ffi.string(result)
      end
      if result == expected:lower() then
        return true
      else
        return false, msgs.hashMismatch:format(result, expected)
      end
    end,
    isInternetConnected = function(self)
      return DM.CDlM_isInternetConnected()
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, etagCacheDir)
      self.manager = ffi.gc(DM.CDlM_new(), freeManager)
      self.downloads = { }
      self.failedDownloads = { }
      if etagCacheDir then
        local result, message = sanitizeFile(etagCacheDir:gsub("[/\\]*$", "/", 1), true)
        assert(message == nil, message)
        self.cache = ETagCache(result)
      end
    end,
    __base = _base_0,
    __name = "DownloadManager"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.version = 0x000500
  self.version_string = "0.5.0"
  self.__depCtrlInit = function(DependencyControl)
    self.version = DependencyControl({
      name = tostring(self.__name),
      version = self.version_string,
      description = "Download things with libcurl without blocking Lua.",
      author = "torque",
      url = "https://github.com/TypesettingTools/ffi-experiments",
      moduleName = "DM." .. tostring(self.__name),
      feed = "https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json"
    })
  end
  freeManager = function(manager)
    return DM.CDlM_freeDM(manager)
  end
  DownloadManager = _class_0
  return _class_0
end
