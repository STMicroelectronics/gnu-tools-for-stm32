/******************************************************************************
 * MIT License
 *
 * Copyright (c) 2022, 2023 STMicroelectronics.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 ******************************************************************************/

/* workarround for defining GetFinalPathNameByHandleW */
#define _WIN32_WINNT 0x0601 /* win7 */

#include <sys/fcntl.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <ntdef.h>
#include <windef.h>
#include <direct.h>
#include <windows.h>
#include <fileapi.h>
#include <errno.h>
#include <assert.h>
#include <stdint.h>
#include <process.h>
#include "stmicroelectronics/longpath.h"


#define IS_PATHSEP(x) ((x) == '\\' || (x) == '/')
#define IS_UNC_PREFIX(x) (IS_PATHSEP((x)[0]) && IS_PATHSEP((x)[1]) && (x)[2] == L'?' && IS_PATHSEP((x)[3]))

#ifndef IO_REPARSE_TAG_LX_SYMLINK
#define IO_REPARSE_TAG_LX_SYMLINK  0xA000001D
#endif


#define MAX_DIR_PATH (MAX_PATH - 8 - 3) /* 8.3 notation for file part. */

int __cdecl __real__waccess(const wchar_t *, int);
errno_t __cdecl __real__waccess_s (const wchar_t *, int);
int __cdecl __real__wcreat(const wchar_t *, int);
int __cdecl __real_fflush(FILE *);
int __cdecl __real_write(int, const void *, size_t);
int __cdecl __real__wopen (const wchar_t *, int, ...);
int __cdecl __real__wchmod(const wchar_t *, int);
FILE * __cdecl __real__wfreopen(const wchar_t *, const wchar_t *, FILE *);
errno_t __cdecl __real__wfreopen_s(FILE **, const wchar_t *, const wchar_t *, FILE *);
FILE * __cdecl __real__wfopen (const wchar_t *, const wchar_t *);
int __cdecl __real__wsopen(const wchar_t *, int, int, ...);
errno_t __cdecl __real__wsopen_s(int *, const wchar_t *, int, int, int);

WINBOOL WINAPI __real_SetCurrentDirectoryW (LPCWSTR);
DWORD WINAPI __real_GetCurrentDirectoryW (DWORD, LPWSTR);

DWORD WINAPI __real_GetFileAttributesW (LPCWSTR);
WINBOOL WINAPI __real_GetFileAttributesExW (LPCWSTR, GET_FILEEX_INFO_LEVELS, LPVOID);
WINBOOL WINAPI __real_SetFileAttributesW (LPCWSTR, DWORD);
WINBOOL WINAPI __real_CreateDirectoryW (LPCWSTR, LPSECURITY_ATTRIBUTES);
WINBOOL WINAPI __real_DeleteFileW (LPCWSTR);
WINBOOL WINAPI __real_RemoveDirectoryW (LPCWSTR);
HANDLE WINAPI __real_CreateFileW (LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);

HANDLE WINAPI __real_FindFirstFileW (LPCWSTR, LPWIN32_FIND_DATAW);
HANDLE WINAPI __real_FindFirstFileExW (LPCWSTR, FINDEX_INFO_LEVELS, LPVOID, FINDEX_SEARCH_OPS, LPVOID, DWORD);

WINBOOL WINAPI __real_DeleteVolumeMountPointW (LPCWSTR);
WINBOOL WINAPI __real_GetVolumeNameForVolumeMountPointW (LPCWSTR, LPWSTR, DWORD);
WINBOOL WINAPI __real_SetVolumeMountPointW (LPCWSTR, LPCWSTR);
WINBOOL WINAPI __real_SetSearchPathMode(DWORD);

WINBOOL WINAPI __real_MoveFileW (LPCWSTR, LPCWSTR);
WINBOOL WINAPI __real_MoveFileExW (LPCWSTR, LPCWSTR, DWORD);
WINBOOL WINAPI __real_MoveFileWithProgressW (LPCWSTR, LPCWSTR, LPPROGRESS_ROUTINE, LPVOID, DWORD);
WINBOOL WINAPI __real_CopyFileW (LPCWSTR, LPCWSTR, WINBOOL);
WINBOOL WINAPI __real_CopyFileExW (LPCWSTR, LPCWSTR, LPPROGRESS_ROUTINE, LPVOID, LPBOOL, DWORD);


/* direct.h */
int __cdecl __wrap_chdir(const char *);
int __cdecl __wrap__chdir(const char *);
int __cdecl __wrap__wchdir(const wchar_t *);

char * __cdecl __wrap_getcwd (char *, int);
char * __cdecl __wrap__getcwd (char *, int);
wchar_t * __cdecl __wrap__wgetcwd(wchar_t *, int);

int __cdecl __wrap_mkdir (const char *, int);
int __cdecl __wrap__mkdir (const char *);
int __cdecl __wrap__wmkdir (const wchar_t *);

int __cdecl __wrap_rmdir (const char *);
int __cdecl __wrap__rmdir (const char *);
int __cdecl __wrap__wrmdir (const wchar_t *);



// io.h
int __cdecl __wrap_access(const char *, int);
int __cdecl __wrap__access(const char *, int);
int __cdecl __wrap__waccess(const wchar_t *, int);
errno_t __cdecl __wrap__access_s(const char *, int);
errno_t __cdecl __wrap__waccess_s (const wchar_t *, int);

int __cdecl __wrap_creat(const char *, int);
int __cdecl __wrap__creat(const char *, int);
int __cdecl __wrap__wcreat(const wchar_t *, int);

int __cdecl __wrap_rename(const char *,const char *);
int __cdecl __wrap__wrename(const wchar_t *,const wchar_t *);

int __cdecl __wrap_remove(const char *);
int __cdecl __wrap__wremove(const wchar_t *);

int __cdecl __wrap_unlink(const char *);
int __cdecl __wrap__unlink(const char *);
int __cdecl __wrap__wunlink(const wchar_t *);


int __cdecl __wrap_open(const char *, int, ...);
int __cdecl __wrap__open(const char *, int, ...);
int __cdecl __wrap__wopen(const wchar_t *, int, ...);

int __cdecl __wrap_sopen(const char *, int, int, ...);
int __cdecl __wrap__sopen(const char *, int, int, ...);
int __cdecl __wrap__wsopen(const wchar_t *, int, int, ...);
errno_t __cdecl __wrap__sopen_s(int *, const char *, int, int, int);
errno_t __cdecl __wrap__wsopen_s(int *, const wchar_t *, int, int, int);

int __cdecl __wrap_chmod(const char *, int);
int __cdecl __wrap__chmod(const char *, int);
int __cdecl __wrap__wchmod(const wchar_t *, int);



char *__wrap_lrealpath (const char *);


char *__cdecl __wrap__fullpath(char *, const char *, size_t);

FILE * __cdecl __wrap_fopen64 (const char *, const char *);
FILE * __cdecl __wrap_fopen (const char *, const char *);
FILE * __cdecl __wrap__wfopen (const wchar_t *, const wchar_t *);
FILE * __cdecl __wrap_freopen (const char *, const char *, FILE *);
FILE * __cdecl __wrap__wfreopen(const wchar_t *, const wchar_t *, FILE *);
errno_t __cdecl __wrap_freopen_s (FILE **, const char *, const char *, FILE *);
errno_t __cdecl __wrap__wfreopen_s(FILE **, const wchar_t *, const wchar_t *, FILE *);

int __cdecl __wrap_fflush( FILE *);
int __cdecl __wrap_write (int , const void *, size_t);

int __cdecl __wrap_stat (const char *, struct stat *);
int __cdecl __wrap_wstat (const wchar_t *, struct stat *);
int __cdecl __wrap__stat64i32(const char *, struct _stat64i32 *);
int __cdecl __wrap__wstat64i32(const wchar_t *, struct _stat64i32 *);

int __cdecl __wrap__stat32(const char *, struct _stat32 *);
int __cdecl __wrap__wstat32(const wchar_t *, struct _stat32 *);

int __cdecl __wrap__stat32i64(const char *, struct _stat32i64 *);
int __cdecl __wrap__wstat32i64(const wchar_t *, struct _stat32i64 *);

int __cdecl __wrap__stat64 (const char *, struct _stat64 *);
int __cdecl __wrap__wstat64(const wchar_t *, struct _stat64 *);
int __cdecl __real__wstat64(const wchar_t *, struct _stat64 *);

int __cdecl __wrap_lstat (const char *, struct stat *);

int __cdecl __wrap__fstat32(int, struct _stat32 *);
int __cdecl __wrap__fstat32i64(int, struct _stat32i64 *);
int __cdecl __wrap__fstat64 (int, struct _stat64 *);
int __cdecl __wrap__fstat64i32(int, struct _stat64i32 *);

/* Validate stat aliases.  */
#ifdef _WIN64
#  ifndef _fstat
#    error _fstat is supposed to be a define
#  endif
#  ifndef _fstati64
#    error _fstati64 is supposed to be a define
#  endif
#  ifndef _stat
#    error _stat is supposed to be a define
#  endif
#  ifndef _stati64
#    error _stati64 is supposed to be a define
#  endif
#  ifndef _wstat
#    error _wstat is supposed to be a define
#  endif
#  ifndef _wstati64
#    error _wstati64 is supposed to be a define
#  endif
#else
#  error Unknown target platform
#endif


WINBOOL WINAPI __wrap_SetCurrentDirectoryA (LPCSTR);
WINBOOL WINAPI __wrap_SetCurrentDirectoryW (LPCWSTR);
DWORD WINAPI __wrap_GetCurrentDirectoryA (DWORD, LPSTR);
DWORD WINAPI __wrap_GetCurrentDirectoryW (DWORD, LPWSTR);

