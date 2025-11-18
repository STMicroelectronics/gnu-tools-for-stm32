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

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <windows.h>
#include "stmicroelectronics/longpath.h"


int __real_main(int, char **, char **);
int __wrap_main(void);


static const size_t LIST_INCREMENT = 5;
typedef struct {
  size_t size;
  size_t next;
  char **data;
} List_t;

static void
list_init(List_t *list)
{
  list->data = NULL;
  list->size = 0;
  list->next = 0;
}

static void
list_free(List_t *list, bool deep)
{
  if (deep)
    {
      for (size_t i = 0; i < list->next; i++) {
        free (list->data[i]);
      }
    }
  free (list->data);
  list_init (list);
}

static bool
list_append(List_t *list, char *ptr)
{
  if (list->next >= list->size)
    {
      /* Resize. */
      const size_t new_size = (list->next + LIST_INCREMENT + 1) * sizeof(char *);
      char **tmp = (char **)realloc (list->data, new_size);
      if (tmp)
        {
          list->data = tmp;
          list->size = list->next + LIST_INCREMENT;
        }
      else
        {
          /* Failed to resize.  */
          fwprintf (stderr, L"Failed to resize list to %u bytes\n", new_size);
          return false;
        }
    }

  list->data[list->next++] = ptr;
  list->data[list->next] = NULL;

  return true;
}

static bool
append_converted_string(wchar_t *str, List_t *arr_utf8, List_t *to_free)
{
  char *ptr = wchar_to_utf8 (str);
  if (!ptr)
    {
      fwprintf (stderr, L"Failed to convert %s\n", str);
      return false;
    }

  if (!list_append (arr_utf8, ptr) || !list_append (to_free, ptr))
    {
      /* Not appended to to_free list, so free it now.  */
      free (ptr);
      return false;
    }

  return true;
}

static bool
convert_argv(List_t *argv_utf8, List_t *to_free)
{
  int argc_wide = 0;
  wchar_t **argv_wide = NULL;

  wchar_t *command_line = GetCommandLineW ();
  if (!command_line)
    {
      fprintf (stderr, "Failed to get command line\n");
      return false;
    }

  argv_wide = CommandLineToArgvW (command_line, &argc_wide);
  if (!argv_wide)
    {
      fprintf (stderr, "Failed to convert to array\n");
      return false;
    }

  for (wchar_t **p = argv_wide; *p; p++)
    {
      if (!append_converted_string (*p, argv_utf8, to_free))
        {
          /* Clean up.  */
          LocalFree (argv_wide);
          return false;
        }
    }

  /* Standard says that last element should be NULL.  */
  argv_utf8->data[argv_utf8->next] = NULL;

  LocalFree (argv_wide);
  return true;
}

static bool
convert_env(List_t *env_utf8, List_t *to_free)
{
  wchar_t *env_wide = GetEnvironmentStringsW ();

  for (wchar_t *p = env_wide; *p; p++)
    {
      if (!append_converted_string (p, env_utf8, to_free))
        {
          FreeEnvironmentStringsW (env_wide);
          return false;
        }

      p += wcslen(p);
    }

  /* Array should be NULL terminated.  */
  env_utf8->data[env_utf8->next] = NULL;

  FreeEnvironmentStringsW (env_wide);
  return true;
}

int
__wrap_main(void)
{
  int ret = 1;
  List_t argv_utf8, env_utf8, to_free;

  list_init (&argv_utf8);
  list_init (&env_utf8);
  list_init (&to_free);

  if (convert_argv (&argv_utf8, &to_free) && convert_env (&env_utf8, &to_free))
    {
      ret = __real_main(argv_utf8.next, argv_utf8.data, env_utf8.data);
    }

  /* Clean up.  */
  list_free (&argv_utf8, false);
  list_free (&env_utf8, false);
  list_free (&to_free, true);
  exit (ret);
}
