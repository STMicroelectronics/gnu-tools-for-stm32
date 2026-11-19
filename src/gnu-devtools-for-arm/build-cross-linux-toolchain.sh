#!/usr/bin/env bash

set -u
set -o errexit
set -o pipefail

PS4='+$(date +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

## Find our executable location
execdir=`dirname $0`
execdir=`cd $execdir; pwd`
default_target=aarch64-none-linux-gnu
all_args="$*"
this_script="build-cross-linux-toolchain.sh"
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ ! -f "$script_dir/utilities.sh" ]; then
  echo "error:Could not find helper script at $script_dir/utilities.sh"
  exit 1
else
  source $script_dir/utilities.sh
fi
tmpdir=$(mktemp -d)
trap cleanup 0

if [ "$(uname -s)" == "Darwin" ]; then
  set_darwin_envvars
fi

usage ()
{
    cat <<EOF

usage: $this_script [OPTION] [STAGE]

  Build linux cross toolchains targetting a specified architecture.

  Without a stage, $this_script will start with "start" and sequence through each of the build stages.  At each stage
  progress is recorded.  Should execution stop and subsequently be restarted, $this_script will continue from the
  recorded progress point.  With one or more stage arguments, $this_script will ignore any recorded progress and
  proceed directly with the specified stages, in the order specified.

  Many of the stages are "chained", once complete they chain into the next stage of the build process. The chained
  stages generally have an unchained equivalent, which if specified, will trigger just the execution of that stage.
  These unchained stages are convenient for development.

  Interesting stages are:

  clean:
    Wipe the build and head for stage start.

  start
    The default stage.

  check
    A pseudo stage that invokes all available check stages.

  binutils (the unchained binutils-chained)
    Build binutils.

  gcc3 (the unchained gcc3-chained)
    Build stage 3 gcc.

  libc (the unchained libc-chained)
    Build glibc.

   Options are:

  --bugurl=TEXT
    Define the --with-bugurl=FOO configuration option text for relevant packages.

  --builddir=DIR
    Define the build directory to be used.  Defaults to the current working
    directory.

  --[no-]check-gdb
    Enable check-gdb as a target for check.  Default off. Using this will run
    gdb testing by default.

  --config-flags-binutils=FLAGS
    Specify additional configuration flags for binutils.

  --config-flags-gcc=FLAGS
    Specify additional configuration flags for gcc.

  --config-flags-host-tools=FLAGS
    Specify additional configuration flags for host-tools.

  --config-flags-libc=options
    Pass options to the configuration of libc.

  --config-flags-qemu=FLAGS
    Specify additional configuration flags for qemu.

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

  --enable-gdb
  --disable-gdb
    Disable building and testing GDB.  The default is to build GDB.

  --enable-gcc
  --disable-gcc
    Disable building and testing GCC.  Default enabled.

  --enable-binutils
  --disable-binutils
    Disable building and testing Binutils.  Default enabled.

  --enable-gdb-with-python=PATH
    Enable building GDB with Python support. PATH determines configuration
    file behavior. 'yes' enables Python support. PATH can be also a path to
    special python-config.sh script which helps to determine local Python
    environment settings.  Default disabled.

  --enable-maintainer-mode
  --disable-maintainer-mode
    Enable or disable maintainer mode, default disable.

  --enable-qemu
  --disable-qemu
    Disable building QEMU.  Default enabled.

  --morello
    Build Morello toolchain.

  -h, --help
    Print brief usage information and exit.

  --host
    The host triple to use. Defaults to that of the build machine (i.e.
    the machine on which this script is run).

  --host-toolchain-path=DIR)
    Path to the host toolchain. Default is to use a toolchain
    on the standard PATH.

  -j N
    Use a maximum of N threads of parallel tasks.

  -l N
    Do not spawn additional threads whilst the system load is N (a
    floating-point number) or more

  --[no-]package
    Enable or disable packaging.

  --qemu-test-path=PATH
    Define a PATH to be add to environment PATH in order to find
    an appropriate pre-built qemu for testing.

  --[no-]release
    Enable a release build.  Default off.  Turns down self consistency
    checking, turns up optimization and disables debug support.

  --resultdir=PATH
    PATH to a directory to copy all test results into.

  --srcdir=PATH
    PATH to a directory containing all the source modules required
    for the build.  Default <builddir>/src

  --tag=FOO
    Define the build tag / version identifier to be hardwired into
    the built components that support such a concept.  Default 'unknown'.

  --tardir=PATH
    PATH to a directory where the built binary tar balls should be placed.
    Default <builddir>

  --target=GNU-TRIPLE
    The GNU-TRIPLE that the built toolchain should target.  Default
    $default_target.

  --target-board=BOARD
    Specify a dejagnu target board.  Defaults to site.exp selection.

  --timestamp=TIMESTAMP

  --with-language=LANGUAGE
    Add the specified language to the gcc configure line.

  -x
    Enable shell debugging of this script.

EOF
}

## The stack of stages is abstracted out to these functions primarily to
## isolate the pain of bash arrays in conjunction with set -u.  We want
## set -u behaviour on in order to improve script robustness.  However
## bash arrays do not play nicely in this context.  Notably taking
## the ${# size of an empty array will throw an exception.

declare -a stages
stages=()

cwd=`pwd`

set_gdb_config()
{
    # GDB now requires mpfr [1] and prefix is required when using --with-gmp and --with-mpfr options.
    # We still want to keep the previous config flags --with-libgmp-prefix, --with-libgmp-type, --with-libmpfr-type, and --with-libmpfr-prefix
    # so that previous versions of GDB can still build.
    # [1] See commit 991180627851801f1999d1ebbc0e569a17e47c74 from  binutils-gdb--gdb: Use toplevel configure for GMP and MPFR for gdb.
    # https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=991180627851801f1999d1ebbc0e569a17e47c74

    gdb_config="--enable-64-bit-bfd \
      --enable-targets="$enable_binutils_targets" \
      --target="$target" \
      ${bugurl:+--with-bugurl="\"$bugurl\""} \
      --enable-initfini-array \
      --enable-plugins \
      --enable-tui \
      --disable-binutils \
      --disable-sim \
      --disable-as \
      --disable-ld \
      --disable-doc \
      --disable-gdbtk \
      --disable-nls \
      --disable-werror \
      --without-x \
      --prefix="${host_prefix}" \
      --with-build-sysroot="${build_sysroot}" \
      --with-sysroot="${sysroot}" \
      ${hostmpfr:+--with-libmpfr-prefix=$hostmpfr} \
      ${hostmpfr:+--with-libmpfr-type=static} \
      ${hostmpfr:+--with-mpfr=$hostmpfr} \
      ${hostgmp:+--with-libgmp-prefix=$hostgmp} \
      ${hostgmp:+--with-libgmp-type=static} \
      ${hostgmp:+--with-gmp=$hostgmp} \
      ${extra_config_flags_binutils:-} \
      ${host_arg:-} \
      ${extra_config_flags_host_tools:-} \
      ${extra_config_flags_gdb:-}"
}

