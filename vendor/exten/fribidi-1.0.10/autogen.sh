#!/bin/sh
# Run this to generate all the initial makefiles, etc.

test -n "$srcdir" || srcdir=`dirname "$0"`
test -n "$srcdir" || srcdir=.

olddir=`pwd`
cd $srcdir

echo -n "checking for pkg-config... "
which pkg-config || {
	echo "*** No pkg-config found, please install it ***"
	exit 1
}

echo -n "checking for libtoolize... "
which glibtoolize || which libtoolize || {
	echo "*** No libtoolize (libtool) found, please install it ***"
	exit 1
}

echo -n "checking for autoreconf... "
which autoreconf || {
	echo "*** No autoreconf (autoconf) found, please install it ***"
	exit 1
}

echo "running autoreconf --force --install --verbose"
autoreconf --force --install --verbose || exit $?

cd $olddir
test -n "$NOCONFIGURE" || {
	echo "running configure $@"
	"$srcdir/configure" "$@"
}
