#!/bin/bash

# MIT License
#
# Copyright (c) 2026 STMicroelectronics.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -eux

src_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
script_path="$src_root/$(basename "${BASH_SOURCE[0]}")"
cross_platforms="aarch64-linux-gnu x86_64-w64-mingw32"
host_os=$(uname -s)
host_arch=$(uname -m)

case "$host_os:$host_arch" in
  Darwin:arm64|Darwin:aarch64) native_platform=aarch64-apple-darwin ;;
  Darwin:x86_64) native_platform=x86_64-apple-darwin ;;
  Linux:x86_64) native_platform=x86_64-linux-gnu ;;
  *)
    echo "Unsupported host platform: $host_os $host_arch" >&2
    exit 1
  ;;
esac

native_dir=$src_root/arm-none-eabi/$native_platform

if [ "$host_os" != "Linux" ] ; then
  # Only do cross builds on linux
  cross_platforms=""
fi
available_platforms="$native_platform $cross_platforms"
build_platforms=""

function usage() {
  cat <<EOF
Usage: $(basename "$0") [--platform PLATFORM]...

With no --platform options, build the native toolchain and all cross-platform
toolchains supported by this host.

Use --platform to build only the selected output platform. Repeat the option
to select multiple platforms. Available platforms:
  $available_platforms

Cross-platform builds require the native toolchain in:
  arm-none-eabi/$native_platform

Select $native_platform in the same command, or build it first with:
  $(basename "$0") --platform=$native_platform
EOF
}

function add_build_platform() {
  local platform="$1"

  case " $available_platforms " in
    *" $platform "*) ;;
    *)
      echo "Unknown platform: $platform" >&2
      usage >&2
      exit 2
    ;;
  esac

  case " $build_platforms " in
    *" $platform "*) ;;
    *) build_platforms="${build_platforms:+$build_platforms }$platform" ;;
  esac
}

platforms_requested=false
while [ $# -gt 0 ]; do
  case "$1" in
    --platform)
      [ $# -ge 2 ] || {
        echo "--platform requires a value" >&2
        exit 2
      }
      platforms_requested=true
      add_build_platform "$2"
      shift 2
    ;;
    --platform=*)
      platforms_requested=true
      add_build_platform "${1#*=}"
      shift
    ;;
    -h|--help)
      usage
      exit 0
    ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
    ;;
  esac
done

if [ "$native_platform" = "x86_64-apple-darwin" ]; then
  force_serial_build=1
fi

if [ "$platforms_requested" = false ]; then
  for platform in $available_platforms; do
    add_build_platform "$platform"
  done
fi

function check_dep() {
  echo -n "Checking for $1 ... "
  if eval $2 >& /dev/null; then
    echo "yes"
  else
    echo "no"
    exit 1
  fi
}

function platform_enabled() {
  case " $build_platforms " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

function run_build_with_log() (
  set -o pipefail

  local build_dir="$1"
  shift
  local build_log="$build_dir/build.log"

  mkdir -p "$build_dir"
  rm -f "$build_log" "$build_log.xz"

  time "$@" 2>&1 | tee "$build_log"

  echo "Compressing $build_log"
  xz "$build_log"
)

if ! platform_enabled "$native_platform" && [ ! -d "$native_dir" ]; then
  echo "Native toolchain not found at $native_dir." >&2
  echo "Build it first with: $(basename "$0") --platform=$native_platform" >&2
  exit 1
fi

cd "$src_root"

# Touch hack to fix configure issue
find src/ ! -type l -print0 | xargs -0 touch -r "$script_path"

# Check build dependencies
check_dep "Checking for C++11 support" "echo -e '#if __cplusplus < 201103L\n#error Compiler does not support C++11\n#endif' | g++ -E -std=c++11 -x c++ -"
check_dep "tex" "tex -version"
check_dep "texi2dvi" "texi2dvi --version"
check_dep "GNU tar" "tar --version | grep -q 'GNU tar'"
check_dep "xz" "xz --version"

for host in $cross_platforms; do
  if platform_enabled $host; then
    check_dep "$host-gcc" "$host-gcc --version"
    check_dep "$host-g++" "$host-g++ --version"
    check_dep "$host-strip" "$host-strip --version"
  fi
done

tag="GNU Tools for STM32 $(git describe --tags 2>/dev/null || git rev-parse --verify HEAD)"

# Native toolchain
if platform_enabled "$native_platform"; then
  run_build_with_log "$native_dir" \
    src/gnu-devtools-for-arm/build-baremetal-toolchain.sh \
    -x \
    ${force_serial_build:+-j 1} \
    --tag="$tag" \
    --target=arm-none-eabi \
    --config-flags-gcc=--with-multilib-list=aprofile,rmprofile \
    --srcdir="$src_root/src" \
    --release \
    --enable-binutils \
    --enable-gcc \
    --enable-gdb \
    --disable-qemu \
    --builddir="$native_dir" \
    --enable-newlib \
    --enable-newlib-nano \
    --ldflags-for-target="--specs=nosys.specs" \
    --ldflags-for-nano-target="--specs=nosys.specs" \
    --enable-html-docs \
    --enable-pdf-docs \
    clean
fi

# Cross toolchains
for host in $cross_platforms; do
  if platform_enabled $host; then
    run_build_with_log "$src_root/arm-none-eabi/$host" \
      src/gnu-devtools-for-arm/build-baremetal-toolchain.sh \
      -x \
      ${force_serial_build:+-j 1} \
      --tag="$tag" \
      --target=arm-none-eabi \
      --config-flags-gcc=--with-multilib-list=aprofile,rmprofile \
      --srcdir="$src_root/src" \
      --release \
      --enable-binutils \
      --enable-gcc \
      --enable-gdb \
      --disable-qemu \
      --builddir="$src_root/arm-none-eabi/$host" \
      --host-toolchain-path="$native_dir/install/bin" \
      --host $host \
      --enable-html-docs \
      --enable-pdf-docs \
      clean
  fi
done