## The layout version for the binary tar ball we create.  This should be stepped
## each time we change the structure of the delivered tar ball.
layout_version="2"

# Reload configuration options
if [ -r build.status ]; then
 . build.status
fi

## Enabled by default, but note may be overridden by host or target options
package_flag=0
release_flag=0
gdb_only_flag=0
extra_languages=""
flag_check_gdb=0
flag_debug_options_flag=0
flag_debug_target_flag=0
flag_enable_gdb=1
flag_enable_gcc=1
flag_enable_binutils=1
enable_multiarch=0
flag_enable_qemu=1
flag_enable_mingw=0
flag_morello=0
libname=glibc
host_arg=

# All the check targets supported by this script.
check_targets="check-binutils check-gdb check-ld check-gold check-gas check-gcc check-g++ check-fortran check-target-libatomic check-target-libstdc++-v3 check-target-libgomp check-ffi"
# Parse command-line options
args=$(getopt -ohj:l:x -l bugurl:,builddir:,config-flags-binutils:,config-flags-gcc:,config-flags-host-tools:,config-flags-libc:,config-flags-qemu:,debug,debug-target,dejagnu-site:,dejagnu-src:,enable-gdb,enable-gdb-with-python:,disable-gdb,enable-gcc,disable-gcc,enable-binutils,disable-binutils,enable-maintainer-mode,disable-maintainer-mode,enable-qemu,disable-qemu,enable-multiarch,disable-multiarch,gdb-only,help,host-toolchain-path:,package,no-package,release,no-release,resultdir:,srcdir:,tag:,tardir:,target:,target-board:,timestamp:,with-language:,check-gdb,no-check-gdb,morello,host: -n $(basename "$0") -- "$@")
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
  --bugurl)
    opt_prev=bugurl
    ;;
  --builddir)
    opt_prev=builddir
    ;;
  --check-gdb)
    flag_check_gdb=1
    ;;
  --no-check-gdb)
    flag_check_gdb=0
    ;;
  --config-flags-binutils)
    opt_append=extra_config_flags_binutils
    ;;
  --config-flags-gcc)
    opt_append=extra_config_flags_gcc
    ;;
  --config-flags-host-tools)
    opt_append=extra_config_flags_host_tools
    ;;
  --config-flags-qemu)
    opt_append=extra_config_flags_qemu
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
  --enable-gdb)
    flag_enable_gdb=1
    ;;
  --disable-gdb)
    flag_enable_gdb=0
    ;;
  --enable-gcc)
    flag_enable_gcc=1
    ;;
  --disable-gcc)
    flag_enable_gcc=0
    ;;
  --enable-binutils)
    flag_enable_binutils=1
    ;;
  --disable-binutils)
    flag_enable_binutils=0
    ;;
  --enable-maintainer-mode)
    flag_maintainer_mode=1
    ;;
  --disable-maintainer-mode)
    flag_maintainer_mode=0
    ;;
  --morello)
    flag_morello=1
    ;;
  --enable-gdb-with-python)
    opt_prev=gdb_with_python
    ;;
  --config-flags-libc)
    opt_append=extra_config_flags_libc
    ;;
  --disable-multiarch)
    enable_multiarch=0
    ;;
  --enable-multiarch)
    enable_multiarch=1
    ;;
  --enable-qemu)
    flag_enable_qemu=1
    ;;
  --disable-qemu)
    flag_enable_qemu=0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --host)
    opt_prev=host
    ;;
  --host-toolchain-path)
    opt_prev=host_toolchain_path
    ;;
  -j)
    opt_prev=flag_parallel
    ;;
  -l)
    opt_prev=flag_load
    ;;
  --package)
    package_flag=1
    ;;
  --gdb-only)
    gdb_only_flag=1
    ;;
  --no-package)
    package_flag=0
    ;;
  --release)
    package_flag=1
    release_flag=1
    ;;
  --no-release)
    release_flag=0
    ;;
  --resultdir)
    opt_prev=resultdir
    ;;
  --srcdir)
    opt_prev=srcdir
    ;;
  --tag)
    opt_prev=tag
    ;;
  --tardir)
    opt_prev=tardir
    ;;
  --target)
    opt_prev=target
    ;;
  --target-board)
    opt_prev=target_board
    ;;
  --timestamp)
    opt_prev=timestamp
    ;;
  --with-language)
    opt_append=extra_languages
    ;;
  -x)
    set -x
    ;;
  --)
    shift
    break 2
    ;;
  esac
  shift 1
done

build=`find_build_triple`
if [[ "$build" == *"darwin"* ]]; then
  TAR_CMD=gtar
  host_is_darwin=1
else
  TAR_CMD=tar
  host_is_darwin=0
fi

if [ -n "${flag_parallel:-}" ]; then
  parallel="-j$flag_parallel"
else
  parallel="-j`number_of_cores`"
fi

if [ -n "${flag_load:-}" ]; then
  parallel="${parallel:-} -l$flag_load"
fi

# If the host triple hasn't been given on the command-line, default to
# the triple of the machine we're building on.
if [ -z "${host:-}" ]; then
  host="$build"
fi

native_build=0
if [ "$build" == "$host" ] && [ "$host" == "$target" ]; then
  native_build=1
fi

if [ $# -gt 0 ]; then
  stages=("$@")
fi

languages=c,c++
for language in $extra_languages
do
  languages="$languages,$language"
done

# Set a default build tag if we didn't get one on the command line.
tag="${tag:-unknown}"

# target
target=${target:-$default_target}

timestamp=${timestamp:-`date +"%Y%m%d-%H%M%S"`}

# builddir: where to build the programs
builddir=${builddir:-$cwd}

# Set a default value for tardir.
tardir="${tardir:-$builddir/bin-tar}"

# Install prefix.
prefix="${prefix:-/}"
host_prefix=

# Install tree staging directory.
installdir="${installdir:-$builddir/install}"

# Install tree staging area for qemu build.
qemu_installdir="${qemu_installdir:-$builddir/install-qemu}"

# Install tree staging area for gdb only.
gdb_only_installdir="${gdb_only_installdir:-$builddir/install-gdb}"

srcdir="${srcdir:-$builddir/src}"
objdir="${objdir:-$builddir/obj}"
resultdir="${resultdir:-$builddir/results}"
build_flags_path="$installdir$prefix/.build_flags"

# Install dir for host tools.
host_tools_install=$builddir/host-tools
build_sysroot=${installdir}/${host_prefix}/${target}/libc
stage_include="$builddir"/stage-include
sysroot=${host_prefix}/${target}/libc

# The machine setup may have set LD_RUN_PATH when installing gcc
# we really do not want this since it will affect both host and cross toolchains
export -n LD_RUN_PATH

case "${host:-}" in *mingw*)
  # MinGW builds are special case and are only used for toolchain official
  # releases. We do not redistribute QEMU. Newlib and Newlib-nano are off
  # as we build Newlib* libraries (if needed) in separate build passes.
  flag_enable_mingw=1
  flag_enable_qemu=0
  # Explicitly use -static-libstdc++ and -static-libgcc
  # Default linking behavior of GDB changed. It was static linking by
  # default. Now it has to be explicitly enabled with
  # --with-static-standard-libraries flag
  extra_config_flags_gdb="${extra_config_flags_gdb:-} --disable-source-highlight --with-static-standard-libraries"
  ;;
