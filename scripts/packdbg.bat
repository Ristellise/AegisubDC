@echo off
robocopy automation\autoload build-dir\Debug\automation\autoload /IS /IT
robocopy automation\include build-dir\Debug\automation\include /IS /IT
robocopy automation\include\aegisub build-dir\Debug\automation\include\aegisub /IS /IT
robocopy automation\include\ln build-dir\Debug\automation\include\ln /IS /IT
robocopy automation\demos build-dir\Debug\automation\demos /IS /IT
robocopy "distro-extras" build-dir\Debug\ /IS /IT
robocopy "distro-extras\csri" build-dir\Debug\csri /IS /IT
robocopy "distro-extras\dictionaries" build-dir\Debug\dictionaries /IS /IT
robocopy "C:\Windows\System32" "build-dir\Debug" AviSynth.dll /IS /IT
robocopy "C:\Boost\lib" "build-dir\Debug" boost_filesystem-vc142-mt-gd-x64-1_73.dll boost_locale-vc142-mt-gd-x64-1_73.dll boost_regex-vc142-mt-gd-x64-1_73.dll boost_thread-vc142-mt-gd-x64-1_73.dll /IS /IT
robocopy "C:\Boost\lib" "build-dir\Debug" boost_filesystem-vc142-mt-gd-x64-1_73.dll boost_locale-vc142-mt-gd-x64-1_73.dll boost_regex-vc142-mt-gd-x64-1_73.dll boost_thread-vc142-mt-gd-x64-1_73.dll /IS /IT
robocopy "C:\Program Files (x86)\AviSynth+\plugins64+" "build-dir\Debug" DirectShowSource.dll /IS /IT
robocopy "vendor\exten\ffms\x64" "build-dir\Debug" ffms2.dll /IS /IT
robocopy "vendor\exten\freetype\win64" "build-dir\Debug" freetype.dll /IS /IT
robocopy "vendor\exten\fribidi-1.0.10\build\lib" "build-dir\Debug" fribidi-0.dll /IS /IT
robocopy "vendor\exten\icu4c\bin64" "build-dir\Debug" icudt67.dll icuin67.dll icuuc67.dll /IS /IT
robocopy "vendor\exten\fftw" "build-dir\Debug" libfftw3.dll /IS /IT
robocopy "vendor\exten\hunspell\msvc\x64\Release_dll" "build-dir\Debug" libhunspell.dll /IS /IT
robocopy "vendor\exten\libiconv\lib" "build-dir\Debug" iconv.dll /IS /IT
robocopy "vendor\exten\uchardet\build\src\Release" "build-dir\Debug" uchardet.dll /IS /IT
robocopy "vendor\exten\wxWidgets\lib\vc14x_x64_dll" "build-dir\Debug" wxbase314ud_vc14x_x64.dll wxbase314ud_xml_vc14x_x64.dll wxmsw314ud_core_vc14x_x64.dll wxmsw314ud_gl_vc14x_x64.dll wxmsw314ud_stc_vc14x_x64.dll /IS /IT
robocopy "vendor\exten\wxWidgets\lib\vc14x_x64_dll" "build-dir\Debug" wxbase314ud_vc14x_x64.pdb wxbase314ud_xml_vc14x_x64.pdb wxmsw314ud_core_vc14x_x64.pdb wxmsw314ud_gl_vc14x_x64.pdb wxmsw314ud_stc_vc14x_x64.pdb /IS /IT
robocopy "vendor\exten\zlib\contrib\vstudio\vc14\x64\ZlibDllRelease" "build-dir\Debug" zlibwapi.dll /IS /IT
rename "build-dir\Debug\libfftw3.dll" "libfftw3-3.dll"
rename "build-dir\Debug\iconv.dll" "libiconv.dll"
pause