#! /usr/bin/env bash
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

set -e
set -x
set -u
set -o pipefail

PS4='+$(date -u +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

umask 022

exec < /dev/null

script_path=$(cd $(dirname $0) && pwd -P)
. $script_path/build-common.sh

# This file contains the sequence of commands used to build the
# GNU Tools Arm Embedded toolchain.
usage ()
{
cat<<EOF
Usage: $0 [--build_type=...] [--skip_steps=...]

This script will build GNU Tools Arm Embedded toolchain.

OPTIONS:
  --build_type=TYPE     specify build type to either ppa or native.
                        If followed by keyword debug, the produced binaries
                        will be debuggable.  The default case will be
                        non-debug native build.

                        Example usages are as:
                        --build_type=native
                        --build_type=ppa
                        --build_type=native,debug
                        --build_type=ppa,debug

  --with-multilib-list  specify list of multilibs included with the build.
                        For example:
                        --with-multilib-list=rmprofile
                        --with-multilib-list=rmprofile,aprofile  (Default value)

  --skip_steps=STEPS    specify which build steps you want to skip.  Concatenate
                        them with comma for skipping more than one steps.
                        Available steps are:
                            gdb-with-python
                            manual
                            md5_checksum
                            mingw[32]
                            mingw[32]-gdb-with-python
                            native
                            package_bins
                            package_sources
                            strip
EOF
}

if [ $# -gt 3 ] ; then
    usage
fi

skip_mingw32=no
BUILD_OPTIONS="-g -O2"
is_ppa_release=no
is_native_build=yes
is_debug_build=no
skip_manual=no
skip_package_bins=no
skip_package_sources=no
skip_md5_checksum=no
skip_steps=
skip_gdb_with_python=no
skip_mingw32_gdb_with_python=no
skip_native_build=no
skip_strip_target_libraries=no
build_type=

MULTILIB_LIST="--with-multilib-list=rmprofile,aprofile"

for ac_arg; do
    case $ac_arg in
        --skip_steps=*)
            skip_steps=$(echo $ac_arg | sed -e "s/--skip_steps=//g" -e "s/,/ /g")
            ;;
        --build_type=*)
            build_type=$(echo $ac_arg | sed -e "s/--build_type=//g" -e "s/,/ /g")
            ;;
        --with-multilib-list=*)
            MULTILIB_LIST="--with-multilib-list=${ac_arg##*=}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [ "x$build_type" != "x" ]; then
  for bt in $build_type; do
    case $bt in
      ppa)
        is_ppa_release=yes
        is_native_build=no
        skip_gdb_with_python=yes
        ;;
      native)
        is_native_build=yes
        is_ppa_release=no
        ;;
      debug)
        BUILD_OPTIONS="-g -O0"
        is_debug_build=yes
        ;;
      *)
        echo "Unknown build type: $bt" 1>&2
        usage
        exit 1
        ;;
    esac
  done
else
  is_ppa_release=no
  is_native_build=yes
fi

if [ "x$skip_steps" != "x" ]; then
    for ss in $skip_steps; do
        case $ss in
            manual)
                skip_manual=yes
                ;;
            package_bins)
                skip_package_bins=yes
                ;;
            package_sources)
                skip_package_sources=yes
                ;;
            md5_checksum)
                skip_md5_checksum=yes
                ;;
            gdb-with-python)
                skip_gdb_with_python=yes
                ;;
            mingw|mingw32)
                skip_mingw32=yes
                skip_mingw32_gdb_with_python=yes
                ;;
            mingw-gdb-with-python|mingw32-gdb-with-python)
                skip_mingw32_gdb_with_python=yes
                ;;
            native)
                skip_native_build=yes
                ;;
            strip)
                skip_strip_target_libraries=yes
                ;;
            *)
               echo "Unknown build steps: $ss" 1>&2
               usage
               exit 1
               ;;
        esac
    done
fi

if dpkg-query -W lbzip2 > /dev/null 2>&1; then
    echo "Using multi-threaded bzip2 compression"
    TAR_FLAGS="--use-compress-program=lbzip2"
fi

if [ "x$BUILD" == "xx86_64-apple-darwin10" ] || [ "x$is_ppa_release" == "xyes" ]; then
    skip_mingw32=yes
    skip_mingw32_gdb_with_python=yes
    BUILD_OPTIONS="$BUILD_OPTIONS -fbracket-depth=512"
fi

#Building mingw gdb with python support requires python windows package and
#a special config file. If any of them is missing, we skip the build of
#mingw gdb with python support.
if [ ! -d $SRCDIR/$PYTHON_WIN ] \
     || [ ! -x $script_path/python-config.sh ]; then
    skip_mingw32_gdb_with_python=yes
fi

