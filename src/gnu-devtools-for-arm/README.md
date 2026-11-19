# README

# Table of Contents
* [Overview](#Overview)
* [Package contents](#Package-contents)
* [Supported configurations](#Supported-configurations)
* [How to build the toolchains](#How-to-build-the-toolchains)
	* [Create the build environment](#Create-the-build-environment)
		* [Install prerequisite packages](#Install-prerequisite-packages)
		* [Create folder for build](#Create-folder-for-build)
		* [Obtain the source code of all the relevant GNU projects](#Obtain-the-source-code-of-all-the-relevant-GNU-projects)
	* [Invoking the build scripts](#Invoking-the-build-scripts)
		* [Building a toolchain in debug mode for development](#Building-a-toolchain-in-debug-mode-for-development)
		* [Building a toolchain in release mode](#Building-a-toolchain-in-release-mode)
		* [Known build issues](#Known-build-issues)
	* [How to test the toolchains](#How-to-test-the-toolchains)
		* [Testing the baremetal toolchains](#Testing-the-baremetal-toolchains)
		* [Testing with QEMU](#Testing-with-QEMU)
		* [Testing with Fastmodels](#Testing-with-Fastmodels)
		* [Testing many configurations with site*.exp](#Testing-many-configurations-with-site*.exp)
		* [GDB testing](#GDB-testing)
	* [How to debug target binaries running on QEMU](#How-to-debug-target-binaries-running-on-QEMU)
* [Licence](#Licence)


# Overview

**gnu-devtools-for-arm is an open-source project for building, testing and debugging the Arm GNU Toolchain**

The Arm GNU toolchain gets periodically released at [https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain)

- gnu-devtools-for-arm provides users access to build scripts that produce toolchains with similar configuration and build of the Arm GNU Toolchain releases. The scripts include capabilities to fully build-test-debug using Arm's [Fast Models](https://developer.arm.com/Tools%20and%20Software/Fast%20Models) or, in some cases, [QEMU](https://www.qemu.org/).
- The intended users of this package are:
  - GNU Toolchain developers, who want to build and test the toolchain on models.
  - Users of the Arm GNU Toolchain that wish to build toolchains similar to Arm GNU Toolchain releases, from Source Code.
- This package is a work-in-progress, it does not currently support all build-host-target variants or complete testing of all variants.

# Package contents

**The components of gnu-devtools-for-arm can be categorised as:**

- Build Scripts
- Testing configuration files (DejaGNU site and board files)
- The Fast Model runner script: models-run
- The Fast Models GDB Plugin

The directory layout is as follows:

```
gnu-devtools-for-arm
├── README.md  --> This file.
├── build-baremetal-toolchain.sh
├── build-cross-linux-toolchain.sh
├── build-gnu-toolchain.sh
├── dejagnu
│   └── <a set of dejagnu test configuration board files>
├── extras
│   ├── fm-gdb-plugin
│   ├── models-run
│   └── source-fetch.py
└── utilities.sh
```

# Supported configurations

**What configurations are officially supported**

The following table shows the list of combinations that work for building the toolchain:


```
| Toolchain [*]                                                                      |
| ---------------------------------------------------------------------------------- |
| Build                   | Host                    | Target                         |
| ---------------------------------------------------------------------------------- |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | aarch64-none-elf               |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | MORELLO aarch64-none-elf       |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | MORELLO aarch64-none-linux-gnu |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-eabi                  |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-linux-gnueabihf       |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-elf               |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | MORELLO aarch64-none-elf       |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | MORELLO aarch64-none-linux-gnu |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-linux-gnu         |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64_be-none-linux-gnu      |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-eabi                  |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-linux-gnueabihf       |
| macOS (x86_64)          | macOS (x86_64)          | aarch64-none-elf               |
| macOS (x86_64)          | macOS (x86_64)          | arm-none-eabi                  |
| macOS (Apple silicon)   | macOS (Apple silicon)   | aarch64-none-elf               |
| macOS (Apple silicon)   | macOS (Apple silicon)   | arm-none-eabi                  |
| x86_64-none-linux-gnu   | Windows (mingw, x86)    | aarch64-none-elf               |
| x86_64-none-linux-gnu   | Windows (mingw, x86)    | arm-none-eabi                  |
| x86_64-none-linux-gnu   | Windows (mingw, x86)    | arm-none-linux-gnueabihf       |
| x86_64-none-linux-gnu   | Windows (mingw, x86)    | aarch64-none-linux-gnu         |
| ---------------------------------------------------------------------------------- |
```

[*] This list of toolchains is the full list of currently released Arm GNU Toolchain variants. Other build-host-target combinations are not supported by these scripts (Contributions welcome!).


# How to build the toolchains

To build the toolchain, please follow the following process:

## Create the build environment

### Install prerequisite packages

The GNU Toolchain binaries that are released by Arm are built in relatively old OS environments, like CentOS7 or Ubuntu 18.04. This is particularly important as to ensure the highest backward compatibility with old glibc versions.
The toolchain binaries produced by these scripts will only work on the same (or newer) OS version on which the scripts are run.

A number of packages are needed to build the toolchain. If source-fetch.py is being used to clone upstream repositories or Python-enabled GDB is needed, a python3 environment will be required.


#### For Ubuntu Linux distros

Here is a list of packages that might be required:

```
sudo apt-get update
sudo apt install -y \
  autoconf autogen automake \
  binutils-mingw-w64-i686 binutils-mingw-w64-x86-64 binutils bison build-essential \
  cgdb cmake coreutils curl \
  dblatex dejagnu dh-autoreconf docbook-xsl-doc-html docbook-xsl-doc-pdf docbook-xsl-ns doxygen \
  emacs expect \
  flex flip \
  g++-mingw-w64-i686 g++-mingw-w64-x86-64 g++ gawk gcc-mingw-w64-base gcc-mingw-w64-i686 gcc-mingw-w64-x86-64 gcc-mingw-w64 gcc-multilib gcc gdb gettext gfortran ghostscript git-core golang google-mock \
  keychain \
  less libbz2-dev libc-dev libc6-dev libelf-dev libglib2.0-dev libgmp-dev libgmp3-dev libisl-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libpugixml-dev libreadline-dev libtool libx11-dev libxml2-utils linux-libc-dev \
  make mingw-w64-common mingw-w64-i686-dev mingw-w64-x86-64-dev \
  ninja-build nsis \
  perl php-cli pkg-config python3 python3-venv \
  libpixman-1-0 \
  qemu-system-arm qemu-user \
  ruby-nokogiri ruby rsync \
  scons shtool swig \
  tcl texinfo texlive-extra-utils texlive-full texlive time transfig \
  valgrind vim \
  wget \
  xsltproc \
  zlib1g-dev
```

#### For macOS 11(Big Sur) or higher

Provided that xcode is installed, run, if needed:

```
sudo xcode-select --install
```

With brew pre-configured, install the additional packages:

```
brew install \
    autoconf automake \
    bash bison \
    ca-certificates cmake coreutils \
    deja-gnu docker dockutil \
    fontconfig freetype \
    gdbm gettext ghostscript git gmp gnu-getopt gnu-sed gnu-tar \
    htop \
    iperf3 \
    jbig2dec jpeg \
    libevent libidn libidn2 libpng libtiff libtool libunistring little-cms2 \
    m4 mactex-no-gui make mpdecimal \
    ncurses \
    openjpeg openssl@1.1 openssl@3 \
    pcre2 pstree python@3.10 \
    readline \
    six smartmontools sqlite ssh-copy-id \
    tmux \
    utf8proc \
    virtualenv \
    watch wget \
    xz
```

Note: a dependency in the current binutils version requires texinfo@6.x installed, not older, not newer. There are two possible cases, depending on the macOS version in use.
For macOS Big Sur this version is known to work correctly:

> brew install texinfo@6.5

In recent OS versions (eg: macOS Sonoma 14.3.1) brew only provides texinfo@7.x and a custom build of the package is required:

```
export PKG=texinfo
export PKGVER=6.8
brew uninstall $PKG

brew tap-new $USER/local-$PKG

brew tap --force homebrew/core

brew extract --version=$PKGVER $PKG $USER/local-$PKG
brew install $PKG@$PKGVER
```



### Create folder for build

In a clean folder, create a ./src subfolder and clone this gnu-devtools-for-arm repo into it

```
mkdir src
git clone https://git.gitlab.arm.com/tooling/gnu-devtools-for-arm.git ./src/gnu-devtools-for-arm
```

### Obtain the source code of all the relevant GNU projects

The source code can be obtained in different ways, please check below for the one that fits best for specific use cases:

#### Download the Source Code tar from one of our releases

The source code of the release to rebuild can be found at this address, in the "Source code" section: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

The content needs to be placed into the ./src folder, such that the ./src folder looks like this:

```
./src
  │
  ├───gnu-devtools-for-arm/
  ├───binutils-gdb/
  ├───binutils-gdb--gdb/
  ├───gcc/
  ├───glibc/
  └───<etc>
```

Note 1: This Source Code package does not contain the source code for QEMU, because QEMU does not form part of the Arm GNU Toolchain release. If tests using QEMU are required, the QEMU source code needs to be fetched and placed in `./src/qemu` (e.g. `git clone https://gitlab.com/qemu-project/qemu.git ./src/qemu`). You might need additional packages to build and use the latest version of Qemu.

Note 2: The build scripts contain legacy code for supporting minor components cloog and libffi. This is not currently used by our standard build processes, hence why they have not been documented in these instructions.


#### Use source-fetch.py to fetch from upstream repositories

With python3 installed in the build environment (see package list above), it is possible to use the source snapshot manifest file of the release to rebuild: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

```
cd ./src/gnu-devtools-for-arm
<download the source snapshot manifest SPEC file and place it into the ./src/gnu-devtools-for-arm folder>

python3 extras/source-fetch.py checkout [--shallow] --src-dir=..   <name of manifest file>
cd ../..
```

Sample manifest files are provided in the spc directory; for example, spc/trunk.spc can be used to build a development version of the toolchain using the latest upstream sources.

If the full history of the respective git repositories is not needed, it is possible to use --shallow for faster and more compact downloads.


Some libraries are not listed in the spec file and are required:


```
gmp
mpc
mpfr
isl
libexpat
libiconv [OPTIONAL: This is only needed if you plan on building mingw-Windows-hosted toolchains -- this is currently unsupported]
```

These will need to be fetched separately:

```
cd ./src/gcc
./contrib/download_prerequisites  --force --directory=..

cd ..
git clone https://github.com/libexpat/libexpat.git -b R_2_4_8
# Fetch libiconv only if planning on building a mingw-Windows-hosted toolchain -- this is currently unsupported
# wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
# tar -xf libiconv-1.17.tar.gz
```

Note 1: This may result in a slightly different revision than those used in Arm's official release. This is _generally_ considered harmless. If the exact revisions used by Arm is needed, it is advised to download the Source Tarball of the release.

Note 2: The advantage of this method is that whole git repositories of the relevant projects are fetched. This allows to make custom changes or apply patches to the code to rebuild, but it is much slower.

Note 3: The source snapshot manifest SPEC file does not contain the source code for QEMU, because QEMU does not form part of the Arm GNU Toolchain release. If the toolchain needs to be tested using QEMU, the QEMU source code needs to be fetched separately and placed in `./src/qemu` (e.g. `git clone https://gitlab.com/qemu-project/qemu.git ./src/qemu` )

Note 4: The build scripts contain legacy code for supporting minor components cloog and libffi. This is not currently used by our standard build processes, hence why they have not been documented in these instructions.

After completion of one of the above steps, the full ./src folder should now contain at least the below components (all these names also support a `-<version_number>` suffix:

```
./src
  │
  ├───gnu-devtools-for-arm/
  ├───binutils-gdb/
  ├───binutils-gdb--gdb/
  ├───gcc/                 (may also be named arm-gnu-toolchain-src-snapshot.* if fetched from our source tarball)
  ├───glibc/
  ├───gmp/
  ├───isl/
  ├───libexpat/
  ├───libiconv/            [OPTIONAL: This is only needed if you plan on building mingw-Windows-hosted toolchains -- this is currently unsupported]
  ├───linux/
  ├───mpc/
  ├───mpfr/
  ├───newlib-cygwin/
  └───qemu/                [OPTIONAL: Only needed if you plan on testing with QEMU. Will only be present if manually fetched.]
```

## Invoking the build scripts

The build scripts can be invoked either directly through the generic wrapper script `build-gnu-toolchain.sh` or with a call to the lower-level scripts `build-baremetal-toolchain.sh` (for baremetal toolchains) and `build-cross-linux-toolchain.sh` (for linux targeting toolchains).

In order to configure the scripts to run, it is possible to either add them to PATH or create a link in the working directory:

Option1: PATH environment variable:

```
export PATH="$PWD/src/gnu-devtools-for-arm:$PATH"
build-gnu-toolchain.sh --target=<target> start
```

Option2: symlink in working dir:

```
ln -s src/gnu-devtools-for-arm/build-gnu-toolchain.sh
./build-gnu-toolchain.sh --target=<target> start
```


### Building a toolchain in debug mode for development
In order to build a toolchain, the build-gnu-toolchain.sh wrapper script is usually used. It has a simple interface for the usual development use cases.

Generally, the calls look like this. Use `build-gnu-toolchain.sh --help` to discover more command line options.

>For debugging add --debug --debug-target to build-gnu-toolchain.sh

```
build-gnu-toolchain.sh --target=<TARGET> start
```

Where `TARGET` can be any of:
- `aarch64-none-elf`
- `aarch64_be-none-elf`
- `arm-none-eabi`
- `arm-none-linux-gnueabihf`
- `aarch64-none-linux-gnu`
- `aarch64_be-none-linux-gnu`

Please refer to the table below, which provides information of the valid target to use for each `build/host` platform.


```
| Toolchain                                                                     |
| ----------------------------------------------------------------------------- |
| Build                   | Host                    | Target                    |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | aarch64-none-elf          |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | aarch64_be-none-elf       |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-eabi             |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-linux-gnueabihf  |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-elf          |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64_be-none-elf       |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-linux-gnu    |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64_be-none-linux-gnu |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-eabi             |
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-linux-gnueabihf  |
| macOS (x86_64)          | macOS (x86_64)          | aarch64-none-elf          |
| macOS (x86_64)          | macOS (x86_64)          | arm-none-eabi             |
| macOS (Apple silicon)   | macOS (Apple silicon)   | aarch64-none-elf          |
| macOS (Apple silicon)   | macOS (Apple silicon)   | arm-none-eabi             |
| ----------------------------------------------------------------------------- |
```

The build scripts log their various "stages" into a `.stage` file. If they failed in stage `C`, they would normally resume building from stage `C`.

However, the `start` at the end of the command instructs the scripts to always start from the beginning of the build process and recompile any changed components (e.g. restart `A` -> `B` -> `C` -> etc.). This is recommended for development, as it will pick up and recompile any changes in any stages. Other commands that can be used are `clean`, to delete any partially built or fully built toolchains, or, in fact, any named stage within the scripts, like `gcc2`, will instruct the scripts to resume from that stage. `gcc2` is a useful one if making changes to GCC and wanting to iterate quickly (although one full build from `start` should have completed successfully at least once to enable this sort of a "resume from gcc2" to succeed).

**Note:**
Since all those invocations use practically the same parameters for all the different targets (or there are parameters whose default is ON, like `--aprofile --rmprofile`), then a lot of these toolchains could also be built in sequence as:

```
build-gnu-toolchain.sh --target=arm-none-eabi --target=aarch64-none-elf --target=aarch64_be-none-linux-gnu --debug --debug-target start
```

For more complex toolchains, the simple interface of the `build-gnu-toolchain.sh` script isn't enough, so we also need to leverage the command line interfaces of the lower-level scripts:
- `build-baremetal-toolchain.sh`
- `build-cross-linux-toolchain.sh`

This can be done by adding "`--`" to separate the `build-gnu-toolchain.sh` command line options from the `build-baremetal-toolchain.sh` or `build-cross-linux-toolchain.sh` command line options.
It is possible to build a toolchain only with one multilib in order to minimise the build time for quick iterations during development. This is especially useful for `arm-none-eabi` toolchains, which normally take hours to build due to the number of "mutlilibs" needed.
```
# Run this at least once to completion:
build-gnu-toolchain.sh --target=arm-none-eabi --with-arch=armv8.1-m.main+mve.fp+fp.dp --disable-multilib -- --config-flags-gcc=--with-float=hard start
# Run this to recompile changes in `gcc2` for quick and easy iteration:
build-gnu-toolchain.sh --target=arm-none-eabi --with-arch=armv8.1-m.main+mve.fp+fp.dp --disable-multilib -- --config-flags-gcc=--with-float=hard gcc2
```

### Building a toolchain in release mode

Running the scripts in release mode also requires that some parameters from the lower-level scripts `build-baremetal-toolchain.sh` and `build-cross-linux-toolchain.sh` to be used.
The following are sample invocations as used to build our binary releases:
```
| Toolchain                                                                     |
| ----------------------------------------------------------------------------- |
| Build                   | Host                    | Target                    |
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | aarch64-none-elf          | build-gnu-toolchain.sh --target=aarch64-none-elf -- --release --package --enable-gdb-with-python=yes
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-eabi             | build-gnu-toolchain.sh --target=arm-none-eabi --aprofile  --rmprofile -- --release --package --enable-newlib-nano --enable-gdb-with-python=yes
| aarch64-none-linux-gnu  | aarch64-none-linux-gnu  | arm-none-linux-gnueabihf  | build-gnu-toolchain.sh --target=arm-none-linux-gnueabihf -- --release --package --enable-gdb-with-python=yes
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-elf          | build-gnu-toolchain.sh --target=aarch64-none-elf -- --release --package --enable-gdb-with-python=yes
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64-none-linux-gnu    | build-gnu-toolchain.sh --target=aarch64-none-linux-gnu -- --release --package --enable-gdb-with-python=yes
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | aarch64_be-none-linux-gnu | build-gnu-toolchain.sh --target=aarch64_be-none-linux-gnu -- --release --package --enable-gdb-with-python=yes
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-eabi             | build-gnu-toolchain.sh --target=arm-none-eabi --aprofile  --rmprofile -- --release --package --enable-newlib-nano --enable-gdb-with-python=yes
| x86_64-none-linux-gnu   | x86_64-none-linux-gnu   | arm-none-linux-gnueabihf  | build-gnu-toolchain.sh --target=arm-none-linux-gnueabihf -- --release --package --enable-gdb-with-python=yes
| macOS (x86_64)          | macOS (x86_64)          | aarch64-none-elf          | build-gnu-toolchain.sh --target=aarch64-none-elf -- --release --package
| macOS (x86_64)          | macOS (x86_64)          | arm-none-eabi             | build-gnu-toolchain.sh --target=arm-none-eabi --aprofile  --rmprofile -- --release --package --enable-newlib-nano
| macOS (Apple silicon)   | macOS (Apple silicon)   | aarch64-none-elf          | build-gnu-toolchain.sh --target=aarch64-none-elf -- --release --package
| macOS (Apple silicon)   | macOS (Apple silicon)   | arm-none-eabi             | build-gnu-toolchain.sh --target=arm-none-eabi --aprofile  --rmprofile -- --release --package --enable-newlib-nano
| ----------------------------------------------------------------------------- |
```

**Notes:**
* The aarch64-none-elf baremetal toolchains are built with both lp64 and ilp32 multilibs.
* The arm-none-eabi baremetal toolchain with both A-profile and RM-profile multilibs. After building, use `./build-arm-none-eabi/install/bin/arm-none-eabi-gcc --print-multi-lib` to view the whole list.
* Inconsistency may be noticed around the `--enable-gdb-with-python=yes` command line option. GDB with Python support is a known inconsistency of the current toolchain-building process. Python scripting support in GDB makes it less portable between OS versions. Currently, we enable `gdb-with-python` for Linux-hosted toolchains, but keep it disabled for macOS and Windows-hosted toolchains.
* At Arm, we use the `--tag` and `--bugurl` options to the lower-level scripts to tag our releases.

**It is important that the same tags used by Arm are not used when building the toolchain. Usage of a different branding needs to be specified in case `--tag` is needed.**

### Building Mingw

Building a Mingw toolchain requires pre-building the equivalent toolchain target for Linux. Make sure to install all the necessary dependencies specified earlier in this document before proceeding. Supported toolchains are aarch64-none-elf,aarch64_none_linux_gnu, arm_none_eabi and arm_none_linux_gnueabihf.
These are steps required to build both 32-bit and 64-bit Mingw toolchains

1. Create a build directory for the mingw toolchain. e.g build-mingw-aarch64-none-elf

    mkdir -p build-mingw-aarch64-none-elf

2. Before building the Mingw toolchain, you need to build the equivalent Linux toolchain for the desired target architecture. This step will ensure that all necessary binaries are available to build the target libraries, like libgcc and libc, when building the final mingw hosted toolchain. You can build this toolchain using the provided build script. e.g:

  build-gnu-toolchain.sh --target=aarch64-none-elf

3. Now, build the Mingw toolchain. Make sure to pass the bin directory containing the binaries of the previously built Linux toolchain using the --host-toolchain-path option. Specify the appropriate MinGW host using the top-level --host option. Use i686-w64-mingw32 for 32-bit builds and x86_64-w64-mingw32 for 64-bit builds. Use --config-flags-host-tools only for additional host-tools configure flags. Here is an example command:

  build-gnu-toolchain.sh --target=aarch64-none-elf -- --builddir=/path-to-builddir/build-mingw-aarch64-none-elf --host=x86_64-w64-mingw32 --host-toolchain-path=/path-to-toolchain/aarch64-none-elf/install/bin

Building Newlib

To build Newlib for integration with the MinGW toolchain, use the build-newlib-for-mingw-toolchain.sh script provided. This script will create a Newlib build directory within the same location as the MinGW toolchain. It calls the build-baremetal-toolchain.sh script with the appropriate arguments and, upon completion, copies the header files and libraries into the existing MinGW toolchain.
You must specify the build directory of the MinGW toolchain created in the previous step and ensure the same target architecture is used. Here is an example.

  build-newlib-for-mingw-toolchain.sh --target=aarch64-none-elf --builddir=/path-to-builddir/build-mingw-aarch64-none-elf

Additionally, any other desired parameters can be passed to the downstream build scripts via -- for example.

  build-newlib-for-mingw-toolchain.sh --target=arm-none-eabi --builddir=/path-to-builddir/build-mingw-arm-none-eabi -- --enable-newlib-nano --config-flags-gcc=--with-multilib-list=aprofile,rmprofile

### Known build issues

* When building gcc-13 or earlier gcc versions, together with glibc v2.38, the build process fails:

```
src/gcc/libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cpp:180:10: fatal error: crypt.h: No such file or directory
  180 | #include <crypt.h>
      |          ^~~~~~~~~
compilation terminated.
```

This can be solved by passing the following argument to the build scripts:

```
--config-flags-libc="--enable-crypt"  # directly to the lower level build scripts
or
--extra="--config-flags-libc=--enable-crypt" # to build-gnu-toolchain.sh
```

* Building certain parts of the toolchain source code might require support for a newer C or C++ language standard. It is recommended to build the toolchain using GCC 9 or later, to avoid such build errors.


## How to test the toolchains

In this section we describe how to test all the above `--target` options (aarch64-none-elf, aarch64-none-linux-gnu, arm-none-eabi, etc.) across different configurations.
All these toolchains are currently cross-compiler toolchains, so they require a model or simulator for the target CPU and environment. Supported models are:
* Arm's various Fast Models products: Supported only on x86_64 Linux hosts and some models may require a licence from Arm.
* QEMU: We compile QEMU from source in these scripts, so it should work on x86_64 and Arm 32-bit and 64-bit Linux hosts.

In order to control the testing we provide `site*.exp` files that define a set of testsuite configurations. These then pull in the applicable DejaGNU `board file.exp` for each architecture target.

### Testing the baremetal toolchains

The baremetal toolchains can be tested with QEMU (on any Linux host) or with Arm's Fastmodels (on x86_64 Linux hosts).

These toolchains contain different multilibs for different target architectures.


<details open>
<summary>For 32-bit `arm-none-eabi` there are currently 39 multilibs (the number generally increases over time)</summary>
<br>
arm/v5te/softfp;@marm@march=armv5te+fp@mfloat-abi=softfp

arm/v5te/hard;@marm@march=armv5te+fp@mfloat-abi=hard

thumb/nofp;@mthumb@mfloat-abi=soft

thumb/v7/nofp;@mthumb@march=armv7@mfloat-abi=soft

thumb/v7+fp/softfp;@mthumb@march=armv7+fp@mfloat-abi=softfp

thumb/v7+fp/hard;@mthumb@march=armv7+fp@mfloat-abi=hard

thumb/v7-r+fp.sp/softfp;@mthumb@march=armv7-r+fp.sp@mfloat-abi=softfp

thumb/v7-r+fp.sp/hard;@mthumb@march=armv7-r+fp.sp@mfloat-abi=hard

thumb/v7-a/nofp;@mthumb@march=armv7-a@mfloat-abi=soft

thumb/v7-a+fp/softfp;@mthumb@march=armv7-a+fp@mfloat-abi=softfp

thumb/v7-a+fp/hard;@mthumb@march=armv7-a+fp@mfloat-abi=hard

thumb/v7-a+simd/softfp;@mthumb@march=armv7-a+simd@mfloat-abi=softfp

thumb/v7-a+simd/hard;@mthumb@march=armv7-a+simd@mfloat-abi=hard

thumb/v7ve+simd/softfp;@mthumb@march=armv7ve+simd@mfloat-abi=softfp

thumb/v7ve+simd/hard;@mthumb@march=armv7ve+simd@mfloat-abi=hard

thumb/v8-a/nofp;@mthumb@march=armv8-a@mfloat-abi=soft

thumb/v8-a+simd/softfp;@mthumb@march=armv8-a+simd@mfloat-abi=softfp

thumb/v8-a+simd/hard;@mthumb@march=armv8-a+simd@mfloat-abi=hard

thumb/v6-m/nofp;@mthumb@march=armv6s-m@mfloat-abi=soft

thumb/v7-m/nofp;@mthumb@march=armv7-m@mfloat-abi=soft

thumb/v7e-m/nofp;@mthumb@march=armv7e-m@mfloat-abi=soft

thumb/v7e-m+fp/softfp;@mthumb@march=armv7e-m+fp@mfloat-abi=softfp

thumb/v7e-m+fp/hard;@mthumb@march=armv7e-m+fp@mfloat-abi=hard

thumb/v7e-m+dp/softfp;@mthumb@march=armv7e-m+fp.dp@mfloat-abi=softfp

thumb/v7e-m+dp/hard;@mthumb@march=armv7e-m+fp.dp@mfloat-abi=hard

thumb/v8-m.base/nofp;@mthumb@march=armv8-m.base@mfloat-abi=soft

thumb/v8-m.main/nofp;@mthumb@march=armv8-m.main@mfloat-abi=soft

thumb/v8-m.main+fp/softfp;@mthumb@march=armv8-m.main+fp@mfloat-abi=softfp

thumb/v8-m.main+fp/hard;@mthumb@march=armv8-m.main+fp@mfloat-abi=hard

thumb/v8-m.main+dp/softfp;@mthumb@march=armv8-m.main+fp.dp@mfloat-abi=softfp

thumb/v8-m.main+dp/hard;@mthumb@march=armv8-m.main+fp.dp@mfloat-abi=hard

thumb/v8.1-m.main+mve/hard;@mthumb@march=armv8.1-m.main+mve@mfloat-abi=hard

thumb/v8.1-m.main+pacbti/bp/nofp;@mthumb@march=armv8.1-m.main+pacbti@mbranch-protection=standard@mfloat-abi=soft

thumb/v8.1-m.main+pacbti+fp/bp/softfp;@mthumb@march=armv8.1-m.main+pacbti+fp@mbranch-protection=standard@mfloat-abi=softfp

thumb/v8.1-m.main+pacbti+fp/bp/hard;@mthumb@march=armv8.1-m.main+pacbti+fp@mbranch-protection=standard@mfloat-abi=hard

thumb/v8.1-m.main+pacbti+dp/bp/softfp;@mthumb@march=armv8.1-m.main+pacbti+fp.dp@mbranch-protection=standard@mfloat-abi=softfp

thumb/v8.1-m.main+pacbti+dp/bp/hard;@mthumb@march=armv8.1-m.main+pacbti+fp.dp@mbranch-protection=standard@mfloat-abi=hard

thumb/v8.1-m.main+pacbti+mve/bp/hard;@mthumb@march=armv8.1-m.main+pacbti+mve@mbranch-protection=standard@mfloat-abi=hard
</details>



For `aarch64` there are currently only 2 (LP64 and ILP32).

Technically, we'd need to test all of the above architecture combinations in Big Endian and Little Endian mode (and even more architecture combinations that aren't reflected in the multilibs) to ensure correctness of the toolchain, but, especially for 32-bit `arm`, that would be really exhaustive. As such, we usually care about testing:

For 32-bit `arm`
```
-marm/-march=armv7-a/-mfloat-abi=soft
-mthumb/-march=armv8-a+simd/-mfloat-abi=hard
-mthumb/-march=armv6s-m/-mtune=cortex-m0/-mfloat-abi=soft
-mthumb/-march=armv7-m/-mtune=cortex-m3/-mfloat-abi=softfp
-mthumb/-march=armv7e-m+fp.dp/-mtune=cortex-m7/-mfloat-abi=hard
-mthumb/-march=armv8-m.base/-mtune=cortex-m23/-mfloat-abi=soft
-mthumb/-march=armv8-m.main+dsp+fp/-mtune=cortex-m33/-mfloat-abi=hard
-mthumb/-march=armv8.1-m.main+mve.fp+fp.dp/-mtune=cortex-m55/-mfloat-abi=hard
```

For 64-bit `aarch64`:
```
-march=armv8-a
-march=armv8.6-a+sve
```

**Note 1:** We generally don't test or track Big Endian configurations.

**Note 2:** The `aarch64` ILP32 configuration, although it exists as a multilib, is also not regularly tested or tracked.

**Note 3:** Internally this testing is done with Fastmodels, but doing it with QEMU is equally valid.

### Testing with QEMU

In order to run testing with QEMU, it is necessary to have it included as per the process described above. This should have happened if a `qemu` folder in `./src` was checked out. The QEMU binary should be found under `./build-<target>/install-qemu/bin/qemu<arm/aarch64>`.
If a version of QEMU under that path wasn't included, it is possible to add the QEMU source in the aforementioned location and re-run the build script, with the same parameters as before, but with the `start` command at the end of the invocation.

Example invocation of tests on QEMU

```
build-gnu-toolchain.sh --target=arm-none-eabi --dejagnu-site=site-exhaustive-qemu.exp check
```

### Testing with Fastmodels

Testing with Fastmodels is possible as long as the correct models are installed, the scripts know where to find them, and the correct license, if needed, is used.

The setup of the testing requires a review of the `board files`, so that they point to a locally installed version of Fastmodels. **Refer to the dejagnu folder and the provided board files, which can be changed as needed to point to a valid Fastmodels for the configuration under test**

<span style="background-color: #FFFF00">TODO: more details on what model is needed in each case</span>

### Testing many configurations with site*.exp

It is possible to test all configurations in one go, using the provided `site-exhaustive-*.exp` file. This will take many hours, but it is possible to create derivatives of `site-exhaustive-*.exp` with fewer test sets.
For using custom exp files, it is required to pass the parameter `--dejagnu-site=<site.exp filename>.exp` to the `build-gnu-toolchain.sh` invocation and add `check` (to test all components) or `check-gcc` (to only test the main compiler) as the command, e.g.:
```
build-gnu-toolchain.sh --target=arm-none-eabi --debug --debug-target --dejagnu-site=site-exhaustive-<model>.exp check
```
Note 1: the cross-linux toolchains `*-linux-gnu*` cannot be tested with Fastmodels, so **even if the Fastmodels site.exp file is given, the scripts will still attempt to run on QEMU**.
Note 2: If testing with Fastmodels, **any board file used needs to customization to point to a valid local installation of Fastmodels**


####  Testing a single configuration with a single target board file

This is similar to using a site*.exp file, except that the `--target-board` parameter must be given and **appropriate RUNTESTFLAGS must be set.**
```
RUNTESTFLAGS="-mthumb/-march=armv8.1-m.main+mve.fp+fp.dp/-mtune=cortex-m55/-mfloat-abi=hard" build-gnu-toolchain.sh --target=arm-none-eabi --debug --debug-target --with-arch=armv8.1-m.main+mve.fp+fp.dp --target-board=arm-eabi-mps2-armv8.1-m.main check

```

#### Testing native toolchains
Building native toolchains through these scripts isn't currently supported.

### GDB testing
GDB testing is generally disabled. We haven't monitored the GDB testsuite through these scripts for many years. This needs proper debugging before re-enabling (also note that GDB testing only works with QEMU as the simulator, not with Fastmodels)

## How to debug target binaries running on QEMU
See (https://qemu-project.gitlab.io/qemu/system/gdb.html)[https://qemu-project.gitlab.io/qemu/system/gdb.html].

The DejaGNU board file provide examples of how the QEMU binary is executed (qemu-aarch64, qemu-aarch64_be, qemu-arm, etc.) and what command line options are available (usually just a `-cpu` option).

# Licence
This project is licensed under the terms of the MIT license.

## fm-gdb-plugin Usage
The GDB Plugin shared library is included in the extras directory and can be used for debugging target binaries running on Fast Models. The GDB Plugin is designed to interface with GDB. It is compatible with any GDB versions that supports target description XML.

**Launching the GDB Plugin**
To use the GDB Plugin, load it during the invocation of Fast Models by including the --fm-gdb-plugin parameter. This parameter points to the shared library file for the plugin. Upon specifying this parameter, the plugin will initialize and launch a GDB server instance, which listens for incoming connections on a specified TCP port.

By default, the GDB server will listen on TCP port 10000. You can confirm that the server is running by checking the command line output. The following message should appear, indicating that the server is active and waiting for a connection:

```GDBServer: Listening on: 0.0.0.0 port: 10000```

**Supported Models**

Currently, the fm-gdb-plugin supports the mps2 and base models. To determine the appropriate command line options to use with models-run, refer to the applicable DejaGNU board file. Typically, you will need to specify the --model and --arch options, with armv8-a being the default architecture.

**Example Command**
Here’s an example of how to run a test program with the GDB plugin:

```models-run --model=mps2 --arch=armv7-m /path/to/your/test_program --fm-gdb-plugin=/path/to/fm-gdb-plugin.so```

**Connecting to GDBServer**
Once the GDB server is listening, you can connect to it using GDB by specifying the correct port number:

```gdb /path/to/your/test_program -ex "tar rem :10000"```

Once connected, GDB provides full control over the test program.
