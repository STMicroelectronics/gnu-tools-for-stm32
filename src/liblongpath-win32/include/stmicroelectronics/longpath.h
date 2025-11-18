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

#ifndef _STMICROELECTRONICS_H_
#define _STMICROELECTRONICS_H_

#define MAX_LONG_PATH 8192

#define SAFE_FREE(ptr) do { free(ptr); ptr = NULL; } while (0)

wchar_t *
utf8_to_wchar (const char *src);

char *
wchar_to_utf8 (const wchar_t *src);

wchar_t *
handle_long_path_utf8 (const char *utf);

wchar_t *
handle_long_path (const wchar_t *path);

wchar_t *
check_long_path (const wchar_t *path);

#endif /* _STMICROELECTRONICS_H_ */
