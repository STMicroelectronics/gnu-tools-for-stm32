/* { dg-do run } */
/* { dg-skip-if "not implemented" { ia64*-*-* } } */
/* { dg-skip-if "not implemented" { arm*-*-* } } */
/* { dg-options "-O2 -fzero-call-used-regs=all-gpr" } */

#include "zero-scratch-regs-1.c"