if [ "x$is_ppa_release" != "xyes" ]; then
  ENV_CFLAGS=" -I$BUILDDIR_NATIVE/host-libs/zlib/include $BUILD_OPTIONS "
  ENV_CPPFLAGS=" -I$BUILDDIR_NATIVE/host-libs/zlib/include "
  ENV_LDFLAGS=" -L$BUILDDIR_NATIVE/host-libs/zlib/lib
                -L$BUILDDIR_NATIVE/host-libs/usr/lib "

  if [ -d $SRCDIR/$PYTHON_WIN ]; then
    ENV_LDFLAGS+=" -L$SRCDIR/$PYTHON_WIN/lib "
  fi

  GCC_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE
                    --with-gmp=$BUILDDIR_NATIVE/host-libs/usr
                    --with-mpfr=$BUILDDIR_NATIVE/host-libs/usr
                    --with-mpc=$BUILDDIR_NATIVE/host-libs/usr
                    --with-isl=$BUILDDIR_NATIVE/host-libs/usr "

  BINUTILS_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE "

  NEWLIB_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE "

  GDB_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE
                    --with-libgmp-prefix=$BUILDDIR_NATIVE/host-libs/usr \
                    --with-libexpat-prefix=$BUILDDIR_NATIVE/host-libs/usr "
fi

if [ "x$skip_native_build" != "xyes" ] ; then
    mkdir -p $BUILDDIR_NATIVE
    rm -rf $INSTALLDIR_NATIVE && mkdir -p $INSTALLDIR_NATIVE
    rm -rf $PACKAGEDIR && mkdir -p $PACKAGEDIR
fi

if [ "x$skip_mingw32" != "xyes" ] ; then
    mkdir -p $BUILDDIR_MINGW
    rm -rf $INSTALLDIR_MINGW && mkdir -p $INSTALLDIR_MINGW
fi

cd $SRCDIR

