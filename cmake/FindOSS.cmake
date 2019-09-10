find_package(PkgConfig QUIET)
pkg_check_modules(PC_oss QUIET oss)
find_path(OSS_INCLUDE_DIRS
  NAMES sys/soundcard.h
  HINTS ${PC_oss_INCLUDE_DIRS}
)
set(OSS_VERSION ${PC_ass_VERSION})
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OSS
  FOUND_VAR OSS_FOUND
  REQUIRED_VARS
    OSS_INCLUDE_DIRS
  VERSION_VAR OSS_VERSION
)
