find_package(PkgConfig QUIET)
pkg_check_modules(PC_FFMS2 QUIET ffms2)
find_path(FFMS2_INCLUDE_DIRS
  NAMES ffms.h ffmscompat.h
  HINTS ${PC_FFMS2_INCLUDE_DIRS}
)
find_library(FFMS2_LIBRARIES
  NAMES ffms2
  HINTS ${PC_FFMS2_LIBRARY_DIRS}
)
set(FFMS2_VERSION ${PC_FFMS2_VERSION})
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(FFMS2
  FOUND_VAR FFMS2_FOUND
  REQUIRED_VARS
    FFMS2_LIBRARIES
    FFMS2_INCLUDE_DIRS
  VERSION_VAR FFMS2_VERSION
)
