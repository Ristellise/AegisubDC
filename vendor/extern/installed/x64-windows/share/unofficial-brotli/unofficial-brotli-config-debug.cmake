#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "unofficial::brotli::brotlienc" for configuration "Debug"
set_property(TARGET unofficial::brotli::brotlienc APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(unofficial::brotli::brotlienc PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/debug/lib/brotlienc.lib"
  IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG "unofficial::brotli::brotlicommon"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/debug/bin/brotlienc.dll"
  )

list(APPEND _IMPORT_CHECK_TARGETS unofficial::brotli::brotlienc )
list(APPEND _IMPORT_CHECK_FILES_FOR_unofficial::brotli::brotlienc "${_IMPORT_PREFIX}/debug/lib/brotlienc.lib" "${_IMPORT_PREFIX}/debug/bin/brotlienc.dll" )

# Import target "unofficial::brotli::brotlidec" for configuration "Debug"
set_property(TARGET unofficial::brotli::brotlidec APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(unofficial::brotli::brotlidec PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/debug/lib/brotlidec.lib"
  IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG "unofficial::brotli::brotlicommon"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/debug/bin/brotlidec.dll"
  )

list(APPEND _IMPORT_CHECK_TARGETS unofficial::brotli::brotlidec )
list(APPEND _IMPORT_CHECK_FILES_FOR_unofficial::brotli::brotlidec "${_IMPORT_PREFIX}/debug/lib/brotlidec.lib" "${_IMPORT_PREFIX}/debug/bin/brotlidec.dll" )

# Import target "unofficial::brotli::brotlicommon" for configuration "Debug"
set_property(TARGET unofficial::brotli::brotlicommon APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(unofficial::brotli::brotlicommon PROPERTIES
  IMPORTED_IMPLIB_DEBUG "${_IMPORT_PREFIX}/debug/lib/brotlicommon.lib"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/debug/bin/brotlicommon.dll"
  )

list(APPEND _IMPORT_CHECK_TARGETS unofficial::brotli::brotlicommon )
list(APPEND _IMPORT_CHECK_FILES_FOR_unofficial::brotli::brotlicommon "${_IMPORT_PREFIX}/debug/lib/brotlicommon.lib" "${_IMPORT_PREFIX}/debug/bin/brotlicommon.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
