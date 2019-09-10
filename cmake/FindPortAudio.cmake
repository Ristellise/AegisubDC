find_package(PkgConfig QUIET)
pkg_check_modules(PC_portaudio QUIET portaudio-2.0)
find_path(PortAudio_INCLUDE_DIRS
  NAMES portaudio.h
  HINTS ${PC_portaudio_INCLUDE_DIRS}
)
find_library(PortAudio_LIBRARIES
  NAMES portaudio
  HINTS ${PC_portaudio_LIBRARY_DIRS}
)
set(PortAudio_VERSION ${PC_portaudio_VERSION})
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PortAudio
  FOUND_VAR PortAudio_FOUND
  REQUIRED_VARS
    PortAudio_LIBRARIES
    PortAudio_INCLUDE_DIRS
  VERSION_VAR PortAudio_VERSION
)
