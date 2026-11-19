/* { dg-options "-Os -fdump-tree-ivopts -fno-tree-loop-distribute-patterns" } */

void
tr5 (short array[], int n)
{
  int x;
  if (n > 0)
    for (x = 0; x < n; x++)
      array[x] = 0;
}

/* { dg-final { scan-tree-dump-times "PHI <" 1 "ivopts"} } */
/* { dg-final { object-size text <= 36 { target { arm_nothumb && arm_iwmmxt_ok }  } } } */
