# Aegisub [Daydream Cafe] Edition

This is basically a patched wangqr build to include latest libraries et all.

### Changes
- Updated all dependencies
- Includes harfbuzz wich shows correct zalgo text
- Updated libass to `66dba8d` at the time of writing.
- Switched from luajit to moonjit, incldes 5.3, **With breaking 5.2 changes.**
- Vector Tools now allows up to 2 decimal places.
- Allow font manager (like fontbase) loaded fonts.
- Removed border UI for Text box. looks cleaner this way.
- Fixed font detection for gdi.
- Fixed FFMS2 to allow VP9/Webm videos, includes audio patch
- Support WWXD keyframes [Requested by Light]
- Added `Experimental Unicode 6.3+` bracket matching option for libass
- Bundle Yutils module as default automation
- Added new hotkey command to reload current font provider. [Default: `CTRL+R`]
- Updated VSFilter to Cyberbeing/xy-VSFilter@fc01a8da5ea6af9091aaab839bc62dc94a90094e
- Updated VSFilterMod to sorayuki/VSFilterMod@R5.2.3
- Made SRT Times to always round down.
- Experimental Video Panning by moex3.

The bug tracker can be found at [the Github Issue Tracker](https://github.com/Ristellise/AegisubDC/issues).

Support for this edition is available only on this issues page.

### Installation

1. Unpack the zip file into a seperate folder. (It's discouraged to replace the Aegisub folder in Program Files if you have it installed, unless you know what are you doing!)
2. If you have a older aegisub version (like 3.2.2), it recommended to archive your `config.json` into another file name to prevent config from clashing (There shouldn't be any changes but it's nice to be safe.).  
   You can find `config.json` at `C:\Users\{YOUR_USERNAME_HERE}\AppData\Roaming\Aegisub\config.json`

### Language Support

As of `9212`, there is a locale.zip which is included & will be updated from time to time.  
To use it, unzip the zip directly into your aegisub installation folder.

## Building Aegisub

### CMake (for Windows only)

This fork includes all the various libraries with their sources, set the current directory to the root of the folder and run: `scripts\createcmake.bat`

To enable AviSynth+ support, install AviSynth, check Filter SDK and modify createcmake.bat.

## Updating Moonscript

From within the Moonscript repository, run `bin/moon bin/splat.moon -l moonscript moonscript/ > bin/moonscript.lua`.
Open the newly created `bin/moonscript.lua`, and within it make the following changes:

1. Prepend the final line of the file, `package.preload["moonscript"]()`, with a `return`, producing `return package.preload["moonscript"]()`.
2. Within the function at `package.preload['moonscript.base']`, remove references to `moon_loader`, `insert_loader`, and `remove_loader`. This means removing their declarations, definitions, and entries in the returned table.
3. Within the function at `package.preload['moonscript']`, remove the line `_with_0.insert_loader()`.

The file is now ready for use, to be placed in `automation/include` within the Aegisub repo.

## License

All files in this repository are licensed under various GPL-compatible BSD-style licenses; see LICENCE and the individual source files for more information.
The official Windows build is GPLv2 due to including fftw3.

## FAQ

Q: Is ~~Linus~~ Linux supported?  
A: As of now... no, in the future? maybe.

Q: What's with the release's "blurb" names?  
A: They are mainly picked at random with whatever I'm interested when I released it.

Q: I'm having issues with random subtitles failing! (9212 & Below)  
A: Try switching your video subtitle renderer in `Options > Advanced > Video >Subtitles provider` to `libass`.