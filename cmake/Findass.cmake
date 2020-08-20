find_package(PkgConfig QUIET)
pkg_check_modules(PC_ass QUIET libass)
find_path(ass_INCLUDE_DIRS
  NAMES ass/ass.h ass/ass_types.h
  PATH_SUFFIXES libass
  HINTS ${PC_ass_INCLUDE_DIRS}
)
find_library(ass_LIBRARIES
  NAMES ass
  HINTS ${PC_ass_LIBRARY_DIRS}
)
set(ass_VERSION ${PC_ass_VERSION})
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ass
  FOUND_VAR ass_FOUND
  REQUIRED_VARS
    ass_LIBRARIES
    ass_INCLUDE_DIRS
  VERSION_VAR ass_VERSION
)
