# GNU Tools for STM32

This repository contains sources and build scripts for **GNU Tools for STM32** C/C++ bare-metal toolchain included into [STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html) advanced development platform and part of the [STM32Cube](https://www.st.com/en/ecosystems/stm32cube.html) software ecosystem. It is based on [ARM GNU Toolchain](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain) sources, with patches improving use in embedded systems.

## Components

* GNU C/C++ Compiler (GCC) - [Upstream source code repository](git://gcc.gnu.org/git/gcc.git)
* GNU Binutils - [Upstream source code repository](git://sourceware.org/git/binutils-gdb.git)
* GDB - [Upstream source code repository](git://sourceware.org/git/binutils-gdb.git)
* Newlib - [Upstream source code repository](git://sourceware.org/git/Newlib-cygwin.git)

## License

See [LICENSE.md](LICENSE.md)

## Host Platforms

* GNU/Linux
* Windows
* macOs

## Communication and support

For communication and support, please refer to:

- [ST Support Center](https://my.st.com/ols#/ols/) for any defect
- ST Community [MCUs](https://community.st.com/t5/stm32cubeide-mcus/bd-p/stm32-mcu-cubeide-forum) or [MPUs](https://community.st.com/t5/stm32cubeide-mpus/bd-p/stm32-mpu-cubeide-forum) forums

## Patches

Patch                                                          | Description |
---------------------------------------------------------------|--------------- |
Fix for long path issues on Windows                            | Windows has a limit of the number of characters in paths to files. This fix allows up to 248 characters in paths to GCC toolchain binaries and up to 4096 characters for all files processed by the GCC tools. Without the patch the latter limit is about 150 characters. |
Provide Newlib string function compatible with all platforms   | Adds aliases for Newlib string functions. Enables the functions to be called on all target platforms without changing the target source code. Useful for unit testing of target source code on Windows. |
Provide compatibility with IAR EW projects                     | Adds pre-processor symbol \_\_FILE_NAME\_\_ which is used in IAR EW. Will be required for import of IAR EW projects. |
Correct stack usage for functions with inline assembler        | Required by Stack Analyzer advanced debug function in CubeIDE. |
Reduce Newlib code size by 10-30%                              | Updates the GCC build scripts for Newlib to use -Os instead of -O2. Beneficial in most embedded projects. |
Enable user config of malloc() pagesize in Newlib              | Provides the ability to set the page size used when allocating memory in malloc(). Done by implementing sysconfig. Without the fix, the default page size is 4 Kbyte which may consume a lot memory in some applications. Applies to the build of the C standard library Newlib. |
Prepare for calculation of cyclomatic complexity               | Provides the ability to calculate cyclomatic complexity of the target source code processed by GCC. The patch integrates the plugin into GCC binaries. |
Include librdimon-v2m.a in delivery for both Newlib variants   | Support rdimon on Cortex-A by including librdimon-v2m.a for the Newlib-nano. |
Correctly mark returned block as used                          | The malloc() function in Newlib-nano did not properly mark allocated block as used under certain conditions. Fixed. |
Generate _newlib_version.h                                     | Solves GCC-11 regression issue with \_newlib\_version.h not containing valid C expressions. |
Added -nostdlibc++                                             | Added flag to disable linkage of libstdc++. |
Improve stack unwinding for Cortex-M targets in GDB            | Solves some of the issues unwinding the stack on Cortex-M33 with TrustZone enabled. |
