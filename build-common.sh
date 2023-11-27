# Copyright (c) 2011-2020, ARM Limited
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Arm nor the names of its contributors may be used
#       to endorse or promote products derived from this software without
#       specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

error () {
    set +u
    echo "$0: error: $@" >&2
    exit 1
    set -u
}

warning () {
    set +u
    echo "$0: warning: $@" >&2
    set -u
}

copy_dir() {
    set +u
    mkdir -p "$2"

    (cd "$1" && tar cf - .) | (cd "$2" && tar xf -)
    set -u
}

copy_dir_clean() {
    set +u
    mkdir -p "$2"
    (cd "$1" && tar cf - \
        --exclude=CVS --exclude=.svn --exclude=.git --exclude=.pc \
        --exclude="*~" --exclude=".#*" \
        --exclude="*.orig" --exclude="*.rej" \
        .) | (cd "$2" && tar xf -)
    set -u
}

# Create source package excluding source control information
#   parameter 1: base dir of the source tree
#   parameter 2: dirname of the source tree
#   parameter 3: target package name
#   parameter 4-10: additional excluding
# This function will create bz2 package for files under param1/param2,
# excluding unnecessary parts, and create package named param2.
pack_dir_clean() {
    set +u
    tar cjfh $3 \
        --exclude=CVS --exclude=.svn --exclude=.git --exclude=.pc \
        --exclude="*~" --exclude=".#*" \
        --exclude="*.orig" --exclude="*.rej" $4 $5 $6 $7 $8 $9 ${10} \
        -C $1 $2
    set -u
}

# Clean all global shell variables except for those needed by build scripts
clean_env () {
    set +u
    local var_list
    var_list=$(export | grep "^declare -x" | sed -e "s/declare -x //" | cut -d"=" -f1 | grep -E '[[:upper:]]+\b')

    for var in $var_list ; do
        case "$var" in
        WORKSPACE | SRC_VERSION)
            ;;
        DEJAGNU | DISPLAY | HOME | LD_LIBRARY_PATH | LOGNAME | PATH | PWD | SHELL | SHLVL | TERM | USER | USERNAME | XAUTHORITY)
            ;;
        com.apple.*)
            ;;
        LSB_* | LSF_* | LS_* | EGO_* | HOSTTYPE | TMPDIR)
            ;;
        LP_ENABLE_WRAP_*)
            ;;
        *)
            unset "$var"
            ;;
        esac
    done

    export LANG=C
    set -u
}

# Start a new stack level to save variables
# Must call this before saving any variables
saveenv () {
    set +u
    # Force expr return 0 to avoid script fail
    stack_level=`expr $stack_level \+ 1 || true`
    eval stack_list_$stack_level=
    set -u
}

# Save a variable to current stack level, and set new value to this var.
# If a variable has been saved, won't save it. Just set new value
# Must be called when stack_level > 0
# $1: variable name
# $2: new variable value
saveenvvar () {
    set +u
    if [ $stack_level -le 0 ]; then
        error Must call saveenv before calling saveenvvar
    fi
    local varname="$1"
    local newval="$2"
    eval local oldval=\"\${$varname}\"
    eval local saved=\"\${level_saved_${stack_level}_${varname}}\"
    if [ "x$saved" = "x" ]; then
        # The variable wasn't saved in the level before. Save it
        eval local temp=\"\${stack_list_$stack_level}\"
        eval stack_list_$stack_level=\"$varname $temp\"
        eval save_level_${stack_level}_$varname=\"$oldval\"
        eval level_saved_${stack_level}_$varname="yes"
        eval level_preset_${stack_level}_${varname}=\"\${$varname+set}\"
        #echo Save $varname: \"$oldval\"
    fi
    eval export $varname=\"$newval\"
    #echo $varname set to \"$newval\"
    set -u
}

# Restore all variables that have been saved in current stack level
restoreenv () {
    set +u
    if [ $stack_level -le 0 ]; then
        error "Trying to restore from an empty stack"
    fi

    eval local list=\"\${stack_list_$stack_level}\"
    local varname
    for varname in $list; do
        eval local varname_preset=\"\${level_preset_${stack_level}_${varname}}\"
        if [ "x$varname_preset" = "xset" ] ; then
            eval $varname=\"\${save_level_${stack_level}_$varname}\"
        else
            unset $varname
        fi
        eval level_saved_${stack_level}_$varname=
        # eval echo $varname restore to \\\"\"\${$varname}\"\\\"
    done
    # Force expr return 0 to avoid script fail
    stack_level=`expr $stack_level \- 1 || true`
    set -u
}

prependenvvar() {
    set +u
    eval local oldval=\"\$$1\"
    saveenvvar "$1" "$2$oldval"
    set -u
}

