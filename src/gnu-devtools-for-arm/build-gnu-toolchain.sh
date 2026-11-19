#!/bin/bash

# build-gnu-toolchain.sh
#
# This script is a top level driver for the build-baremetal-toolchain.sh,
# build-cross-linux-toolchain.sh and build-native-toolchain.sh build scripts.
#
# The scripts rely on the following paths:
# - execdir: Current working directory
# - script_dir: Directory where the scripts are collected (location of gnu-devtools-for-arm)
# - buildroot: Directory where the builds are created (same as execdir)
# - srcdir: Source directory ($buildroot/src)

set -e
set -u

PS4='+$(date +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

execdir=`pwd`
execdir=`cd "$execdir"; pwd`
if [[ "$(uname -s)" == "Darwin" ]]; then
    script_dir=$(dirname $(greadlink -f "${BASH_SOURCE[0]}"))
else
    script_dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
fi
if [ ! -f "$script_dir/utilities.sh" ]; then
  echo "error:Could not find helper script at $script_dir/utilities.sh"
  exit 1
else
  source $script_dir/utilities.sh
fi

variant=`basename $execdir`

all_targets_nonmorello="aarch64-none-elf aarch64-none-linux-gnu aarch64-none-linux-gnu_ilp32 aarch64_be-none-elf aarch64_be-none-linux-gnu arm-none-eabi arm-none-linux-gnueabihf arm-none-linux-gnueabi arm-none-eabi"
all_targets="aarch64-none-linux-gnu_purecap $all_targets_nonmorello"
flag_debug_options_flag=0
flag_debug_target_flag=0
flag_disable_gdb=0
flag_disable_multilib=0
flag_enable_aprofile=0
flag_enable_check_gdb=1
flag_enable_rmprofile=0
flag_native_build=0
flag_morello=0

targets_list=""
NL=$'\n'
TAB=$'\t'
for t in $all_targets
do
  targets_list="$NL $TAB * $t or ${t/-none-/-} $targets_list"
done

usage()
{
cat <<EOF
Usage: build-gnu-toolchain.sh [OPTIONs]

This script is a top level driver for the:
* build-native-toolchain.sh
* build-baremetal-toolchain.sh and
* build-cross-linux-toolchain.sh build scripts.

  --aprofile
    Enable aprofile multilib only. Also see --rmprofile.
    Default is "--aprofile --rmprofile" to build both A-profile and
    RM-class multilibs.

  --[no-]check-gdb
    Disable gdb testing for your toolchain builds(s).

  --debug
    Options for debugging the toolchain. Builds the host components of
    the toolchain with extra debugging information. Disabled by default.

  --debug-target
    Enable debugging options when building target code (e.g. target
    libraries such as libgcc and libstdc++). Disabled by default.

  --dejagnu-site=Alternative site.exp file to be used.
    Specify name of an alternative site.exp to be used along with --dejagnu-src
    if on a different path. Else this will look for the named site.exp in
    the default location. Default is to use site-exhaustive-fastmodels.exp.

  --dejagnu-src=PATH.
    Define the PATH to a dejagnu install.  Default is to use the relative
    path from gnu-devtools-for-arm/dejagnu in the source area.

  --disable-gdb
    Disable build of GDB for your toolchain build(s).

  --disable-multilib
    Disable multilibs for GCC builds.

  --extra=EXTRA
    Pass extra flags to gnu-devtools-for-arm/build-*.sh scripts.

  -h / --help
    Print this help message

  --host-toolchain=PATH_TO_BIN
    Use host toolchain for native builds.
    Default HOST_TOOLCHAIN_ROOT environment variable.

  --native
    Force native build behavior. See --host-toolchain command line switch.

  --rmprofile
    Enable rmprofile multilib only. Also see --aprofile.
    Default is "--aprofile --rmprofile" to build both A-profile and
    RM-class multilibs.

  --morello
    Build Morello toolchain.

  --target=TARGET
    Target for toolchain to build. If building multiple toolchains, you may
    specify this multiple times: --target=<targ1> --target=<targ2> etc.
    Available targets: ${targets_list:-}

  --target-board=BOARD
    Specify a dejagnu target board.  Defaults to site.exp selection.

  --with-arch=ARCH
    Pass to toolchain build flag: --config-flags-gcc=--with-arch=ARCH
    This sets the defaults for -march=, -mtune=, -mfpu=, etc. and builds the
    default multilib for those options.  This means that it can be used
    together with --disable-multilib to build a single-multilib toolchain.
    This is useful to cut down the toolchain build time during development.

  -x
    Enable Bash debug prints for this script and following build-*.sh toolchain
    scripts.

  FILESYSTEM LAYOUT:
  <buildroot>/
    build-gnu-toolchain.sh
    src
      <all toolchain components>
      gnu-devtools-for-arm/
    build-<target>/

  To build (or rebuild) everything:
  $ build-gnu-toolchain.sh

  To build to a specific output directory:
  $ build-gnu-toolchain.sh --builddir=some/output/dir

  To build (or rebuild) just one target use this form:
  $ build-gnu-toolchain.sh --target=aarch64-none-linux-gnu

  To build (or rebuild) just one target from a specific stage use this form:
  $ build-gnu-toolchain.sh --target=aarch64-none-linux-gnu gcc-3

  Use the last flavour to run the test suites:
  $ build-gnu-toolchain.sh --target=aarch64-none-linux-gnu check

  Building different variations of GDB:

  $ build-gnu-toolchain.sh '--extra=--enable-gdb-with-python=yes' --target=aarch64-elf gdb

  Also all components of binutils can be tested with one command

  $ build-gnu-toolchain.sh  --target=aarch64-none-linux-gnu check-binutils-all

  Building toolchains with debug information

  The default is for toolchains to be built with "lightweight debug" -O1 -g

  To build toolchain with CFLAGS="-O0 -g3" given target do:

  $ build-gnu-toolchain.sh --debug --target=aarch64-none-linux-gnu

  To build target libraries with CFLAGS="-O0 -g3" given target do:

  $ build-gnu-toolchain.sh --debug-target --target=aarch64-none-linux-gnu

  These options can be used together for maximum debug-ability:

  $ build-gnu-toolchain.sh --debug --debug-target --target=aarch64-none-linux-gnu

  To build a single-multilib toolchain,

  Or even:
  $ build-gnu-toolchain.sh check

EOF
}

