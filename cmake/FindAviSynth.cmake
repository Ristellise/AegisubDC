find_package(PkgConfig QUIET)
pkg_check_modules(PC_AviSynth QUIET AviSynth)
find_path(AviSynth_INCLUDE_DIRS
  NAMES avisynth.h
  HINTS ${PC_AviSynth_INCLUDE_DIRS}
)
find_library(AviSynth_LIBRARIES
  NAMES avisynth
  PATH_SUFFIXES c_api
  HINTS ${PC_AviSynth_LIBRARY_DIRS}
)
set(AviSynth_VERSION ${PC_AviSynth_VERSION})
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(AviSynth
  FOUND_VAR AviSynth_FOUND
  REQUIRED_VARS
    AviSynth_LIBRARIES
    AviSynth_INCLUDE_DIRS
  VERSION_VAR AviSynth_VERSION
)
