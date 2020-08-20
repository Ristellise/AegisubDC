#!/bin/sh

# Derived from INSTALL.windows in the original source
# to support VS2008/2010/2013/2015/2017/2019.

# Set environment variables for using MSVC 10/11/12/14,
# for creating native Windows executables.

_VS2008=${_VS2008:=0}
_VS2010=${_VS2010:=0}
_VS2013=${_VS2013:=0}
_VS2015=${_VS2015:=1} # default
_VS2017=${_VS2017:=0}
_VS2019=${_VS2019:=0}
_TARGET_X64=${_TARGET_X64:=0}
_DO_CONFIG=${_DO_CONFIG:=1}
_DO_MAKE=${_DO_MAKE:=0}
_DO_CHECK=${_DO_CHECK:=0}

if [ "${_TARGET_X64}" -eq 1 ]; then
  ARCH=x64
  ARCH_U=X64
  ARCH_ALT=amd64
  ARCH_BITS=64
  ARCH_HOST=x86_64-w64-mingw32
else
  ARCH=x86
  ARCH_U=X86
  ARCH_ALT=
  ARCH_BITS=32
  ARCH_HOST=i686-w64-mingw32
fi

INSTALL_PREFIX="/usr/local/msvc${ARCH_BITS}"

if [ `basename "$0"` == config_for_vs.sh ]; then
  BuildAuxDir=`dirname "$0"`'/build-aux'
  BuildAuxDir=`realpath "$BuildAuxDir"`
  [ ! -x "${BuildAuxDir}/compile" ] && exit 1
  [ ! -x "${BuildAuxDir}/ar-lib" ] && exit 1
  _BUILD_CC="${BuildAuxDir}/compile"
  _BUILD_AR="${BuildAuxDir}/ar-lib"
fi

# Windows C library headers and libraries.
WindowsCrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\10.0.10240.0\ucrt\'
WindowsCrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\10.0.10240.0\ucrt\'
[ ! -d "${WindowsCrtIncludeDir}" ] && exit 1
[ ! -d "${WindowsCrtLibDir}" ] && exit 1
INCLUDE="${WindowsCrtIncludeDir};${INCLUDE}"
LIB="${WindowsCrtLibDir}${ARCH};${LIB}"

# Windows API headers and libraries.
WindowsSdkIncludeDir='C:\Program Files (x86)\Windows Kits\8.1\Include\'
WindowsSdkLibDir='C:\Program Files (x86)\Windows Kits\8.1\Lib\winv6.3\um\'
[ ! -d "${WindowsSdkIncludeDir}" ] && exit 1
[ ! -d "${WindowsSdkLibDir}" ] && exit 1
INCLUDE="${WindowsSdkIncludeDir}um;${WindowsSdkIncludeDir}shared;${INCLUDE}"
LIB="${WindowsSdkLibDir}${ARCH};${LIB}"

# Visual C++ tools, headers and libraries.
if [ "${_VS2019}" -eq 1 ]; then
  _ARCH_PATH_W="\\${ARCH}"
  VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\'
  _VCVER=`( cd "/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC" && ls -1rd [1-9]* | head -1 )`
  VCINSTALLDIR="${VSINSTALLDIR}"'VC\Tools\MSVC\'"${_VCVER}"'\'
  _VCBINDIR=`cygpath -u "${VCINSTALLDIR}"`"/bin/Host${ARCH_U}/${ARCH}"
elif [ "${_VS2017}" -eq 1 ]; then
  _ARCH_PATH_W="\\${ARCH}"
  VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\'
  _VCVER=`( cd "/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC" && ls -1rd [1-9]* | head -1 )`
  VCINSTALLDIR="${VSINSTALLDIR}"'VC\Tools\MSVC\'"${_VCVER}"'\'
  _VCBINDIR=`cygpath -u "${VCINSTALLDIR}"`"/bin/Host${ARCH_U}/${ARCH}"
else
  if [ "${_TARGET_X64}" -eq 1 ]; then
    _ARCH_PATH="/${ARCH_ALT}"
    _ARCH_PATH_W="\\${ARCH_ALT}"
  else
    _ARCH_PATH=
    _ARCH_PATH_W=
  fi
  if [ "${_VS2008}" -eq 1 ]; then
    VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 10.0\'
  elif [ "${_VS2010}" -eq 1 ]; then
    VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 11.0\'
  elif [ "${_VS2013}" -eq 1 ]; then
    VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 12.0\'
  elif [ "${_VS2015}" -eq 1 ]; then
    VSINSTALLDIR='C:\Program Files (x86)\Microsoft Visual Studio 14.0\'
  else
    exit 1
  fi
  VCINSTALLDIR="${VSINSTALLDIR}"'VC\'
  _VCBINDIR=`cygpath -u "${VCINSTALLDIR}"`"/bin${_ARCH_PATH}"
  unset _ARCH_PATH
fi
[ ! -d "${VSINSTALLDIR}" ] && exit 1
[ ! -d "${VCINSTALLDIR}" ] && exit 1
[ ! -d "${_VCBINDIR}" ] && exit 1
[ ! -x "${_VCBINDIR}/cl.exe" ] && exit 1
if [ "${_TARGET_X64}" -ne 1 -a \( "${_VS2008}" -eq 1 -o "${_VS2010}" -eq 1 \) ]; then
  # VS2008/VS2010 32-bit needs IDE directory in path.
  PATH="${_VCBINDIR}:${VSINSTALLDIR}/Common7/IDE:${PATH}"
else
  PATH="${_VCBINDIR}:${PATH}"
fi
INCLUDE="${VCINSTALLDIR}include;${INCLUDE}"
LIB="${VCINSTALLDIR}lib${_ARCH_PATH_W};${LIB}"
unset _ARCH_PATH_W

echo "PATH=${PATH}"
echo "INCLUDE=${INCLUDE}"
echo "LIB=${LIB}"

export INCLUDE LIB

PATH="${INSTALL_PREFIX}/bin:${PATH}"
export PATH

[ `basename "$0"` != config_for_vs.sh ] && return 0

win32_target=_WIN32_WINNT_WINXP   # for MSVC 9.0
win32_target=_WIN32_WINNT_VISTA   # possibly for MSVC >= 10.0
win32_target=_WIN32_WINNT_WIN7    # possibly for MSVC >= 10.0
win32_target=_WIN32_WINNT_WIN8    # possibly for MSVC >= 10.0

if [ "${_DO_CONFIG}" -eq 1 ]; then
  ./configure --host=${ARCH_HOST} --prefix=${INSTALL_PREFIX} \
      CC="${_BUILD_CC} cl -nologo" \
      CFLAGS="-MD" \
      CXX="${_BUILD_CC} cl -nologo" \
      CXXFLAGS="-MD" \
      CPPFLAGS="-D_WIN32_WINNT=${win32_target} -I${INSTALL_PREFIX}/include" \
      LDFLAGS="-L${INSTALL_PREFIX}/lib" \
      LD="link" \
      NM="dumpbin -symbols" \
      STRIP=":" \
      AR="${_BUILD_AR} lib" \
      RANLIB=":"
fi

[ "${_DO_MAKE}" -eq 1 ] && make
[ "${_DO_CHECK}" -eq 1 ] && make check
