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

Patch                                                                | Description |
---------------------------------------------------------------------|--------------- |
Fix for long path issues on Windows                                  | Windows has a limit of the number of characters in paths to files. This fix allows up to 248 characters in paths to GCC toolchain binaries and up to 4096 characters for all files processed by the GCC tools. Without the patch the latter limit is about 150 characters. |
Provide Newlib string function compatible with all platforms         | Adds aliases for Newlib string functions. Enables the functions to be called on all target platforms without changing the target source code. Useful for unit testing of target source code on Windows. |
Provide compatibility with IAR EW projects                           | Adds pre-processor symbol \_\_FILE_NAME\_\_ which is used in IAR EW. Will be required for import of IAR EW projects. |
Enable debugging of functions in target libraries libg or libg\_nano | Updates the GCC build scripts for libg and libg\_nano in Newlib, so that debug symbols are not stripped. |
Correct stack usage for functions with inline assembler              | Required by Stack Analyzer advanced debug function in CubeIDE. |
Prepare for calculation of cyclomatic complexity                     | Provides the ability to calculate cyclomatic complexity of the target source code processed by GCC. The patch integrates the plugin into GCC binaries. |
Include librdimon-v2m.a in delivery for both Newlib variants         | Support rdimon on Cortex-A by including librdimon-v2m.a for the Newlib-nano. |

## Backports

### Binutils

- [ld: Rename a file on Windows fails if target already exists](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=233cd5946413108bf4902b22a9cb23ad0a468f5e)


### GCC

- [arm: avoid unmatched insn in movhfcc \[PR118460\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=99af0f9078865269ae13367a25e2b156c8ccba77)
- [arm: Always use vmov.f64 instead of vmov.f32 with MVE](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=37c21d4c6ad0afe2aacdd6384b9efa96f5754169)
- [arm: Use POP {pc} to return when returning \[PR118089\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=5163cf2ae14c5e7ec730ad72680564001d0d0441)
- [arm: remove constraints from \*pop\_multiple\_with\_writeback\_and\_return](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=b47c7a5a3c8280ea64754a6c24582236eacef8a2)
- [arm: cleanup code in ldm\_stm\_operation\_p; relax limits on ldm/stm](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=aead1d44b7df50c77ff63482f5548f237ff29033)
- [c, c++: preserve type name in conversion \[PR116060\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=c6b54302df470bf09801ad6785d5713ef23dcb38)
- [testsuite: arm: Simplify fp16-aapcs tests](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=bfd2c5550130e7cb8596f0621afc59dee082f212)
- [\[testsuite\] add missing require vect\_early\_break\_hw for vect-tsvc](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=22e5f9073c061959ba8674c4ff31ef3635f778c9)
- [testsuite: handle-multiline-outputs must allow both cc1 and cc1.exe](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=0f8bacc8b2e62d3b81d64ae466ee994d3cab72a4)
- [testsuite: Improve check-function-bodies](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=acdc9df371fbe99e814a3f35a439531e08af79e7)
- [\[testsuite\] \[arm\] adjust wmul expectations \[PR113560\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=fed57c8ec95ce3d86e74c5afb73a3a4a499d4ec4)
- [testsuite: Fix fallout of turning warnings into errors on 32-bit Arm](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=115857bf1e32637e258a9329fdf25cf924d01e90)
- [testsuite: fix testcase pr110279-1.c](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=5c19ba52519be975d4464b063d3d5a2c700dd241)
- [testsuite: Only run test if alarm is available](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=57b706d141b87c06dfbba577048a1e4903d33f70)
- [testsuite: Fix pr101145inf\*.c testcases \[PR117494\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=0dc389f21bfd4ee49d57bcfaa1d1936456c55e48)
- [arm: testsuite: remove gcc.target/arm/lp1243022.c \[PR117931\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=9ee6c2619b256878d43800a16f7b98b3ddf59e52)
- [libstdc++: Move new functions to separate files \[PR119110\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=c21d5a3591fd761872e18278e1cd8ec18e36d4cb)
- [libstdc++: Add missing \<vector\> header to unordered\_set/pr115285.cc test](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=a51d220377ab8117305567e888a942d127ef6a48)
- [\[testsuite\] add linkonly to dg-additional-sources \[PR115295\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=9223d1715918e4e8e7a59471b228f815b4a3467c)
- [\[testsuite\] conditionalize dg-additional-sources on target and type](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=bdc264a16e327c63d133131a695a202fbbc0a6a0)
- [testsuite: arm: Disable sched2 and sched3 in unsigned-extend-2.c](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=4b4ee2fa4a555c63869475bb340bb58d5d29ae74)
- [testsuite: arm: Fix unsigned-extend-2.c \[PR116445\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=20c25919132b497c3a46a4bc4044f65b6459b99e)
- [testsuite: arm: rename arm\_v8\_1\_lob\_ok into arm\_v8\_1m\_lob\_hw](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=5cc8a75140032b0ac70ca0d25e0e5fda350d8511)
