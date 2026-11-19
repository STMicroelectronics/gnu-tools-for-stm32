#ifndef LIBLONGPATH_WIN32_CALLING_CONVENTION_H
#define LIBLONGPATH_WIN32_CALLING_CONVENTION_H

/*
 * __cdecl and WINAPI (__stdcall) select calling conventions on 32-bit x86.
 * Windows x64 and ARM64 use a single platform calling convention, so these
 * keywords have no effect there. GCC warns that their attributes are ignored
 * on AArch64, which causes compilation to fail when warnings are treated as
 * errors.
 * https://learn.microsoft.com/en-us/cpp/cpp/cdecl
 * https://learn.microsoft.com/en-us/cpp/cpp/stdcall
 */
#if defined(__i386__) || defined(_M_IX86)
#define LP_CDECL __cdecl
#define LP_WINAPI WINAPI
#elif defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64) \
  || defined(__aarch64__) || defined(_M_ARM64)
#define LP_CDECL
#define LP_WINAPI
#else
#error Unsupported Windows architecture for calling conventions
#endif

#endif
