/* { dg-do compile } */
/* { dg-options "-fstack-usage" } */
/* nvptx doesn't have a reg allocator, and hence no stack usage data.  */
/* { dg-skip-if "" { nvptx-*-* } { "*" } { "" } } */

#include "nop.h"

void foo(int size)
{
    int i;
    int v[size];
    i = 1;
    v[0] = 1;
}

void bar(int size)
{
    int i;
    int v[size];
    i = 1;
    v[0] = 1;
    asm(NOP);
}

/* { dg-final { scan-stack-usage "foo\t\[1-9\]\[0-9\]*\tdynamic" } } */
/* { dg-final { scan-stack-usage "bar\t\[1-9\]\[0-9\]*\tdynamic,ignoring_inline_asm" } } */
/* { dg-final { cleanup-stack-usage } } */
