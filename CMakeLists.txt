cmake_minimum_required(VERSION 3.11)
cmake_policy(SET CMP0074 NEW)

project(Aegisub)

set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)

include_directories("build")
include_directories("libaegisub/include")
include_directories("vendor/luajit/include")

add_library(libaegisub STATIC
    libaegisub/common/parser.cpp
    libaegisub/ass/dialogue_parser.cpp
    libaegisub/ass/time.cpp
    libaegisub/ass/uuencode.cpp
    libaegisub/audio/provider.cpp
    libaegisub/audio/provider_convert.cpp
    libaegisub/audio/provider_dummy.cpp
    libaegisub/audio/provider_hd.cpp
    libaegisub/audio/provider_lock.cpp
    libaegisub/audio/provider_pcm.cpp
    libaegisub/audio/provider_ram.cpp
    libaegisub/common/cajun/elements.cpp
    libaegisub/common/cajun/reader.cpp
    libaegisub/common/cajun/writer.cpp
    libaegisub/lua/modules/lfs.cpp
    libaegisub/lua/modules/re.cpp
    libaegisub/lua/modules/unicode.cpp
    libaegisub/lua/modules/lpeg.c
    libaegisub/lua/modules.cpp
    libaegisub/lua/script_reader.cpp
    libaegisub/lua/utils.cpp
    libaegisub/common/calltip_provider.cpp
    libaegisub/common/character_count.cpp
    libaegisub/common/charset.cpp
    libaegisub/common/charset_6937.cpp
    libaegisub/common/charset_conv.cpp
    libaegisub/common/color.cpp
    libaegisub/common/file_mapping.cpp
    libaegisub/common/format.cpp
    libaegisub/common/fs.cpp
    libaegisub/common/hotkey.cpp
    libaegisub/common/io.cpp
    libaegisub/common/json.cpp
    libaegisub/common/kana_table.cpp
    libaegisub/common/karaoke_matcher.cpp
    libaegisub/common/keyframe.cpp
    libaegisub/common/line_iterator.cpp
    libaegisub/common/log.cpp
    libaegisub/common/mru.cpp
    libaegisub/common/option.cpp
    libaegisub/common/option_value.cpp
    libaegisub/common/path.cpp
    libaegisub/common/thesaurus.cpp
    libaegisub/common/util.cpp
    libaegisub/common/vfr.cpp
    libaegisub/common/ycbcr_conv.cpp
    libaegisub/common/dispatch.cpp
)
if (UNIX)
    target_sources(libaegisub PRIVATE
        libaegisub/unix/access.cpp
        libaegisub/unix/fs.cpp
        libaegisub/unix/log.cpp
        libaegisub/unix/path.cpp
        libaegisub/unix/util.cpp
    )
elseif(WIN32)
    target_sources(libaegisub PRIVATE
        libaegisub/windows/access.cpp
        libaegisub/windows/charset_conv_win.cpp
        libaegisub/windows/fs.cpp
        libaegisub/windows/lagi_pre.cpp
        libaegisub/windows/log_win.cpp
        libaegisub/windows/path_win.cpp
        libaegisub/windows/util_win.cpp
    )
endif(UNIX)
SET_TARGET_PROPERTIES(libaegisub PROPERTIES PREFIX "")

add_library(luabins STATIC
    vendor/luabins/src/fwrite.c
    vendor/luabins/src/load.c
    vendor/luabins/src/luabins.c
    vendor/luabins/src/luainternals.c
    vendor/luabins/src/save.c
    vendor/luabins/src/savebuffer.c
    vendor/luabins/src/write.c
)

