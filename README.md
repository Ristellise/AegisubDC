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

The bug tracker can be found at https://github.com/Ristellise/AegisubDC/issues .

Support for this edition is available on this issues page.

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

## Expanding the Git history

The Git history of this project is truncated.
To fetch and graft the remaining history, run the following command (replace `origin` with the appropriate remote name as necessary):

```sh
git fetch origin "+refs/replace/*:refs/replace/*"
```

## License

All files in this repository are licensed under various GPL-compatible BSD-style licenses; see LICENCE and the individual source files for more information.
The official Windows build is GPLv2 due to including fftw3.
