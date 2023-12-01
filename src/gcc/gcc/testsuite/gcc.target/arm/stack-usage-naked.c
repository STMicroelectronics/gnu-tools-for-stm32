/* { dg-do compile } */
/* { dg-options -fstack-usage } */


void __attribute__((naked)) foo()
{
}

void __attribute__((naked)) bar()
{
    asm("nop");
}

/* { dg-final { scan-stack-usage "foo\t0\tstatic" } } */
/* { dg-final { scan-stack-usage "bar\t0\tstatic,ignoring_inline_asm" } } */
/* { dg-final { cleanup-stack-usage } } */
