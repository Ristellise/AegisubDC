cmake -S . -B "build-dir" -G "Visual Studio 16 2019" -A x64 ^
    -DWITH_AVISYNTH=OFF -DWITH_CSRI=ON -DWITH_DIRECTSOUND=ON -DWITH_FFMS2=ON -DWITH_FFTW3=ON -DWITH_HUNSPELL=ON -DWITH_UCHARDET=ON -DWITH_XAUDIO2=ON -DWITH_BUILD_CREDIT=ON -DWITH_STARTUPLOG=OFF -DBUILD_CREDIT="\"Daydream Cafe Edition [Shinon]\"" -DCMAKE_TOOLCHAIN_FILE="%cd%/vendor/extern/scripts/buildsystems/vcpkg.cmake" ^
    -DBOOST_ROOT="C:\Boost" ^
    -Dass_INCLUDE_DIRS="%cd%/vendor/extra/libass/libass" ^
    -Dass_LIBRARIES="%cd%/vendor/extra/libass/bin/Release_x64/libass.lib" ^
    -DFFMS2_INCLUDE_DIRS="%cd%/vendor/extra/ffms/include" ^
    -DFFMS2_LIBRARIES="%cd%/vendor/extra/ffms/x64/ffms2.lib" ^
    -DFFMS2_LIBRARIES="%cd%/vendor/extra/ffms/x64/ffms2.lib" ^
    -DFFTW_LIB="%cd%/vendor/extern/installed/x64-windows/lib/fftw3.lib" ^
    -DFFTWL_LIB="%cd%/vendor/extern/installed/x64-windows/lib/fftw3l.lib" ^
    -DFFTWF_LIB="%cd%/vendor/extern/installed/x64-windows/lib/fftw3f.lib" ^
    -DHUNSPELL_LIBRARIES="%cd%/vendor/extern/installed/x64-windows/lib/libhunspell.lib" ^
    -DHUNSPELL_INCLUDE_DIR="%cd%/vendor/extern/installed/x64-windows/include" ^
    -DwxWidgets_ROOT_DIR="%cd%/vendor/extra/wxWidgets" ^
    -DwxWidgets_LIB_DIR="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll" ^
    -DwxWidgets_wxrc_EXECUTABLE:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxrc.exe" ^
    -DWX_base:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxbase31u.lib" ^
    -DWX_tiff:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxtiff.lib" ^
    -DWX_png:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxpng.lib" ^
    -DwxWidgets_ROOT_DIR:PATH="%cd%/vendor/extra/wxWidgets" ^
    -DWX_expat:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxexpat.lib" ^
    -DWX_jpeg:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxjpeg.lib" ^
    -DWX_stc:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxmsw31u_stc.lib" ^
    -DWX_core:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxmsw31u_core.lib" ^
    -DWX_gl:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxmsw31u_gl.lib" ^
    -DWX_zlib:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxzlib.lib" ^
    -DWX_xml:FILEPATH="%cd%/vendor/extra/wxWidgets/lib/vc14x_x64_dll/wxbase31u_xml.lib" ^
    -DCMAKE_TOOLCHAIN_FILE="%cd%/vendor/extern/scripts/buildsystems/vcpkg.cmake"


pause