/* { dg-do run } */

int a, b, c;
_Bool d, e;

void
foo (void)
{
  if (d)
    {
    l: b = -1;
    }
  e = c <= b;
  a = a - 7;
  if (e)
    goto l;
}

int
main ()
{
  foo ();
  if (a != -14)
    __builtin_abort ();
}
