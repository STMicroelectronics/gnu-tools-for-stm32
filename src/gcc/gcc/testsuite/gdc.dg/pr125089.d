// { dg-do compile }
struct R125089
{
    S125089.T st;
}

struct S125089
{
    struct T
    {
        void* v;
        ~this() {}
    }

    T t;
    this(R125089 r)
    {
        this.t = r.st;
    }
}
