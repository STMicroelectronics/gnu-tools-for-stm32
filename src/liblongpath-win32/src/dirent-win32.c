/*
 * dirent.c
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-runtime package.
 * No warranty is given; refer to the file DISCLAIMER within the package.
 *
 * Derived from DIRLIB.C by Matt J. Weinstein
 * This note appears in the DIRLIB.H
 * DIRLIB.H by M. J. Weinstein   Released to public domain 1-Jan-89
 *
 * Updated by Jeremy Bettis <jeremy@hksys.com>
 * Significantly revised and rewinddir, seekdir and telldir added by Colin
 * Peters <colin@fu.is.saga-u.ac.jp>
 *
 * Updated by Torbjörn SVENSSON <torbjorn.svensson@foss.st.com>
 * Added support for long paths
 *
 */

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <io.h>
#include <direct.h>
#include <dirent.h>

#include <windows.h> /* for GetFileAttributes */

#include "stmicroelectronics/longpath.h"

#define TO_WCHAR_PATTERN(ptr) ((wchar_t *)((ptr) + strlen (ptr) + 1))

DIR * __cdecl __wrap_opendir(const char *);
struct dirent * __cdecl __wrap_readdir(DIR *);
int __cdecl __wrap_closedir(DIR *);
void __cdecl __wrap_rewinddir (DIR *);
long __cdecl __wrap_telldir (DIR *);
void __cdecl __wrap_seekdir (DIR *, long);

/*
 * opendir
 *
 * Returns a pointer to a DIR structure appropriately filled in to begin
 * searching a directory.
 */
DIR *
__wrap_opendir (const char *szPath)
{
  DIR *nd;
  unsigned int rc;
  wchar_t *fullpath, *path, *pattern;
  char *pattern_utf8;
  size_t len;

  errno = 0;

  if (!szPath)
    {
      errno = EFAULT;
      return NULL;
    }

  if (szPath[0] == '\0')
    {
      errno = ENOTDIR;
      return NULL;
    }

  /* Make an absolute pathname.  */
  path = utf8_to_wchar (szPath);
  fullpath = _wfullpath(NULL, path, MAX_LONG_PATH);
  SAFE_FREE(path);
  if (fullpath == NULL)
    {
      errno = ENOMEM;
      return NULL;
    }

  /* Make a long path if needed.  */
  path = handle_long_path(fullpath);
  SAFE_FREE(fullpath);
  if (path == NULL)
    {
      errno = ENOMEM;
      return NULL;
    }

  /* Attempt to determine if the given path really is a directory. */
  rc = GetFileAttributesW (path);
  if (rc == INVALID_FILE_ATTRIBUTES)
    {
      /* call GetLastError for more error info */
      SAFE_FREE(path);
      errno = ENOENT;
      return NULL;
    }
  if (!(rc & FILE_ATTRIBUTE_DIRECTORY))
    {
      /* Error, entry exists but not a directory. */
      SAFE_FREE(path);
      errno = ENOTDIR;
      return NULL;
    }

  len = wcslen (path);

  /* Make pattern.  */
  pattern = (wchar_t *)malloc((len + 3) * sizeof(wchar_t));
  if (pattern == NULL)
    {
      SAFE_FREE(path);
      errno = ENOMEM;
      return NULL;
    }
  wcscpy (pattern, path);
  SAFE_FREE(path);

  /* Convert to windows style path.  */
  for (wchar_t *ptr = pattern; *ptr; ptr++)
    if (*ptr == '/')
      *ptr = '\\';

  /* Ensure pattern ends with \*.  */
  if (len && pattern[len - 1] != '\\')
    pattern[len++] = '\\';
  pattern[len++] = '*';
  pattern[len] = '\0';

  pattern_utf8 = wchar_to_utf8 (pattern);

  /* Allocate enough space to store DIR structure and the complete
   * directory path given in both utf8 and wchar_t format. */
  nd = (DIR *) malloc (sizeof(DIR) +
		      (strlen (pattern_utf8) + 1) * sizeof(char) +
		      (len + 1) * sizeof(wchar_t));

  if (!nd)
    {
      /* Error, out of memory. */
      SAFE_FREE(pattern);
      SAFE_FREE(pattern_utf8);
      errno = ENOMEM;
      return NULL;
    }


  /* Save the search pattern in utf8 format.  */
  strcpy(nd->dd_name, pattern_utf8);

  /* Save the search pattern in wchar_t format.  */
  wcscpy(TO_WCHAR_PATTERN(nd->dd_name), pattern);

  SAFE_FREE(pattern);
  SAFE_FREE(pattern_utf8);

  /* Initialize handle to -1 so that a premature closedir doesn't try
   * to call _findclose on it. */
  nd->dd_handle = -1;

  /* Initialize the status. */
  nd->dd_stat = 0;

  /* Initialize the dirent structure. ino and reclen are invalid under
   * Win32, and name simply points at the appropriate part of the
   * findfirst_t structure. */
  nd->dd_dir.d_ino = 0;
  nd->dd_dir.d_reclen = 0;
  nd->dd_dir.d_namlen = 0;
  memset (nd->dd_dir.d_name, 0, 260 * sizeof(nd->dd_dir.d_name[0])  /*FILENAME_MAX*/);

  return nd;
}