esac

if [ $flag_enable_mingw -eq 1 ]; then
  host_arg="--host=$host"
  host_tools_triplet="$host"

fi

if [ $release_flag -eq 0 ]; then
  if [ $flag_debug_options_flag -eq 0 ]; then
    cflags="-O1 -g"
  else
    cflags="-O0 -g3"
  fi
  flag_check_bootstrap="${flag_check_bootstrap:-yes}"
  flag_check_final="${flag_check_final:-yes}"
else
  cflags="-O2"
  flag_check_bootstrap="${flag_check_bootstrap:-yes}"
  flag_check_final="${flag_check_final:-release}"
fi

if [ $flag_debug_target_flag -eq 1 ]; then
  cflags_for_target="-O0 -g3"
fi

target_prefix=/usr
target_lib=lib
multilib_purecap=0
case $target in
  arm*-*-linux-gnueabi* | arm*-linux-gnueabi*)
    extra_config_flags_gcc="${extra_config_flags_gcc:-} --with-arch=armv7-a"
    linux_arch=arm
    qemu_target=arm-linux-user,armeb-linux-user
    enable_binutils_targets="arm-none-eabi,arm-none-linux-gnueabihf,armeb-none-eabi,armeb-none-linux-gnueabihf"
    ;;

  aarch64*-*-linux-gnu* | aarch64*-linux-gnu)
    linux_arch=arm64
    qemu_target="aarch64-linux-user,aarch64_be-linux-user"
    enable_binutils_targets="arm-none-eabi,aarch64_be-none-linux-gnu,aarch64_be-none-elf,aarch64-none-linux-gnu,aarch64-none-linux-gnu_ilp32,aarch64-none-elf"
    extra_config_flags_gcc="${extra_config_flags_gcc:-} --enable-fix-cortex-a53-843419"
    target_lib=lib64

    case $target in *ilp32)
      # check configure?
      target_lib=libilp32
      extra_config_flags_gcc="${extra_config_flags_gcc:-} --disable-libsanitizer"
    esac

    multilib_purecap=$flag_morello
    build_purecap=$flag_morello

    case $target in *purecap)
      target_lib=lib64c
      multilib_purecap=0
      build_purecap=1
    esac

    if [ $build_purecap -eq 1 ]; then
      # disable non-purecap-compatible libs
      extra_config_flags_gcc="${extra_config_flags_gcc:-} --disable-libsanitizer --disable-libgomp --disable-libitm"
      # avoid cheri warnings breaking libc-headers build
      extra_config_flags_libc="${extra_config_flags_libc:-} --disable-werror"
      # only c,c++ is supported
      extra_languages=
    fi
    ;;

  *)
    printf "error: $target not recognized\n" >&2
    exit 1
    ;;
esac

libc_cv_slibdir=""
libc_cv_rtlddir=""

case $target in
  aarch64-*-linux-gnu | aarch64-linux-gnu)
    target_tuple=aarch64-linux-gnu
    ldsoname="ld-linux-aarch64.so.1"
    if [ $multilib_purecap -eq 1 ]; then
      purecap_ldsoname="ld-linux-aarch64_purecap.so.1"
      purecap_abi="-mabi=purecap -march=morello+c64"
      purecap_libname="$libname-purecap"
      purecap_target_lib=lib64c
      # No multiarch support for now.
      purecap_target_libdir="$target_prefix/$purecap_target_lib"
      if [ $enable_multiarch -eq 1 ]; then
        printf "error: multiarch is not supported with multilib" >&2
        exit 1
      fi
    fi
    ;;

  aarch64*-linux-gnu_purecap)
    target_tuple=aarch64-linux-gnu_purecap
    ldsoname="ld-linux-aarch64_purecap.so.1"
    ;;

  aarch64*-linux-gnu_ilp32)
    target_tuple=aarch64-linux-gnu_ilp32
    # This is not necessary but one day we will support multilib
    abi="-mabi=ilp32"
    ldsoname="ld-linux-aarch64_ilp32.so.1"
    ;;

  aarch64_be-*-linux-gnu | aarch64_be-linux-gnu)
    target_tuple=aarch64_be-linux-gnu
    ldsoname="ld-linux-aarch64_be.so.1"
    if [ $multilib_purecap -eq 1 ]; then
      printf "error: $target is not supported with multilib purecap" >&2
      exit 1
    fi
    ;;

  arm-*-linux-gnueabi | arm-linux-gnueabi)
    target_tuple=arm-linux-gnueabi
    ldsoname="ld-linux.so.3"
    ;;

  arm-*-linux-gnueabihf | arm-linux-gnueabihf)
    target_tuple=arm-linux-gnueabihf
    ldsoname="ld-linux-armhf.so.3"
    ;;

  armeb-*-linux-gnueabi | armeb-linux-gnueabi)
    target_tuple=arm-linux-gnueabi
    ldsoname="ld-linux.so.3"
    ;;

  armeb-*-linux-gnueabihf | armeb-linux-gnueabihf)
    target_tuple=arm-linux-gnueabihf
    ldsoname="ld-linux-armhf.so.3"
    ;;

  *)
    echo "Specify one {arm x86 ppc mips} architecture to build."
    exit 1
    ;;
esac

## Ensure the work directory exists
mkdir -p "$builddir"
cd "$builddir"

for component in gcc linux "$libname" gmp mpfr mpc binutils isl zstd
do
  find_component_or_error "$srcdir" $component
done

for component in cloog libffi libiconv newlib qemu
do
  find_component "$srcdir" "$component" || true
done

if [ -d "$srcdir/binutils-gdb" ]; then
  binutils_src="$srcdir/binutils-gdb"
fi

gdb_src="$binutils_src"
if [ -d "$srcdir/binutils-gdb--gdb" ]; then
  gdb_src="$srcdir/binutils-gdb--gdb"
fi

eval libc_src="\${${libname}_src}"

# dejagnu site.exp
dejagnu_site="${dejagnu_site:-site-exhaustive-fastmodels.exp}"