add_executable(luajit-minilua vendor/luajit/src/host/minilua.c)
if (NOT MSVC)
target_link_libraries(luajit-minilua m)
endif(NOT MSVC)
add_custom_command(TARGET luajit-minilua POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_SOURCE_DIR}/vendor/luajit/src/gen
    COMMAND luajit-minilua ../dynasm/dynasm.lua -D P64 -D JIT -D FFI -D FPU -D HFABI -D VER= -o gen/buildvm_arch.h vm_x86.dasc
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)
add_custom_command(TARGET luajit-minilua POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/src/libresrc/default_config_win.json ${PROJECT_SOURCE_DIR}/src/libresrc/default_config_platform.json
    COMMAND luajit-minilua ../../tools/respack.lua manifest.respack default_config.cpp default_config.h
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/src/libresrc
    BYPRODUCTS ${PROJECT_SOURCE_DIR}/src/libresrc/default_config.cpp ${PROJECT_SOURCE_DIR}/src/libresrc/default_config.h
)
add_custom_command(TARGET luajit-minilua POST_BUILD
    COMMAND luajit-minilua ../../tools/respack.lua manifest.respack ../libresrc/bitmap.cpp ../libresrc/bitmap.h
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/src/bitmaps
    BYPRODUCTS ${PROJECT_SOURCE_DIR}/src/libresrc/bitmap.cpp ${PROJECT_SOURCE_DIR}/src/libresrc/bitmap.h
)

add_executable(luajit-buildvm
    vendor/luajit/src/host/buildvm.c
    vendor/luajit/src/host/buildvm_asm.c
    vendor/luajit/src/host/buildvm_peobj.c
    vendor/luajit/src/host/buildvm_lib.c
    vendor/luajit/src/host/buildvm_fold.c
)
target_include_directories(luajit-buildvm PRIVATE vendor/luajit/src vendor/luajit/src/gen)
add_dependencies(luajit-buildvm luajit-minilua)
if(UNIX)
    add_custom_command(TARGET luajit-buildvm POST_BUILD
        COMMAND luajit-buildvm -m elfasm -o lj_vm.s
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        BYPRODUCTS ${PROJECT_SOURCE_DIR}/vendor/luajit/src/lj_vm.s
    )
    set_property(SOURCE vendor/luajit/src/lj_vm.s PROPERTY LANGUAGE C)
elseif(MSVC)
    add_custom_command(TARGET luajit-buildvm POST_BUILD
        COMMAND luajit-buildvm -m peobj -o lj_vm.obj
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
        BYPRODUCTS ${PROJECT_SOURCE_DIR}/vendor/luajit/src/lj_vm.obj
    )
endif(UNIX)
add_custom_command(TARGET luajit-buildvm POST_BUILD
    COMMAND luajit-buildvm -m ffdef -o gen/lj_ffdef.h lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    COMMAND luajit-buildvm -m bcdef -o gen/lj_bcdef.h lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    COMMAND luajit-buildvm -m folddef -o gen/lj_folddef.h lj_opt_fold.c
    COMMAND luajit-buildvm -m recdef -o gen/lj_recdef.h lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    COMMAND luajit-buildvm -m libdef -o gen/lj_libdef.h lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    COMMAND luajit-buildvm -m vmdef -o jit/vmdef.lua lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/vendor/luajit/src
)


