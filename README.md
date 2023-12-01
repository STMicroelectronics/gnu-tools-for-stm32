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

Patch                                                                   | Description |
------------------------------------------------------------------------|--------------- |
Fix for long path issues on Windows                                     | Windows has a limit of the number of characters in paths to files. This fix allows up to 248 characters in paths to GCC toolchain binaries and up to 4096 characters for all files processed by the GCC tools. Without the patch the latter limit is about 150 characters. |
Provide Newlib string function compatible with all platforms            | Adds aliases for Newlib string functions. Enables the functions to be called on all target platforms without changing the target source code. Useful for unit testing of target source code on Windows. |
Provide compatibility with IAR EW projects                              | Adds pre-processor symbol \_\_FILE_NAME\_\_ which is used in IAR EW. Will be required for import of IAR EW projects. |
Enable debugging of functions in target libraries libg or libg\_nano    | Updates the GCC build scripts for libg and libg\_nano in newlib, so that debug symbols are not stripped. |
Correct stack usage for functions with inline assembler                 | Required by Stack Analyzer advanced debug function in CubeIDE. |
Reduce Newlib code size by 10-30%                                       | Updates the GCC build scripts for Newlib to use -Os instead of -O2. Beneficial in most embedded projects. |
Enable user config of malloc() pagesize in Newlib                       | Provides the ability to set the page size used when allocating memory in malloc(). Done by implementing sysconfig. Without the fix, the default page size is 4 Kbyte which may consume a lot memory in some applications. Applies to the build of the C standard library Newlib. |
Prepare for calculation of cyclomatic complexity                        | Provides the ability to calculate cyclomatic complexity of the target source code processed by GCC. The patch integrates the plugin into GCC binaries. |
Fix for "Empty if-statements" warning                                   | Eliminates warning emitted for an empty if-statement. |
Fix for "Missing function prototype" warning                            | Eliminates warning by adding missing function prototypes. |
Fix for "Unused arguments" warning in \_\_GLIBCXX\_THROW\_OR\_ABORT\_\_ | Eliminates warning in cases were the arguments to \_\_GLIBCXX\_THROW\_OR\_ABORT\_\_ are not used. |
Fix for "Maybe used uninitialized" warning                              | Eliminates warning for variables that are not initialized before first use. |
Include librdimon-v2m.a in delivery for both Newlib variants            | Support rdimon on Cortex-A by including librdimon-v2m.a for the Newlib-nano. |
Support lto-wrapper on Windows                                          | Properly identify number of threads on Windows. |
Fix for GDB suspend issue with -g3                                      | When GDB suspends in certain cases with a binary compiled with -g3, all compile units need to be resolved and it takes a long time. |
