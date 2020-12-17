local version = '0.1.2'
local ffi = require('ffi')
local libPrefix, libSuffix = 'lib', '.so'
local _exp_0 = ffi.os
if 'Windows' == _exp_0 then
  libPrefix = ''
  libSuffix = '.dll'
elseif 'OSX' == _exp_0 then
  libSuffix = '.dylib'
end
local packagePaths
packagePaths = function(namespace, libraryName, useCLibrarySearchPath)
  local paths = { }
  local fixedLibraryName = namespace .. '/' .. libPrefix .. libraryName .. libSuffix
  package.path:gsub("([^;]+)", function(path)
    if path:match("/%?/init%.lua$") then
      return 
    end
    path = path:gsub("//?%?%.lua$", '/' .. fixedLibraryName)
    table.insert(paths, path)
  end)
  if useCLibrarySearchPath then
    table.insert(paths, libraryName)
  end
  return paths
end
local tryLoad
tryLoad = function(name, paths)
  local messages = {
    ("FFI could not load %q. Search paths:"):format(name)
  }
  local success = false
  for _index_0 = 1, #paths do
    local path = paths[_index_0]
    local library
    success, library = pcall(ffi.load, path)
    if success then
      return library, path
    else
      table.insert(messages, ("  - %q (%s)"):format(path, library:gsub("[\n\t\r]", " ")))
    end
  end
  return error(table.concat(messages, "\n"))
end
local requireffi
requireffi = function(self, name, useCLibrarySearchPath)
  if useCLibrarySearchPath == nil then
    useCLibrarySearchPath = true
  end
  local libraryName
  local namespace = name:gsub('%.?([^%.]+)$', function(libName)
    libraryName = libName
    return ''
  end)
  namespace = namespace:gsub('%.', '/')
  return tryLoad(name, packagePaths(namespace, libraryName, useCLibrarySearchPath))
end
local versionRecord
versionRecord = {
  version = version,
  __depCtrlInit = function(DependencyControl)
    versionRecord.version = DependencyControl({
      name = "requireffi",
      version = version,
      description = "FFI.load wrapper for loading C modules.",
      author = "torque",
      url = "https://github.com/TypesettingTools/ffi-experiments",
      moduleName = "requireffi.requireffi",
      feed = "https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json"
    })
  end
}
return setmetatable(versionRecord, {
  __call = requireffi
})
