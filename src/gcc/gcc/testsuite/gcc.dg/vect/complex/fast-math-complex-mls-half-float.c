/* { dg-do compile } */
/* { dg-additional-options "-ffast-math" } */
/* { dg-require-effective-target vect_complex_add_half } */
/* { dg-require-effective-target float16 } */
/* { dg-add-options arm_v8_3a_fp16_complex_neon } */

#define TYPE _Float16
#define N 200
#include "complex-mls-template.c"
/* COMPLEX_ADD_ROT270 is no longer recognized in fms_elemconjsnd.
   The COMPLEX_EXPR that prevented reassoc from changing X - (Y + Z)
   into (X + (-Y)) + (-Z) has been removed since the introduction of
   DCE at the end of cplxlower1.  */
/* { dg-final { scan-tree-dump "Found COMPLEX_ADD_ROT270" "vect" { xfail *-*-* } } } */
/* { dg-final { scan-tree-dump "Found COMPLEX_FMS_CONJ" "vect" } } */
/* { dg-final { scan-tree-dump "Found COMPLEX_FMS" "vect" } } */