prepend_path() {
    set +u
    eval local old_path="\"\$$1\""
    if [ x"$old_path" == "x" ]; then
        prependenvvar "$1" "$2"
    else
        prependenvvar "$1" "$2:"
    fi
    set -u
}

# Breaks a hard link (created with ln) between one or more files
break_hardlink() {
    if [ $# -ne 1 ] ; then
        warning "break_hardlink: Missing argument"
        return 0
    fi
    local filename="$1"

    if [ ! -f "$filename" ] ; then
        error "break_hardlink: Argument is not a file ($filename)"
        return 1
    fi

    local dir=$(dirname -- "$filename")
    local tmp=$(TMPDIR=$dir mktemp)
    cp -p -- "$filename" "$tmp"
    mv -f -- "$tmp" "$filename"
}

# Strip binary files as in "strip binary" form, for both native(linux/mac) and mingw.
strip_binary() {
    set +e
    if [ $# -ne 2 ] ; then
        warning "strip_binary: Missing arguments"
        return 0
    fi
    local strip="$1"
    local bin="$2"

    file $bin | grep -q -e "\bELF\b" -e "\bPE\b" -e "\bPE32\b" -e "\bMach-O\b"
    if [ $? -eq 0 ]; then
        $strip $bin 2>/dev/null || true
    fi

    set -e
}

# Copy target libraries from each multilib directories.
# Usage copy_multi_libs dst_prefix=... src_prefix=... target_gcc=...
copy_multi_libs() {
    local -a multilibs
    local multilib
    local multi_dir
    local src_prefix
    local dst_prefix
    local src_dir
    local dst_dir
    local target_gcc

    for arg in "$@" ; do
        eval "${arg// /\\ }"
    done

    multilibs=( $("${target_gcc}" -print-multi-lib 2>/dev/null) )
    for multilib in "${multilibs[@]}" ; do
        multi_dir="${multilib%%;*}"
        src_dir=${src_prefix}/${multi_dir}
        dst_dir=${dst_prefix}/${multi_dir}
        cp -f "${src_dir}/libstdc++.a" "${dst_dir}/libstdc++_nano.a"
        cp -f "${src_dir}/libsupc++.a" "${dst_dir}/libsupc++_nano.a"
        cp -f "${src_dir}/libc.a" "${dst_dir}/libc_nano.a"
        cp -f "${src_dir}/libg.a" "${dst_dir}/libg_nano.a"
        cp -f "${src_dir}/librdimon.a" "${dst_dir}/librdimon_nano.a"
        cp -f "${src_dir}/librdimon-v2m.a" "${dst_dir}/librdimon-v2m_nano.a"
        cp -f "${src_dir}/nano.specs" "${dst_dir}/"
        cp -f "${src_dir}/rdimon.specs" "${dst_dir}/"
        cp -f "${src_dir}/nosys.specs" "${dst_dir}/"
        cp -f "${src_dir}/"*crt0.o "${dst_dir}/"
    done
}

# Clean up unnecessary global shell variables
clean_env

ROOT=`pwd`
SRCDIR=$ROOT/src

BUILDDIR_NATIVE=$ROOT/build-native
BUILDDIR_MINGW=$ROOT/build-mingw
INSTALLDIR_NATIVE=$ROOT/install-native
INSTALLDIR_NATIVE_DOC=$ROOT/install-native/share/doc/gcc-arm-none-eabi
INSTALLDIR_MINGW=$ROOT/install-mingw
INSTALLDIR_MINGW_DOC=$ROOT/install-mingw/share/doc/gcc-arm-none-eabi

PACKAGEDIR=$ROOT/pkg

GMP_VER=6.2.1
MPFR_VER=3.1.6
MPC_VER=1.0.3
ISL_VER=0.18
EXPAT_VER=2.2.5
LIBICONV_VER=1.15
ZLIB_VER=1.2.12
PYTHON_WIN_VER=2.7.13

BINUTILS=binutils
GCC=gcc
NEWLIB=newlib
NEWLIB_NANO=newlib
GDB=gdb
GMP=gmp
MPFR=mpfr
MPC=mpc
ISL=isl
EXPAT=expat
LIBICONV=libiconv
ZLIB=zlib-$ZLIB_VER
PYTHON_WIN=python-$PYTHON_WIN_VER.amd64

GMP_PACK=$GMP.tar.bz2
MPFR_PACK=$MPFR.tar.bz2
MPC_PACK=$MPC.tar.gz
ISL_PACK=$ISL.tar.xz
EXPAT_PACK=$EXPAT.tar.bz2
LIBICONV_PACK=$LIBICONV.tar.gz
ZLIB_PACK=$ZLIB.tar.gz
PYTHON_WIN_PACK=$PYTHON_WIN.msi

GMP_URL=https://gmplib.org/download/gmp/$GMP_PACK
MPFR_URL=http://www.mpfr.org/$MPFR/$MPFR_PACK
MPC_URL=ftp://ftp.gnu.org/gnu/mpc/$MPC_PACK
ISL_URL=http://isl.gforge.inria.fr/$ISL_PACK
EXPAT_URL=https://downloads.sourceforge.net/project/expat/expat/$EXPAT_VER/$EXPAT_PACK
LIBICONV_URL=https://ftp.gnu.org/pub/gnu/libiconv/$LIBICONV_PACK
ZLIB_URL=http://www.zlib.net/fossils/$ZLIB_PACK
PYTHON_WIN_URL=https://www.python.org/ftp/python/$PYTHON_WIN_VER/$PYTHON_WIN_PACK

TAR=tar
# Set variables according to real environment to make this script can run
# on Ubuntu and Mac OS X.
uname_string=`uname | sed 'y/LINUXDARWIN/linuxdarwin/'`
host_arch=`uname -m | sed 'y/XI/xi/'`
if [ "x$uname_string" == "xlinux" ] ; then
    BUILD="$host_arch"-linux-gnu
    HOST_NATIVE="$host_arch"-linux-gnu
    READLINK=readlink
    JOBS=`grep ^processor /proc/cpuinfo|wc -l`
    GCC_CONFIG_OPTS_LCPP="--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
    MD5="md5sum -b"
    PACKAGE_NAME_SUFFIX="${host_arch}-linux"
    WGET="wget -q"
elif [ "x$uname_string" == "xdarwin" ] ; then
    BUILD=x86_64-apple-darwin10
    HOST_NATIVE=x86_64-apple-darwin10
    READLINK=greadlink
    # Disable parallel build for mac as we will randomly run into "Permission denied" issue.
    #JOBS=`sysctl -n hw.ncpu`
    JOBS=1
    GCC_CONFIG_OPTS_LCPP="--with-host-libstdcxx=-static-libgcc -Wl,-lstdc++ -lm"
    MD5="md5 -r"
    PACKAGE_NAME_SUFFIX=mac-$(sw_vers -productVersion)
    #Redefine wget command to curl as MacOS does not have wget by default
    WGET="curl -OLs"
    TAR=gtar
else
    error "Unsupported build system : $uname_string"
fi

SRC_PREREQS="GMP MPFR MPC ISL EXPAT LIBICONV ZLIB"
WIN_PREREQS="PYTHON_WIN"

PREREQS="$SRC_PREREQS"
if [ "x$BUILD" != "xx86_64-apple-darwin10" ]; then
    PREREQS="$SRC_PREREQS $WIN_PREREQS"
fi

SCRIPT=$(basename $0)

RELEASEDATE=20220808
RELEASEVER=Rel1


# This is a build script, go on
# format of pattern match is:
# build-* or *_build
if [[ "${SCRIPT%%-*}" = "build" || "${SCRIPT#*_*}" = "build" ]]; then

    stack_level=0

    LICENSE_FILE=license.txt
    GCC_VER=`cat $SRCDIR/$GCC/gcc/BASE-VER`
    GCC_VER_DISPLAY=`cut -d'.' -f1,2 $SRCDIR/$GCC/gcc/BASE-VER`
    STM32_TOOLS_VER=`git describe --tags 2>/dev/null || echo "$GCC_VER_DISPLAY-$RELEASEVER~$(git rev-parse --verify HEAD)"`

    # sed -r doesn't exist in Darwin
    if [[ $(uname -s) == "Darwin" ]]
    then
        SEDOPTION='-E'
    else
        SEDOPTION='-r'
    fi
    HOST_MINGW=x86_64-w64-mingw32
    HOST_MINGW_TOOL=x86_64-w64-mingw32
    TARGET=arm-none-eabi
    ENV_CFLAGS=
    ENV_CPPFLAGS=
    ENV_LDFLAGS=
    BINUTILS_CONFIG_OPTS=
    GCC_CONFIG_OPTS=
    GDB_CONFIG_OPTS=
    NEWLIB_CONFIG_OPTS=


    PKGROOTNAME="GNU Tools for STM32"
    PKGVERSION="$PKGROOTNAME $STM32_TOOLS_VER"
    BUGURL="https://developer.arm.com/open-source/gnu-toolchain/gnu-rm"

    OBJ_SUFFIX_MINGW=$TARGET-$RELEASEDATE-$HOST_MINGW
    OBJ_SUFFIX_NATIVE=$TARGET-$RELEASEDATE-$HOST_NATIVE
    PACKAGE_NAME=gnu-tools-for-stm32-$STM32_TOOLS_VER
    PACKAGE_NAME_NATIVE=$PACKAGE_NAME-$PACKAGE_NAME_SUFFIX
    PACKAGE_NAME_MINGW=$PACKAGE_NAME-win32
    INSTALL_PACKAGE_NAME=$PACKAGE_NAME

fi # not a build script
