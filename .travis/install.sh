#! /bin/bash

set -e

if [ "$TRAVIS_OS_NAME" = 'linux' ]; then
  # Remove the CMake provided by travis
  sudo rm -rf /usr/local/cmake*
  if [ "$BUILD_SUIT" = 'autotools' ]; then
    if [ ! -z "$WITH_COVERALLS" ]; then
      sudo pip3 install -U cpp-coveralls
    fi
    git submodule --quiet init
    git submodule --quiet update vendor/googletest
  else
    pushd /usr/src/googletest
    sudo cmake .
    sudo make install -j2
    popd
  fi
fi
sudo luarocks install busted > /dev/null
sudo luarocks install moonscript > /dev/null
sudo luarocks install uuid > /dev/null
