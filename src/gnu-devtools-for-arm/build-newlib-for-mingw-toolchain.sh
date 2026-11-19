#!/bin/bash
# Helper script to automate the building and synchronization of Newlib with an existing Mingw toolchain.

downstream_args=()

usage() {
  echo "Usage: $(basename "$0") [--builddir <path>] [--target <name>] [-h|--help]"
  exit 0
}

args=$(getopt -o h -l builddir:,target:,help -n "$(basename "$0")" -- "$@")
if [ $? -ne 0 ]; then
  echo "Error parsing arguments" >&2
  exit 1
fi
eval set -- "$args"
while [ $# -gt 0 ]; do
  if [ -n "${opt_prev:-}" ]; then
    eval "$opt_prev=\$1"
    opt_prev=
    shift
    continue
  elif [ -n "${opt_append:-}" ]; then
    eval "$opt_append=\"\${$opt_append:-} \$1\""
    opt_append=
    shift
    continue
  fi

  case $1 in
    --builddir)
        opt_prev="builddir"
        ;;
    --target)
        opt_prev="target"
        ;;
    -h | --help)
        usage
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Unexpected option: $1" >&2
        exit 1
        ;;
  esac
  shift
done

downstream_args=("$@")
execdir=$(pwd)
buildroot="$execdir"
srcdir="$buildroot/src"

if [[ -z "$target" || -z "$builddir" ]]; then
    echo "Usage: $0 --target <target-architecture> --builddir <build-directory>"
    exit 1
fi

if [ ! -d "$builddir" ]; then
    echo "Error: Toolchain Build directory '$builddir' does not exist or is not a directory."
    exit 1
fi

dirname=$(dirname "$builddir")

newlibbuilddir="${dirname}/build-newlib-${target}"

"$srcdir/gnu-devtools-for-arm/build-baremetal-toolchain.sh" --target=$target --with-language=fortran --srcdir=$srcdir --builddir=$newlibbuilddir --release --enable-binutils --enable-gcc --enable-gdb --no-check-gdb --enable-newlib --disable-qemu ${downstream_args[@]} start-bootstrap-newlib
"$srcdir/gnu-devtools-for-arm/build-baremetal-toolchain.sh" --target=$target --with-language=fortran --srcdir=$srcdir --builddir=$newlibbuilddir --release --enable-binutils --enable-gcc --enable-gdb --no-check-gdb --enable-newlib --disable-qemu ${downstream_args[@]} install-newlib --newlib-installdir=${builddir}/install

rsync -a $newlibbuilddir/install/$target/include/ $builddir/install/$target/include/
rsync -a $newlibbuilddir/install/$target/lib/ $builddir/install/$target/lib/
rsync -a $newlibbuilddir/install/lib/gcc/$target/*/ $builddir/install/lib/gcc/$target/*/