if [ -z "${dejagnu_src:-}" ]; then
  # The dejagnu directory should be available in gnu-devtools-for-arm
  find_component_or_error "$srcdir/gnu-devtools-for-arm" dejagnu
fi
##Set the DEJAGNU environment variable for check targets
set_env_var DEJAGNU "$dejagnu_src/$dejagnu_site"
check_if_readable $DEJAGNU

std_libc_config_opts="--enable-shared --with-tls --disable-profile --disable-omitfp --disable-bounded --disable-sanity-checks"

if [ $enable_multiarch -eq 1 ]; then
  std_libc_config_opts="$std_libc_config_opts --enable-multi-arch --libdir=/lib/$target_tuple"
  libc_cv_slibdir="/lib/$target_tuple"
  libc_cv_rtlddir="/lib"
fi

AARCH64SYSROOT="$build_sysroot"
export AARCH64SYSROOT

if empty_stages_p; then
  if [ -r ,stage ]; then
    # Continue from last failing stage
    stages=(`cat ,stage`)
  else
    # Build from the start
    stages=(start)
  fi
fi

hostgmp="$host_tools_install"
hosticonv="$host_tools_install"
hostmpfr="$host_tools_install"
hostmpc="$host_tools_install"
hostexpat="$host_tools_install"
hostzstd="$host_tools_install"

# We are (currently) tolerant to absence ISL and CLOOG hence we only setup
# the relevant --with- flags if the source is present.  These are set here
# rather than in the corresponding build or install stages because it is a
# valid use case to repeatedly restart a build at an arbitrary stage.
if [ -d "$srcdir/isl" ];
then
  hostisl="$host_tools_install"

  # CLOOG requires ISL hence only enable if ISL is also enabled.
  if [ -d "$srcdir/cloog" ];
  then
    hostcloog="$host_tools_install"
  fi
fi

# Ensure binutils components are visible in the PATH
PATH_ORIGINAL="$PATH"
PATH="${installdir}/${host_prefix}/bin:${qemu_installdir}/${host_prefix}/bin:$execdir:$PATH"

if [ -n "${host_toolchain_path:-}" ]; then
  PATH="$host_toolchain_path:$PATH"
fi

target_rtlddir="$target_prefix/lib"
if [ "$enable_multiarch" -eq 1 -a -n "${target_tuple:-}" ]; then
  target_libdir="$target_prefix/lib/$target_tuple"
else
  target_libdir="$target_prefix/$target_lib"
fi

RUNTESTFLAGS="${target_board:+--target_board=$target_board} ${RUNTESTFLAGS:-}"

# 8GB limit on ulimit -v
# Note that 32 bit qemu guest on 64 bit host will request 4GB reserved
# virtual address space.
memlimit=8000000