DWORD WINAPI __wrap_GetFileAttributesA (LPCSTR);
DWORD WINAPI __wrap_GetFileAttributesW (LPCWSTR);
WINBOOL WINAPI __wrap_GetFileAttributesExA (LPCSTR, GET_FILEEX_INFO_LEVELS, LPVOID);
WINBOOL WINAPI __wrap_GetFileAttributesExW (LPCWSTR, GET_FILEEX_INFO_LEVELS, LPVOID);
WINBOOL WINAPI __wrap_CreateDirectoryA (LPCSTR, LPSECURITY_ATTRIBUTES);
WINBOOL WINAPI __wrap_CreateDirectoryW (LPCWSTR, LPSECURITY_ATTRIBUTES);
WINBOOL WINAPI __wrap_DeleteFileA (LPCSTR);
WINBOOL WINAPI __wrap_DeleteFileW (LPCWSTR);
WINBOOL WINAPI __wrap_RemoveDirectoryA (LPCSTR);
WINBOOL WINAPI __wrap_RemoveDirectoryW (LPCWSTR);
WINBOOL WINAPI __wrap_SetFileAttributesA (LPCSTR, DWORD);
WINBOOL WINAPI __wrap_SetFileAttributesW (LPCWSTR, DWORD);
HANDLE WINAPI __wrap_CreateFileA (LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
HANDLE WINAPI __wrap_CreateFileW (LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);


HANDLE WINAPI __wrap_FindFirstFileA (LPCSTR, LPWIN32_FIND_DATAA);
HANDLE WINAPI __wrap_FindFirstFileW (LPCWSTR, LPWIN32_FIND_DATAW);
HANDLE WINAPI __wrap_FindFirstFileExA (LPCSTR, FINDEX_INFO_LEVELS, LPVOID, FINDEX_SEARCH_OPS, LPVOID, DWORD);
HANDLE WINAPI __wrap_FindFirstFileExW (LPCWSTR, FINDEX_INFO_LEVELS, LPVOID, FINDEX_SEARCH_OPS, LPVOID, DWORD);

WINBOOL WINAPI __wrap_DeleteVolumeMountPointA (LPCSTR);
WINBOOL WINAPI __wrap_DeleteVolumeMountPointW (LPCWSTR);
WINBOOL WINAPI __wrap_GetVolumeNameForVolumeMountPointA (LPCSTR, LPSTR, DWORD);
WINBOOL WINAPI __wrap_GetVolumeNameForVolumeMountPointW (LPCWSTR, LPWSTR, DWORD);
WINBOOL WINAPI __wrap_SetVolumeMountPointA (LPCSTR, LPCSTR);
WINBOOL WINAPI __wrap_SetVolumeMountPointW (LPCWSTR, LPCWSTR);


WINBOOL WINAPI __wrap_MoveFileA (LPCSTR, LPCSTR);
WINBOOL WINAPI __wrap_MoveFileW (LPCWSTR, LPCWSTR);
WINBOOL WINAPI __wrap_MoveFileExA (LPCSTR, LPCSTR, DWORD);
WINBOOL WINAPI __wrap_MoveFileExW (LPCWSTR, LPCWSTR, DWORD);
WINBOOL WINAPI __wrap_MoveFileWithProgressA (LPCSTR, LPCSTR, LPPROGRESS_ROUTINE, LPVOID, DWORD);
WINBOOL WINAPI __wrap_MoveFileWithProgressW (LPCWSTR, LPCWSTR, LPPROGRESS_ROUTINE, LPVOID, DWORD);
UINT WINAPI __wrap_GetTempFileNameA (LPCSTR, LPCSTR, UINT, LPSTR);
DWORD WINAPI __wrap_GetModuleFileNameA (HMODULE, LPSTR, DWORD);
WINBOOL WINAPI __wrap_CopyFileA (LPCSTR, LPCSTR, WINBOOL);
WINBOOL WINAPI __wrap_CopyFileW (LPCWSTR, LPCWSTR, WINBOOL);
WINBOOL WINAPI __wrap_CopyFileExA (LPCSTR, LPCSTR, LPPROGRESS_ROUTINE, LPVOID, LPBOOL, DWORD);
WINBOOL WINAPI __wrap_CopyFileExW (LPCWSTR, LPCWSTR, LPPROGRESS_ROUTINE, LPVOID, LPBOOL, DWORD);

#ifdef ENABLE_LP_DEBUG
static const wchar_t *
lp_debug_file (void)
{
  static int init = 0;
  static const wchar_t *path = NULL;
  if (!init)
    {
      path = _wgetenv (L"LP_DEBUG_FILE");
      init = 1;
    }

  return path;
}

static void
lp_debug_print (const char *fmt, ...)
{
  static int pid = 0;
  static char *cmd = NULL;
  va_list args;

  FILE *f = __real__wfopen(lp_debug_file (), L"a");
  if (!f)
    {
      perror ("Can't open debug log");
      exit (1);
    }

  if (!cmd)
    {
      int argc;
      wchar_t** argv = CommandLineToArgvW (GetCommandLineW (), &argc);
      if (!argv)
	{
	  fprintf (stderr, "CommandLineToArgvW failed\n");
	  fclose (f);
	  exit (1);
	}

      pid = _getpid ();
      cmd = wchar_to_utf8 (argv[0]);
      if (!cmd)
	{
	  perror ("Failed to convert to utf8");
	  fclose (f);
	  exit (1);
	}

      for (int i = 0; i < argc; i++)
	  fwprintf (f, L"%s[%d] argv[%d]: %s\n", cmd, pid, i, argv[i]);

      LocalFree (argv);
    }

  fprintf (f, "%s[%d] ", cmd, pid);

  va_start (args, fmt);
  vfprintf (f, fmt, args);
  va_end (args);

  fflush (f);
  fclose (f);
}
#define LP_DEBUG(...) do { if (lp_debug_file()) lp_debug_print(__VA_ARGS__); } while (0)
#else
#define LP_DEBUG(...)
#endif

/*
 * BZ#80181 - GetLongPathNameW is a fairly slow operation and is called very often.
 */
typedef struct {
  wchar_t *cwd;
  wchar_t *long_cwd;
  size_t long_cwd_len;
  char *long_cwd_utf8;
  size_t long_cwd_utf8_len;
} _long_path_name_cache_t;
static _long_path_name_cache_t _long_path_name = {NULL, NULL, 0, NULL, 0};

static int internal_update_cwd_cache(void);

static int
to_errno(DWORD err)
{
  switch (err)
    {
      case ERROR_ACCESS_DENIED: return EACCES;
      case ERROR_ACCOUNT_DISABLED: return EACCES;
      case ERROR_ACCOUNT_RESTRICTION: return EACCES;
      case ERROR_ALREADY_ASSIGNED: return EBUSY;
      case ERROR_ALREADY_EXISTS: return EEXIST;
      case ERROR_ARITHMETIC_OVERFLOW: return ERANGE;
      case ERROR_BAD_COMMAND: return EIO;
      case ERROR_BAD_DEVICE: return ENODEV;
      case ERROR_BAD_DRIVER_LEVEL: return ENXIO;
      case ERROR_BAD_EXE_FORMAT: return ENOEXEC;
      case ERROR_BAD_FORMAT: return ENOEXEC;
      case ERROR_BAD_LENGTH: return EINVAL;
      case ERROR_BAD_PATHNAME: return ENOENT;
      case ERROR_BAD_PIPE: return EPIPE;
      case ERROR_BAD_UNIT: return ENODEV;
      case ERROR_BAD_USERNAME: return EINVAL;
      case ERROR_BROKEN_PIPE: return EPIPE;
      case ERROR_BUFFER_OVERFLOW: return ENAMETOOLONG;
      case ERROR_BUSY: return EBUSY;
      case ERROR_BUSY_DRIVE: return EBUSY;
      case ERROR_CALL_NOT_IMPLEMENTED: return ENOSYS;
      case ERROR_CANNOT_MAKE: return EACCES;
      case ERROR_CANTOPEN: return EIO;
      case ERROR_CANTREAD: return EIO;
      case ERROR_CANTWRITE: return EIO;
      case ERROR_CRC: return EIO;
      case ERROR_CURRENT_DIRECTORY: return EACCES;
      case ERROR_DEVICE_IN_USE: return EBUSY;
      case ERROR_DEV_NOT_EXIST: return ENODEV;
      case ERROR_DIRECTORY: return EINVAL;
      case ERROR_DIR_NOT_EMPTY: return ENOTEMPTY;
      case ERROR_DISK_CHANGE: return EIO;
      case ERROR_DISK_FULL: return ENOSPC;
      case ERROR_DRIVE_LOCKED: return EBUSY;
      case ERROR_ENVVAR_NOT_FOUND: return EINVAL;
      case ERROR_EXE_MARKED_INVALID: return ENOEXEC;
      case ERROR_FILENAME_EXCED_RANGE: return ENAMETOOLONG;
      case ERROR_FILE_EXISTS: return EEXIST;
      case ERROR_FILE_INVALID: return ENODEV;
      case ERROR_FILE_NOT_FOUND: return ENOENT;
      case ERROR_GEN_FAILURE: return EIO;
      case ERROR_HANDLE_DISK_FULL: return ENOSPC;
      case ERROR_INSUFFICIENT_BUFFER: return ENOMEM;
      case ERROR_INVALID_ACCESS: return EACCES;
      case ERROR_INVALID_ADDRESS: return EFAULT;
      case ERROR_INVALID_BLOCK: return EFAULT;
      case ERROR_INVALID_DATA: return EINVAL;
      case ERROR_INVALID_DRIVE: return ENODEV;
      case ERROR_INVALID_EXE_SIGNATURE: return ENOEXEC;
      case ERROR_INVALID_FLAGS: return EINVAL;
      case ERROR_INVALID_FUNCTION: return ENOSYS;
      case ERROR_INVALID_HANDLE: return EBADF;
      case ERROR_INVALID_LOGON_HOURS: return EACCES;
      case ERROR_INVALID_NAME: return EINVAL;
      case ERROR_INVALID_OWNER: return EINVAL;
      case ERROR_INVALID_PARAMETER: return EINVAL;
      case ERROR_INVALID_PASSWORD: return EPERM;
      case ERROR_INVALID_PRIMARY_GROUP: return EINVAL;
      case ERROR_INVALID_REPARSE_DATA: return EINVAL;
      case ERROR_INVALID_SIGNAL_NUMBER: return EINVAL;
      case ERROR_INVALID_TARGET_HANDLE: return EIO;
      case ERROR_INVALID_WORKSTATION: return EACCES;
      case ERROR_IO_DEVICE: return EIO;
      case ERROR_IO_INCOMPLETE: return EINTR;
      case ERROR_LOCKED: return EBUSY;
      case ERROR_LOCK_VIOLATION: return EACCES;
      case ERROR_LOGON_FAILURE: return EACCES;
      case ERROR_MAPPED_ALIGNMENT: return EINVAL;
      case ERROR_META_EXPANSION_TOO_LONG: return E2BIG;
      case ERROR_MORE_DATA: return EPIPE;
      case ERROR_NEGATIVE_SEEK: return ESPIPE;
      case ERROR_NOACCESS: return EFAULT;
      case ERROR_NONE_MAPPED: return EINVAL;
      case ERROR_NOT_A_REPARSE_POINT: return EINVAL;
      case ERROR_NOT_ENOUGH_MEMORY: return ENOMEM;
      case ERROR_NOT_READY: return EAGAIN;
      case ERROR_NOT_SAME_DEVICE: return EXDEV;
      case ERROR_NO_DATA: return EPIPE;
      case ERROR_NO_MORE_SEARCH_HANDLES: return EIO;
      case ERROR_NO_PROC_SLOTS: return EAGAIN;
      case ERROR_NO_SUCH_PRIVILEGE: return EACCES;
      case ERROR_OPEN_FAILED: return EIO;
      case ERROR_OPEN_FILES: return EBUSY;
      case ERROR_OPERATION_ABORTED: return EINTR;
      case ERROR_OUTOFMEMORY: return ENOMEM;
      case ERROR_PASSWORD_EXPIRED: return EACCES;
      case ERROR_PATH_BUSY: return EBUSY;
      case ERROR_PATH_NOT_FOUND: return ENOENT;
      case ERROR_PIPE_BUSY: return EBUSY;
      case ERROR_PIPE_CONNECTED: return EPIPE;
      case ERROR_PIPE_LISTENING: return EPIPE;
      case ERROR_PIPE_NOT_CONNECTED: return EPIPE;
      case ERROR_PRIVILEGE_NOT_HELD: return EACCES;
      case ERROR_READ_FAULT: return EIO;
      case ERROR_REPARSE_ATTRIBUTE_CONFLICT: return EINVAL;
      case ERROR_REPARSE_TAG_INVALID: return EINVAL;
      case ERROR_REPARSE_TAG_MISMATCH: return EINVAL;
      case ERROR_SEEK: return EIO;
      case ERROR_SEEK_ON_DEVICE: return ESPIPE;
      case ERROR_SHARING_BUFFER_EXCEEDED: return ENFILE;
      case ERROR_SHARING_VIOLATION: return EACCES;
      case ERROR_STACK_OVERFLOW: return ENOMEM;
      case ERROR_SWAPERROR: return ENOENT;
      case ERROR_TOO_MANY_MODULES: return EMFILE;
      case ERROR_TOO_MANY_OPEN_FILES: return EMFILE;
      case ERROR_UNRECOGNIZED_MEDIA: return ENXIO;
      case ERROR_UNRECOGNIZED_VOLUME: return ENODEV;
      case ERROR_WAIT_NO_CHILDREN: return ECHILD;
      case ERROR_WRITE_FAULT: return EIO;
      case ERROR_WRITE_PROTECT: return EROFS;
      default: return ENOSYS;
    }
}



static wchar_t *
to_unix_like_path(wchar_t *path)
{
  if (*path == '\\')
    {
      const struct foo {
	const wchar_t * prefix;
	const wchar_t * replace;
      } REPLACE_PATTERNS[] = {
	  {L"\\??\\UNC\\", L"\\\\"},
	  {L"\\??\\", L""},
	  {L"\\\\?\\UNC\\", L"\\\\"},
	  {L"\\\\?\\", L""},
	  {L"\\DosDevices\\UNC\\", L"\\\\"},
	  {L"\\DosDevices\\", L""},
      };

      for (size_t i = 0; i < sizeof(REPLACE_PATTERNS) / sizeof(REPLACE_PATTERNS[0]); i++)
	{
	  int from_len = wcslen(REPLACE_PATTERNS[i].prefix);
	  if (wcsnicmp(path, REPLACE_PATTERNS[i].prefix, from_len) == 0)
	    {
	      int to_len = wcslen(REPLACE_PATTERNS[i].replace);

	      /* Skip and replace prefix. */
	      path += from_len - to_len;
	      memcpy(path, REPLACE_PATTERNS[i].replace, to_len * sizeof(wchar_t));

	      /* Matched, path is cleaned.  */
	      break;
	    }
	}
    }

  /* Swap \ to / */
  for (wchar_t *p = path; *p; p++)
    if (*p == '\\')
      *p = '/';

  return path;
}



char *
__wrap__fullpath(char *_FullPath, const char *_Path, size_t _SizeInBytes)
{
  wchar_t *wpath = handle_long_path_utf8 (_Path);
  wchar_t *buf = (wchar_t *)calloc (_SizeInBytes, sizeof (wchar_t));
  char *ptr = NULL;
  wchar_t *wptr = NULL;

  if (wpath == NULL || buf == NULL)
    {
      SAFE_FREE(wpath);
      SAFE_FREE(buf);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return NULL;
    }

  wptr = _wfullpath(buf, wpath, _SizeInBytes);
  if (wptr)
    {
      ptr = wchar_to_utf8(wptr);

      SAFE_FREE(buf);
      SAFE_FREE(wpath);

      if (_FullPath)
	{
	  /* Copy the result to the output buffer.  */
	  size_t len = strlen (ptr);
	  if (len < _SizeInBytes)
	    {
	      /* Fits within provided buffer.  */
	      memcpy (_FullPath, ptr, len);
	      _FullPath[len] = '\0';
	      SAFE_FREE(ptr);
	      return _FullPath;
	    }
	  else
	    {
	      /* Provided buffer is too small.  */
	      _FullPath[0] = '\0';
	      SAFE_FREE(ptr);
	      SetLastError (ERROR_FILENAME_EXCED_RANGE);
	      return NULL;
	    }
	}
      else
	{
	  /* Allocate new buffer.  */
	  return ptr;
	}
    }

  /* Failed to get path.  */
  DWORD err = GetLastError ();
  SAFE_FREE(buf);
  SAFE_FREE(wpath);
  SetLastError (err);
  return NULL;
}


static int
internal_open(wchar_t const *pathname, int flags, int mode)
{
  HANDLE handle;
  int fd;
  DWORD create = (flags & O_CREAT) ? OPEN_ALWAYS : OPEN_EXISTING;

  if ((flags & O_APPEND) != O_APPEND)
    return __real__wopen(pathname, flags, mode);

  if ((flags & ~O_CREAT) != (O_WRONLY | O_APPEND))
    {
      errno = ENOSYS;
      return -1;
    }

  handle = CreateFileW (pathname, FILE_APPEND_DATA,
			FILE_SHARE_WRITE | FILE_SHARE_READ,
			NULL, create, FILE_ATTRIBUTE_NORMAL, NULL);
  if (handle == INVALID_HANDLE_VALUE)
    {
      errno = to_errno (GetLastError ());
      return -1;
    }

  fd = _open_osfhandle ((intptr_t) handle, O_BINARY);
  if (fd < 0)
    CloseHandle (handle);

  return fd;
}

int
__wrap__wopen (const wchar_t *pathname, int flags, ...)
{
  va_list args;
  int mode;
  int fd;
  wchar_t *wpathname = NULL;

  va_start(args, flags);
  mode = va_arg(args, int);
  va_end(args);

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  fd = internal_open (wpathname, flags, mode);
  if (fd < 0)
    {
      if ((flags & O_ACCMODE) != O_RDONLY && errno == EACCES)
	{
	  DWORD attrs = __real_GetFileAttributesW (pathname);
	  if (attrs != INVALID_FILE_ATTRIBUTES
	      && (attrs & FILE_ATTRIBUTE_DIRECTORY))
	    errno = EISDIR;
	}

      if ((flags & O_CREAT) && errno == EACCES)
	fd = internal_open (wpathname, flags & ~O_CREAT, mode);
    }

  SAFE_FREE(wpathname);
  return fd;
}


int
__wrap_open (const char *pathname, int flags, ...)
{
  va_list args;
  int mode;
  int fd;
  wchar_t *wpathname = NULL;

  va_start(args, flags);
  mode = va_arg(args, int);
  va_end(args);

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  fd = internal_open (wpathname, flags, mode);
  if (fd < 0)
    {
      if ((flags & O_ACCMODE) != O_RDONLY && errno == EACCES)
	{
	  DWORD attrs = __real_GetFileAttributesW (wpathname);
	  if (attrs != INVALID_FILE_ATTRIBUTES
	      && (attrs & FILE_ATTRIBUTE_DIRECTORY))
	    errno = EISDIR;
	}

      if ((flags & O_CREAT) && errno == EACCES)
	fd = internal_open (wpathname, flags & ~O_CREAT, mode);
    }

  SAFE_FREE(wpathname);
  return fd;
}

int
__wrap__open (const char *pathname, int flags, ...)
{
  va_list args;
  int mode;

  va_start(args, flags);
  mode = va_arg(args, int);
  va_end(args);

  return __wrap_open(pathname, flags, mode);
}


static inline int
internal_sopen (wchar_t *pathname, int openFlag, int shareFlag, int mode)
{
  int ret = __real__wsopen (pathname, openFlag, shareFlag, mode);
  SAFE_FREE(pathname);
  return ret;
}

int
__wrap_sopen(const char *pathname, int openFlag, int shareFlag, ...)
{
  va_list args;
  int mode;
  wchar_t *wpathname = NULL;

  va_start(args, shareFlag);
  mode = va_arg(args, int);
  va_end(args);

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_sopen (wpathname, openFlag, shareFlag, mode);
}

int
__wrap__sopen(const char *pathname, int openFlag,  int shareFlag, ...)
{
  va_list args;
  int mode;
  wchar_t *wpathname = NULL;

  va_start(args, shareFlag);
  mode = va_arg(args, int);
  va_end(args);

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_sopen (wpathname, openFlag, shareFlag, mode);
}

int
__wrap__wsopen(const wchar_t *pathname, int openFlag, int shareFlag, ...)
{
  va_list args;
  int mode;
  wchar_t *wpathname = NULL;

  va_start(args, shareFlag);
  mode = va_arg(args, int);
  va_end(args);

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_sopen (wpathname, openFlag, shareFlag, mode);
}


static inline errno_t
internal_sopen_s (int *fd, wchar_t *pathname, int openFlag, int shareFlag, int mode)
{
  errno_t ret = __real__wsopen_s (fd, pathname, openFlag, shareFlag, mode);
  SAFE_FREE(pathname);
  return ret;
}

errno_t
__wrap__sopen_s(int *fd, const char *pathname, int openFlag, int shareFlag, int mode)
{
  wchar_t *wpathname = NULL;

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_sopen_s (fd, wpathname, openFlag, shareFlag, mode);
}
errno_t
__wrap__wsopen_s(int *fd, const wchar_t *pathname, int openFlag, int shareFlag, int mode)
{
  wchar_t *wpathname = NULL;

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_sopen_s (fd, wpathname, openFlag, shareFlag, mode);
}


static inline FILE *
internal_fopen(wchar_t *pathname, wchar_t *mode)
{
  FILE *file = __real__wfopen (pathname, mode);
  DWORD err = GetLastError ();
#ifdef ENABLE_SYMLINK_SUPPORT
  if (!file && err == ERROR_CANT_ACCESS_FILE)
    {
      HANDLE handle;
      handle = CreateFileW (
	  pathname, 0,
	  FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
	  NULL,
	  OPEN_EXISTING,
	  FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
      if (handle != INVALID_HANDLE_VALUE)
        {
	  int fd = _open_osfhandle((intptr_t)handle, _O_ACCMODE);
	  if (fd != -1)
	    {
	      file = _wfdopen (fd, mode);
	      if (file)
		{
		  SAFE_FREE(pathname);
		  SAFE_FREE(mode);
		  return file;
		}
	    }
	}

      CloseHandle (handle);
    }
#endif

  SAFE_FREE(pathname);
  SAFE_FREE(mode);
  if (!file && err == ERROR_INVALID_NAME)
    errno = ENOENT;
  return file;
}

FILE *
__wrap_fopen (const char *pathname, const char *mode)
{
  wchar_t *wpathname, *wmode;

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  wmode = utf8_to_wchar (mode);
  if (wpathname == NULL || wmode == NULL)
    {
      SAFE_FREE(wpathname);
      SAFE_FREE(wmode);
      return NULL;
    }
  return internal_fopen (wpathname, wmode);
}


FILE *
__wrap__wfopen (const wchar_t *pathname, const wchar_t *mode)
{
  wchar_t *wpathname, *wmode;

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  wmode = wcsdup(mode);
  if (wpathname == NULL || wmode == NULL)
    {
      SAFE_FREE(wpathname);
      SAFE_FREE(wmode);
      return NULL;
    }

  return internal_fopen (wpathname, wmode);
}

FILE *
__wrap_fopen64 (const char *pathname, const char *mode)
{
  wchar_t *wpathname, *wmode;

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  wmode = utf8_to_wchar (mode);
  if (wpathname == NULL || wmode == NULL)
    {
      SAFE_FREE(wpathname);
      SAFE_FREE(wmode);
      return NULL;
    }

  return internal_fopen (wpathname, wmode);
}



FILE *
__wrap_freopen (const char *pathname, const char *mode, FILE *stream)
{
  FILE *file;
  wchar_t *wpathname, *wmode;

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  wmode = utf8_to_wchar (mode);
  if (wpathname == NULL || wmode == NULL)
    {
      SAFE_FREE(wpathname);
      SAFE_FREE(wmode);
      return NULL;
    }

  file = __real__wfreopen (wpathname, wmode, stream);

  SAFE_FREE(wpathname);
  SAFE_FREE(wmode);
  return file;
}

FILE *
__wrap__wfreopen (const wchar_t *pathname, const wchar_t *mode, FILE *stream)
{
  FILE *file;
  wchar_t *wpathname;

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    {
      SAFE_FREE(wpathname);
      return NULL;
    }

  file = __real__wfreopen (wpathname, mode, stream);

  SAFE_FREE(wpathname);
  return file;
}

errno_t
__wrap_freopen_s (FILE **fp, const char *pathname, const char *mode, FILE *stream)
{
  errno_t ret;
  wchar_t *wpathname, *wmode;

  if (pathname && strcmp (pathname, "/dev/null") == 0)
    pathname = "nul";

  wpathname = handle_long_path_utf8 (pathname);
  wmode = utf8_to_wchar (mode);
  if (wpathname == NULL || wmode == NULL)
    {
      SAFE_FREE(wpathname);
      SAFE_FREE(wmode);
      return errno;
    }

  ret = __real__wfreopen_s (fp, wpathname, wmode, stream);

  SAFE_FREE(wpathname);
  SAFE_FREE(wmode);
  return ret;
}

errno_t
__wrap__wfreopen_s (FILE **fp, const wchar_t *pathname, const wchar_t *mode, FILE *stream)
{
  errno_t ret;
  wchar_t *wpathname;

  if (pathname && wcscmp (pathname, L"/dev/null") == 0)
    pathname = L"nul";

  wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    {
      SAFE_FREE(wpathname);
      return errno;
    }

  ret = __real__wfreopen_s (fp, wpathname, mode, stream);

  SAFE_FREE(wpathname);
  return ret;
}

int
__wrap_fflush(FILE *stream)
{
  int ret = __real_fflush (stream);

  if (ret && errno == EINVAL)
    {
      HANDLE h = (HANDLE) _get_osfhandle ((intptr_t) _fileno (stream));
      if (GetFileType (h) == FILE_TYPE_PIPE)
	errno = EPIPE;
    }

  return ret;
}

int
__wrap_write(int fd, const void *buf, size_t count)
{
  int res = __real_write (fd, buf, count);

  if (res < 0 && buf && errno == EINVAL)
    {
      HANDLE h = (HANDLE) _get_osfhandle (fd);
      if (GetFileType (h) == FILE_TYPE_PIPE)
	errno = EPIPE;
    }

  return res;
}



static inline int
internal_access(wchar_t *pathname, int mode)
{
  int ret = __real__waccess (pathname, mode & ~X_OK);
  SAFE_FREE (pathname);
  return ret;
}

int
__wrap_access(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_access (wpathname, mode);
}

int
__wrap__access(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_access (wpathname, mode);
}

int
__wrap__waccess(const wchar_t *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_access (wpathname, mode);
}



static inline errno_t
internal_access_s(wchar_t *pathname, int mode)
{
  int ret = __real__waccess_s (pathname, mode & ~X_OK);
  SAFE_FREE (pathname);
  return ret;
}

errno_t
__wrap__access_s(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_access_s (wpathname, mode);
}

errno_t
__wrap__waccess_s (const wchar_t *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_access_s (wpathname, mode);
}



static inline int
internal_creat(wchar_t *pathname, int mode)
{
  int ret = __real__wcreat (pathname, mode);
  SAFE_FREE (pathname);
  return ret;
}

int
__wrap_creat(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_creat (wpathname, mode);
}

int
__wrap__creat(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_creat (wpathname, mode);
}

int
__wrap__wcreat(const wchar_t *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_creat (wpathname, mode);
}





static inline int
internal_chmod(wchar_t *pathname, int mode)
{
  int ret = __real__wchmod (pathname, mode);
  SAFE_FREE (pathname);
  return ret;
}

int
__wrap_chmod(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chmod (wpathname, mode);
}

int
__wrap__chmod(const char *pathname, int mode)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chmod (wpathname, mode);
}

int
__wrap__wchmod(const wchar_t *pathname, int mode)

{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chmod (wpathname, mode);
}







static inline int
internal_unlink(wchar_t *pathname)
{
  if (DeleteFileW (pathname))
    {
      SAFE_FREE (pathname);
      return 0;
    }

  DWORD err = GetLastError ();
  SAFE_FREE(pathname);
  errno = to_errno (err);
  return -1;
}

int
__wrap_remove(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_unlink (wpathname);
}

int
__wrap__wremove(const wchar_t *pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_unlink (wpathname);
}

int
__wrap_unlink(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_unlink (wpathname);
}

int
__wrap__unlink(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_unlink (wpathname);
}

int
__wrap__wunlink(const wchar_t *pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_unlink (wpathname);
}




static inline int
internal_rename (wchar_t *oldname, wchar_t *newname)
{
  int ret = -1;
  if (MoveFileW (oldname, newname))
    ret = 0;

  SAFE_FREE (oldname);
  SAFE_FREE (newname);
  return ret;
}

int
__wrap_rename(const char *oldname, const char *newname)
{
  wchar_t *woldname = handle_long_path_utf8 (oldname);
  wchar_t *wnewname = handle_long_path_utf8 (newname);

  if (woldname == NULL || wnewname == NULL)
    {
      SAFE_FREE(woldname);
      SAFE_FREE(wnewname);
      return -1;
    }

  return internal_rename (woldname, wnewname);
}

int
__wrap__wrename(const wchar_t *oldname, const wchar_t *newname)
{
  wchar_t *woldname = handle_long_path (oldname);
  wchar_t *wnewname = handle_long_path (newname);

  if (woldname == NULL || wnewname == NULL)
    {
      SAFE_FREE(woldname);
      SAFE_FREE(wnewname);
      return -1;
    }

  return internal_rename (woldname, wnewname);
}





static inline int
internal_chdir(wchar_t *pathname)
{
  if (__real_SetCurrentDirectoryW (pathname))
    {
      SAFE_FREE(pathname);
      return 0;
    }

  DWORD err = GetLastError ();
  SAFE_FREE(pathname);
  errno = to_errno (err);
  return -1;
}

int
__wrap_chdir(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chdir (wpathname);
}

int
__wrap__chdir(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chdir (wpathname);
}

int
__wrap__wchdir(const wchar_t *pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chdir (wpathname);
}

WINBOOL WINAPI
__wrap_SetCurrentDirectoryA (LPCSTR pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chdir (wpathname) == 0;
}

WINBOOL WINAPI
__wrap_SetCurrentDirectoryW (LPCWSTR pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_chdir (wpathname) == 0;
}



static inline int
internal_mkdir(wchar_t *pathname)
{
  if (__real_CreateDirectoryW (pathname, NULL))
    {
      SAFE_FREE(pathname);
      return 0;
    }

  DWORD err = GetLastError ();
  SAFE_FREE(pathname);
  errno = to_errno (err);
  return -1;
}

int
__wrap_mkdir(const char *pathname, int mode)
{
  (void) mode; /* Unused */
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_mkdir (wpathname);
}

int
__wrap__mkdir(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_mkdir (wpathname);
}

int
__wrap__wmkdir(const wchar_t *pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_mkdir(wpathname);
}




static inline int
internal_rmdir(wchar_t *pathname)
{
  if (__real_RemoveDirectoryW (pathname))
    {
      SAFE_FREE(pathname);
      return 0;
    }

  DWORD err = GetLastError ();
  SAFE_FREE(pathname);
  errno = to_errno (err);
  return -1;
}

int
__wrap_rmdir(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_rmdir (wpathname);
}

int
__wrap__rmdir(const char *pathname)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_rmdir (wpathname);
}

