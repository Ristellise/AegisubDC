@echo off
robocopy automation build-dir\RelWithDebInfo\automation /IS /IT /S
robocopy automation\demos build-dir\RelWithDebInfo\automation\demos /IS /IT
robocopy "distro-extras" build-dir\RelWithDebInfo\ /IS /IT /S
robocopy "C:\Windows\System32" "build-dir\RelWithDebInfo" AviSynth.dll /IS /IT
robocopy "C:\Boost\lib" "build-dir\RelWithDebInfo" boost_filesystem-vc142-mt-x64-1_73.dll boost_locale-vc142-mt-x64-1_73.dll boost_regex-vc142-mt-x64-1_73.dll boost_thread-vc142-mt-x64-1_73.dll /IS /IT
robocopy "C:\Program Files (x86)\AviSynth+\plugins64+" "build-dir\RelWithDebInfo" DirectShowSource.dll /IS /IT
robocopy "vendor\exten\ffms\x64" "build-dir\RelWithDebInfo" ffms2.dll /IS /IT
robocopy "vendor\exten\freetype\win64" "build-dir\RelWithDebInfo" freetype.dll /IS /IT
robocopy "vendor\exten\fribidi-1.0.10\build\lib" "build-dir\RelWithDebInfo" fribidi-0.dll /IS /IT
robocopy "vendor\exten\icu4c\bin64" "build-dir\RelWithDebInfo" icudt67.dll icuin67.dll icuuc67.dll /IS /IT
robocopy "vendor\exten\fftw" "build-dir\RelWithDebInfo" libfftw3.dll /IS /IT
robocopy "vendor\exten\hunspell\msvc\x64\Release_dll" "build-dir\RelWithDebInfo" libhunspell.dll /IS /IT
robocopy "vendor\exten\libiconv\lib" "build-dir\RelWithDebInfo" iconv.dll /IS /IT
robocopy "vendor\exten\uchardet\build\src\Release" "build-dir\RelWithDebInfo" uchardet.dll /IS /IT
robocopy "vendor\exten\wxWidgets\lib\vc14x_x64_dll" "build-dir\RelWithDebInfo" wxbase314u_vc14x_x64.dll wxbase314u_xml_vc14x_x64.dll wxmsw314u_core_vc14x_x64.dll wxmsw314u_gl_vc14x_x64.dll wxmsw314u_stc_vc14x_x64.dll /IS /IT
robocopy "vendor\exten\zlib\contrib\vstudio\vc14\x64\ZlibDllRelease" "build-dir\RelWithDebInfo" zlibwapi.dll /IS /IT
rename "build-dir\RelWithDebInfo\libfftw3.dll" "libfftw3-3.dll"
rename "build-dir\RelWithDebInfo\iconv.dll" "libiconv.dll"
pause