set_darwin_envvars

# Parse command-line options
args=$(getopt -ohj:l:x -l aprofile,check-gdb,no-check-gdb,debug,debug-target,dejagnu-site:,dejagnu-src:,disable-gdb,disable-multilib,morello,extra:,native,rmprofile,help,target:,with-arch:,builddir:,host-toolchain:,target-board: -n $(basename "$0") -- "$@")
eval set -- "$args"
while [ $# -gt 0 ]; do
  if [ -n "${opt_prev:-}" ]; then
    eval "$opt_prev=\$1"
    opt_prev=
    shift 1
    continue
  elif [ -n "${opt_append:-}" ]; then
    eval "$opt_append=\"\${$opt_append:-} \$1\""
    opt_append=
    shift 1
    continue
  fi
  case $1 in
  --aprofile)
    flag_enable_aprofile=1
    ;;

  --check-gdb)
    flag_enable_check_gdb=1
    ;;

  --no-check-gdb)
    flag_enable_check_gdb=0
    ;;

  --debug)
    flag_debug_options_flag=1
    ;;

  --debug-target)
    flag_debug_target_flag=1
    ;;

  --dejagnu-site)
    opt_prev=dejagnu_site
    ;;

  --dejagnu-src)
    opt_prev=dejagnu_src
    ;;

  --disable-gdb)
    flag_disable_gdb=1
    flag_enable_check_gdb=0
    ;;

  --disable-multilib)
    flag_disable_multilib=1
    ;;

  --morello)
    extra="${extra:-} --morello"
    flag_morello=1
    ;;

  --extra)
    opt_append=extra
    ;;

  --target-board)
    opt_prev=target_board
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  --native)
    flag_native_build=1
    ;;

  --rmprofile)
    flag_enable_rmprofile=1
    ;;

  --target)
    opt_append=targets
    ;;

  --with-arch)
    opt_prev=arch
    ;;

  --builddir)
    opt_prev=builddir
    ;;

  --host-toolchain)
    opt_prev=host_toolchain_path
    ;;

  -x)
    set -x
    extra="${extra:-} -x"
    ;;

  --)
    shift
    break 2
    ;;
  esac
  shift 1
done

declare -a make_targets=()
for i in "$@"
do
  if [[ "$i" = "check-binutils-all" ]]; then
    make_targets+=("check-binutils" "check-gas" "check-gdb" "check-ld")
  else
    make_targets+=("$i")
  fi
done

buildroot="$execdir"
srcdir="$buildroot/src"

if [ -z "${targets:-}" ]; then
  targets=$all_targets_nonmorello
fi

target_count=$(echo $targets | wc -w)
if [ "$target_count" -gt 1 ]; then
    printf "warning: You have specified multiple targets, and therefore if the specified arguments are invalid for a target, that target build will fail.\n"
fi