int
__wrap__wrmdir(const wchar_t *pathname)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_rmdir (wpathname);
}






static const uint64_t UNIX_EPOCH_AS_WINDOWS_TIME = 0x019DB1DED53E8000;
static inline time_t
filetime_to_timet(const FILETIME ft)
{
  uint64_t datetime = ((uint64_t) ft.dwHighDateTime << 32) + ft.dwLowDateTime;
  return (time_t) ((datetime - UNIX_EPOCH_AS_WINDOWS_TIME) / 10000000);
}


static inline int
handle_to_fileinfo(HANDLE handle, struct _stat64 *statbuf)
{
  BY_HANDLE_FILE_INFORMATION file_info;
  if (!GetFileInformationByHandle (handle, &file_info))
    {
      errno = to_errno (GetLastError ());
      return -1;
    }

  memset (statbuf, 0, sizeof(struct _stat64));
  statbuf->st_nlink = 1;
  statbuf->st_mode = S_IREAD;
  if (!(file_info.dwFileAttributes & FILE_ATTRIBUTE_READONLY))
    statbuf->st_mode |= S_IWRITE;
  if (file_info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
    statbuf->st_mode |= S_IFDIR;
  else
    statbuf->st_mode |= S_IFREG;
  statbuf->st_size = (__int64) (file_info.nFileSizeLow | (((__int64) file_info.nFileSizeHigh) << 32));
  statbuf->st_atime = filetime_to_timet (file_info.ftLastAccessTime);
  statbuf->st_mtime = filetime_to_timet (file_info.ftLastWriteTime);
  statbuf->st_ctime = filetime_to_timet (file_info.ftCreationTime);
  return 0;
}

static inline int
to_stat(int ret, struct stat *statbuf, struct _stat64 *statbuf64)
{
  memset (statbuf, 0, sizeof(struct stat));
  if (ret >= 0)
    {
      statbuf->st_nlink = statbuf64->st_nlink;
      statbuf->st_mode = statbuf64->st_mode;
      statbuf->st_size = statbuf64->st_size;
      statbuf->st_atime = statbuf64->st_atime;
      statbuf->st_mtime = statbuf64->st_mtime;
      statbuf->st_ctime = statbuf64->st_ctime;
    }
  return ret;
}

static inline int
to_stat32(int ret, struct _stat32 *statbuf, struct _stat64 *statbuf64)
{
  memset (statbuf, 0, sizeof(struct _stat32));
  if (ret >= 0)
    {
      statbuf->st_nlink = statbuf64->st_nlink;
      statbuf->st_mode = statbuf64->st_mode;
      statbuf->st_size = statbuf64->st_size;
      statbuf->st_atime = statbuf64->st_atime;
      statbuf->st_mtime = statbuf64->st_mtime;
      statbuf->st_ctime = statbuf64->st_ctime;
    }
  return ret;
}

static inline int
to_stat32i64(int ret, struct _stat32i64 *statbuf, struct _stat64 *statbuf64)
{
  memset (statbuf, 0, sizeof(struct _stat32i64));
  if (ret >= 0)
    {
      statbuf->st_nlink = statbuf64->st_nlink;
      statbuf->st_mode = statbuf64->st_mode;
      statbuf->st_size = statbuf64->st_size;
      statbuf->st_atime = statbuf64->st_atime;
      statbuf->st_mtime = statbuf64->st_mtime;
      statbuf->st_ctime = statbuf64->st_ctime;
    }
  return ret;
}

static inline int
to_stat64i32(int ret, struct _stat64i32 *statbuf, struct _stat64 *statbuf64)
{
  memset (statbuf, 0, sizeof(struct _stat32i64));
  if (ret >= 0)
    {
      statbuf->st_nlink = statbuf64->st_nlink;
      statbuf->st_mode = statbuf64->st_mode;
      statbuf->st_size = statbuf64->st_size;
      statbuf->st_atime = statbuf64->st_atime;
      statbuf->st_mtime = statbuf64->st_mtime;
      statbuf->st_ctime = statbuf64->st_ctime;
    }
  return ret;
}






static inline int
internal_stat64(wchar_t *pathname, struct _stat64 *statbuf, _Bool follow)
{
  HANDLE handle;
  int result;

  if (_wcsicmp (pathname, L"nul") == 0)
    return __real__wstat64 (pathname, statbuf);

  handle = CreateFileW (pathname, 0,
		     FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
		     NULL,
		     OPEN_EXISTING,
		     FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  if (handle == INVALID_HANDLE_VALUE)
    {
      DWORD err = GetLastError ();
      SAFE_FREE(pathname);
      errno = to_errno (err);
      return -1;
    }

#ifdef ENABLE_SYMLINK_SUPPORT
  if (follow)
    {
      FILE_ATTRIBUTE_TAG_INFO tag_info;
      if (!GetFileInformationByHandleEx(handle, FileAttributeTagInfo, &tag_info, sizeof(tag_info)))
        {
          DWORD err = GetLastError ();
          SAFE_FREE(pathname);
          errno = to_errno (err);
          return -1;
        }

      if ((tag_info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) && tag_info.ReparseTag == IO_REPARSE_TAG_LX_SYMLINK)
	{
	  PREPARSE_DATA_BUFFER buffer = (PREPARSE_DATA_BUFFER) malloc(MAXIMUM_REPARSE_DATA_BUFFER_SIZE);
	  DWORD dummy;

	  if (buffer == NULL)
	    {
	      SAFE_FREE(pathname);
	      errno = ENOMEM;
	      return -1;
	    }


	  if (!DeviceIoControl (handle, FSCTL_GET_REPARSE_POINT, NULL, 0, buffer,
			    MAXIMUM_REPARSE_DATA_BUFFER_SIZE,
			    &dummy, NULL))
	    {
	      DWORD err = GetLastError ();
	      CloseHandle (handle);
	      SAFE_FREE(buffer);
	      SAFE_FREE(pathname);
	      errno = to_errno (err);
	      return -1;
	    }
	  CloseHandle (handle);

	  int len = buffer->ReparseDataLength - sizeof (DWORD); /* Filetype */
	  char *ptr = calloc (len + 1, sizeof (char));
	  if (ptr == NULL)
	    {
	      SAFE_FREE(buffer);
	      errno = ENOMEM;
	      return -1;
	    }

	  memcpy (ptr, (const char *)buffer->GenericReparseBuffer.DataBuffer + sizeof (DWORD), len);
	  ptr[len] = '\0';
	  SAFE_FREE(buffer);

	  if (ptr[0] == '\\' || ptr[0] == '/')
	    {
	      /* Path is absolute.  */
	      wchar_t *wpath = handle_long_path_utf8 (ptr);
	      SAFE_FREE(ptr);
	      SAFE_FREE(pathname);
	      return internal_stat64 (wpath, statbuf, follow);
	    }
	  else
	    {
	      /* Path is relative.  */
	      if (internal_update_cwd_cache() < 0)
		{
		  SAFE_FREE(ptr);
		  SAFE_FREE(pathname);
		  return -1;
		}

	      /* Preserve cwd so we can restore it.  */
	      wchar_t *previous_cwd = wcsdup (_long_path_name.cwd);

	      wchar_t *wptr = handle_long_path_utf8 (ptr);
	      SAFE_FREE(ptr);
	      if (wptr == NULL)
		{
		  SAFE_FREE(pathname);
		  SAFE_FREE(previous_cwd);
		  errno = ENOMEM;
		  return -1;
		}

	      /* Find the dirname of the path and terminate the string.  */
	      for (int i = wcslen(pathname); i >= 0; i--)
		{
		  if (pathname[i] == '\\' || pathname[i] == '/')
		    {
		      pathname[i] = '\0';
		      break;
		    }
		}
	      _wchdir (pathname);
	      SAFE_FREE(pathname);

	      wchar_t *wpath = _wfullpath (NULL, wptr, MAX_LONG_PATH);
	      SAFE_FREE(wptr);

	      /* Restore previous cwd.  */
	      _wchdir (previous_cwd);
	      SAFE_FREE(previous_cwd);

	      if (wpath == NULL)
		{
		  errno = ENOMEM;
		  return -1;
		}

	      /* Stat what the symlink pointed at.  */
	      return internal_stat64 (wpath, statbuf, follow);
	    }
	}
    }
#else
  (void)follow;
#endif
  SAFE_FREE(pathname);

  result = handle_to_fileinfo (handle, statbuf);
  CloseHandle (handle);
  return result;
}

int
__wrap__stat64(const char *pathname, struct _stat64 *statbuf)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_stat64 (wpathname, statbuf, TRUE);
}

int
__wrap__wstat64(const wchar_t *pathname, struct _stat64 *statbuf)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_stat64 (wpathname, statbuf, TRUE);
}