while true; do
  # If jump_stage is set to a stage, it is run instead of popping an item
  # from the stage list. This allows running a stage without recording it
  # on disk which is necessary if it cannot be restarted on interrupt.
  if [ -n "${jump_stage:-}" ]; then
    stage="$jump_stage"
    jump_stage=
  else
    if empty_stages_p; then
      push_stages stop
    fi

    # Record the current build stage and shift
    echo "${stages[*]}" >,stage

    pop_stages
    stage="$item"
  fi

  update_stage "$stage"
  case "$stage" in
  clean)
    rm -rf "$installdir"
    rm -rf "$prefix"
    rm -rf "$objdir"
    rm -rf "$qemu_installdir"
    rm -rf "$gdb_only_installdir"
    push_stages "start"
    ;;

  start)
    mk_bin_dirs $host_prefix $build_sysroot
    write_build_status > build.status
    push_stages gmp mpfr mpc isl cloog iconv zstd qemu binutils-chain gdb perms
    ;;

  gmp)
    gmp_srcdir=$gmp_src
    gmp_objdir=$objdir/gmp
    gmp_config="--disable-maintainer-mode --disable-shared --prefix=${host_tools_install} --host=${host} ${extra_config_flags_host_tools:-}"
    do_config_build_install gmp
    ;;

  mpfr)
    mpfr_srcdir=$mpfr_src
    mpfr_objdir=$objdir/mpfr
    mpfr_config="--disable-maintainer-mode --disable-shared --prefix=${host_tools_install} ${hostgmp:+--with-gmp=$hostgmp} ${host_arg:-} ${extra_config_flags_host_tools:-}"
    do_config_build_install mpfr
    ;;

  mpc)
    mpc_srcdir=$mpc_src
    mpc_objdir=$objdir/mpc
    mpc_config="--disable-maintainer-mode --disable-shared --prefix=${host_tools_install} ${hostgmp:+--with-gmp=$hostgmp} ${hostmpfr:+--with-mpfr=$hostmpfr} ${host_arg:-} ${extra_config_flags_host_tools:-}"
    do_config_build_install mpc
    ;;

  isl)
    if [ -n "${hostisl:-}" ]; then
      isl_srcdir=$isl_src
      isl_objdir=$objdir/isl
      isl_config="--disable-maintainer-mode --disable-shared --prefix=${host_tools_install} ${hostgmp:+--with-gmp-prefix=$hostgmp} ${host_arg:-} ${extra_config_flags_host_tools:-}"
      do_config_build_install isl
    fi
    ;;

  cloog)
    if [ -n "${hostcloog:-}" ]; then
      cloog_srcdir=$cloog_src
      cloog_objdir=$objdir/cloog
      cloog_config="--disable-maintainer-mode --disable-shared --prefix=${host_tools_install} ${hostgmp:+--with-gmp-prefix=$hostgmp} ${hostisl:+--with-isl-prefix=$hostisl} ${host_arg:-} ${extra_config_flags_host_tools:-}"
      do_config_build_install cloog
    fi
    ;;

  zstd)
    if [ -n "${hostzstd:-}" ]; then
      zstd_srcdir="$zstd_src/lib"
      zstd_objdir="$zstd_src/lib"
      zstd_build_targets="libzstd.a-release"
      zstd_install_targets="install-static install-includes"
      zstd_extra_install_envflags="PREFIX=$hostzstd"
      zstd_extra_make_envflags=
      if [ $flag_enable_mingw -eq 1 ]; then
        zstd_extra_make_envflags="CC=${host_tools_triplet}-gcc AR=${host_tools_triplet}-ar RANLIB=${host_tools_triplet}-ranlib"
      fi
      do_make zstd
      do_install zstd
    fi
    ;;

  qemu)
    if [ $flag_enable_qemu -eq 1 -a -n "${qemu_src:-}" ]; then
      qemu_parallel=0
      qemu_srcdir="$qemu_src"
      qemu_objdir="$objdir/qemu"
      qemu_config="--target-list=$qemu_target \
                   --prefix=${qemu_installdir}/${host_prefix} \
                   --disable-strip \
                   --disable-werror \
                   --disable-docs \
                   --disable-kvm \
                   --disable-system \
                   --disable-tools \
                   ${extra_config_flags_qemu:-}"
      do_config_build_install qemu
    fi
    ;;

  iconv)
    if [ $flag_enable_mingw -eq 1 ]; then
      iconv_srcdir="$libiconv_src"
      iconv_objdir="$objdir/iconv"
      iconv_config="--prefix=$hosticonv \
                    --disable-shared \
                     ${host_arg:-} \
                     ${extra_config_flags_host_tools:-}"
      do_config_build_install iconv
    fi
    ;;

  binutils-chain)
    push_stages binutils gcc1-chain
    ;;

  binutils)
    binutils_srcdir=$binutils_src
    binutils_objdir=$objdir/binutils
    extra_config_flags_binutils="${extra_config_flags_binutils:-} --without-debuginfod"
    if [ $flag_enable_mingw -eq 1 ]; then
      extra_config_flags_binutils="${extra_config_flags_binutils:-} --disable-werror"
    fi

    if [ ${flag_maintainer_mode:-0} -eq 1 ]; then
      extra_config_flags_binutils="${extra_config_flags_binutils:-} --enable-maintainer-mode"
    fi

    binutils_cflags="$cflags"
    binutils_cxxflags="$cflags"
    # binutils gold requires C++11. Add -std=gnu++11 as a temporary workaround to build binutils gold if GCC major version is less than 6.
    gcc_major_ver=$( gcc -dumpfullversion -dumpversion | awk -F. '{print $1}' )
    if [ $gcc_major_ver -lt 6 ]; then
        binutils_cxxflags="$binutils_cxxflags -std=gnu++11"
    fi
    binutils_config="--enable-64-bit-bfd \
       --enable-targets=$enable_binutils_targets \
       --target=$target \
       ${bugurl:+--with-bugurl="\"$bugurl\""} \
       --enable-gold \
       --enable-initfini-array \
       --enable-plugins \
       --disable-doc \
       --disable-gdb \
       --disable-gdbtk \
       --disable-nls \
       --disable-tui \
       --disable-werror \
       --without-gdb \
       --without-python \
       --without-x \
       --prefix=${host_prefix} \
       --with-build-sysroot=${build_sysroot} \
       --with-sysroot=${sysroot} \
       ${host_arg:-} \
       ${extra_config_flags_host_tools:-} \
       ${extra_config_flags_binutils:-}"

    binutils_build_targets="all-binutils all-gas all-gprof all-ld all-gold"
    binutils_install_targets="install-binutils install-gas install-ld install-gold install-gprof"
    binutils_destdir=${installdir}
    do_config_build_install binutils
    ;;

  gdb)
    if [ $flag_enable_gdb -eq 1 ]; then
      extra_config_flags_gdb="${extra_config_flags_gdb:-} --without-debuginfod"
      if [ -d "$srcdir/libexpat" ]; then
        # With libexpat component present add libexpat to GDB configuration
        extra_config_flags_gdb="${extra_config_flags_gdb:-} --with-expat --with-libexpat-prefix=${host_tools_install} --with-libexpat-type=static"
        push_stages libexpat main-gdb gdbserver
      else
        push_stages main-gdb gdbserver
      fi
    fi
    ;;

  libexpat)
    libexpat_srcdir="$srcdir/libexpat/expat"
    libexpat_objdir="$objdir/libexpat"

    libexpat_config="--prefix="${host_tools_install}" \
        --without-docbook \
        --without-xmlwf \
        ${host_arg:-} \
        ${extra_config_flags_host_tools:-}"
    libexpat_build_targets="lib"
    libexpat_install_targets="install"
    do_config_build_install libexpat
    # Upgrade Note: Updating libexpat from version 2.2.5 to 2.7.1.
    # Workaround: Delete libexpat.la to prevent incorrect linker flags from being injected
    # when building GDB with a static archive of libexpat. This .la file may cause libtool
    # or the build system to pull in unnecessary dependencies like -lm and the libm.a static
    # archive, which leads to link errors in environments where libm is not available.
    # Removing the .la file ensures a cleaner and more predictable link process.
    rm -f $hostexpat/lib/libexpat.la
    ;;

  main-gdb)
    gdb_srcdir="$gdb_src"
    gdb_objdir="$objdir/gdb"

    if [ $flag_enable_mingw -eq 1 ]; then
        extra_config_flags_gdb="${extra_config_flags_gdb:-} --disable-tui"
    fi

    saved_path="$PATH"
    if [ $native_build -eq 1 ]; then
      # If we're doing a native build (e.g. on aarch64 linux), then we want to
      # make sure our GDB can do native debugging. For this to work, GDB
      # needs to be in a native config (i.e. --host == --build == --target).
      #
      # Typically we will have a target like aarch64-none-linux-gnu, but
      # if we don't set --host or --build, then configure will
      # auto-detect --host=aarch64-unknown-linux-gnu, and since --host
      # != --target in this case, native debugging will not be enabled.
      #
      # To fix this, we can force --host = --build = --target =
      # aarch64-none-linux-gnu if we know we're doing a native build, but we
      # must make sure to sanitize the PATH to avoid GDB picking up the
      # newly-built tools and thus linking against the target libc.
      #
      # Dropping our newly-built tools from the PATH will force GDB to use the
      # system tools and link against the system libc, which is what we want
      # here.
      PATH="$PATH_ORIGINAL"
      extra_config_flags_gdb="${extra_config_flags_gdb:-} --host=$host --build=$build"

      # We want the final binaries to be named e.g. $tuple-gdb, not just "gdb",
      # to match the other installed toolchain binaries.
      extra_config_flags_gdb="${extra_config_flags_gdb:-} --program-prefix=$host-"
    fi

    gdb_cflags="$cflags"
    gdb_cxxflags="$cflags"

    set_gdb_config
    gdb_config="${gdb_config:-} --with-python=no"

    gdb_build_targets="all-gdb html-gdb"
    gdb_install_targets="install-gdb install-html-gdb"
    gdb_destdir="${installdir}"
    do_config_build_install gdb

    if [ "$gdb_only_flag" -eq 1 ]; then
      gdb_destdir="${gdb_only_installdir}"
      do_install gdb
    fi

    if [ ${gdb_with_python:-no} != "no" ]; then
        push_stages "gdb-python"
    fi

    PATH="$saved_path"
    ;;

  gdb-python)
    gdb_python_srcdir="$gdb_src"
    gdb_python_objdir="$objdir/gdb_python"

    saved_path="$PATH"
    if [ $native_build -eq 1 ]; then
      # Dropping our newly-built tools from the PATH will force GDB to use the
      # system tools and link against the system libc, which is what we want
      # here.
      PATH="$PATH_ORIGINAL"
    fi

    gdb_python_cflags="$cflags"
    gdb_python_cxxflags="$cflags"

    set_gdb_config
    gdb_python_config="${gdb_config:-} --with-python=$gdb_with_python --program-prefix=$target- --program-suffix=-py"
    gdb_python_build_targets="all-gdb"
    gdb_python_install_targets="install-gdb"
    gdb_python_destdir="${installdir}"
    do_config_build_install gdb_python

    if [ "$gdb_only_flag" -eq 1 ]; then
      gdb_python_destdir="${gdb_only_installdir}"
      do_install gdb_python
    fi

    PATH="$saved_path"
    ;;

  gdbserver)
    if [ -d "$gdb_src/gdbserver" ]; then
	  gdbserver_srcdir="$gdb_src"
    else
          gdbserver_srcdir="$gdb_src/gdb/gdbserver"
    fi
    gdbserver_objdir="$objdir/gdbserver"

    CPPFLAGS="--sysroot=$installdir/${sysroot}"
    CXXFLAGS="--sysroot=$installdir/${sysroot}"
    CFLAGS="--sysroot=$installdir/${sysroot}"

    # Use --disable-gdb when configuring gdbserver to avoid the need for mpfr and gmp.
    gdbserver_config=" --target=$target \
      --host=$target \
      --disable-gdb \
      --program-prefix= \
      --prefix=/usr"
    if [ -d "$gdb_src/gdbserver" ]; then
      gdbserver_build_targets="all-gdbserver"
      gdbserver_install_targets="install-gdbserver"
    fi
    gdbserver_destdir="$installdir/${sysroot}"
    do_config_build_install gdbserver

    if [ "$gdb_only_flag" -eq 1 ]; then
      gdbserver_destdir="${gdb_only_installdir}/${sysroot}"
      do_install gdbserver
    fi
    ;;

  gcc1-chain)
    push_stages gcc1 kernel-headers
    ;;

  gcc1)
    if [ $flag_enable_mingw -eq 1 ]; then
      extra_config_flags_gcc="${extra_config_flags_gcc:-} --with-libiconv-prefix=$hosticonv --enable-mingw-wildcard"
      host_config_options=
    else
      host_config_options="\
        ${hostgmp:+--with-gmp=$hostgmp} \
        ${hostmpfr:+--with-mpfr=$hostmpfr} \
        ${hostmpc:+--with-mpc=$hostmpc} \
        ${hostcloog:+--with-cloog=$hostcloog} \
        ${hostisl:+--with-isl=$hostisl} \
        ${hostzstd:+--with-zstd=$hostzstd}"
    fi
    gcc1_srcdir=$gcc_src
    gcc1_objdir=$objdir/gcc1
    gcc1_cflags="$cflags"
    gcc1_cxxflags="$cflags"
    gcc1_config="$host_config_options \
        --target=$target \
        --prefix=${host_prefix} \
        --with-sysroot=${sysroot} \
        --with-build-sysroot=${build_sysroot} \
        --without-headers \
        --with-newlib \
        ${bugurl:+--with-bugurl="\"$bugurl\""} \
        --without-cloog \
        --without-isl \
        --disable-shared \
        --disable-threads \
        --disable-libatomic \
        --disable-libsanitizer \
        --disable-libssp \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --enable-checking=$flag_check_bootstrap \
        --enable-languages=c"
    gcc1_destdir=${installdir}
    do_config_build_install gcc1
    ;;

  kernel-headers)
    rsync -a --exclude=.git --delete-after "$linux_src/" "$objdir/linux/"

    kernel_headers_objdir="$objdir/linux"
    kernel_headers_extra_install_envflags="ARCH=$linux_arch CROSS_COMPILE=$target- \
					  INSTALL_HDR_PATH=$stage_include"
    kernel_headers_install_targets="headers_install"
    do_install kernel_headers
    mkdir -p "$build_sysroot"/usr/include
    rsync -a "$stage_include"/include/ "$build_sysroot"/usr/include
    push_stages libc-headers-chain
    ;;

  libc-headers-chain)
    push_stages libc-headers gcc2-chain
    if [ $multilib_purecap -eq 1 ]; then
      push_stages libc-headers-purecap libc-multilib-restore
    fi
    ;;

  libc-headers-purecap)
    saved_libname="$libname"
    saved_abi="${abi:-}"
    saved_ldsoname="$ldsoname"
    saved_target_lib="$target_lib"
    saved_target_libdir="$target_libdir"
    saved_vars=1
    libname="$purecap_libname"
    abi="$purecap_abi"
    ldsoname="$purecap_ldsoname"
    target_lib="$purecap_target_lib"
    target_libdir="$purecap_target_libdir"

    # Run the libc-headers build with changed settings
    jump_stage=libc-headers
    ;;

  libc-headers)
    # In a parallel build situation we do not want autoconf kicking in
    # and modifying the src directory. Disable autoconf
    libc_headers_srcdir="$libc_src"
    libc_headers_extra_config_envflags=$(
    cat <<-'EOF'
      AUTOCONF=no \
      BUILD_CC=gcc \
      CC=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-gcc" "${installdir}/${host_prefix}/bin/$target-gcc ${abi:-}") \
      CXX=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-g++" "${installdir}/${host_prefix}/bin/$target-g++ ${abi:-}") \
      AR=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-ar" "${installdir}/${host_prefix}/bin/$target-ar") \
      RANLIB=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-ranlib" "${installdir}/${host_prefix}/bin/$target-ranlib")