/*
 * readdir
 *
 * Return a pointer to a dirent structure filled with the information on the
 * next entry in the directory.
 */
struct dirent *
__wrap_readdir (DIR * dirp)
{
  struct _wfinddata_t fdata;
  errno = 0;

  /* Check for valid DIR struct. */
  if (!dirp)
    {
      errno = EFAULT;
      return NULL;
    }

  if (dirp->dd_stat < 0)
    {
      /* We have already returned all files in the directory
       * (or the structure has an invalid dd_stat). */
      return NULL;
    }
  else if (dirp->dd_stat == 0)
    {
      /* We haven't started the search yet. */
      /* Start the search */
      dirp->dd_handle = _wfindfirst (TO_WCHAR_PATTERN(dirp->dd_name), &fdata);

      if (dirp->dd_handle == -1)
	{
	  /* Whoops! Seems there are no files in that
	   * directory. */
	  dirp->dd_stat = -1;
	}
      else
	{
	  dirp->dd_stat = 1;
	}
    }
  else
    {
      /* Get the next search entry. */
      if (_wfindnext (dirp->dd_handle, &fdata))
	{
	  /* We are off the end or otherwise error.
	     _findnext sets errno to ENOENT if no more file
	     Undo this. */
	  DWORD winerr = GetLastError ();
	  if (winerr == ERROR_NO_MORE_FILES)
	    errno = 0;
	  _findclose (dirp->dd_handle);
	  dirp->dd_handle = -1;
	  dirp->dd_stat = -1;
	}
      else
	{
	  /* Update the status to indicate the correct
	   * number. */
	  dirp->dd_stat++;
	}
    }

  if (dirp->dd_stat > 0)
    {
      /* Successfully got an entry. Everything about the file is
       * already appropriately filled in except the length of the
       * file name. */
      /* convert UTF-16 name to UTF-8 */
      char *ptr = wchar_to_utf8 (fdata.name);
      size_t len = strlen(ptr);
      if (len >= sizeof(dirp->dd_dir.d_name))
        len = sizeof(dirp->dd_dir.d_name) - 1;

      dirp->dd_dir.d_namlen = len;
      memcpy(dirp->dd_dir.d_name, ptr, len);
      dirp->dd_dir.d_name[len] = '\0';
      SAFE_FREE(ptr);
      return &dirp->dd_dir;
    }

  return NULL;
}


/*
 * closedir
 *
 * Frees up resources allocated by opendir.
 */
int
__wrap_closedir (DIR * dirp)
{
  int rc;

  errno = 0;
  rc = 0;

  if (!dirp)
    {
      errno = EFAULT;
      return -1;
    }

  if (dirp->dd_handle != -1)
    {
      rc = _findclose (dirp->dd_handle);
    }

  /* Delete the dir structure. */
  free (dirp);

  return rc;
}

/*
 * rewinddir
 *
 * Return to the beginning of the directory "stream". We simply call findclose
 * and then reset things like an opendir.
 */
void
__wrap_rewinddir (DIR * dirp)
{
  errno = 0;

  if (!dirp)
    {
      errno = EFAULT;
      return;
    }

  if (dirp->dd_handle != -1)
    {
      _findclose (dirp->dd_handle);
    }

  dirp->dd_handle = -1;
  dirp->dd_stat = 0;
}

/*
 * telldir
 *
 * Returns the "position" in the "directory stream" which can be used with
 * seekdir to go back to an old entry. We simply return the value in stat.
 */
long
__wrap_telldir (DIR * dirp)
{
  errno = 0;

  if (!dirp)
    {
      errno = EFAULT;
      return -1;
    }
  return dirp->dd_stat;
}

/*
 * seekdir
 *
 * Seek to an entry previously returned by telldir. We rewind the directory
 * and call readdir repeatedly until either dd_stat is the position number
 * or -1 (off the end). This is not perfect, in that the directory may
 * have changed while we weren't looking. But that is probably the case with
 * any such system.
 */
void
__wrap_seekdir (DIR * dirp, long lPos)
{
  errno = 0;

  if (!dirp)
    {
      errno = EFAULT;
      return;
    }

  if (lPos < -1)
    {
      /* Seeking to an invalid position. */
      errno = EINVAL;
      return;
    }
  else if (lPos == -1)
    {
      /* Seek past end. */
      if (dirp->dd_handle != -1)
	{
	  _findclose (dirp->dd_handle);
	}
      dirp->dd_handle = -1;
      dirp->dd_stat = -1;
    }
  else
    {
      /* Rewind and read forward to the appropriate index. */
      rewinddir (dirp);

      while ((dirp->dd_stat < lPos) && readdir (dirp))
	;
    }
}
