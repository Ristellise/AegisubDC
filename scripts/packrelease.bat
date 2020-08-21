@echo off
robocopy automation\autoload build-dir\Release\automation\autoload /IS /IT
robocopy automation\include build-dir\Release\automation\include /IS /IT
robocopy automation\include\aegisub build-dir\Release\automation\include\aegisub /IS /IT
robocopy automation\include\ln build-dir\Release\automation\include\ln /IS /IT
robocopy automation\demos build-dir\Release\automation\demos /IS /IT
robocopy "distro-extras" build-dir\Release\ /IS /IT
robocopy "distro-extras\csri" build-dir\Release\csri /IS /IT
robocopy "distro-extras\dictionaries" build-dir\Release\dictionaries /IS /IT
robocopy "C:\Windows\System32" "build-dir\Release" AviSynth.dll /IS /IT
robocopy "C:\Boost\lib" "build-dir\Release" boost_filesystem-vc142-mt-x64-1_73.dll boost_locale-vc142-mt-x64-1_73.dll boost_regex-vc142-mt-x64-1_73.dll boost_thread-vc142-mt-x64-1_73.dll /IS /IT
robocopy "C:\Program Files (x86)\AviSynth+\plugins64+" "build-dir\Release" DirectShowSource.dll /IS /IT
robocopy "vendor\exten\ffms\x64" "build-dir\Release" ffms2.dll /IS /IT
robocopy "vendor\exten\freetype\win64" "build-dir\Release" freetype.dll /IS /IT
robocopy "vendor\exten\fribidi-1.0.10\build\lib" "build-dir\Release" fribidi-0.dll /IS /IT
robocopy "vendor\exten\icu4c\bin64" "build-dir\Release" icudt67.dll icuin67.dll icuuc67.dll /IS /IT
robocopy "vendor\exten\fftw" "build-dir\Release" libfftw3.dll /IS /IT
robocopy "vendor\exten\hunspell\msvc\x64\Release_dll" "build-dir\Release" libhunspell.dll /IS /IT
robocopy "vendor\exten\libiconv\lib" "build-dir\Release" iconv.dll /IS /IT
robocopy "vendor\exten\uchardet\build\src\Release" "build-dir\Release" uchardet.dll /IS /IT
robocopy "vendor\exten\wxWidgets\lib\vc14x_x64_dll" "build-dir\Release" wxbase314u_vc14x_x64.dll wxbase314u_xml_vc14x_x64.dll wxmsw314u_core_vc14x_x64.dll wxmsw314u_gl_vc14x_x64.dll wxmsw314u_stc_vc14x_x64.dll /IS /IT
robocopy "vendor\exten\zlib\contrib\vstudio\vc14\x64\ZlibDllRelease" "build-dir\Release" zlibwapi.dll /IS /IT
rename "build-dir\Release\libfftw3.dll" "libfftw3-3.dll"
rename "build-dir\Release\iconv.dll" "libiconv.dll"
pause