if [ "x$skip_native_build" != "xyes" ] ; then
    echo Task [III-0] /$HOST_NATIVE/binutils/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -rf $BUILDDIR_NATIVE/binutils && mkdir -p $BUILDDIR_NATIVE/binutils
    pushd $BUILDDIR_NATIVE/binutils
    saveenv
    saveenvvar CFLAGS "$ENV_CFLAGS"
    saveenvvar CPPFLAGS "$ENV_CPPFLAGS"
    saveenvvar LDFLAGS "$ENV_LDFLAGS"
    $SRCDIR/$BINUTILS/configure  \
        ${BINUTILS_CONFIG_OPTS} \
        --target=$TARGET \
        --prefix=$INSTALLDIR_NATIVE \
        --infodir=$INSTALLDIR_NATIVE_DOC/info \
        --mandir=$INSTALLDIR_NATIVE_DOC/man \
        --htmldir=$INSTALLDIR_NATIVE_DOC/html \
        --pdfdir=$INSTALLDIR_NATIVE_DOC/pdf \
        --disable-nls \
        --disable-werror \
        --disable-sim \
        --disable-gdb \
        --enable-interwork \
        --enable-plugins \
        --with-sysroot=$INSTALLDIR_NATIVE/arm-none-eabi \
        "--with-pkgversion=$PKGVERSION"

    make -j$JOBS

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make install-html install-pdf
    fi

    copy_dir $INSTALLDIR_NATIVE $BUILDDIR_NATIVE/target-libs
    restoreenv
    popd

    pushd $INSTALLDIR_NATIVE
    rm -rf ./lib
    popd

    echo Task [III-1] /$HOST_NATIVE/gcc-first/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -rf $BUILDDIR_NATIVE/gcc-first && mkdir -p $BUILDDIR_NATIVE/gcc-first
    pushd $BUILDDIR_NATIVE/gcc-first
    $SRCDIR/$GCC/configure --target=$TARGET \
        --prefix=$INSTALLDIR_NATIVE \
        --libexecdir=$INSTALLDIR_NATIVE/lib \
        --infodir=$INSTALLDIR_NATIVE_DOC/info \
        --mandir=$INSTALLDIR_NATIVE_DOC/man \
        --htmldir=$INSTALLDIR_NATIVE_DOC/html \
        --pdfdir=$INSTALLDIR_NATIVE_DOC/pdf \
        --enable-languages=c \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-newlib \
        --without-headers \
        --with-gnu-as \
        --with-gnu-ld \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot=$INSTALLDIR_NATIVE/arm-none-eabi \
	--with-zstd=no \
        ${GCC_CONFIG_OPTS}                              \
        "${GCC_CONFIG_OPTS_LCPP}"                              \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    make -j$JOBS CXXFLAGS="$BUILD_OPTIONS" all-gcc

    make install-gcc

    popd

    pushd $INSTALLDIR_NATIVE
    rm -rf bin/arm-none-eabi-gccbug
    rm -rf ./lib/libiberty.a
    rm -rf  include
    popd

    echo Task [III-2] /$HOST_NATIVE/newlib/ | tee -a "$BUILDDIR_NATIVE/.stage"
    saveenv
    prepend_path PATH $INSTALLDIR_NATIVE/bin
    saveenvvar CFLAGS_FOR_TARGET '-g -Os -ffunction-sections -fdata-sections -fno-unroll-loops -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -DSMALL_MEMORY'
    rm -rf $BUILDDIR_NATIVE/newlib && mkdir -p $BUILDDIR_NATIVE/newlib
    pushd $BUILDDIR_NATIVE/newlib

    $SRCDIR/$NEWLIB/configure  \
        $NEWLIB_CONFIG_OPTS \
        --target=$TARGET \
        --prefix=$INSTALLDIR_NATIVE \
        --infodir=$INSTALLDIR_NATIVE_DOC/info \
        --mandir=$INSTALLDIR_NATIVE_DOC/man \
        --htmldir=$INSTALLDIR_NATIVE_DOC/html \
        --pdfdir=$INSTALLDIR_NATIVE_DOC/pdf \
        --enable-newlib-io-long-long \
        --enable-newlib-io-c99-formats \
        --enable-newlib-reent-check-verify \
        --enable-newlib-register-fini \
        --enable-newlib-retargetable-locking \
        --disable-newlib-supplied-syscalls \
        --disable-nls

    make -j$JOBS

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make pdf
        mkdir -p $INSTALLDIR_NATIVE_DOC/pdf
        cp $BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libc/libc.pdf $INSTALLDIR_NATIVE_DOC/pdf/libc.pdf
        cp $BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libm/libm.pdf $INSTALLDIR_NATIVE_DOC/pdf/libm.pdf

        make html
        mkdir -p $INSTALLDIR_NATIVE_DOC/html
        copy_dir $BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libc/libc.html $INSTALLDIR_NATIVE_DOC/html/libc
        copy_dir $BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libm/libm.html $INSTALLDIR_NATIVE_DOC/html/libm
    fi

    popd
    restoreenv

    echo Task [III-3] /$HOST_NATIVE/newlib-nano/ | tee -a "$BUILDDIR_NATIVE/.stage"
    saveenv
    prepend_path PATH $INSTALLDIR_NATIVE/bin
    saveenvvar CFLAGS_FOR_TARGET '-g -Os -ffunction-sections -fdata-sections -fno-unroll-loops -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -DSMALL_MEMORY'
    rm -rf $BUILDDIR_NATIVE/newlib-nano && mkdir -p $BUILDDIR_NATIVE/newlib-nano
    pushd $BUILDDIR_NATIVE/newlib-nano

    $SRCDIR/$NEWLIB_NANO/configure  \
        $NEWLIB_CONFIG_OPTS \
        --target=$TARGET \
        --prefix=$BUILDDIR_NATIVE/target-libs \
        --disable-newlib-supplied-syscalls    \
        --enable-newlib-reent-check-verify    \
        --enable-newlib-reent-small           \
        --enable-newlib-retargetable-locking  \
        --disable-newlib-fvwrite-in-streamio  \
        --disable-newlib-fseek-optimization   \
        --disable-newlib-wide-orient          \
        --enable-newlib-nano-malloc           \
        --disable-newlib-unbuf-stream-opt     \
        --enable-lite-exit                    \
        --enable-newlib-global-atexit         \
        --enable-newlib-nano-formatted-io     \
        --disable-nls

    make -j$JOBS
    make install

    popd
    restoreenv

    echo Task [III-4] /$HOST_NATIVE/gcc-final/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -f $INSTALLDIR_NATIVE/arm-none-eabi/usr
    ln -s . $INSTALLDIR_NATIVE/arm-none-eabi/usr

    rm -rf $BUILDDIR_NATIVE/gcc-final && mkdir -p $BUILDDIR_NATIVE/gcc-final
    pushd $BUILDDIR_NATIVE/gcc-final

    $SRCDIR/$GCC/configure --target=$TARGET \
        --prefix=$INSTALLDIR_NATIVE \
        --libexecdir=$INSTALLDIR_NATIVE/lib \
        --infodir=$INSTALLDIR_NATIVE_DOC/info \
        --mandir=$INSTALLDIR_NATIVE_DOC/man \
        --htmldir=$INSTALLDIR_NATIVE_DOC/html \
        --pdfdir=$INSTALLDIR_NATIVE_DOC/pdf \
        --enable-languages=c,c++ \
        --enable-plugins \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-gnu-as \
        --with-gnu-ld \
        --with-newlib \
        --with-headers=yes \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot=$INSTALLDIR_NATIVE/arm-none-eabi \
	--with-zstd=no \
        $GCC_CONFIG_OPTS                                \
        "${GCC_CONFIG_OPTS_LCPP}"                              \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    # Passing USE_TM_CLONE_REGISTRY=0 via INHIBIT_LIBC_CFLAGS to disable
    # transactional memory related code in crtbegin.o.
    # This is a workaround. Better approach is have a t-* to set this flag via
    # CRTSTUFF_T_CFLAGS
    make -j$JOBS CXXFLAGS="$BUILD_OPTIONS" \
            INHIBIT_LIBC_CFLAGS="-DUSE_TM_CLONE_REGISTRY=0"

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make install-html install-pdf
    fi

    pushd $INSTALLDIR_NATIVE
    rm -rf bin/arm-none-eabi-gccbug
    LIBIBERTY_LIBRARIES=$(find $INSTALLDIR_NATIVE/arm-none-eabi/lib -name libiberty.a)
    for libiberty_lib in $LIBIBERTY_LIBRARIES ; do
        rm -rf $libiberty_lib
    done
    rm -rf ./lib/libiberty.a
    rm -rf  include
    popd

    rm -f $INSTALLDIR_NATIVE/arm-none-eabi/usr
    popd

    echo Task [III-5] /$HOST_NATIVE/gcc-size-libstdcxx/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -f $BUILDDIR_NATIVE/target-libs/arm-none-eabi/usr
    ln -s . $BUILDDIR_NATIVE/target-libs/arm-none-eabi/usr

    rm -rf $BUILDDIR_NATIVE/gcc-size-libstdcxx && mkdir -p $BUILDDIR_NATIVE/gcc-size-libstdcxx
    pushd $BUILDDIR_NATIVE/gcc-size-libstdcxx

    $SRCDIR/$GCC/configure --target=$TARGET \
        --prefix=$BUILDDIR_NATIVE/target-libs \
        --enable-languages=c,c++ \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-libstdcxx-verbose \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-gnu-as \
        --with-gnu-ld \
        --with-newlib \
        --with-headers=yes \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot=$BUILDDIR_NATIVE/target-libs/arm-none-eabi \
	--with-zstd=no \
        $GCC_CONFIG_OPTS \
        "${GCC_CONFIG_OPTS_LCPP}"                              \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    make -j$JOBS CCXXFLAGS="$BUILD_OPTIONS" CXXFLAGS_FOR_TARGET="-g -Os -ffunction-sections -fdata-sections -fno-exceptions"
    make install

    copy_multi_libs src_prefix="$BUILDDIR_NATIVE/target-libs/arm-none-eabi/lib" \
                    dst_prefix="$INSTALLDIR_NATIVE/arm-none-eabi/lib"           \
                    target_gcc="$BUILDDIR_NATIVE/target-libs/bin/arm-none-eabi-gcc"

    # Copy the nano configured newlib.h file into the location that nano.specs
    # expects it to be.
    mkdir -p $INSTALLDIR_NATIVE/arm-none-eabi/include/newlib-nano
    cp -f $BUILDDIR_NATIVE/target-libs/arm-none-eabi/include/newlib.h \
          $INSTALLDIR_NATIVE/arm-none-eabi/include/newlib-nano/newlib.h

    popd

    echo Task [III-6] /$HOST_NATIVE/gdb/ | tee -a "$BUILDDIR_NATIVE/.stage"
    build_gdb()
    {
        GDB_EXTRA_CONFIG_OPTS=$1

        rm -rf $BUILDDIR_NATIVE/gdb && mkdir -p $BUILDDIR_NATIVE/gdb
        pushd $BUILDDIR_NATIVE/gdb
        saveenv
        saveenvvar CFLAGS "$ENV_CFLAGS"
        saveenvvar CPPFLAGS "$ENV_CPPFLAGS"
        saveenvvar LDFLAGS "$ENV_LDFLAGS"

        $SRCDIR/$GDB/configure  \
            --target=$TARGET \
            --prefix=$INSTALLDIR_NATIVE \
            --infodir=$INSTALLDIR_NATIVE_DOC/info \
            --mandir=$INSTALLDIR_NATIVE_DOC/man \
            --htmldir=$INSTALLDIR_NATIVE_DOC/html \
            --pdfdir=$INSTALLDIR_NATIVE_DOC/pdf \
            --disable-nls \
            --disable-sim \
            --disable-gas \
            --disable-binutils \
            --disable-ld \
            --disable-gprof \
            --with-libexpat \
            --with-lzma=no \
            --with-system-gdbinit=$INSTALLDIR_NATIVE/$HOST_NATIVE/arm-none-eabi/lib/gdbinit \
            $GDB_CONFIG_OPTS \
            $GDB_EXTRA_CONFIG_OPTS \
            '--with-gdb-datadir='\''${prefix}'\''/arm-none-eabi/share/gdb' \
            "--with-pkgversion=$PKGVERSION"

        make -j$JOBS

        make install

        if [ "x$skip_manual" != "xyes" ]; then
            make install-html install-pdf
            rm -v $INSTALLDIR_NATIVE_DOC/html/gdb/qMemTags.html
        fi

        restoreenv
        popd
    }


    #Always enable python support in GDB for PPA build.
    if [ "x$is_ppa_release" == "xyes" ]; then
        build_gdb "--with-python=yes"
    else
        #First we build GDB without python support.
        build_gdb "--with-python=no"

        #Then build gdb with python support.
        if [ "x$skip_gdb_with_python" == "xno" ]; then
            build_gdb "--with-python=yes --program-prefix=$TARGET-  --program-suffix=-py"
        fi
    fi

    echo Task [III-8] /$HOST_NATIVE/pretidy/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -rf $INSTALLDIR_NATIVE/lib/libiberty.a
    find $INSTALLDIR_NATIVE -name '*.la' -exec rm '{}' ';'

    echo Task [III-9] /$HOST_NATIVE/strip_host_objects/ | tee -a "$BUILDDIR_NATIVE/.stage"
    if [ "x$is_debug_build" == "xno" ] ; then
        STRIP_BINARIES=$(find $INSTALLDIR_NATIVE/bin/ -name arm-none-eabi-\*)
        for bin in $STRIP_BINARIES ; do
            strip_binary strip $bin
        done

        STRIP_BINARIES=$(find $INSTALLDIR_NATIVE/arm-none-eabi/bin/ -maxdepth 1 -mindepth 1 -name \*)
        for bin in $STRIP_BINARIES ; do
            strip_binary strip $bin
        done

        if [ "x$BUILD" == "xx86_64-apple-darwin10" ]; then
            STRIP_BINARIES=$(find $INSTALLDIR_NATIVE/lib/gcc/arm-none-eabi/$GCC_VER/ -maxdepth 1 -name \* -perm +111 -and ! -type d)
        else
            STRIP_BINARIES=$(find $INSTALLDIR_NATIVE/lib/gcc/arm-none-eabi/$GCC_VER/ -maxdepth 1 -name \* -perm /111 -and ! -type d)
        fi
        for bin in $STRIP_BINARIES ; do
            strip_binary strip $bin
        done
    fi

    echo Task [III-10] /$HOST_NATIVE/strip_target_objects/ | tee -a "$BUILDDIR_NATIVE/.stage"
    saveenv
    prepend_path PATH $INSTALLDIR_NATIVE/bin

    if [ "x$skip_strip_target_libraries" == "xno" ] ; then
        TARGET_LIBRARIES=$(find $INSTALLDIR_NATIVE/arm-none-eabi/lib -name libg.a -or -name libg_nano.a)
        for target_lib in $TARGET_LIBRARIES ; do
            break_hardlink "$target_lib"
        done
        TARGET_LIBRARIES=$(find $INSTALLDIR_NATIVE/arm-none-eabi/lib -name \*.a ! -name libg.a ! -name libg_nano.a)
        for target_lib in $TARGET_LIBRARIES ; do
            arm-none-eabi-strip --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_lib || true
        done

        TARGET_OBJECTS=$(find $INSTALLDIR_NATIVE/arm-none-eabi/lib -name \*.o)
        for target_obj in $TARGET_OBJECTS ; do
            arm-none-eabi-strip --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_lib || true
        done

        TARGET_LIBRARIES=$(find $INSTALLDIR_NATIVE/lib/gcc/arm-none-eabi/$GCC_VER -name \*.a)
        for target_lib in $TARGET_LIBRARIES ; do
            arm-none-eabi-strip --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_lib || true
        done

        TARGET_OBJECTS=$(find $INSTALLDIR_NATIVE/lib/gcc/arm-none-eabi/$GCC_VER -name \*.o)
        for target_obj in $TARGET_OBJECTS ; do
            arm-none-eabi-strip --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_lib || true
        done
    fi
    restoreenv

    echo Task [III-11] /$HOST_NATIVE/specs/ | tee -a "$BUILDDIR_NATIVE/.stage"
    pushd $BUILDDIR_NATIVE
    $INSTALLDIR_NATIVE/bin/arm-none-eabi-gcc -print-multi-lib | cut -d';' -f 1 | while read dir; do
      cp -v $SRCDIR/specs/{nano_c_standard_cpp,standard_c_nano_cpp}.specs $INSTALLDIR_NATIVE/arm-none-eabi/lib/$dir/
    done
    popd

    # PPA release needn't following steps, so we exit here.
    if [ "x$is_ppa_release" == "xyes" ] ; then
      exit 0
    fi

    echo Task [III-12] /$HOST_NATIVE/package_tbz2/ | tee -a "$BUILDDIR_NATIVE/.stage"

    # Copy release.txt into share.
    cp $ROOT/$LICENSE_FILE $INSTALLDIR_NATIVE_DOC/

    # Cleanup any pre-existing state.
    rm -f $PACKAGEDIR/$PACKAGE_NAME_NATIVE.tar.bz2
    rm -f $BUILDDIR_NATIVE/$INSTALL_PACKAGE_NAME

    # Start making the package.
    pushd $BUILDDIR_NATIVE
    ln -s $INSTALLDIR_NATIVE $INSTALL_PACKAGE_NAME

    # Make the package tarball.
    ${TAR} cjf $PACKAGEDIR/$PACKAGE_NAME_NATIVE.tar.bz2   \
        --exclude=host-$HOST_NATIVE             \
        --exclude=host-$HOST_MINGW              \
        $INSTALL_PACKAGE_NAME/arm-none-eabi     \
        $INSTALL_PACKAGE_NAME/bin               \
        $INSTALL_PACKAGE_NAME/lib               \
        $INSTALL_PACKAGE_NAME/share

    # Remove stale links.
    rm -f $INSTALL_PACKAGE_NAME
    popd

    if [ "x$skip_package_bins" != "xyes" ]; then
        echo Task [III-13] /Package toolchain in ST version/
        pushd $ROOT
        time ${TAR} czf $PACKAGEDIR/${PACKAGE_NAME_NATIVE}-build.tar.gz --owner=0 --group=0 build-native/
        time ${TAR} czf $PACKAGEDIR/${PACKAGE_NAME_NATIVE}-install.tar.gz --owner=0 --group=0 install-native/
        popd
    fi  # end of if [ "x$skip_package_bins" != "xyes" ]; then