add_library(luajit STATIC
    vendor/luajit/src/lj_gc.c
    vendor/luajit/src/lj_err.c
    vendor/luajit/src/lj_char.c
    vendor/luajit/src/lj_bc.c
    vendor/luajit/src/lj_obj.c
    vendor/luajit/src/lj_str.c
    vendor/luajit/src/lj_tab.c
    vendor/luajit/src/lj_func.c
    vendor/luajit/src/lj_udata.c
    vendor/luajit/src/lj_meta.c
    vendor/luajit/src/lj_debug.c
    vendor/luajit/src/lj_state.c
    vendor/luajit/src/lj_dispatch.c
    vendor/luajit/src/lj_vmevent.c
    vendor/luajit/src/lj_vmmath.c
    vendor/luajit/src/lj_strscan.c
    vendor/luajit/src/lj_api.c
    vendor/luajit/src/lj_lex.c
    vendor/luajit/src/lj_parse.c
    vendor/luajit/src/lj_bcread.c
    vendor/luajit/src/lj_bcwrite.c
    vendor/luajit/src/lj_load.c
    vendor/luajit/src/lj_ir.c
    vendor/luajit/src/lj_opt_mem.c
    vendor/luajit/src/lj_opt_fold.c
    vendor/luajit/src/lj_opt_narrow.c
    vendor/luajit/src/lj_opt_dce.c
    vendor/luajit/src/lj_opt_loop.c
    vendor/luajit/src/lj_opt_split.c
    vendor/luajit/src/lj_opt_sink.c
    vendor/luajit/src/lj_mcode.c
    vendor/luajit/src/lj_snap.c
    vendor/luajit/src/lj_record.c
    vendor/luajit/src/lj_crecord.c
    vendor/luajit/src/lj_ffrecord.c
    vendor/luajit/src/lj_asm.c
    vendor/luajit/src/lj_trace.c
    vendor/luajit/src/lj_gdbjit.c
    vendor/luajit/src/lj_ctype.c
    vendor/luajit/src/lj_cdata.c
    vendor/luajit/src/lj_cconv.c
    vendor/luajit/src/lj_ccall.c
    vendor/luajit/src/lj_ccallback.c
    vendor/luajit/src/lj_carith.c
    vendor/luajit/src/lj_clib.c
    vendor/luajit/src/lj_cparse.c
    vendor/luajit/src/lj_lib.c
    vendor/luajit/src/lj_alloc.c
    vendor/luajit/src/lib_aux.c
    vendor/luajit/src/lib_base.c
    vendor/luajit/src/lib_math.c
    vendor/luajit/src/lib_bit.c
    vendor/luajit/src/lib_string.c
    vendor/luajit/src/lib_table.c
    vendor/luajit/src/lib_io.c
    vendor/luajit/src/lib_os.c
    vendor/luajit/src/lib_package.c
    vendor/luajit/src/lib_debug.c
    vendor/luajit/src/lib_jit.c
    vendor/luajit/src/lib_ffi.c
    vendor/luajit/src/lib_init.c
)
if(MSVC)
    target_sources(luajit PRIVATE vendor/luajit/src/lj_vm.obj)
else(MSVC)
    target_sources(luajit PRIVATE vendor/luajit/src/lj_vm.s)
    set_property(SOURCE vendor/luajit/src/lj_vm.s PROPERTY LANGUAGE C)
endif(MSVC)
target_include_directories(luajit PRIVATE vendor/luajit/src/gen)
add_dependencies(luajit luajit-buildvm)
target_compile_definitions(luajit PRIVATE LUAJIT_ENABLE_LUA52COMPAT)

add_library(resrc STATIC
    src/libresrc/bitmap.cpp
    src/libresrc/default_config.cpp
    src/libresrc/libresrc.cpp
)
add_dependencies(resrc luajit-minilua)

add_library(csri STATIC
    vendor/csri/lib/list.c
    vendor/csri/lib/wrap.c
    vendor/csri/subhelp/logging.c
)
target_include_directories(csri PRIVATE "vendor/csri/include")
IF (WIN32)
    target_include_directories(csri PRIVATE "vendor/csri/lib/win32")
    target_sources(csri PRIVATE vendor/csri/lib/win32/enumerate.c)
ELSE()
    target_include_directories(csri PRIVATE "vendor/csri/lib/posix")
    target_sources(csri PRIVATE vendor/csri/lib/posix/enumerate.c)
ENDIF()

