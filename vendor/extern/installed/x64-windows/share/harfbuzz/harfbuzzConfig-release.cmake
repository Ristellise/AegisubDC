#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "harfbuzz::harfbuzz" for configuration "Release"
set_property(TARGET harfbuzz::harfbuzz APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(harfbuzz::harfbuzz PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/harfbuzz.lib"
  IMPORTED_LINK_INTERFACE_LIBRARIES_RELEASE "${_IMPORT_PREFIX}/lib/freetype.lib;${_IMPORT_PREFIX}/lib/icuuc.lib;${_IMPORT_PREFIX}/lib/icudt.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/harfbuzz.dll"
  )

list(APPEND _IMPORT_CHECK_TARGETS harfbuzz::harfbuzz )
list(APPEND _IMPORT_CHECK_FILES_FOR_harfbuzz::harfbuzz "${_IMPORT_PREFIX}/lib/harfbuzz.lib" "${_IMPORT_PREFIX}/bin/harfbuzz.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
