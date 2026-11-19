# GNU Tools for STM32

This repository contains sources and build scripts for **GNU Tools for STM32** C/C++ bare-metal toolchain included into [STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html) advanced development platform and part of the [STM32Cube](https://www.st.com/en/ecosystems/stm32cube.html) software ecosystem. It is based on [ARM GNU Toolchain](https://gitlab.arm.com/tooling/gnu-toolchains-for-arm/-/tree/main) sources, with patches improving use in embedded systems.

## Components

* GNU C/C++ Compiler (GCC) - [Upstream source code repository](https://gcc.gnu.org/git/gcc.git)
* GNU Binutils - [Upstream source code repository](https://sourceware.org/git/binutils-gdb.git)
* GDB - [Upstream source code repository](https://sourceware.org/git/binutils-gdb.git)
* Newlib - [Upstream source code repository](https://sourceware.org/git/newlib-cygwin.git)

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

- [arm: delay setting of plt header and entry size](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=bd8942a0e049a466f9b649364bf53445fb47dd0c)
- [PR 33697, fuzzer segfault](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=66a3492ce68e1ae45b2489bd9a815c39ea5d7f66)
- [ld: Account for .tbss size on Arm embedded targets](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=1cc9aa9de2af3cd54d5433c0e4a522b73719c3cb)
- [Objdump: New feature display of global variable info based on DWARF info section](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=164959506e947a88cf558558c054a6d654ef4409)
- [Re: bfd/Dwarf: Add suitable defines to use at call and use sites](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=0efa88d649d2ba7184951bd7795cc3ed581eb9e9)
- [bfd/Dwarf: Add suitable defines to use at call and use sites](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=1f7e70ddd2c49dd5442b8873dd6ef29b0a10fdc3)

### GCC

- [libstdc++: Resolve integer type mismatches in stdx::simd \[PR122981\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=4e08734e5fcfba5fb657a163a20c001236655f01)
- [c++: ICE on on systems without mmap support \[PR124806\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=996979360a4027c1e85770cde031e673f8288e9d)
- [tree-optimization: Fold constant conditional selects \[PR124663\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=920c3de1f84a6d7ac6ea689e742da84446c0ac50)
- [Make -Wuse-after-free alias for -Wuse-after-free=1 \[PR124058\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=0a93e3b70f1f69aff67ec7e40f987f3cfaac458e)
- [c++: coroutines: initialize refcount](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=5422486d4bc728688dd2c874cb014fadf745b2da)
- [arm: allow at least one insn when loading a constant \[PR102309\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=d2216cfce1ad776a5c69bee61f4c924a1481be5d)
- [testsuite: arm: Set tuning for MVE FP intrinsic tests](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=b56c7709b773a29cc039b1677bc48907497c1773)
- [doc: Fix up doc build](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=ec6d35f95d0fcc18759d38aa3b94a5fe2b226fcb)
- [testsuite: arm: require fp16 alternative hw for tests](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=0cf2c695680fa2fe9777e5e7d91d04bcd52ab586)
- [testsuite: require cortex-a53 in reg\_equal\_test.c test](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=26bb36f81b68ef69c6f3b53766b6cc87324b95c3)
- [testsuite: prevent packing enum in vect-early-break\_65.c \[PR124112\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=29d4a53ae0cae3a79776765f6cdfffd12cbf3776)
- [testsuite: remove xfail "vectorized 1 loops" arm\_neon \[PR124726\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=55aaddd14ab47b0df4b0161d323d1c9a6e0c888e)
- [testsuite: remove xfail for arm\_mve from ssa-dom-cse-2.c \[PR124361\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=5abb918b15754855d308db35c541705c83cb635c)
- [testsuite: arm: remove xfail for MVE, NEON and thumb1 \[PR124364\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=af341ce9bd49239ebbf84d39e8613fda3bc3ee0e)
- [testsuite: cast argument to char\* in can\_deref\_null \[PR126261\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=223e11e08039a864ffc7fa4ae6d03de8c3e5f69e)
- [testsuite: skip test for targets that can deref null \[PR126261\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=cf69dd0145e174e5497739a373100f83be1894f6)
- [testsuite: use arm\_neon as xfail condition \[PR118407\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=dda27f680737ec981719ae8eaa20d816f1adeb11)
- [testsuite: arm: xfail predcom-8.c test in hard float without MVE \[PR118407\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=155193b2697facd1e84b34c5959345d9160cf34b)
- [testsuite: arm: xfail crypto tests for -mthumb -mfloat-abi=hard \[PR124043\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=bd5ba3e4720e18c0c9e41b71987cf8f03f14b2ae)
- [testsuite: arm: crypto-vsha1\*\_u32 tests got late-combine improvements](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=94ace2557836a6eecb23475e5640c8c4a5407902)
- [testsuite: arm: Add MVE link effective target](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=004713cadcff519e07697cdadb0df4a7f278e064)
- [testsuite: arm: update fast-math-complex-mls-{float,double}.c \[PR116463\]](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=aca3a6235baad23e7156ee8c80c0b7433a2ddfab)
- [testsuite/115827 - avoid false negative because of CCP](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=539e6a417856519d6112e99a1583da1926e34047)
- [testsuite: arm: Properly quote command line arguments](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=8d1b16962f6bc1de780d9c2bbaac3896efa599ff)
- [arm: testsuite: Yet another typo in pr45701-2.c](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=047a37d3db8fc33b875cd85e2de11823977ecb31)
- [arm: testsuite: properly escape '\[\]' in pr45701-2.c](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=2efd5c35688fa351d5f03fdd73dff245ae1634bf)
- [arm: testsuite: avoid pr45701 matching asm across newlines](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=82cfe20e2493175c34757b075a7607e7d99ffabb)
- [arm: testsuite: Improve stability of tests for pr45701](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=11b4f8ca5cbff912ef0a5e28dfe9afebde4c2d51)
- [arm: testsuite: remove some flaky code-size tests](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=7a7b400577a26dab8f6d1cdcafdb9f9e421b7071)
- [testsuite: g++.dg/cpp2a/decomp2.C requires tls\_runtime](https://gcc.gnu.org/git/?p=gcc.git;a=commit;h=dd1ee31540bd3eaca5441dc815ea9284bcc09af3)

### GDB

- [PR 33697, fuzzer segfault](https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=66a3492ce68e1ae45b2489bd9a815c39ea5d7f66)
