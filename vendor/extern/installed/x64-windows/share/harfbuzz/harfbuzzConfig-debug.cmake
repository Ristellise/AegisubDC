#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "harfbuzz::harfbuzz" for configuration "Debug"
set_property(TARGET harfbuzz::harfbuzz APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(harfbuzz::harfbuzz PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/debug/lib/harfbuzz.lib"
  IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG "${_IMPORT_PREFIX}/debug/lib/freetyped.lib;${_IMPORT_PREFIX}/debug/lib/icuucd.lib;${_IMPORT_PREFIX}/debug/lib/icudtd.lib"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/debug/bin/harfbuzz.dll"
  )

list(APPEND _IMPORT_CHECK_TARGETS harfbuzz::harfbuzz )
list(APPEND _IMPORT_CHECK_FILES_FOR_harfbuzz::harfbuzz "${_IMPORT_PREFIX}/debug/lib/harfbuzz.lib" "${_IMPORT_PREFIX}/debug/bin/harfbuzz.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