fi  #if [ "x$skip_native_build" != "xyes" ] ; then

# skip building mingw32 toolchain if "--skip_mingw32" specified
# this huge if statement controls all $BUILDDIR_MINGW tasks till "task [IV-8]"
if [ "x$skip_mingw32" != "xyes" ] ; then
    saveenv
    saveenvvar CC_FOR_BUILD gcc
    saveenvvar CC $HOST_MINGW_TOOL-gcc
    saveenvvar CXX $HOST_MINGW_TOOL-g++
    saveenvvar AR $HOST_MINGW_TOOL-ar
    saveenvvar RANLIB $HOST_MINGW_TOOL-ranlib
    saveenvvar STRIP $HOST_MINGW_TOOL-strip
    saveenvvar NM $HOST_MINGW_TOOL-nm

    echo Task [IV-0] /$HOST_MINGW/host_unpack/ | tee -a "$BUILDDIR_MINGW/.stage"
    rm -rf $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE && mkdir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE
    pushd $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE
    ln -s . $INSTALL_PACKAGE_NAME
    tar xf $PACKAGEDIR/$PACKAGE_NAME_NATIVE.tar.bz2 ${TAR_FLAGS:-}
    rm $INSTALL_PACKAGE_NAME
    popd

    echo Task [IV-1] /$HOST_MINGW/binutils/ | tee -a "$BUILDDIR_MINGW/.stage"
    prepend_path PATH $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/bin
    rm -rf $BUILDDIR_MINGW/binutils && mkdir -p $BUILDDIR_MINGW/binutils
    pushd $BUILDDIR_MINGW/binutils
    saveenv
    saveenvvar CFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include -I$BUILDDIR_MINGW/host-libs/usr/include $BUILD_OPTIONS"
    saveenvvar CPPFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include -I$BUILDDIR_MINGW/host-libs/usr/include"
    saveenvvar LDFLAGS "-L$BUILDDIR_MINGW/host-libs/zlib/lib -L$BUILDDIR_MINGW/host-libs/usr/lib -Wl,/usr/$HOST_MINGW/lib/CRT_glob.o"
    saveenvvar LDFLAGS_WRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/exe.inputs"
    saveenvvar LDFLAGS_DLLWRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/dll.inputs"
    $SRCDIR/$BINUTILS/configure --build=$BUILD \
        --host=$HOST_MINGW \
        --target=$TARGET \
        --prefix=$INSTALLDIR_MINGW \
        --infodir=$INSTALLDIR_MINGW_DOC/info \
        --mandir=$INSTALLDIR_MINGW_DOC/man \
        --htmldir=$INSTALLDIR_MINGW_DOC/html \
        --pdfdir=$INSTALLDIR_MINGW_DOC/pdf \
        --disable-nls \
        --disable-sim \
        --disable-gdb \
        --enable-plugins \
        --with-sysroot=$INSTALLDIR_MINGW/arm-none-eabi \
        "--with-pkgversion=$PKGVERSION"

    make -j$JOBS

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make install-html install-pdf
    fi

    restoreenv
    popd

    pushd $INSTALLDIR_MINGW
    rm -rf ./lib
    popd

    echo Task [IV-2] /$HOST_MINGW/copy_libs/ | tee -a "$BUILDDIR_MINGW/.stage"
    if [ "x$skip_manual" != "xyes" ]; then
        copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/share/doc/gcc-arm-none-eabi/html $INSTALLDIR_MINGW_DOC/html
        copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/share/doc/gcc-arm-none-eabi/pdf $INSTALLDIR_MINGW_DOC/pdf
    fi
    copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/arm-none-eabi/lib $INSTALLDIR_MINGW/arm-none-eabi/lib
    copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/arm-none-eabi/include $INSTALLDIR_MINGW/arm-none-eabi/include
    copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/arm-none-eabi/include/c++ $INSTALLDIR_MINGW/arm-none-eabi/include/c++
    copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/lib/gcc/arm-none-eabi $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi

    echo Task [IV-3] /$HOST_MINGW/gcc-final/ | tee -a "$BUILDDIR_MINGW/.stage"
    saveenv
    saveenvvar AR_FOR_TARGET $TARGET-ar
    saveenvvar NM_FOR_TARGET $TARGET-nm
    saveenvvar OBJDUMP_FOR_TARET $TARGET-objdump
    saveenvvar STRIP_FOR_TARGET $TARGET-strip
    saveenvvar CC_FOR_TARGET $TARGET-gcc
    saveenvvar GCC_FOR_TARGET $TARGET-gcc
    saveenvvar CXX_FOR_TARGET $TARGET-g++
    saveenvvar LDFLAGS_WRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/exe.inputs"
    saveenvvar LDFLAGS_DLLWRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/dll.inputs"

    pushd $INSTALLDIR_MINGW/arm-none-eabi/
    rm -f usr
    ln -s . usr
    popd
    rm -rf $BUILDDIR_MINGW/gcc && mkdir -p $BUILDDIR_MINGW/gcc
    pushd $BUILDDIR_MINGW/gcc
    saveenvvar CFLAGS "$BUILD_OPTIONS"
    $SRCDIR/$GCC/configure --build=$BUILD --host=$HOST_MINGW --target=$TARGET \
        --prefix=$INSTALLDIR_MINGW \
        --libexecdir=$INSTALLDIR_MINGW/lib \
        --infodir=$INSTALLDIR_MINGW_DOC/info \
        --mandir=$INSTALLDIR_MINGW_DOC/man \
        --htmldir=$INSTALLDIR_MINGW_DOC/html \
        --pdfdir=$INSTALLDIR_MINGW_DOC/pdf \
        --enable-languages=c,c++ \
        --enable-mingw-wildcard \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-gnu-as \
        --with-gnu-ld \
        --with-headers=yes \
        --with-newlib \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot=$INSTALLDIR_MINGW/arm-none-eabi \
        --with-libiconv-prefix=$BUILDDIR_MINGW/host-libs/usr \
        --with-gmp=$BUILDDIR_MINGW/host-libs/usr \
        --with-mpfr=$BUILDDIR_MINGW/host-libs/usr \
        --with-mpc=$BUILDDIR_MINGW/host-libs/usr \
        --with-isl=$BUILDDIR_MINGW/host-libs/usr \
        "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm" \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}

    make -j$JOBS all-gcc

    make install-gcc

    if [ "x$skip_manual" != "xyes" ]; then
        make install-html-gcc install-pdf-gcc
    fi
    popd

    pushd $INSTALLDIR_MINGW
    rm -rf bin/arm-none-eabi-gccbug
    rm -rf  include
    popd

    copy_dir $BUILDDIR_MINGW/tools-$OBJ_SUFFIX_NATIVE/lib/gcc/arm-none-eabi $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi
    rm -rf $INSTALLDIR_MINGW/arm-none-eabi/usr
    rm -rf $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi/*/plugin
    find $INSTALLDIR_MINGW -executable -and -not -type d -and -not -name \*.exe \
      -and -not -name liblto_plugin.dll -exec rm -vf \{\} \;
    find $INSTALLDIR_MINGW -name 'liblto_plugin.so*' -exec rm -vf \{\} \;
    restoreenv

    echo Task [IV-4] /$HOST_MINGW/gdb/ | tee -a "$BUILDDIR_MINGW/.stage"
    build_mingw_gdb()
    {
        MINGW_GDB_CONF_OPTS=$1
        rm -rf $BUILDDIR_MINGW/gdb && mkdir -p $BUILDDIR_MINGW/gdb
        pushd $BUILDDIR_MINGW/gdb
        saveenv
        saveenvvar CFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include $BUILD_OPTIONS"
        saveenvvar CPPFLAGS "-I$BUILDDIR_MINGW/host-libs/zlib/include"
        saveenvvar LDFLAGS "-L$BUILDDIR_MINGW/host-libs/zlib/lib -Wl,/usr/$HOST_MINGW/lib/CRT_glob.o"
        saveenvvar LDFLAGS_WRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/exe.inputs"
        saveenvvar LDFLAGS_DLLWRAP_FILEIO "@$BUILDDIR_MINGW/liblongpath-win32/gcc/dll.inputs"
        $SRCDIR/$GDB/configure --build=$BUILD \
            --host=$HOST_MINGW \
            --target=$TARGET \
            --prefix=$INSTALLDIR_MINGW \
            --infodir=$INSTALLDIR_MINGW_DOC/info \
            --mandir=$INSTALLDIR_MINGW_DOC/man \
            --htmldir=$INSTALLDIR_MINGW_DOC/html \
            --pdfdir=$INSTALLDIR_MINGW_DOC/pdf \
            --disable-nls \
            --disable-sim \
            --disable-gas \
            --disable-binutils \
            --disable-ld \
            --disable-gprof \
            --with-lzma=no \
            $MINGW_GDB_CONF_OPTS \
            --with-libexpat \
            --with-libexpat-prefix=$BUILDDIR_MINGW/host-libs/usr \
            --with-libiconv-prefix=$BUILDDIR_MINGW/host-libs/usr \
            --with-libgmp-prefix=$BUILDDIR_MINGW/host-libs/usr \
            --with-system-gdbinit=$INSTALLDIR_MINGW/$HOST_MINGW/arm-none-eabi/lib/gdbinit \
            '--with-gdb-datadir='\''${prefix}'\''/arm-none-eabi/share/gdb' \
            "--with-pkgversion=$PKGVERSION"

        make -j$JOBS

        make install
        if [ "x$skip_manual" != "xyes" ]; then
            make install-html install-pdf
            rm -v $INSTALLDIR_MINGW_DOC/html/gdb/qMemTags.html
        fi

        restoreenv
        popd
    }

    build_mingw_gdb_conf_opts="--disable-source-highlight --with-static-standard-libraries"
    build_mingw_gdb "--with-python=no $build_mingw_gdb_conf_opts"

    if [ "x$skip_mingw32_gdb_with_python" == "xno" ]; then
        export GNURM_PYTHON_WIN_DIR=$SRCDIR/$PYTHON_WIN
        build_mingw_gdb "--with-python=$script_path/python-config.sh --program-suffix=-py --program-prefix=$TARGET- $build_mingw_gdb_conf_opts"
    fi

    echo Task [IV-5] /$HOST_MINGW/pretidy/ | tee -a "$BUILDDIR_MINGW/.stage"
    pushd $INSTALLDIR_MINGW
    rm -rf ./lib/libiberty.a
    rm -rf $INSTALLDIR_MINGW_DOC/info
    rm -rf $INSTALLDIR_MINGW_DOC/man

    find $INSTALLDIR_MINGW -name '*.la' -exec rm '{}' ';'

    echo Task [IV-6] /Validate executables/
    $SRCDIR/liblongpath-win32/helper.py --validate $INSTALLDIR_MINGW  --triplet $HOST_MINGW_TOOL

    echo Task [IV-6] /$HOST_MINGW/strip_host_objects/ | tee -a "$BUILDDIR_MINGW/.stage"
    STRIP_BINARIES=$(find $INSTALLDIR_MINGW/bin/ -name arm-none-eabi-\*.exe)
    if [ "x$is_debug_build" == "xno" ] ; then
        for bin in $STRIP_BINARIES ; do
            strip_binary $HOST_MINGW_TOOL-strip $bin
        done

        STRIP_BINARIES=$(find $INSTALLDIR_MINGW/arm-none-eabi/bin/ -maxdepth 1 -mindepth 1 -name \*.exe)
        for bin in $STRIP_BINARIES ; do
            strip_binary $HOST_MINGW_TOOL-strip $bin
        done

        STRIP_BINARIES=$(find $INSTALLDIR_MINGW/lib/gcc/arm-none-eabi/$GCC_VER/ -name \*.exe)
        for bin in $STRIP_BINARIES ; do
            strip_binary $HOST_MINGW_TOOL-strip $bin
        done
    fi

    echo Task [IV-7] /$HOST_MINGW/installation/ | tee -a "$BUILDDIR_MINGW/.stage"
    rm -f $PACKAGEDIR/$PACKAGE_NAME_MINGW.exe
    pushd $BUILDDIR_MINGW
    rm -f $INSTALL_PACKAGE_NAME
    cp $ROOT/$LICENSE_FILE $INSTALLDIR_MINGW_DOC/
    flip -m -b $INSTALLDIR_MINGW_DOC/$LICENSE_FILE
    rm -rf $INSTALLDIR_MINGW/include
    popd
    restoreenv

    echo Task [IV-8] /Package toolchain in zip format/
    pushd $(dirname $INSTALLDIR_MINGW)
    ln -s $(basename $INSTALLDIR_MINGW) $PACKAGE_NAME
    rm -f $PACKAGEDIR/$PACKAGE_NAME_MINGW.zip
    zip -r9 $PACKAGEDIR/$PACKAGE_NAME_MINGW.zip $PACKAGE_NAME
    rm $PACKAGE_NAME
    popd

    if [ "x$skip_package_bins" != "xyes" ]; then
        echo Task [IV-10] /Package toolchain in ST version/
        pushd $ROOT
        time ${TAR} czf $PACKAGEDIR/${PACKAGE_NAME_MINGW}-build.tar.gz --owner=0 --group=0 build-mingw/
        time ${TAR} czf $PACKAGEDIR/${PACKAGE_NAME_MINGW}-install.tar.gz --owner=0 --group=0 install-mingw/
        popd
    fi #end of if [ "x$skip_package_bins" != "xyes" ]; then
fi #end of if [ "x$skip_mingw32" != "xyes" ] ;

if [ "x$skip_package_sources" != "xyes" ]; then
    echo Task [V-0] /package_sources/
    pushd "$PACKAGEDIR"
    rm -rf "$PACKAGE_NAME" && mkdir -p "$PACKAGE_NAME/src"
    pack_dir_clean "$SRCDIR" "$BINUTILS" "$PACKAGE_NAME/src/$BINUTILS.tar.bz2" \
      --exclude="gdb/testsuite/config/qemu.exp" --exclude="sim"
    pack_dir_clean "$SRCDIR" "$GCC" "$PACKAGE_NAME/src/$GCC.tar.bz2"
    pack_dir_clean "$SRCDIR" "$GDB" "$PACKAGE_NAME/src/$GDB.tar.bz2" \
      --exclude="gdb/testsuite/config/qemu.exp" --exclude="sim"
    pack_dir_clean "$SRCDIR" "$NEWLIB" "$PACKAGE_NAME/src/$NEWLIB.tar.bz2"

    for prereq in $SRC_PREREQS; do
        eval prereq_pack="\$${prereq}_PACK"
        cp "$SRCDIR/$prereq_pack" "$PACKAGE_NAME/src/"
    done

    if [ -f "$SRCDIR/source.spc" ]; then
        cp "$SRCDIR/source.spc" "$PACKAGE_NAME/src/"
    fi

    cp "$ROOT/$LICENSE_FILE" "$PACKAGE_NAME/"
    if [ -d "$ROOT/docker" ]; then
        cp -r "$ROOT/docker" "$PACKAGE_NAME/"
    fi

    cp "$script_path/install-sources.sh" "$PACKAGE_NAME/"
    cp "$script_path/build-common.sh" "$PACKAGE_NAME/"
    cp "$script_path/build-prerequisites.sh" "$PACKAGE_NAME/"
    cp "$script_path/build-toolchain.sh" "$PACKAGE_NAME/"
    cp "$script_path/python-config.sh" "$PACKAGE_NAME/"
    if [ -f "$script_path/build.sh" ]; then
        cp "$script_path/build.sh" "$PACKAGE_NAME/"
    fi

    tar cf "$PACKAGE_NAME-src.tar.bz2" "$PACKAGE_NAME" ${TAR_FLAGS:-}
    rm -rf "$PACKAGE_NAME"
    popd
fi

if [ "x$skip_md5_checksum" != "xyes" ]; then
    echo Task [V-1] /md5_checksum/
    pushd "$PACKAGEDIR"
    MD5_CHECKSUM_FILE="md5-$(uname -m)-$(uname | tr '[:upper:]' '[:lower:]').txt"
    rm -rf "$MD5_CHECKSUM_FILE"
    $MD5 "$PACKAGE_NAME_NATIVE.tar.bz2" > "$MD5_CHECKSUM_FILE"

    if [ "x$skip_package_sources" != "xyes" ]; then
        $MD5 "$PACKAGE_NAME-src.tar.bz2" >> "$MD5_CHECKSUM_FILE"
    fi
    popd
fi