for target in $targets
do
  builddir="$buildroot/build-$target"
  extraflags=""

  if [ $flag_enable_check_gdb -eq 1 ]; then
      extraflags="${extraflags:-} --check-gdb"
  else
      extraflags="${extraflags:-} --no-check-gdb"
  fi

  if [ $flag_disable_gdb -eq 1 ]; then
      extraflags="$extraflags --disable-gdb"
  fi

  if [ $flag_disable_multilib -eq 1 ]; then
      extraflags="$extraflags --config-flags-gcc=--disable-multilib"
  fi

  if [ $flag_debug_options_flag -eq 1 ]; then
      extraflags="$extraflags --debug"
  fi

  if [ $flag_debug_target_flag -eq 1 ]; then
      extraflags="$extraflags --debug-target"
  fi

  if [ ! -z "${dejagnu_site:-}" ]; then
      extraflags="$extraflags --dejagnu-site=$dejagnu_site"
  fi

  if [ ! -z "${dejagnu_src:-}" ]; then
      extraflags="$extraflags --dejagnu-src=$dejagnu_src"
  fi

  if [ ! -z "${target_board:-}" ]; then
      extraflags="$extraflags --target-board=$target_board"
  fi

  case $target in
  arm*-none-eabi)
    if [[ "$flag_enable_aprofile" == "0" && "$flag_enable_rmprofile" == "0" ]]; then
      # If no A or RM profile was selected, build both
      flag_enable_aprofile=1
      flag_enable_rmprofile=1
    fi
    ;;

  arm*-none-linux-gnueabi)
    arch="${arch:-armv8-a}"
    extraflags="$extraflags --config-flags-gcc=--with-float=softfp"
    extraflags="$extraflags --config-flags-gcc=--with-fpu=crypto-neon-fp-armv8"
    extraflags="$extraflags --config-flags-gcc=--with-mode=thumb"
    ;;

  arm*-none-linux-gnueabihf)
    arch="${arch:-armv7-a}"
    extraflags="$extraflags --config-flags-gcc=--with-float=hard"
    extraflags="$extraflags --config-flags-gcc=--with-fpu=neon"
    ;;

  esac

  if [ -n "${arch:-}" ] ; then
    extraflags="$extraflags --config-flags-gcc=--with-arch=$arch"
    builddir="$builddir-$arch"
  fi

  maybe_fortran="--with-language=fortran"
  if [ $flag_morello -eq 1 ]; then
    maybe_fortran=""
  fi

  case $target in
  *-linux-gnu | *-linux-gnu_ilp32 | *-linux-gnu_purecap | *-linux-gnueabi*)
    if [ $flag_native_build -eq 0 ]; then
      script="build-cross-linux-toolchain.sh"
      extraflags="$extraflags ${maybe_fortran} --disable-multiarch"
    else
      script="build-native-toolchain.sh"
      printf "error: Native builds not yet implemented" >&2
      exit 1
      # Host toolchain > GCC 4.8 is required for native builds
      if [ -n "${HOST_TOOLCHAIN_ROOT:-}" ]; then
        host_toolchain_path="${host_toolchain_path:-$HOST_TOOLCHAIN_ROOT/$target/bin}"
      fi

      if [ ! -d "${host_toolchain_path:-}" ]; then
        printf "error: can't find host toolchain path: %s \n" "$host_toolchain_path" >&2
        printf "       try setting HOST_TOOLCHAIN_ROOT or use --host-toolchain \n\n" >&2
        exit 1
      fi
      extraflags="$extraflags --host-toolchain-path=${host_toolchain_path:-}"
    fi
    ;;

  *-elf | *-eabi)
    script="build-baremetal-toolchain.sh"
    extraflags="$extraflags ${maybe_fortran}"
    ;;

  *)
    printf "error: do not know how to build $target\n" >&2
    exit 1
    ;;
  esac

  # Set GCC multilib-list configuration flag
  if [ $flag_disable_multilib -eq 0 ]; then
    extra_multilib="--config-flags-gcc=--with-multilib-list="
    if [ $flag_enable_aprofile -eq 1 ]; then
      extra_multilib="${extra_multilib}aprofile"
    fi

    if [ $flag_enable_rmprofile -eq 1 ]; then
      if [[ $extra_multilib == *profile ]]; then
        # --with-multilib-list=aprofile,rmprofile
        extra_multilib="${extra_multilib},"
      fi
      extra_multilib="${extra_multilib}rmprofile"
    fi
    # Only inject with-multilib-list with profile if flag was explicitly set
    if [[ $extra_multilib == *profile ]]; then
      extraflags="$extraflags $extra_multilib"
    fi
  fi

  case $target in aarch64*-linux-gnu_ilp32)
    # TODO: Add multilib support lp64,ilp32
    extraflags="$extraflags --config-flags-gcc=--with-multilib-list=ilp32"
  esac

  case $target in aarch64*-linux-gnu_purecap)
    # qemu and gdbserver build fails with purecap
    extraflags="$extraflags --disable-qemu --disable-gdb"
    # default to purecap abi
    extraflags="$extraflags --config-flags-gcc=--with-abi=purecap --config-flags-gcc=--with-arch=morello+c64"
  esac

  case $target in aarch64*-linux-gnu)
    if [ $flag_morello -eq 1 ]; then
      extraflags="$extraflags --config-flags-gcc=--with-multilib-list=lp64,purecap"
    fi
  esac

  # The user-specified build directory should override the one computed
  builddir=${builddir_arg:-$builddir}

  "$srcdir/gnu-devtools-for-arm/$script" --builddir="$builddir" --target="$target" $extraflags ${extra:-} --srcdir="$srcdir" "${make_targets[@]:-}"
done