static inline int
internal_lstat(wchar_t *pathname, struct stat *statbuf)
{
  int ret;
  struct _stat64 st;

  ret = internal_stat64 (pathname, &st, FALSE);
  pathname = NULL; /* freed in internal_stat64 */
  if (ret == -1)
    {
      memset (statbuf, 0, sizeof(struct stat));
      return -1;
    }

  return to_stat (ret, statbuf, &st);
}

int
__wrap_lstat(const char *pathname, struct stat *statbuf)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal_lstat(wpathname, statbuf);
}

int
__wrap_stat(const char *pathname, struct stat *statbuf)
{
  int ret;
  struct _stat64 st;
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    {
      memset (statbuf, 0, sizeof(struct stat));
      return -1;
    }

  ret = internal_stat64 (wpathname, &st, TRUE);
  wpathname = NULL; /* freed in internal_stat64 */
  return to_stat (ret, statbuf, &st);
}

int
__wrap_wstat(const wchar_t *pathname, struct stat *statbuf)
{
  int ret;
  struct _stat64 st;
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    {
      memset (statbuf, 0, sizeof(struct stat));
      return -1;
    }
  ret = internal_stat64 (wpathname, &st, TRUE);
  wpathname = NULL; /* freed in internal_stat64 */
  return to_stat (ret, statbuf, &st);
}