EOF
    )
    libc_headers_config="$std_libc_config_opts \
            --prefix=$target_prefix \
            ${bugurl:+--with-bugurl="\"$bugurl\""} \
            --with-headers=$build_sysroot/usr/include \
            --includedir=$target_prefix/include \
            $(ternary $flag_enable_mingw --target=$target --build=$target) \
            --host=$target \
            --enable-obsolete-rpc \
            --disable-profile --without-gd --without-cvs \
            --without-selinux \
            ${extra_config_flags_libc:-}"
    libc_headers_objdir="$objdir/$libname-headers"
    libc_headers_install_targets="install-headers install_root=${build_sysroot} install-bootstrap-headers=yes"
    do_config libc_headers
    do_install libc_headers

    # For static build we don;t get a lib-names.h at the moment, fake one.
    cat > "$tmpdir/lib-names.h" <<EOF
#define LIBCIDN_SO ""
EOF
    mkdir -p "${build_sysroot}/$target_libdir"
    mkdir -p "${build_sysroot}/$target_rtlddir"

    make -C "$objdir/$libname-headers" csu/subdir_lib
    cp $objdir/$libname-headers/csu/crt1.o $objdir/$libname-headers/csu/crti.o $objdir/$libname-headers/csu/crtn.o "$build_sysroot/$target_libdir"

    libc_host_compiler="$installdir/$host_prefix/bin"
    if [ $flag_enable_mingw -eq 1 ]; then
      libc_host_compiler="$host_toolchain_path"
    fi

    $libc_host_compiler/$target-gcc ${abi:-} -nostdlib -nostartfiles -shared -x c /dev/null \
                               -o ${build_sysroot}/$target_libdir/libc.so
    touch "$build_sysroot/$target_prefix/include/gnu/stubs.h"
    ;;

  gcc2-chain)
    push_stages gcc2 libc-chain
    ;;

  gcc2)
    if [ $flag_enable_mingw -eq 1 ]; then
      gcc2_host_config_options=
    else
      gcc2_host_config_options="\
        ${hostgmp:+--with-gmp=$hostgmp} \
        ${hostmpfr:+--with-mpfr=$hostmpfr} \
        ${hostmpc:+--with-mpc=$hostmpc} \
        ${hostzstd:+--with-zstd=$hostzstd}"
    fi
    gcc2_srcdir="$gcc_src"
    gcc2_objdir="$objdir/gcc2"
    gcc2_cflags="$cflags"
    gcc2_cxxflags="$cflags"
    gcc2_config="--target=$target \
           --prefix=${host_prefix} \
           --with-sysroot=${sysroot} \
           --with-build-sysroot=${build_sysroot} \
           ${bugurl:+--with-bugurl="\"$bugurl\""} \
           --enable-shared \
           --disable-libatomic \
           --without-cloog \
           --without-isl \
           --disable-libssp \
           --disable-libgomp \
           --disable-libmudflap \
           --disable-libquadmath \
           --enable-checking=$flag_check_bootstrap \
           --enable-languages=c \
           ${gcc2_host_config_options} \
           ${extra_config_flags_gcc:-}"
    gcc2_destdir="$installdir"
    do_config_build_install gcc2
    ;;

  libc-chain)
    push_stages libc gcc3-chain
    # Build libc for multilib variants.
    saved_vars=0
    if [ $multilib_purecap -eq 1 ]; then
      push_stages libc-purecap libc-multilib-restore
    fi
    ;;

  libc-purecap)
    saved_libname="$libname"
    saved_abi="${abi:-}"
    saved_ldsoname="$ldsoname"
    saved_target_lib="$target_lib"
    saved_target_libdir="$target_libdir"
    saved_vars=1
    libname="$purecap_libname"
    abi="$purecap_abi"
    ldsoname="$purecap_ldsoname"
    target_lib="$purecap_target_lib"
    target_libdir="$purecap_target_libdir"

    # Run the libc build with changed settings
    jump_stage=libc
    ;;

  libc-multilib-restore)
    if [ $saved_vars -eq 1 ]; then
      libname="$saved_libname"
      abi="$saved_abi"
      ldsoname="$saved_ldsoname"
      target_lib="$saved_target_lib"
      target_libdir="$saved_target_libdir"
      saved_vars=0
    fi
    ;;

  libc)
    libc_objdir="$objdir/$libname"
    libc_srcdir="$libc_src"
    libc_install_targets="install install_root=$build_sysroot"
    libc_extra_config_envflags=$(
    cat <<-'EOF'
      AUTOCONF=no \
      BUILD_CC=gcc \
      CC=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-gcc" "${installdir}/${host_prefix}/bin/$target-gcc ${abi:-}") \
      CXX=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-g++" "${installdir}/${host_prefix}/bin/$target-g++ ${abi:-}") \
      AR=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-ar" "${installdir}/${host_prefix}/bin/$target-ar") \
      RANLIB=$(ternary $flag_enable_mingw "${host_toolchain_path:-}/$target-ranlib" "${installdir}/${host_prefix}/bin/$target-ranlib") \
      libc_cv_slibdir=$libc_cv_slibdir \
      libc_cv_rtlddir=$libc_cv_rtlddir