add_executable(Aegisub WIN32
    src/command/app.cpp
    src/command/audio.cpp
    src/command/automation.cpp
    src/command/command.cpp
    src/command/edit.cpp
    src/command/grid.cpp
    src/command/help.cpp
    src/command/keyframe.cpp
    src/command/recent.cpp
    src/command/subtitle.cpp
    src/command/time.cpp
    src/command/timecode.cpp
    src/command/tool.cpp
    src/command/video.cpp
    src/command/vis_tool.cpp
    src/dialog_about.cpp
    src/dialog_attachments.cpp
    src/dialog_automation.cpp
    src/dialog_autosave.cpp
    src/dialog_colorpicker.cpp
    src/dialog_detached_video.cpp
    src/dialog_dummy_video.cpp
    src/dialog_export.cpp
    src/dialog_export_ebu3264.cpp
    src/dialog_fonts_collector.cpp
    src/dialog_jumpto.cpp
    src/dialog_kara_timing_copy.cpp
    src/dialog_log.cpp
    src/dialog_paste_over.cpp
    src/dialog_progress.cpp
    src/dialog_properties.cpp
    src/dialog_resample.cpp
    src/dialog_search_replace.cpp
    src/dialog_selected_choices.cpp
    src/dialog_selection.cpp
    src/dialog_shift_times.cpp
    src/dialog_spellchecker.cpp
    src/dialog_style_editor.cpp
    src/dialog_style_manager.cpp
    src/dialog_styling_assistant.cpp
    src/dialog_text_import.cpp
    src/dialog_timing_processor.cpp
    src/dialog_translation.cpp
    src/dialog_version_check.cpp
    src/dialog_video_details.cpp
    src/dialog_video_properties.cpp
    src/subtitle_format.cpp
    src/subtitle_format_ass.cpp
    src/subtitle_format_ebu3264.cpp
    src/subtitle_format_encore.cpp
    src/subtitle_format_microdvd.cpp
    src/subtitle_format_mkv.cpp
    src/subtitle_format_srt.cpp
    src/subtitle_format_ssa.cpp
    src/subtitle_format_transtation.cpp
    src/subtitle_format_ttxt.cpp
    src/subtitle_format_txt.cpp
    src/visual_tool.cpp
    src/visual_tool_clip.cpp
    src/visual_tool_cross.cpp
    src/visual_tool_drag.cpp
    src/visual_tool_rotatexy.cpp
    src/visual_tool_rotatez.cpp
    src/visual_tool_scale.cpp
    src/visual_tool_vector_clip.cpp
    src/MatroskaParser.c
    src/aegisublocale.cpp
    src/ass_attachment.cpp
    src/ass_dialogue.cpp
    src/ass_entry.cpp
    src/ass_export_filter.cpp
    src/ass_exporter.cpp
    src/ass_file.cpp
    src/ass_karaoke.cpp
    src/ass_override.cpp
    src/ass_parser.cpp
    src/ass_style.cpp
    src/ass_style_storage.cpp
    src/async_video_provider.cpp
    src/audio_box.cpp
    src/audio_colorscheme.cpp
    src/audio_controller.cpp
    src/audio_display.cpp
    src/audio_karaoke.cpp
    src/audio_marker.cpp
    src/audio_player.cpp
    src/audio_provider_factory.cpp
    src/audio_renderer.cpp
    src/audio_renderer_spectrum.cpp
    src/audio_renderer_waveform.cpp
    src/audio_timing_dialogue.cpp
    src/audio_timing_karaoke.cpp
    src/auto4_base.cpp
    src/auto4_lua.cpp
    src/auto4_lua_assfile.cpp
    src/auto4_lua_dialog.cpp
    src/auto4_lua_progresssink.cpp
    src/base_grid.cpp
    src/charset_detect.cpp
    src/colorspace.cpp
    src/colour_button.cpp
    src/compat.cpp
    src/context.cpp
    src/export_fixstyle.cpp
    src/export_framerate.cpp
    src/fft.cpp
    src/font_file_lister.cpp
    src/frame_main.cpp
    src/gl_text.cpp
    src/gl_wrap.cpp
    src/grid_column.cpp
    src/help_button.cpp
    src/hotkey.cpp
    src/hotkey_data_view_model.cpp
    src/initial_line_state.cpp
    src/main.cpp
    src/menu.cpp
    src/mkv_wrap.cpp
    src/pen.cpp
    src/persist_location.cpp
    src/preferences.cpp
    src/preferences_base.cpp
    src/project.cpp
    src/resolution_resampler.cpp
    src/search_replace_engine.cpp
    src/selection_controller.cpp
    src/spellchecker.cpp
    src/spline.cpp
    src/spline_curve.cpp
    src/string_codec.cpp
    src/subs_controller.cpp
    src/subs_edit_box.cpp
    src/subs_edit_ctrl.cpp
    src/subs_preview.cpp
    src/subtitles_provider.cpp
    src/subtitles_provider_libass.cpp
    src/text_file_reader.cpp
    src/text_file_writer.cpp
    src/text_selection_controller.cpp
    src/thesaurus.cpp
    src/timeedit_ctrl.cpp
    src/toggle_bitmap.cpp
    src/toolbar.cpp
    src/tooltip_manager.cpp
    src/utils.cpp
    src/validators.cpp
    src/vector2d.cpp
    src/version.cpp
    src/video_box.cpp
    src/video_controller.cpp
    src/video_display.cpp
    src/video_frame.cpp
    src/video_out_gl.cpp
    src/video_provider_cache.cpp
    src/video_provider_dummy.cpp
    src/video_provider_manager.cpp
    src/video_provider_yuv4mpeg.cpp
    src/video_slider.cpp
    src/visual_feature.cpp
)
target_link_libraries(Aegisub ${CMAKE_DL_LIBS} libaegisub luabins luajit resrc csri)