static inline int
internal__stat64i32(wchar_t *pathname, struct _stat64i32 *statbuf)
{
  int ret;
  struct _stat64 st;

  ret = internal_stat64 (pathname, &st, TRUE);
  pathname = NULL; /* freed in internal_stat64 */
  if (ret == -1)
    {
      memset (statbuf, 0, sizeof(struct _stat64i32));
      return -1;
    }

  return to_stat64i32 (ret, statbuf, &st);
}

int
__wrap__stat64i32(const char *pathname, struct _stat64i32 *statbuf)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat64i32 (wpathname, statbuf);
}

int
__wrap__wstat64i32(const wchar_t *pathname, struct _stat64i32 *statbuf)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat64i32 (wpathname, statbuf);
}



static inline int
internal__stat32(wchar_t *pathname, struct _stat32 *statbuf)
{
  int ret;
  struct _stat64 st;

  ret = internal_stat64 (pathname, &st, TRUE);
  pathname = NULL; /* freed in internal_stat64 */
  if (ret == -1)
    {
      memset (statbuf, 0, sizeof(struct _stat32));
      return -1;
    }

  return to_stat32 (ret, statbuf, &st);
}

int
__wrap__stat32(const char *pathname, struct _stat32 *statbuf)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat32 (wpathname, statbuf);
}

int
__wrap__wstat32(const wchar_t *pathname, struct _stat32 *statbuf)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat32 (wpathname, statbuf);
}



static inline int
internal__stat32i64(wchar_t *pathname, struct _stat32i64 *statbuf)
{
  int ret;
  struct _stat64 st;

  ret = internal_stat64 (pathname, &st, TRUE);
  pathname = NULL; /* freed in internal_stat64 */
  if (ret == -1)
    {
      memset (statbuf, 0, sizeof(struct _stat32i64));
      return -1;
    }

  return to_stat32i64 (ret, statbuf, &st);
}

int
__wrap__stat32i64(const char *pathname, struct _stat32i64 *statbuf)
{
  wchar_t *wpathname = handle_long_path_utf8 (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat32i64 (wpathname, statbuf);
}

int
__wrap__wstat32i64(const wchar_t *pathname, struct _stat32i64 *statbuf)
{
  wchar_t *wpathname = handle_long_path (pathname);
  if (wpathname == NULL)
    return -1;

  return internal__stat32i64 (wpathname, statbuf);
}



static inline int
internal__fstat64(int fd, struct _stat64 *statbuf)
{
  HANDLE fh = (HANDLE) _get_osfhandle (fd);
  DWORD type = GetFileType (fh) & ~FILE_TYPE_REMOTE;

  if (type == FILE_TYPE_DISK)
    return handle_to_fileinfo (fh, statbuf);
  else if (type == FILE_TYPE_CHAR)
    {
      memset (statbuf, 0, sizeof(struct _stat64));
      statbuf->st_nlink = 1;
      statbuf->st_mode = _S_IFCHR;
      return 0;
    }
  else if (type == FILE_TYPE_PIPE)
    {
      DWORD avail;
      memset (statbuf, 0, sizeof(struct _stat64));
      statbuf->st_nlink = 1;
      statbuf->st_mode = _S_IFIFO;
      if (PeekNamedPipe (fh, NULL, 0, NULL, &avail, NULL))
	statbuf->st_size = avail;
      return 0;
    }
  else
    {
      errno = EBADF;
      return -1;
    }
}

int
__wrap__fstat64(int fd, struct _stat64 *statbuf)
{
  return internal__fstat64 (fd, statbuf);
}

int
__wrap__fstat32(int fd, struct _stat32 *statbuf)
{
  struct _stat64 st;
  int ret = internal__fstat64 (fd, &st);
  return to_stat32 (ret, statbuf, &st);
}

int
__wrap__fstat32i64(int fd, struct _stat32i64 *statbuf)
{
  struct _stat64 st;
  int ret = internal__fstat64 (fd, &st);
  return to_stat32i64 (ret, statbuf, &st);
}

int
__wrap__fstat64i32(int fd, struct _stat64i32 *statbuf)
{
  struct _stat64 st;
  int ret = internal__fstat64 (fd, &st);
  return to_stat64i32 (ret, statbuf, &st);
}

static wchar_t *internal_realpath_1 (const wchar_t *);
static wchar_t *internal_realpath_2 (const wchar_t *);
static wchar_t *internal_realpath_3 (const wchar_t *);

static wchar_t *
internal_realpath (const wchar_t *path)
{
  LP_DEBUG("%s:%d; %S\n", __func__, __LINE__, path);
  return internal_realpath_1 (path);
}

static wchar_t *
internal_realpath_1 (const wchar_t *path)
{
  DWORD dest_len = GetLongPathNameW (path, NULL, 0);
  if (dest_len == 0)
    {
      int error = GetLastError ();
      LP_DEBUG("%s:%d; %S -> %d\n", __func__, __LINE__, path, error);
      switch (error)
	{
	case ERROR_FILE_NOT_FOUND:
	case ERROR_PATH_NOT_FOUND:
	case ERROR_ACCESS_DENIED:
	  return internal_realpath_2 (path);
	default:
	  errno = ENOMEM;
	  return NULL;
	}
    }

  wchar_t *buf = (wchar_t *)malloc ((dest_len + 1) * sizeof(wchar_t));
  if (buf == NULL)
    {
      errno = ENOMEM;
      return NULL;
    }
  GetLongPathNameW (path, buf, dest_len);
  buf[dest_len] = L'\0';
  LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf);
  return buf;
}

static wchar_t *
internal_realpath_2 (const wchar_t *path)
{
  HANDLE hnd = __real_CreateFileW (path, 0,
				   FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
				   NULL,
				   OPEN_EXISTING,
				   FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (hnd == INVALID_HANDLE_VALUE)
    {
      LP_DEBUG("%s:%d; %S -> INVALID_HANDLE_VALUE\n", __func__, __LINE__, path);
      return internal_realpath_3 (path);
    }

  DWORD dest_len = GetFinalPathNameByHandleW (hnd, NULL, 0, 0);
  if (dest_len == 0)
    {
      LP_DEBUG("%s:%d; %S -> %d\n", __func__, __LINE__, path, (int)GetLastError ());
      CloseHandle (hnd);
      return internal_realpath_3 (path);
    }

  wchar_t *buf = (wchar_t *)malloc ((dest_len + 1) * sizeof(wchar_t));
  if (buf == NULL)
    {
      errno = ENOMEM;
      return NULL;
    }
  GetFinalPathNameByHandleW (hnd, buf, dest_len, 0);
  buf[dest_len] = L'\0';
  CloseHandle (hnd);
  LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf);
  return buf;
}

static wchar_t *
internal_realpath_3 (const wchar_t *path)
{
  DWORD dest_len;
  dest_len = GetFullPathNameW (path, 0, NULL, NULL);
  if (dest_len == 0)
    {
      int error = GetLastError ();
      LP_DEBUG("%s:%d; %S -> %s\n", __func__, __LINE__, path, "(null)");
      errno = to_errno (error);
      return NULL;
    }

  wchar_t *buf = (wchar_t *)malloc ((dest_len + 1) * sizeof(wchar_t));
  if (buf == NULL)
    {
      errno = ENOMEM;
      return NULL;
    }
  GetFullPathNameW (path, dest_len, buf, NULL);
  buf[dest_len] = L'\0';
  LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf);
  return buf;
}

static int
internal_update_cwd_cache(void)
{
  wchar_t *cwd = NULL;
  DWORD ret = __real_GetCurrentDirectoryW(0, NULL);
  if (ret == 0)
    {
      errno = to_errno (GetLastError ());
      return -1;
    }

  cwd = (wchar_t *)malloc((ret + 1) * sizeof(wchar_t));
  if (cwd == NULL)
    {
      errno = ENOMEM;
      return -1;
    }

  ret = __real_GetCurrentDirectoryW (ret, cwd);

  /*
   * BZ#80181 - GetLongPathNameW is a fairly slow operation and is called very often.
   * Remember the input and output for the last call, and if the input doesn't change,
   * re-use the latest output.
   */
  if (_long_path_name.cwd == NULL || wcscmp (_long_path_name.cwd, cwd) != 0)
    {
      /* Free old state.  */
      SAFE_FREE(_long_path_name.cwd);
      SAFE_FREE(_long_path_name.long_cwd);

      wchar_t *long_cwd = internal_realpath (cwd);
      if (long_cwd == NULL)
	{
	  int tmp = errno;
	  SAFE_FREE(cwd);
	  errno = tmp;
	  return -1;
	}

      wchar_t *ptr = to_unix_like_path (long_cwd);
      char *buf = wchar_to_utf8 (ptr);
      if (!buf)
	{
	  /* errno already set.  */
	  int tmp = errno;
	  SAFE_FREE(cwd);
	  SAFE_FREE(long_cwd);
	  errno = tmp;
	  return -1;
	}

      /* Success, save values for consecutive calls.  */
      _long_path_name.cwd = _wcsdup(cwd);
      _long_path_name.long_cwd = wcsdup(ptr);
      _long_path_name.long_cwd_len = wcslen(ptr);
      _long_path_name.long_cwd_utf8 = buf;
      _long_path_name.long_cwd_utf8_len = strlen(buf);

      SAFE_FREE(long_cwd);
    }

  SAFE_FREE(cwd);
  return 0;
}


static inline char *
internal_getcwd(char *buffer, int maxlen)
{
  if (internal_update_cwd_cache() < 0)
    return NULL;

  if (_long_path_name.long_cwd_utf8_len >= (size_t)maxlen)
    {
      /* Buffer too small.  */
      errno = ERANGE;
      return NULL;
    }

  *buffer = 0;
  strncat(buffer, _long_path_name.long_cwd_utf8, _long_path_name.long_cwd_utf8_len);

  return buffer;
}

static inline wchar_t *
internal_wgetcwd(wchar_t *buffer, int maxlen)
{
  if (internal_update_cwd_cache() < 0)
    return NULL;

  if (_long_path_name.long_cwd_len >= (size_t)maxlen)
    {
      /* Buffer too small.  */
      errno = ERANGE;
      return NULL;
    }

  *buffer = 0;
  wcsncat(buffer, _long_path_name.long_cwd, _long_path_name.long_cwd_len);

  return buffer;
}

