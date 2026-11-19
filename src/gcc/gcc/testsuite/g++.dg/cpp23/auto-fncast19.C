// PR c++/120685
// { dg-do compile { target c++11 } }
// { dg-options "" }

template <typename T>
void foo (decltype (auto (T ())) x) {}	// { dg-warning "'auto\\\(x\\\)' only available with" "" { target c++20_down } }

int
main ()
{
  foo <int> (1);
}
