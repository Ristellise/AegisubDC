# libiconv-win-build

libiconv Windows build with Visual Studio.

This version is libiconv-1.16.

To build, simply open the required solution file, and
you know how to use Visual Studio, right?
(or perhaps this is the wrong place for you.)

Windows command prompt based testing is far too complicated.

To test, using cygwin (MSYS would probably work too):

> cd libiconv-win-build/tests

> make -f check-all-with-cygwin.mak check bindir={bindir}

where {bindir} is some Visual Studio output directory
containing the required set of binaries.

For example, set bindir to "../build-VS2013/Release" to test
VS2013 release build 32-bit binaries.