EOF
    )
    libc_config="$std_libc_config_opts \
            --prefix=$target_prefix \
            --with-headers=$build_sysroot/usr/include \
            --includedir=$target_prefix/include \
            --build=$build \
            --host=$target \
            --disable-werror \
            --enable-obsolete-rpc \
            --disable-profile --without-gd --without-cvs \
            --without-selinux \
            ${bugurl:+--with-bugurl="\"$bugurl\""} \
            ${extra_config_flags_libc:-}"
    do_config_build_install libc

    if [ ! -e "$build_sysroot/lib/$ldsoname" -a "$enable_multiarch" -eq 1 -a -n "${target_tuple:-}" ]; then
      installedlinker="$build_sysroot/lib/$target_tuple/$ldsoname"
      if [ -f "$installedlinker" ]; then
        name=`readlink "$installedlinker"`
        ln -sf "aarch64-linux-gnu/$name" "$build_sysroot/lib/$ldsoname"
      else
        echo "error: missing $installedlinker" >&2
        exit 1
      fi
    fi
    ;;

  gcc3-chain)
    push_stages gcc3 gcc4-chain
    ;;

  gcc3)
    gcc3_srcdir=$gcc_src
    gcc3_objdir=$objdir/gcc3
    gcc3_cflags="$cflags"
    gcc3_cxxflags="$cflags"
    gcc3_cflags_for_target="${cflags_for_target:-}"
    gcc3_cxxflags_for_target="${cflags_for_target:-}"
    gcc3_config="--target=$target \
            --prefix=${host_prefix} \
            --with-sysroot=${sysroot} \
            --with-build-sysroot=${build_sysroot} \
            ${bugurl:+--with-bugurl="\"$bugurl\""} \
            --enable-gnu-indirect-function \
            --enable-shared \
            --disable-libssp \
            --disable-libmudflap \
            --enable-checking=$flag_check_final \
            --enable-languages=$languages \
            ${hostgmp:+--with-gmp=$hostgmp} \
            ${hostmpfr:+--with-mpfr=$hostmpfr} \
            ${hostmpc:+--with-mpc=$hostmpc} \
            ${hostisl:+--with-isl=$hostisl} \
            ${hostcloog:+--with-cloog=$hostcloog} \
            ${host_arg:-} \
            ${hostzstd:+--with-zstd=$hostzstd} \
            ${extra_config_flags_host_tools:-} \
            ${extra_config_flags_gcc:-}"
    gcc3_destdir=${installdir}
    do_config_build_install gcc3

    for f in ${installdir}/${host_prefix}/${target}/$target_lib/*.so*
    do
      test -f "$f" && cp -d "$f" "$build_sysroot/$target_libdir"
    done

    if [ $multilib_purecap -eq 1 ]; then
      for f in ${installdir}/${host_prefix}/${target}/$purecap_target_lib/*.so*
      do
        test -f "$f" && cp -d "$f" "$build_sysroot/$purecap_target_libdir"
      done
    fi
    ;;

  gcc4 | gcc4-chain)
    if [ $flag_enable_mingw -eq 1 ]; then
      gcc4_host_config_options=
    else
      gcc4_host_config_options="\
         ${hostgmp:+--with-gmp=$hostgmp} \
         ${hostmpfr:+--with-mpfr=$hostmpfr} \
         ${hostmpc:+--with-mpc=$hostmpc} \
         ${hostisl:+--with-isl=$hostisl} \
         ${hostcloog:+--with-cloog=$hostcloog} \
         ${hostzstd:+--with-zstd=$hostzstd}"
    fi
    gcc4_srcdir=$gcc_src
    gcc4_objdir=$objdir/gcc4
    gcc4_cflags="$cflags"
    gcc4_cxxflags="$cflags"
    gcc4_cflags_for_target="${cflags_for_target:-}"
    gcc4_cxxflags_for_target="${cflags_for_target:-}"
    gcc4_config="--target=$target \
            --prefix=${host_prefix} \
            --with-sysroot=${build_sysroot} \
            ${bugurl:+--with-bugurl="\"$bugurl\""} \
            --enable-shared \
            --disable-libssp \
            --disable-libmudflap \
            --enable-checking=$flag_check_bootstrap \
            --enable-languages=$languages \
            ${gcc4_host_config_options} \
            ${extra_config_flags_gcc:-}"
    do_config gcc4
    do_make gcc4
    push_stages libffi
    ;;

  libffi)
  if [ -d "$srcdir/libffi" ];
  then
    if [ -n "${libffi_src:-}" -a -d "${libffi_src:-}" ]; then
      libffi_destdir="$build_sysroot"
      libffi_config="--host=$target --target=$target --prefix=$target_prefix \
                     --libdir=$target_libdir"
      libffi_copy_src_to_obj=1
      libffi_update_gnuconfig=1
      libffi_srcdir="${libffi_src:-}"
      libffi_objdir="$objdir/libffi"
      do_config_build_install libffi
    fi
  fi
  ;;

  perms)
    if [ "$package_flag" -eq 1 ]; then
      push_stages "tar"
    fi
    ;;

  tar)
    if [ "$package_flag" -eq 1 ]; then
      echo "$layout_version" > "$installdir/.version"
      tarfile="$tardir/$target-tools.tar.xz"
      rm -f "$tarfile.tmp"
      mkdir -p "$tardir"
      ${TAR_CMD} c -J -f "$tarfile.tmp" -C "$installdir" --exclude="*gccbug"  --owner=0 --group=0 --mode=a+u,go-w .
      [ -e "$tarfile" ] && chmod +w "$tarfile"
      mv "$tarfile.tmp" "$tarfile"
      chmod 444 "$tarfile"

      if [ $flag_enable_qemu -eq 1 -a "$qemu_installdir" != "$installdir" ];
      then
        echo "$layout_version" > "$qemu_installdir/.version"
        tarfile="$tardir/$target-qemu.tar.xz"
        rm -f "$tarfile.tmp"
        ${TAR_CMD} c -J -f "$tarfile.tmp" -C "$qemu_installdir" --owner=0 --group=0 --mode=a+u,go-w .
        [ -e "$tarfile" ] && chmod +w "$tarfile"
        mv "$tarfile.tmp" "$tarfile"
        chmod 440 "$tarfile"
      fi

      if [ $gdb_only_flag -eq 1 ]; then
        echo "$layout_version" > "$gdb_only_installdir/.version"
        tarfile="$tardir/$target-gdb.tar.xz"
        rm -f "$tarfile.tmp"
        if [ -d "$gdb_only_installdir" ]; then
          ${TAR_CMD} c -J -f "$tarfile.tmp" -C "$gdb_only_installdir" --owner=0 --group=0 --mode=a+u,go-w .
          [ -e "$tarfile" ] && chmod +w "$tarfile"
          mv "$tarfile.tmp" "$tarfile"
          chmod 444 "$tarfile"
        else
          echo "Error: Directory '$gdb_only_installdir' does not exist."
        fi
      fi
    fi
    ;;

  check)
    push_stages ${check_targets}
    ;;

  check-binutils | check-gas | check-ld | check-gold | check-gdb)
    objdir_local="$objdir/binutils"
    flag_check=1
    if [ "$stage" == check-gdb ]; then
      objdir_local="$objdir/gdb"
      if [ $flag_check_gdb -eq 0 ]; then
        flag_check=0
      fi
    fi

    if [ $flag_check -eq 1 ]; then
      # 120s limit on cpu time
      ( ulimit -S -t 120 &&
        RUNTESTFLAGS="$RUNTESTFLAGS" \
        DESTDIR=${installdir} \
        make -C $objdir_local -k $parallel $stage \
        CC_FOR_TARGET="${installdir}/${host_prefix}/bin/$target-gcc" ) \
      || true

      # Capture the results
      mkdir -p "$resultdir"
      name=`echo "$stage" | sed "s/check-target-//" | sed "s/check-//"`
      for f in `find "$objdir_local" -type f -name "$name.log" -o -type f -name "$name.sum" -o -type f -name "$name.xml"`
      do
        cp "$f" "$resultdir"
      done
    fi
    ;;

  check-gcc | check-g++ | check-fortran)
    name=`echo "$stage" | sed "s/check-target-//;s/fortran/gfortran/;s/check-//"`
    check_in_gcc "$name" "$objdir/gcc4/gcc" "$stage" "$resultdir"
    ;;

  check-target-*)

    name=`echo "$stage" | sed "s/check-target-//" | sed "s/check-//"`
    # libstdc++-v3 is awkward, the check target and resulting output files use
    # different names!
    case $name in
    libstdc++-v3)
      name="libstdc++"
      ;;
    esac
    check_in_gcc "$name" "$objdir/gcc4" "$stage" "$resultdir"
    ;;

  check-ffi)
  if [ -d "$srcdir/libffi" ];
  then
    RUNTESTFLAGS="$RUNTESTFLAGS CC_FOR_TARGET=$target-gcc" \
    make -C "$objdir/libffi" PARALLELMFLAGS=$parallel -k check || true
    # Capture the results
    mkdir -p "$resultdir"
    name=libffi
    for f in `find "$objdir/$name" -type f -name "$name.log" -o -type f -name "$name.sum" -o -type f -name "$name.xml"`
    do
      cp "$f" "$resultdir"
    done
  fi
  ;;

  check-*)
    printf "warning: skipping $stage\n" >&2
    ;;

  stop)
    echo "  $target completed as requested"
    exit 0
    ;;

  *)
    echo "(BUILD) Unknown stage: $stage"
    rm -f ,stage
    exit 1
    ;;
  esac
done