if (MSVC)
    set_target_properties(libaegisub PROPERTIES COMPILE_FLAGS "/Yu${PROJECT_SOURCE_DIR}/libaegisub/lagi_pre.h" COMPILE_FLAGS "/FI${PROJECT_SOURCE_DIR}/libaegisub/lagi_pre.h")
else(MSVC)
    target_compile_options(libaegisub PRIVATE -include "${PROJECT_SOURCE_DIR}/libaegisub/lagi_pre.h")
endif(MSVC)

set_property(
    SOURCE libaegisub/unix/path.cpp
    PROPERTY COMPILE_DEFINITIONS
        P_DATA="${CMAKE_INSTALL_PREFIX}/share/aegisub/"
)

if (MSVC)
    add_definitions("-DNOMINMAX -MP -DINITGUID")
    set_target_properties(Aegisub PROPERTIES COMPILE_FLAGS "/Yu${PROJECT_SOURCE_DIR}/src/agi_pre.h" COMPILE_FLAGS "/FI${PROJECT_SOURCE_DIR}/src/agi_pre.h")
    target_link_libraries (Aegisub Usp10)
    #target_sources(Aegisub PRIVATE src/res/res.rc src/res/strings.rc src/crash_writer_minidump.cpp)
    target_sources(Aegisub PRIVATE src/res/res.rc src/res/strings.rc src/crash_writer.cpp src/dpi_aware.manifest)
    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT Aegisub)
else(MSVC)
    target_sources(Aegisub PRIVATE src/crash_writer.cpp)
    target_compile_options(Aegisub PRIVATE -include "${PROJECT_SOURCE_DIR}/src/agi_pre.h")
endif(MSVC)

if (WIN32)
    target_sources(Aegisub PRIVATE src/font_file_lister_gdi.cpp)
else (WIN32)
    find_package(Fontconfig REQUIRED)
    target_link_libraries (Aegisub ${Fontconfig_LIBRARIES})
    target_sources(Aegisub PRIVATE src/font_file_lister_fontconfig.cpp)
    set_property(SOURCE src/font_file_lister_fontconfig.cpp PROPERTY INCLUDE_DIRECTORIES "${Fontconfig_INCLUDE_DIRS}")
endif (WIN32)

find_package(ass REQUIRED)
include_directories(${ass_INCLUDE_DIRS})
target_link_libraries (Aegisub ${ass_LIBRARIES})

find_package(Boost REQUIRED chrono filesystem locale regex system thread)
include_directories(${Boost_INCLUDE_DIRS})
target_link_directories(Aegisub PRIVATE ${Boost_LIBRARY_DIRS})
target_link_libraries(Aegisub ${Boost_LIBRARIES})

find_package(OpenGL REQUIRED)
include_directories(${OPENGL_INCLUDE_DIR})
target_link_libraries (Aegisub ${OPENGL_LIBRARIES})

find_package(Hunspell REQUIRED)
include_directories(${HUNSPELL_INCLUDE_DIR})
target_link_libraries (Aegisub ${HUNSPELL_LIBRARIES})
add_definitions("-DWITH_HUNSPELL")
target_sources(Aegisub PRIVATE src/spellchecker_hunspell.cpp)