char *
__wrap_getcwd(char *buffer, int maxlen)
{
  return internal_getcwd (buffer, maxlen);
}

char *
__wrap__getcwd(char *buffer, int maxlen)
{
  return internal_getcwd (buffer, maxlen);
}

wchar_t *
__wrap__wgetcwd(wchar_t *buffer, int maxlen)
{
  return internal_wgetcwd (buffer, maxlen);
}

DWORD WINAPI
__wrap_GetCurrentDirectoryA (DWORD nBufferLength, LPSTR lpBuffer)
{
  return internal_getcwd (lpBuffer, nBufferLength) != NULL;
}

DWORD WINAPI
__wrap_GetCurrentDirectoryW (DWORD nBufferLength, LPWSTR lpBuffer)
{
  return internal_wgetcwd (lpBuffer, nBufferLength) != NULL;
}









static inline DWORD
internal_GetFileAttributes(wchar_t *pathname)
{
  DWORD ret = __real_GetFileAttributesW (pathname);
  SAFE_FREE(pathname);
  return ret;
}

DWORD WINAPI
__wrap_GetFileAttributesA (LPCSTR lpFileName)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (INVALID_FILE_ATTRIBUTES);
      return FALSE;
    }

  return internal_GetFileAttributes (wpathname);
}

DWORD WINAPI
__wrap_GetFileAttributesW (LPCWSTR lpFileName)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (INVALID_FILE_ATTRIBUTES);
      return FALSE;
    }

  return internal_GetFileAttributes (wpathname);
}




static inline WINBOOL
internal_GetFileAttributesEx(wchar_t *pathname, GET_FILEEX_INFO_LEVELS fInfoLevelId, LPVOID lpFileInformation)
{
  WINBOOL ret = __real_GetFileAttributesExW (pathname, fInfoLevelId, lpFileInformation);
  SAFE_FREE(pathname);
  return ret;
}

WINBOOL WINAPI
__wrap_GetFileAttributesExA (LPCSTR lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, LPVOID lpFileInformation)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_GetFileAttributesEx (wpathname, fInfoLevelId, lpFileInformation);
}

WINBOOL WINAPI
__wrap_GetFileAttributesExW (LPCWSTR lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, LPVOID lpFileInformation)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_GetFileAttributesEx (wpathname, fInfoLevelId, lpFileInformation);
}


static inline WINBOOL
internal_CreateDirectory(wchar_t *pathname, LPSECURITY_ATTRIBUTES fInfoLevelId)
{
  WINBOOL ret = __real_CreateDirectoryW (pathname, fInfoLevelId);
  SAFE_FREE(pathname);
  return ret;
}

WINBOOL WINAPI
__wrap_CreateDirectoryA (LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpPathName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_CreateDirectory (wpathname, lpSecurityAttributes);
}

WINBOOL WINAPI
__wrap_CreateDirectoryW (LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes)
{
  wchar_t *wpathname = handle_long_path (lpPathName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_CreateDirectory (wpathname, lpSecurityAttributes);
}


static inline WINBOOL
internal_DeleteFile(wchar_t *pathname)
{
  WINBOOL ret = __real_DeleteFileW (pathname);
  SAFE_FREE(pathname);
  return ret;
}

WINBOOL WINAPI
__wrap_DeleteFileA (LPCSTR lpFileName)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_DeleteFile (wpathname);
}

WINBOOL WINAPI
__wrap_DeleteFileW (LPCWSTR lpFileName)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_DeleteFile (wpathname);
}


static inline WINBOOL
internal_RemoveDirectory(wchar_t *pathname)
{
  WINBOOL ret = __real_RemoveDirectoryW (pathname);
  SAFE_FREE(pathname);
  return ret;
}

WINBOOL WINAPI
__wrap_RemoveDirectoryA (LPCSTR lpPathName)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpPathName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_RemoveDirectory (wpathname);
}

WINBOOL WINAPI
__wrap_RemoveDirectoryW (LPCWSTR lpPathName)
{
  wchar_t *wpathname = handle_long_path (lpPathName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_RemoveDirectory (wpathname);
}


static inline WINBOOL
internal_SetFileAttributes(wchar_t *pathname, DWORD dwFileAttributes)
{
  WINBOOL ret = __real_SetFileAttributesW (pathname, dwFileAttributes);
  SAFE_FREE(pathname);
  return ret;
}

WINBOOL WINAPI
__wrap_SetFileAttributesA (LPCSTR lpFileName, DWORD dwFileAttributes)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_SetFileAttributes (wpathname, dwFileAttributes);
}

WINBOOL WINAPI
__wrap_SetFileAttributesW (LPCWSTR lpFileName, DWORD dwFileAttributes)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_SetFileAttributes (wpathname, dwFileAttributes);
}


static inline HANDLE
internal_CreateFile (wchar_t *pathname, DWORD dwDesiredAccess,
			    DWORD dwShareMode,
			    LPSECURITY_ATTRIBUTES lpSecurityAttributes,
			    DWORD dwCreationDisposition,
			    DWORD dwFlagsAndAttributes, HANDLE hTemplateFile)
{
  HANDLE ret = __real_CreateFileW (pathname, dwDesiredAccess, dwShareMode,
				   lpSecurityAttributes, dwCreationDisposition,
				   dwFlagsAndAttributes, hTemplateFile);
  SAFE_FREE(pathname);
  return ret;
}

HANDLE WINAPI
__wrap_CreateFileA (LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
		    LPSECURITY_ATTRIBUTES lpSecurityAttributes,
		    DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes,
		    HANDLE hTemplateFile)
{
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }

  return internal_CreateFile (wpathname, dwDesiredAccess, dwShareMode,
			      lpSecurityAttributes, dwCreationDisposition,
			      dwFlagsAndAttributes, hTemplateFile);
}

HANDLE WINAPI
__wrap_CreateFileW (LPCWSTR lpFileName, DWORD dwDesiredAccess,
		    DWORD dwShareMode,
		    LPSECURITY_ATTRIBUTES lpSecurityAttributes,
		    DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes,
		    HANDLE hTemplateFile)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }

  return internal_CreateFile (wpathname, dwDesiredAccess, dwShareMode,
			      lpSecurityAttributes, dwCreationDisposition,
			      dwFlagsAndAttributes, hTemplateFile);
}



static inline HANDLE
WIN32_FIND_DATAW_to_WIN32_FIND_DATAA (HANDLE handle, LPWIN32_FIND_DATAW src, LPWIN32_FIND_DATAA dest)
{
  char *p = NULL;

  dest->dwFileAttributes = src->dwFileAttributes;
  dest->ftCreationTime = src->ftCreationTime;
  dest->ftLastAccessTime = src->ftLastAccessTime;
  dest->ftLastWriteTime = src->ftLastWriteTime;
  dest->nFileSizeHigh = src->nFileSizeHigh;
  dest->nFileSizeLow = src->nFileSizeLow;
  dest->dwReserved0 = src->dwReserved0;
  dest->dwReserved1 = src->dwReserved1;

  p = wchar_to_utf8 (src->cFileName);
  if (p == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }
  strncpy (dest->cFileName, p, sizeof(dest->cFileName));
  SAFE_FREE(p);

  p = wchar_to_utf8 (src->cAlternateFileName);
  if (p == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }
  strncpy (dest->cAlternateFileName, p, sizeof(dest->cAlternateFileName));
  SAFE_FREE(p);

  return handle;
}


static inline HANDLE
internal_FindFirstFile (wchar_t *pathname, LPWIN32_FIND_DATAW data)
{
  HANDLE ret = __real_FindFirstFileW(pathname, data);
  SAFE_FREE(pathname);
  return ret;
}

HANDLE WINAPI
__wrap_FindFirstFileA (LPCSTR lpFileName, LPWIN32_FIND_DATAA lpFindFileData)
{
  WIN32_FIND_DATAW data;
  wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }

  return WIN32_FIND_DATAW_to_WIN32_FIND_DATAA (
      internal_FindFirstFile (wpathname, &data), &data, lpFindFileData);
}

HANDLE WINAPI
__wrap_FindFirstFileW (LPCWSTR lpFileName, LPWIN32_FIND_DATAW lpFindFileData)
{
  wchar_t *wpathname = handle_long_path (lpFileName);
  if (wpathname == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return INVALID_HANDLE_VALUE;
    }

  return internal_FindFirstFile (wpathname, lpFindFileData);
}


static inline HANDLE
internal_FindFirstFileEx (wchar_t *pathname, FINDEX_INFO_LEVELS fInfoLevelId,
			  LPWIN32_FIND_DATAW lpFindFileData,
			  FINDEX_SEARCH_OPS fSearchOp, LPVOID lpSearchFilter,
			  DWORD dwAdditionalFlags)
{
  HANDLE ret = __real_FindFirstFileExW (pathname, fInfoLevelId, lpFindFileData,
					fSearchOp, lpSearchFilter,
					dwAdditionalFlags);
  SAFE_FREE(pathname);
  return ret;
}

HANDLE WINAPI
__wrap_FindFirstFileExA (LPCSTR lpFileName, FINDEX_INFO_LEVELS fInfoLevelId,
			 LPVOID lpFindFileData, FINDEX_SEARCH_OPS fSearchOp,
			 LPVOID lpSearchFilter, DWORD dwAdditionalFlags)
{
  switch (fInfoLevelId)
    {
    case FindExInfoStandard:
    case FindExInfoBasic:
      {
	WIN32_FIND_DATAW data;
	wchar_t *wpathname = handle_long_path_utf8 (lpFileName);
	if (wpathname == NULL)
	  {
	    SetLastError (ERROR_NOT_ENOUGH_MEMORY);
	    return INVALID_HANDLE_VALUE;
	  }

	return WIN32_FIND_DATAW_to_WIN32_FIND_DATAA (
	    internal_FindFirstFileEx (wpathname, fInfoLevelId, &data, fSearchOp,
				      lpSearchFilter, dwAdditionalFlags),
	    &data, (LPWIN32_FIND_DATAA) lpFindFileData);
      }

    default:
      SetLastError (ERROR_INVALID_DATA);
      return INVALID_HANDLE_VALUE;
    }
}

HANDLE WINAPI
__wrap_FindFirstFileExW (LPCWSTR lpFileName, FINDEX_INFO_LEVELS fInfoLevelId,
			 LPVOID lpFindFileData, FINDEX_SEARCH_OPS fSearchOp,
			 LPVOID lpSearchFilter, DWORD dwAdditionalFlags)
{
  (void)lpFindFileData;
  switch (fInfoLevelId)
    {
    case FindExInfoStandard:
    case FindExInfoBasic:
      {
	WIN32_FIND_DATAW data;
	wchar_t *wpathname = handle_long_path (lpFileName);
	if (wpathname == NULL)
	  {
	    SetLastError (ERROR_NOT_ENOUGH_MEMORY);
	    return INVALID_HANDLE_VALUE;
	  }

	return internal_FindFirstFileEx (wpathname, fInfoLevelId, &data,
					 fSearchOp, lpSearchFilter,
					 dwAdditionalFlags);
      }

    default:
      SetLastError (ERROR_INVALID_DATA);
      return INVALID_HANDLE_VALUE;
    }
}




static inline WINBOOL
internal_DeleteVolumeMountPoint (wchar_t *mountpoint)
{
  WINBOOL ret = __real_DeleteVolumeMountPointW(mountpoint);
  SAFE_FREE(mountpoint);
  return ret;
}

