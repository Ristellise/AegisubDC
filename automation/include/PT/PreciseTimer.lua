local ffi = require("ffi")
local requireffi = require("requireffi.requireffi")
ffi.cdef([[struct CPT;
typedef struct CPT CPT;
 CPT* startTimer( void );
 double getDuration( CPT *pt );
 unsigned int version( void );
 void freeTimer( CPT *pt );
int usleep(unsigned int);
void Sleep(unsigned long);
]])
local PTVersion = 0x000100
local PT, loadedLibraryPath = requireffi("PT.PreciseTimer.PreciseTimer")
local libVer = PT.version()
if libVer < PTVersion or math.floor(libVer / 65536 % 256) > math.floor(PTVersion / 65536 % 256) then
  error("Library version mismatch. Wanted " .. tostring(PTVersion) .. ", got " .. tostring(libVer) .. ".")
end
local PreciseTimer
do
  local _class_0
  local freeTimer
  local _base_0 = {
    loadedLibraryPath = loadedLibraryPath,
    timeElapsed = function(self)
      return PT.getDuration(self.timer)
    end,
    sleep = ffi.os == "Windows" and (function(ms)
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
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.timer = ffi.gc(PT.startTimer(), freeTimer)
    end,
    __base = _base_0,
    __name = "PreciseTimer"
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
  self.version = 0x000106
  self.version_string = "0.1.6"
  self.__depCtrlInit = function(DependencyControl)
    self.version = DependencyControl({
      name = tostring(self.__name),
      version = self.version_string,
      description = "Measure times down to the nanosecond. Except not really.",
      author = "torque",
      url = "https://github.com/TypesettingTools/ffi-experiments",
      moduleName = "PT." .. tostring(self.__name),
      feed = "https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json"
    })
  end
  freeTimer = function(timer)
    return PT.freeTimer(timer)
  end
  PreciseTimer = _class_0
  return _class_0
end
