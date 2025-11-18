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

#include <windows.h>
#include "stmicroelectronics/longpath.h"

char *
__wrap_getenv (const char *varname)
{
  wchar_t *varname_wide = utf8_to_wchar (varname);
  if (varname_wide)
    {
      wchar_t *val_wide = _wgetenv (varname_wide);
      SAFE_FREE(varname_wide);
      if (val_wide)
        {
          /* This call allocates memory that is never free'ed... */
          return wchar_to_utf8 (val_wide);
        }
    }

  /* Failed to convert string or variable not defined.  */
  return NULL;
}

static int
internal_putenv (const char *envstring)
{
  wchar_t *envstring_wide = utf8_to_wchar (envstring);
  if (envstring_wide)
    {
      int res = _wputenv (envstring_wide);
      SAFE_FREE(envstring_wide);
      return res;
    }

  /* Failed to convert string. Errno already set.  */
  return -1;
}

int
__wrap__putenv (const char *envstring)
{
  return internal_putenv (envstring);
}

int
__wrap_putenv (const char *envstring)
{
  return internal_putenv (envstring);
}