find_package(Iconv REQUIRED)
include_directories(${Iconv_INCLUDE_DIRS})
target_link_libraries (Aegisub ${Iconv_LIBRARIES})
add_definitions("-DHAVE_ICONV")
if (NOT Iconv_IS_BUILT_IN)
set_property(
    SOURCE libaegisub/common/charset_conv.cpp
    PROPERTY COMPILE_DEFINITIONS AGI_ICONV_CONST
)
endif (NOT Iconv_IS_BUILT_IN)

find_package(ICU REQUIRED uc dt in)
include_directories(${ICU_INCLUDE_DIRS})
target_link_libraries (Aegisub ${ICU_LIBRARIES})

find_package(wxWidgets REQUIRED adv base core gl stc xml)
include(${wxWidgets_USE_FILE})
target_link_libraries(Aegisub ${wxWidgets_LIBRARIES})

find_package(ZLIB REQUIRED)
include_directories(${ZLIB_INCLUDE_DIRS})
target_link_libraries (Aegisub ${ZLIB_LIBRARIES})

find_package(ALSA)
if (ALSA_FOUND)
    include_directories(${ALSA_INCLUDE_DIRS})
    target_link_libraries (Aegisub ${ALSA_LIBRARIES})
    add_definitions("-DWITH_ALSA")
    target_sources(Aegisub PRIVATE src/audio_player_alsa.cpp)
endif(ALSA_FOUND)

# target_compile_definitions(Aegisub PRIVATE "WITH_AVISYNTH")
# target_sources(Aegisub PRIVATE src/audio_provider_avs.cpp src/avisynth_wrap.cpp src/video_provider_avs.cpp)

target_compile_definitions(Aegisub PRIVATE "WITH_CSRI")
target_sources(Aegisub PRIVATE src/subtitles_provider_csri.cpp)
set_property(SOURCE src/subtitles_provider_csri.cpp PROPERTY INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}/vendor/csri/include")

if(MSVC)
    target_link_libraries (Aegisub dsound)
    add_definitions("-DWITH_DIRECTSOUND")
    target_sources(Aegisub PRIVATE src/audio_player_dsound.cpp src/audio_player_dsound2.cpp)
endif(MSVC)

find_package(FFMS2)
if (FFMS2_FOUND)
    include_directories(${FFMS2_INCLUDE_DIRS})
    target_link_libraries (Aegisub ${FFMS2_LIBRARIES})
    add_definitions("-DWITH_FFMS2")
    target_sources(Aegisub PRIVATE src/audio_provider_ffmpegsource.cpp src/ffmpegsource_common.cpp src/video_provider_ffmpegsource.cpp)
endif(FFMS2_FOUND)

find_package(FFTW)
if (FFTW_FOUND)
    include_directories(${FFTW_INCLUDES})
    target_link_libraries (Aegisub ${FFTW_LIBRARIES})
    add_definitions("-DWITH_FFTW3")
endif(FFTW_FOUND)

#ifdef WITH_LIBPULSE
#add_definitions("-DWITH_LIBPULSE")
#target_sources(Aegisub PRIVATE src/audio_player_pulse.cpp)

find_package(OpenAL)
if (OPENAL_FOUND)
    include_directories(${OPENAL_INCLUDE_DIR})
    target_link_libraries (Aegisub ${OPENAL_LIBRARY})
    add_definitions("-DWITH_OPENAL")
    target_sources(Aegisub PRIVATE src/audio_player_openal.cpp)
endif(OPENAL_FOUND)

#ifdef WITH_OSS
#ifdef WITH_PORTAUDIO
#ifdef WITH_STARTUPLOG

find_package(uchardet)
if (uchardet_FOUND)
    include_directories(${uchardet_INCLUDE_DIRS})
    target_link_libraries (Aegisub ${uchardet_LIBRARIES})
    add_definitions("-DWITH_UCHARDET")
endif(uchardet_FOUND)

#ifdef WITH_UPDATE_CHECKER