WINBOOL WINAPI
__wrap_DeleteVolumeMountPointA (LPCSTR lpszVolumeMountPoint)
{
  wchar_t *wmountpoint = handle_long_path_utf8 (lpszVolumeMountPoint);
  if (wmountpoint == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_DeleteVolumeMountPoint(wmountpoint);
}

WINBOOL WINAPI
__wrap_DeleteVolumeMountPointW (LPCWSTR lpszVolumeMountPoint)
{
  wchar_t *wmountpoint = handle_long_path (lpszVolumeMountPoint);
  if (wmountpoint == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_DeleteVolumeMountPoint(wmountpoint);
}



static inline WINBOOL
internal_GetVolumeNameForVolumeMountPoint (wchar_t *mountpoint, wchar_t *buffer, DWORD bufferLen)
{
  WINBOOL ret = __real_GetVolumeNameForVolumeMountPointW(mountpoint, buffer, bufferLen);
  SAFE_FREE(mountpoint);
  return ret;
}

WINBOOL WINAPI
__wrap_GetVolumeNameForVolumeMountPointA (LPCSTR lpszVolumeMountPoint, LPSTR lpszVolumeName, DWORD cchBufferLength)
{
  WINBOOL ret;
  wchar_t buffer[50];
  wchar_t *wmountpoint = handle_long_path_utf8 (lpszVolumeMountPoint);
  if (wmountpoint == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  ret = internal_GetVolumeNameForVolumeMountPoint(wmountpoint, buffer, sizeof(buffer));
  wmountpoint = NULL; /* Freed in internal_GetVolumeNameForVolumeMountPoint */

  if (ret)
    {
      char *p = wchar_to_utf8 (buffer);
      if (p == NULL)
        {
          SetLastError (ERROR_NOT_ENOUGH_MEMORY);
          return FALSE;
        }
      strncpy (lpszVolumeName, p, cchBufferLength);
      SAFE_FREE(p);
    }

  return ret;
}

WINBOOL WINAPI
__wrap_GetVolumeNameForVolumeMountPointW (LPCWSTR lpszVolumeMountPoint, LPWSTR lpszVolumeName, DWORD cchBufferLength)
{
  wchar_t *wmountpoint = handle_long_path (lpszVolumeMountPoint);
  if (wmountpoint == NULL)
    {
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_GetVolumeNameForVolumeMountPoint(wmountpoint, lpszVolumeName, cchBufferLength);
}




static inline WINBOOL
internal_SetVolumeMountPoint (wchar_t *mountpoint, wchar_t *name)
{
  WINBOOL ret = __real_SetVolumeMountPointW(mountpoint, name);
  SAFE_FREE(mountpoint);
  SAFE_FREE(name);
  return ret;
}


WINBOOL WINAPI
__wrap_SetVolumeMountPointA (LPCSTR lpszVolumeMountPoint, LPCSTR lpszVolumeName)
{
  wchar_t *wmountpoint = handle_long_path_utf8 (lpszVolumeMountPoint);
  wchar_t *wname = utf8_to_wchar (lpszVolumeName);
  if (wmountpoint == NULL || wname == NULL)
    {
      SAFE_FREE(wmountpoint);
      SAFE_FREE(wname);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_SetVolumeMountPoint (wmountpoint, wname);
}

WINBOOL WINAPI
__wrap_SetVolumeMountPointW (LPCWSTR lpszVolumeMountPoint, LPCWSTR lpszVolumeName)
{
  wchar_t *wmountpoint = handle_long_path (lpszVolumeMountPoint);
  wchar_t *wname = wcsdup (lpszVolumeName);
  if (wmountpoint == NULL || wname == NULL)
    {
      SAFE_FREE(wmountpoint);
      SAFE_FREE(wname);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return FALSE;
    }

  return internal_SetVolumeMountPoint (wmountpoint, wname);
}





static char *
reparse_to_path (wchar_t *ptr, int offset, int len)
{
  wchar_t *wptr = (wchar_t *)((char *)ptr + offset);
  wptr[len / sizeof(wchar_t) + 1] = L'\0';
  return wchar_to_utf8 (to_unix_like_path (wptr));
}

ssize_t
readlink(const char *path, char *buf, size_t bufsiz)
{
  HANDLE handle;
  wchar_t *wpath;
  PREPARSE_DATA_BUFFER buffer = (PREPARSE_DATA_BUFFER) malloc(MAXIMUM_REPARSE_DATA_BUFFER_SIZE);
  DWORD dummy;
  char *ptr = NULL;
  size_t len;

  if (buffer == NULL)
    {
      errno = ENOMEM;
      return -1;
    }

  wpath = utf8_to_wchar (path);
  if (wpath == NULL)
    {
      SAFE_FREE(buffer);
      errno = ENOMEM;
      return -1;
    }

  /* read reparse point data */
  handle = CreateFileW (wpath, 0,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
      NULL,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  if (handle == INVALID_HANDLE_VALUE)
    {
      DWORD err = GetLastError ();
      SAFE_FREE(buffer);
      SAFE_FREE(wpath);
      errno = to_errno (err);
      return -1;
    }
  SAFE_FREE(wpath);

  if (!DeviceIoControl (handle, FSCTL_GET_REPARSE_POINT, NULL, 0, buffer,
			MAXIMUM_REPARSE_DATA_BUFFER_SIZE,
			&dummy, NULL))
    {
      DWORD err = GetLastError ();
      CloseHandle (handle);
      SAFE_FREE(buffer);
      errno = to_errno (err);
      return -1;
    }
  CloseHandle (handle);

  switch (buffer->ReparseTag)
    {
    case IO_REPARSE_TAG_SYMLINK:
      ptr = reparse_to_path (
	  buffer->SymbolicLinkReparseBuffer.PathBuffer,
	  buffer->SymbolicLinkReparseBuffer.SubstituteNameOffset,
	  buffer->SymbolicLinkReparseBuffer.SubstituteNameLength);
      break;

    case IO_REPARSE_TAG_MOUNT_POINT:
      ptr = reparse_to_path (
	  buffer->MountPointReparseBuffer.PathBuffer,
	  buffer->MountPointReparseBuffer.SubstituteNameOffset,
	  buffer->MountPointReparseBuffer.SubstituteNameLength);
      break;

    case IO_REPARSE_TAG_LX_SYMLINK:
      len = buffer->ReparseDataLength - sizeof (DWORD); /* Filetype */
      ptr = (char *)malloc (len + 1);
      strncat_s (ptr, len + 1, (const char *)buffer->GenericReparseBuffer.DataBuffer + sizeof (DWORD), len);
      break;

    default:
      SAFE_FREE(buffer);
      errno = EINVAL;
      return -1;
    }
  SAFE_FREE(buffer);

  if (ptr == NULL)
    {
      errno = ENOMEM;
      return -1;
    }

  len = strlen (ptr);
  if (bufsiz < len)
    len = bufsiz - 1;

  memcpy (buf, ptr, len);
  buf[len] = 0;

  SAFE_FREE(ptr);
  return len;
}

char *
__wrap_lrealpath(const char *path)
{
  wchar_t *wpath = handle_long_path_utf8 (path);

  wchar_t *wbuf = internal_realpath (wpath);
  SAFE_FREE(wpath);
  if (wbuf == NULL)
    {
      return strdup (path);
    }

  char *buf = wchar_to_utf8 (wbuf);
  SAFE_FREE(wbuf);
  LP_DEBUG("%s:%d; %s -> %s\n", __func__, __LINE__, path, buf);
  return buf;
}


static struct {
  bool active;
  bool set;
} setSafeProcessSearchMode_cache = {false, false};

WINBOOL WINAPI
__wrap_SetSearchPathMode(DWORD flags)
{
  BOOL res = __real_SetSearchPathMode(flags);
  if (res)
  {
    setSafeProcessSearchMode_cache.active = flags & BASE_SEARCH_PATH_ENABLE_SAFE_SEARCHMODE;
    setSafeProcessSearchMode_cache.set = true;
  }

  return res;
}

static bool
internal_SearchPath(const wchar_t *path_var, const wchar_t *filename, const wchar_t *ext, wchar_t **res)
{
  bool isSafeSearchActive = false;

  if (setSafeProcessSearchMode_cache.set)
    {
      isSafeSearchActive = setSafeProcessSearchMode_cache.active;
    }
  else
    {
      /* Read the setting from SafeProcessSearchMode registery setting.  */
      /* See https://learn.microsoft.com/en-us/windows/win32/api/processenv/nf-processenv-searchpathw for details.  */
      const char *subKey = "SYSTEM\\CurrentControlSet\\Control\\Session Manager";
      const char *value = "SafeProcessSearchMode";
      DWORD data = 0;
      DWORD size = sizeof(value);
      if (RegGetValue (HKEY_LOCAL_MACHINE, subKey, value, RRF_RT_REG_DWORD, NULL, (PVOID)&data, &size) == ERROR_SUCCESS)
	{
	  isSafeSearchActive = data == 1;
	}
      else
	{
	  isSafeSearchActive = false;
	}
    }

  if (!path_var)
    {
      path_var = _wgetenv (L"PATH");
      if (!path_var)
	{
	  /* Fall back to alternative name.  */
	  path_var = _wgetenv (L"Path");
	}

      if (!path_var)
	{
	  LP_DEBUG("%s:%d No path variable set.\n", __func__, __LINE__);
	  return false;
	}
    }

  const size_t filename_ext_len = wcslen(filename) + (ext ? wcslen(ext) : 0);
  wchar_t *filename_ext = (wchar_t *)malloc ((filename_ext_len + 1) * sizeof(wchar_t));
  if (!filename_ext)
    {
      /* Out of memory.  */
      return false;
    }
  *filename_ext = L'\0';
  wcscat (filename_ext, filename);
  if (ext)
    {
      wcscat(filename_ext, ext);
    }


  if (!isSafeSearchActive)
    {
      /* Check relative to current working directory.  */
      wchar_t *tmp = internal_realpath_2 (filename_ext);
      if (_waccess (tmp, 0) == 0)
	{
	  *res = tmp;
	  SAFE_FREE(filename_ext);
	  return true;
	}
      SAFE_FREE(tmp);
    }


  /* Check $PATH.  */
  for (const wchar_t *pStart = path_var; pStart; )
    {
      /* Skip empty path entries.  */
      while (*pStart == L';')
	{
	  pStart++;
	}

      if (*pStart == L'\0')
	{
	  /* No more entries.  */
	  break;
	}

      /* Identify end of entry.  */
      const wchar_t *pEnd = wcschr(pStart, L';');
      if (pEnd == NULL)
	{
	  /* No delimiter found, use rest of string.  */
	  pEnd = pStart + wcslen(pStart);
	}

      /* Build file path.  */
      size_t len = pEnd - pStart + 1 + filename_ext_len + 1;
      wchar_t *tmp = (wchar_t *)malloc (len * sizeof(wchar_t));
      tmp[0] = '\0';
      wcsncpy(tmp, pStart, pEnd - pStart);
      tmp[pEnd - pStart] = '\0';
      if (!IS_PATHSEP(*(pEnd - 1)))
	{
	  wcscat(tmp, L"\\");
	}
      wcscat(tmp, filename_ext);

      LP_DEBUG("    pStart:(%p) %ls\n", (void*)pStart, pStart);
      LP_DEBUG("    pEnd:  (%p) %ls\n", (void*)pEnd, pEnd);
      LP_DEBUG("    tmp:   (%p) %ls\n", (void*)tmp, tmp);

      if (_waccess (tmp, 0) == 0)
	{
	  *res = tmp;
	  SAFE_FREE(filename_ext);
	  return true;
	}

      SAFE_FREE(tmp);

      /* Try next entry.  */
      pStart = pEnd;
    }


  if (isSafeSearchActive)
    {
      /* Check relative to current working directory.  */
      wchar_t *tmp = internal_realpath_2 (filename_ext);
      if (_waccess (tmp, 0) == 0)
	{
	  *res = tmp;
	  SAFE_FREE(filename_ext);
	  return true;
	}
      SAFE_FREE(tmp);
    }

  SAFE_FREE(filename_ext);
  return false;
}

DWORD
__wrap_SearchPathA(const char *path, const char *filename, const char *ext, DWORD buf_len, char *buf, char **file_part)
{
  wchar_t *wpath = handle_long_path_utf8 (path);
  wchar_t *wfilename = utf8_to_wchar (filename);
  wchar_t *wext = utf8_to_wchar (ext);

  if ((path && !wpath) || !filename || !wfilename || (ext && !wext))
    {
      SAFE_FREE(wpath);
      SAFE_FREE(wfilename);
      SAFE_FREE(wext);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  wchar_t *res = NULL;
  bool found = internal_SearchPath(wpath, wfilename, wext, &res);

  SAFE_FREE(wpath);
  SAFE_FREE(wfilename);
  SAFE_FREE(wext);

  if (found)
    {
      char *tmp = wchar_to_utf8 (res);
      if (!tmp)
	{
	  SetLastError (ERROR_NOT_ENOUGH_MEMORY);
	  return 0;
	}

      size_t len = strlen (tmp);
      size_t offset = 0;

      /* Skip UNC prefix if short path.  */
      if (IS_UNC_PREFIX(tmp) && len < MAX_DIR_PATH)
      {
	offset = 4;
      }

      if (buf && len - offset < buf_len)
	{
	  buf[0] = '\0';
	  strcat (buf, tmp + offset);
	}
      SAFE_FREE(tmp);

      if (file_part)
	{
	  /* Find last path separator.  */
	  for (char *p = buf + len - offset; p >= buf; p--)
	    {
	      if (IS_PATHSEP(*p))
	      {
		*file_part = p + 1;
		break;
	      }
	    }

	  /* Don't count if last character in string is a path separator.  */
	  if (*file_part && *(*file_part + 1) == L'\0')
	    {
	      *file_part = NULL;
	    }
	}
      return len - offset;
    }

  SetLastError (ERROR_NOT_FOUND);
  return 0;
}

DWORD
__wrap_SearchPathW(const wchar_t *path, const wchar_t *filename, const wchar_t *ext, DWORD buf_len, wchar_t *buf, wchar_t **file_part)
{
  wchar_t *wpath = handle_long_path (path);

  if ((path && !wpath) || !filename)
  {
    SAFE_FREE(wpath);
    SetLastError (ERROR_NOT_ENOUGH_MEMORY);
    return 0;
  }

  wchar_t *res = NULL;
  bool found = internal_SearchPath(wpath, filename, ext, &res);

  SAFE_FREE(wpath);

  if (found)
    {
      size_t len = wcslen (res);
      size_t offset = 0;

      /* Skip UNC prefix if short path.  */
      if (IS_UNC_PREFIX(res) && len < MAX_DIR_PATH)
      {
	offset = 4;
      }

      if (buf && len - offset < buf_len)
	{
	  buf[0] = L'\0';
	  wcscat (buf, res + offset);
	}

      if (file_part)
	{
	  /* Find last path separator.  */
	  for (wchar_t *p = buf + len - offset; p >= buf; p--)
	    {
	      if (IS_PATHSEP(*p))
	      {
		*file_part = p + 1;
		break;
	      }
	    }

	  /* Don't count if last character in string is a path separator.  */
	  if (*file_part && *(*file_part + 1) == L'\0')
	    {
	      *file_part = NULL;
	    }
	}

      return len - offset;
    }

  SetLastError (ERROR_NOT_FOUND);
  return 0;
}


WINBOOL WINAPI
__wrap_MoveFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName)
{
  wchar_t *wexistingFileName = handle_long_path_utf8 (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path_utf8 (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileW (wexistingFileName, wnewFileName);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_MoveFileW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName)
{
  wchar_t *wexistingFileName = handle_long_path (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileW (wexistingFileName, wnewFileName);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_MoveFileExA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, DWORD dwFlags)
{
  wchar_t *wexistingFileName = handle_long_path_utf8 (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path_utf8 (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileExW (wexistingFileName, wnewFileName, dwFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_MoveFileExW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, DWORD dwFlags)
{
  wchar_t *wexistingFileName = handle_long_path (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileExW (wexistingFileName, wnewFileName, dwFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_MoveFileWithProgressA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags)
{
  wchar_t *wexistingFileName = handle_long_path_utf8 (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path_utf8 (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileWithProgressW (wexistingFileName, wnewFileName, lpProgressRoutine, lpData, dwFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_MoveFileWithProgressW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags)
{
  wchar_t *wexistingFileName = handle_long_path (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_MoveFileWithProgressW (wexistingFileName, wnewFileName, lpProgressRoutine, lpData, dwFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_CopyFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, WINBOOL bFailIfExists)
{
  wchar_t *wexistingFileName = handle_long_path_utf8 (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path_utf8 (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_CopyFileW (wexistingFileName, wnewFileName, bFailIfExists);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_CopyFileW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, WINBOOL bFailIfExists)
{
  wchar_t *wexistingFileName = handle_long_path (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_CopyFileW (wexistingFileName, wnewFileName, bFailIfExists);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_CopyFileExA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags)
{
  wchar_t *wexistingFileName = handle_long_path_utf8 (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path_utf8 (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_CopyFileExW (wexistingFileName, wnewFileName, lpProgressRoutine, lpData, pbCancel, dwCopyFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

WINBOOL WINAPI
__wrap_CopyFileExW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags)
{
  wchar_t *wexistingFileName = handle_long_path (lpExistingFileName);
  wchar_t *wnewFileName = handle_long_path (lpNewFileName);

  if (wexistingFileName == NULL || wnewFileName == NULL)
    {
      /* Error */
      SAFE_FREE(wexistingFileName);
      SAFE_FREE(wnewFileName);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  WINBOOL res = __real_CopyFileExW (wexistingFileName, wnewFileName, lpProgressRoutine, lpData, pbCancel, dwCopyFlags);
  SAFE_FREE(wexistingFileName);
  SAFE_FREE(wnewFileName);
  return res;
}

UINT WINAPI
__wrap_GetTempFileNameA (LPCSTR lpPathName, LPCSTR lpPrefixString, UINT uUnique, LPSTR lpTempFileName)
{
  wchar_t *path = utf8_to_wchar (lpPathName);
  wchar_t *prefix = utf8_to_wchar (lpPrefixString);

  if (path == NULL || prefix == NULL)
    {
      /* Error */
      SAFE_FREE(path);
      SAFE_FREE(prefix);
      SetLastError (ERROR_NOT_ENOUGH_MEMORY);
      return 0;
    }

  wchar_t buf[MAX_PATH + 1];
  UINT res = GetTempFileNameW (path, prefix, uUnique, buf);
  SAFE_FREE(path);
  SAFE_FREE(prefix);
  if (res > 0)
    {
      buf[MAX_PATH] = L'\0';
      char *buf_utf8 = wchar_to_utf8 (buf);
      if (buf_utf8 == NULL)
        {
          /* Error */
          SetLastError (ERROR_NOT_ENOUGH_MEMORY);
          return 0;
        }
      strncpy (lpTempFileName, buf_utf8, MAX_PATH);
      lpTempFileName[MAX_PATH - 1] = '\0';
      SAFE_FREE(buf_utf8);
    }
  return res;
}

#if 0
This is a nop-wrapping, so skip it.
UINT WINAPI
__wrap_GetTempFileNameW (LPCWSTR lpPathName, LPCWSTR lpPrefixString, UINT uUnique, LPWSTR lpTempFileName)
{
  return __real_GetTempFileNameW (lpPathName, lpPrefixString, uUnique, lpTempFileName);
}
#endif

DWORD WINAPI
__wrap_GetModuleFileNameA (HMODULE hModule, LPSTR lpFilename, DWORD nSize)
{
  wchar_t buf[nSize + 1];
  DWORD res = GetModuleFileNameW (hModule, buf, nSize);
  if (res > 0)
    {
      buf[nSize] = L'\0';
      char *buf_utf8 = wchar_to_utf8 (buf);
      if (buf_utf8 == NULL)
        {
          /* Error */
          SetLastError (ERROR_NOT_ENOUGH_MEMORY);
          return 0;
        }
      strncpy (lpFilename, buf_utf8, nSize);
      lpFilename[nSize > 1 ? nSize - 1 : 0] = '\0';
      SAFE_FREE(buf_utf8);
      return strlen (lpFilename);
    }
  return res;
}

#if 0
This is a nop-wrapping, so skip it.
DWORD WINAPI
__wrap_GetModuleFileNameW (HMODULE hModule, LPWSTR lpFilename, DWORD nSize)
{
  return __real_GetModuleFileNameW (hModule, lpFilename, nSize);
}
#endif


wchar_t *
utf8_to_wchar(const char *src)
{
  wchar_t *dest;
  int dest_len;

  if (src == NULL)
    {
      errno = EINVAL;
      return NULL;
    }

  dest_len = MultiByteToWideChar (CP_UTF8, 0, src, -1, NULL, 0);
  if (dest_len < 1)
    {
      errno = EINVAL;
      return NULL;
    }

  dest = (wchar_t *)calloc (dest_len + 1, sizeof(wchar_t));
  if (dest == NULL)
    {
      errno = ERANGE;
      return NULL;
    }

  dest_len = MultiByteToWideChar (CP_UTF8, 0, src, -1, dest, dest_len);
  if (dest_len)
    return dest;

  /* this should never happen! */
  SAFE_FREE(dest);

  errno = ERANGE;
  return NULL;
}


char *
wchar_to_utf8(const wchar_t *src)
{
  char *dest;
  int dest_len;

  if (src == NULL)
    {
      errno = EINVAL;
      return NULL;
    }

  dest_len = WideCharToMultiByte(CP_UTF8, 0, src, -1, NULL, 0, NULL, NULL);
  if (dest_len < 1)
    {
      errno = EINVAL;
      return NULL;
    }

  dest = (char *)calloc (dest_len + 1, sizeof(char));
  if (dest == NULL)
    {
      errno = ERANGE;
      return NULL;
    }

  dest_len = WideCharToMultiByte(CP_UTF8, 0, src, -1, dest, dest_len, NULL, NULL);
  if (dest_len)
    return dest;

  /* this should never happen! */
  SAFE_FREE(dest);

  errno = ERANGE;
  return NULL;
}

wchar_t *
check_long_path(const wchar_t *path)
{
  int len = wcslen (path);

  if (len == 3 && _wcsicmp (path, L"nul") == 0)
    return wcsdup (path);

  if (internal_update_cwd_cache() < 0)
    return NULL;

  /* Path is absolute and short enough.  */
  if (len >= 2 && (IS_PATHSEP(path[0]) || path[1] == L':'))
    {
      if (len < MAX_DIR_PATH - 1)
	{
	  /* Strip of UNC prefix.  */
	  if (IS_UNC_PREFIX(path))
	    {
	      return wcsdup (path + 4);
	    }
	  return wcsdup (path);
	}
    }

  /* Path is relative and short enough.  */
  else if (_long_path_name.long_cwd_len + len < MAX_DIR_PATH - 1)
    return wcsdup (path);

  return NULL;
}

wchar_t *
handle_long_path_utf8(const char *path)
{
  wchar_t *wpath = NULL;
  wchar_t *ptr = NULL;
  wpath = utf8_to_wchar (path);
  if (wpath == NULL)
    {
      if (errno == ERANGE)
	errno = ENAMETOOLONG;

      return NULL;
    }

  ptr = handle_long_path(wpath);
  SAFE_FREE(wpath);
  return ptr;
}

wchar_t *
handle_long_path(const wchar_t *path)
{
  int result;
  wchar_t *buf = NULL;
  wchar_t *ptr = NULL;

  ptr = check_long_path (path);
  if (ptr != NULL)
    {
      LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, ptr);
      return ptr;
    }

  /*
   * handle everything else:
   * - absolute paths: "C:\dir\file"
   * - absolute UNC paths: "\\server\share\dir\file"
   * - absolute paths on current drive: "\dir\file"
   * - relative paths on other drive: "X:file"
   * - prefixed paths: "\\?\...", "\\.\..."
   */

  /* convert to absolute path using GetFullPathNameW */
  buf = (wchar_t *)malloc(MAX_LONG_PATH * sizeof(wchar_t));
  result = GetFullPathNameW (path, MAX_LONG_PATH, buf, NULL);
  if (result == 0)
    {
      errno = to_errno (GetLastError ());
      SAFE_FREE(buf);
      LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, L"(null)");
      return NULL;
    }

  /*
   * return absolute path if it fits within max_path (even if
   * "cwd + path" doesn't due to '..' components)
   */
  if (result < MAX_DIR_PATH - 1)
    {
      LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf);
      return buf;
    }

  /* prefix full path with "\\?\" or "\\?\UNC\" */
  if (buf[0] == '\\')
    {
      /* ...unless already prefixed */
      if (buf[1] == '\\' && (buf[2] == '?' || buf[2] == '.'))
	return buf;

      int len = wcslen(buf) + 6 + 1;
      wchar_t *buf2 = (wchar_t *)malloc(len * sizeof(wchar_t));

      wcscpy (buf2, L"\\\\?\\UNC\\");
      wcscpy (buf2 + 8, buf + 2);
      LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf2);
      SAFE_FREE(buf);
      return buf2;
    }
  else
    {
      int len = wcslen(buf) + 4 + 1;
      wchar_t *buf2 = (wchar_t *)malloc(len * sizeof(wchar_t));

      wcscpy (buf2, L"\\\\?\\");
      wcscpy (buf2 + 4, buf);
      LP_DEBUG("%s:%d; %S -> %S\n", __func__, __LINE__, path, buf2);
      SAFE_FREE(buf);
      return buf2;
    }
}

