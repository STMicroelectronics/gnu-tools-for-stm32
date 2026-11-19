/* PR 125049: ensure stack canary and its address are not leaked.  */
/* { dg-options "-O2 -fstack-protector-strong -ffixed-r30 -ffixed-r31" } */
/* { dg-do run } */
/* { dg-require-effective-target fstack_protector } */

extern long __stack_chk_guard;
register long s7 asm ("s7"), *s8 asm ("s8");

[[gnu::zero_call_used_regs ("all"), gnu::noipa]] void
init_test (void)
{
  s7 = __stack_chk_guard;
  s8 = &__stack_chk_guard;
}

[[gnu::always_inline]] static inline void
check_reg (void)
{
#pragma GCC unroll 30
  for (int i = 4; i < 30; i++)
    asm goto (
      "beq $r%0,$s7,%l[error]\n\t"
      "beq $r%0,$s8,%l[error]\n\t"
      :
      : "i" (i)
      :
      : error
    );
  return;
error:
  __builtin_trap ();
}

[[gnu::noipa]] void
test (void)
{
  char buf[256];
  asm ("":"+m"(buf));

  check_reg ();
}

int
main (void)
{
  init_test ();
  test ();

  check_reg ();
}
