cmake -S . -B build-dir -G "Visual Studio 16 2019" -A x64 ^
    -DWITH_AVISYNTH=OFF -DWITH_CSRI=ON -DWITH_DIRECTSOUND=ON ^
    -DWITH_FFMS2=ON -DWITH_FFTW3=ON -DWITH_HUNSPELL=ON -DWITH_UCHARDET=ON ^
    -DWITH_XAUDIO2=ON -DWITH_BUILD_CREDIT=ON -DWITH_STARTUPLOG=OFF ^
    -DBUILD_CREDIT="\"Daydream Cafe Edition [Shinon]\"" ^
    -Dass_INCLUDE_DIRS="%cd%/vendor/exten/libass/libass" -Dass_LIBRARIES="%cd%/vendor/exten/libass/bin/Release_x64/libass.lib" ^
    -DIconv_INCLUDE_DIR="%cd%/vendor/exten/libiconv/include" -DIconv_LIBRARY="%cd%/vendor/exten/libiconv/lib/iconv.lib" ^
    -DICU_ROOT="%cd%/vendor/exten/icu4c" -DwxWidgets_ROOT_DIR="%cd%/vendor/exten/wxWidgets" ^
    -DZLIB_ROOT="%cd%/vendor/exten/zlib" -DZLIB_LIBRARY="%cd%/vendor/exten/zlib/contrib/vstudio/vc14/x64/ZlibDllRelease/zlib.lib" ^
    -DFFMS2_INCLUDE_DIRS="%cd%/vendor/exten/ffms/include" -DFFMS2_LIBRARIES="%cd%/vendor/exten/ffms/x64/ffms2.lib" ^
    -DFFTW_ROOT="%cd%/vendor/exten/fftw" -DFFTW_LIB="%cd%/vendor/exten/fftw/fftw3.lib" -DFFTW_INCLUDES="%cd%/vendor/exten/fftw" ^
    -DFFTWF_LIB="%cd%/vendor/exten/fftw/fftw3f.lib" -DFFTWL_LIB="%cd%/vendor/exten/fftw/fftw3l.lib" ^
    -DHUNSPELL_INCLUDE_DIR="%cd%/vendor/exten/hunspell/src" -DHUNSPELL_LIBRARIES="%cd%/vendor/exten/hunspell/msvc/x64/Release_dll/libhunspell.lib" ^
    -Duchardet_INCLUDE_DIRS="%cd%/vendor/exten/uchardet/src" -Duchardet_LIBRARIES="%cd%/vendor/exten/uchardet/build/src/Release/uchardet.lib"
pause