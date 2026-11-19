// { dg-do compile { target c++11 } }

// LWG 4324. unique_ptr<void>::operator* is not SFINAE-friendly

#include <memory>

template<class T, bool = true>
struct nothrow_dereference
: std::false_type { };

template<class T>
struct nothrow_dereference<T, noexcept(*std::declval<T>())>
: std::true_type { };

static_assert( nothrow_dereference<std::unique_ptr<int>>::value, "");
static_assert( ! nothrow_dereference<std::unique_ptr<void>>::value, "");

#if __cplusplus >= 202002L // C++20
template<class T> concept dereferenceable = requires(T& t) { *t; };
static_assert( dereferenceable<std::unique_ptr<int>>);
static_assert(!dereferenceable<std::unique_ptr<void>>);
#endif
