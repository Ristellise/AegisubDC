@echo off
robocopy automation build-dir\RelWithDebInfo\automation /IS /IT /S
robocopy automation\demos build-dir\RelWithDebInfo\automation\demos /IS /IT
robocopy "distro-extras" build-dir\RelWithDebInfo\ /IS /IT /S
robocopy "vendor\extra\wxWidgets\lib\vc14x_x64_dll" "build-dir\RelWithDebInfo" wxbase314u_vc14x_x64.dll wxbase314u_xml_vc14x_x64.dll wxmsw314u_core_vc14x_x64.dll wxmsw314u_gl_vc14x_x64.dll wxmsw314u_stc_vc14x_x64.dll /IS /IT
robocopy "vendor\extra\ffms\x64" "build-dir\RelWithDebInfo" ffms2.dll ffms2.pdb /IS /IT
pause