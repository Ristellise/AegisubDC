local ffi = require("ffi")
local requireffi = require("requireffi.requireffi")
ffi.cdef([[ void lock( void );
 bool try_lock( void );
 void unlock( void );
 unsigned int version( void );
]])
local BM, loadedLibraryPath = requireffi("BM.BadMutex.BadMutex")
local BMVersion = 0x000100
local libVer = BM.version()
if libVer < BMVersion or math.floor(libVer / 65536 % 256) > math.floor(BMVersion / 65536 % 256) then
  error("Library version mismatch. Wanted " .. tostring(BMVersion) .. ", got " .. tostring(libVer) .. ".")
end
local BadMutex
BadMutex = {
  lock = function()
    return BM.lock()
  end,
  tryLock = function()
    return BM.try_lock()
  end,
  unlock = function()
    return BM.unlock()
  end,
  version = 0x000103,
  __depCtrlInit = function(DependencyControl)
    BadMutex.version = DependencyControl({
      name = "BadMutex",
      version = BadMutex.version,
      description = "A global mutex.",
      author = "torque",
      url = "https://github.com/TypesettingTools/ffi-experiments",
      moduleName = "BM.BadMutex",
      feed = "https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json"
    })
  end,
  loadedLibraryPath = loadedLibraryPath
}
return BadMutex
