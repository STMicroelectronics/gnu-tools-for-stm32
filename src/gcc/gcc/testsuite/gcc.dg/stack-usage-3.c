/* { dg-do compile } */
/* { dg-options "-fstack-usage" } */
/* nvptx doesn't have a reg allocator, and hence no stack usage data.  */
/* { dg-skip-if "" { nvptx-*-* } { "*" } { "" } } */

#include "nop.h"

void foo()
{
    int i;
    i = 1;
}

void bar()
{
    int i;
    i = 1;
    asm(NOP);
}

/* { dg-final { scan-stack-usage "foo\t\[1-9\]\[0-9\]*\tstatic" } } */
/* { dg-final { scan-stack-usage "bar\t\[1-9\]\[0-9\]*\tstatic,ignoring_inline_asm" } } */
/* { dg-final { cleanup-stack-usage } } */

