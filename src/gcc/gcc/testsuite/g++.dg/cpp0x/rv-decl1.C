// PR c++/65271
// { dg-do compile { target c++11 } }

struct {} && m0 = {};
union  {} && m1 = {};
class  {} && m2 = {};
enum   {} && m3 = {};
