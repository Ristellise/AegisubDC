find_path(XAudio2redist_INCLUDE_DIRS
  NAMES xaudio2redist.h
)
find_library(XAudio2redist_LIBRARIES
  NAMES xaudio2_9redist
)
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(XAudio2redist
  FOUND_VAR XAudio2redist_FOUND
  REQUIRED_VARS
    XAudio2redist_LIBRARIES
    XAudio2redist_INCLUDE_DIRS
)
