from ctypes import *

isl = cdll.LoadLibrary("libisl.so")
libc = cdll.LoadLibrary("libc.so.6")

class Error(Exception):
    pass

class Context:
    defaultInstance = None

    def __init__(self):
        ptr = isl.isl_ctx_alloc()
        self.ptr = ptr

    def __del__(self):
        isl.isl_ctx_free(self)

    def from_param(self):
        return self.ptr

    @staticmethod
    def getDefaultInstance():
        if Context.defaultInstance == None:
            Context.defaultInstance = Context()
        return Context.defaultInstance

isl.isl_ctx_alloc.restype = c_void_p
isl.isl_ctx_free.argtypes = [Context]

class union_map:
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and args[0].__class__ is basic_map:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_map_from_basic_map(isl.isl_basic_map_copy(args[0].ptr))
            return
        if len(args) == 1 and args[0].__class__ is map:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_map_from_map(isl.isl_map_copy(args[0].ptr))
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_map_read_from_str(self.ctx, args[0])
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_union_map_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_union_map_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.union_map("%s")' % str(self)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_affine_hull(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def polyhedral_hull(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_polyhedral_hull(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def coalesce(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_coalesce(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def lexmin(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_lexmin(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_lexmax(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def union(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_union(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def subtract(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_subtract(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_intersect(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def intersect_params(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            raise
        res = isl.isl_union_map_intersect_params(isl.isl_union_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_gist(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def gist_params(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            raise
        res = isl.isl_union_map_gist_params(isl.isl_union_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def gist_domain(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_gist_domain(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def gist_range(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_gist_range(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def intersect_domain(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_intersect_domain(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def intersect_range(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_intersect_range(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def subtract_domain(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_subtract_domain(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def subtract_range(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_map_subtract_range(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def apply_domain(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_apply_domain(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def apply_range(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_apply_range(isl.isl_union_map_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def reverse(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_reverse(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_detect_equalities(isl.isl_union_map_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def deltas(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_deltas(isl.isl_union_map_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_is_empty(arg0.ptr)
        return res
    def is_single_valued(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_is_single_valued(arg0.ptr)
        return res
    def is_injective(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_is_injective(arg0.ptr)
        return res
    def is_bijective(arg0):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        res = isl.isl_union_map_is_bijective(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_is_subset(arg0.ptr, arg1.ptr)
        return res
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_is_equal(arg0.ptr, arg1.ptr)
        return res
    def is_strict_subset(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_map_is_strict_subset(arg0.ptr, arg1.ptr)
        return res
    def foreach_map(arg0, arg1):
        try:
            if not arg0.__class__ is union_map:
                arg0 = union_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is stat (isl_map *, void *):
                arg1 = stat (isl_map *, void *)(arg1)
        except:
            raise
        exc_info = [None]
        fn = CFUNCTYPE(c_int, c_void_p, c_void_p)
        def cb_func(cb_arg0, cb_arg1):
            cb_arg0 = map(ctx=arg0.ctx, ptr=cb_arg0)
            try:
                arg1(cb_arg0)
            except:
                import sys
                exc_info[0] = sys.exc_info()
                return -1
            return 0
        cb = fn(cb_func)
        res = isl.isl_union_map_foreach_map(arg0.ptr, cb, None)
        if exc_info[0] != None:
            raise exc_info[0][0], exc_info[0][1], exc_info[0][2]
        return res

isl.isl_union_map_from_basic_map.restype = c_void_p
isl.isl_union_map_from_basic_map.argtypes = [c_void_p]
isl.isl_union_map_from_map.restype = c_void_p
isl.isl_union_map_from_map.argtypes = [c_void_p]
isl.isl_union_map_read_from_str.restype = c_void_p
isl.isl_union_map_read_from_str.argtypes = [Context, c_char_p]
isl.isl_union_map_affine_hull.restype = c_void_p
isl.isl_union_map_polyhedral_hull.restype = c_void_p
isl.isl_union_map_coalesce.restype = c_void_p
isl.isl_union_map_lexmin.restype = c_void_p
isl.isl_union_map_lexmax.restype = c_void_p
isl.isl_union_map_union.restype = c_void_p
isl.isl_union_map_subtract.restype = c_void_p
isl.isl_union_map_intersect.restype = c_void_p
isl.isl_union_map_intersect_params.restype = c_void_p
isl.isl_union_map_gist.restype = c_void_p
isl.isl_union_map_gist_params.restype = c_void_p
isl.isl_union_map_gist_domain.restype = c_void_p
isl.isl_union_map_gist_range.restype = c_void_p
isl.isl_union_map_intersect_domain.restype = c_void_p
isl.isl_union_map_intersect_range.restype = c_void_p
isl.isl_union_map_subtract_domain.restype = c_void_p
isl.isl_union_map_subtract_range.restype = c_void_p
isl.isl_union_map_apply_domain.restype = c_void_p
isl.isl_union_map_apply_range.restype = c_void_p
isl.isl_union_map_reverse.restype = c_void_p
isl.isl_union_map_detect_equalities.restype = c_void_p
isl.isl_union_map_deltas.restype = c_void_p
isl.isl_union_map_free.argtypes = [c_void_p]
isl.isl_union_map_to_str.argtypes = [c_void_p]
isl.isl_union_map_to_str.restype = POINTER(c_char)

class map(union_map):
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_map_read_from_str(self.ctx, args[0])
            return
        if len(args) == 1 and args[0].__class__ is basic_map:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_map_from_basic_map(isl.isl_basic_map_copy(args[0].ptr))
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_map_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_map_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.map("%s")' % str(self)
    def lexmin(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_lexmin(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_lexmax(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def reverse(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_reverse(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def union(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).union(arg1)
        res = isl.isl_map_union(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def intersect_domain(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_map(arg0).intersect_domain(arg1)
        res = isl.isl_map_intersect_domain(isl.isl_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def intersect_range(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_map(arg0).intersect_range(arg1)
        res = isl.isl_map_intersect_range(isl.isl_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def apply_domain(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).apply_domain(arg1)
        res = isl.isl_map_apply_domain(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def apply_range(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).apply_range(arg1)
        res = isl.isl_map_apply_range(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).intersect(arg1)
        res = isl.isl_map_intersect(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def intersect_params(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_map(arg0).intersect_params(arg1)
        res = isl.isl_map_intersect_params(isl.isl_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def subtract(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).subtract(arg1)
        res = isl.isl_map_subtract(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def complement(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_complement(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def deltas(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_deltas(isl.isl_map_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_detect_equalities(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_affine_hull(isl.isl_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def polyhedral_hull(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_polyhedral_hull(isl.isl_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def flatten(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_flatten(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def flatten_domain(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_flatten_domain(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def flatten_range(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_flatten_range(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def sample(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_sample(isl.isl_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_is_empty(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).is_subset(arg1)
        res = isl.isl_map_is_subset(arg0.ptr, arg1.ptr)
        return res
    def is_strict_subset(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).is_strict_subset(arg1)
        res = isl.isl_map_is_strict_subset(arg0.ptr, arg1.ptr)
        return res
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).is_equal(arg1)
        res = isl.isl_map_is_equal(arg0.ptr, arg1.ptr)
        return res
    def is_disjoint(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).is_disjoint(arg1)
        res = isl.isl_map_is_disjoint(arg0.ptr, arg1.ptr)
        return res
    def is_single_valued(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_is_single_valued(arg0.ptr)
        return res
    def is_injective(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_is_injective(arg0.ptr)
        return res
    def is_bijective(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_is_bijective(arg0.ptr)
        return res
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_map(arg0).gist(arg1)
        res = isl.isl_map_gist(isl.isl_map_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def gist_domain(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_map(arg0).gist_domain(arg1)
        res = isl.isl_map_gist_domain(isl.isl_map_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def coalesce(arg0):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        res = isl.isl_map_coalesce(isl.isl_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def foreach_basic_map(arg0, arg1):
        try:
            if not arg0.__class__ is map:
                arg0 = map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is stat (isl_basic_map *, void *):
                arg1 = stat (isl_basic_map *, void *)(arg1)
        except:
            return union_map(arg0).foreach_basic_map(arg1)
        exc_info = [None]
        fn = CFUNCTYPE(c_int, c_void_p, c_void_p)
        def cb_func(cb_arg0, cb_arg1):
            cb_arg0 = basic_map(ctx=arg0.ctx, ptr=cb_arg0)
            try:
                arg1(cb_arg0)
            except:
                import sys
                exc_info[0] = sys.exc_info()
                return -1
            return 0
        cb = fn(cb_func)
        res = isl.isl_map_foreach_basic_map(arg0.ptr, cb, None)
        if exc_info[0] != None:
            raise exc_info[0][0], exc_info[0][1], exc_info[0][2]
        return res

isl.isl_map_read_from_str.restype = c_void_p
isl.isl_map_read_from_str.argtypes = [Context, c_char_p]
isl.isl_map_from_basic_map.restype = c_void_p
isl.isl_map_from_basic_map.argtypes = [c_void_p]
isl.isl_map_lexmin.restype = c_void_p
isl.isl_map_lexmax.restype = c_void_p
isl.isl_map_reverse.restype = c_void_p
isl.isl_map_union.restype = c_void_p
isl.isl_map_intersect_domain.restype = c_void_p
isl.isl_map_intersect_range.restype = c_void_p
isl.isl_map_apply_domain.restype = c_void_p
isl.isl_map_apply_range.restype = c_void_p
isl.isl_map_intersect.restype = c_void_p
isl.isl_map_intersect_params.restype = c_void_p
isl.isl_map_subtract.restype = c_void_p
isl.isl_map_complement.restype = c_void_p
isl.isl_map_deltas.restype = c_void_p
isl.isl_map_detect_equalities.restype = c_void_p
isl.isl_map_affine_hull.restype = c_void_p
isl.isl_map_polyhedral_hull.restype = c_void_p
isl.isl_map_flatten.restype = c_void_p
isl.isl_map_flatten_domain.restype = c_void_p
isl.isl_map_flatten_range.restype = c_void_p
isl.isl_map_sample.restype = c_void_p
isl.isl_map_gist.restype = c_void_p
isl.isl_map_gist_domain.restype = c_void_p
isl.isl_map_coalesce.restype = c_void_p
isl.isl_map_free.argtypes = [c_void_p]
isl.isl_map_to_str.argtypes = [c_void_p]
isl.isl_map_to_str.restype = POINTER(c_char)

class basic_map(map):
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_basic_map_read_from_str(self.ctx, args[0])
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_basic_map_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_basic_map_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.basic_map("%s")' % str(self)
    def intersect_domain(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return map(arg0).intersect_domain(arg1)
        res = isl.isl_basic_map_intersect_domain(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def intersect_range(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return map(arg0).intersect_range(arg1)
        res = isl.isl_basic_map_intersect_range(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).intersect(arg1)
        res = isl.isl_basic_map_intersect(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def union(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).union(arg1)
        res = isl.isl_basic_map_union(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def apply_domain(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).apply_domain(arg1)
        res = isl.isl_basic_map_apply_domain(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def apply_range(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).apply_range(arg1)
        res = isl.isl_basic_map_apply_range(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_affine_hull(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def reverse(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_reverse(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def sample(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_sample(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_detect_equalities(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).is_equal(arg1)
        res = isl.isl_basic_map_is_equal(arg0.ptr, arg1.ptr)
        return res
    def lexmin(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_lexmin(isl.isl_basic_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_lexmax(isl.isl_basic_map_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_is_empty(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).is_subset(arg1)
        res = isl.isl_basic_map_is_subset(arg0.ptr, arg1.ptr)
        return res
    def deltas(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_deltas(isl.isl_basic_map_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def flatten(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_flatten(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def flatten_domain(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_flatten_domain(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def flatten_range(arg0):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        res = isl.isl_basic_map_flatten_range(isl.isl_basic_map_copy(arg0.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is basic_map:
                arg0 = basic_map(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return map(arg0).gist(arg1)
        res = isl.isl_basic_map_gist(isl.isl_basic_map_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return basic_map(ctx=arg0.ctx, ptr=res)

isl.isl_basic_map_read_from_str.restype = c_void_p
isl.isl_basic_map_read_from_str.argtypes = [Context, c_char_p]
isl.isl_basic_map_intersect_domain.restype = c_void_p
isl.isl_basic_map_intersect_range.restype = c_void_p
isl.isl_basic_map_intersect.restype = c_void_p
isl.isl_basic_map_union.restype = c_void_p
isl.isl_basic_map_apply_domain.restype = c_void_p
isl.isl_basic_map_apply_range.restype = c_void_p
isl.isl_basic_map_affine_hull.restype = c_void_p
isl.isl_basic_map_reverse.restype = c_void_p
isl.isl_basic_map_sample.restype = c_void_p
isl.isl_basic_map_detect_equalities.restype = c_void_p
isl.isl_basic_map_lexmin.restype = c_void_p
isl.isl_basic_map_lexmax.restype = c_void_p
isl.isl_basic_map_deltas.restype = c_void_p
isl.isl_basic_map_flatten.restype = c_void_p
isl.isl_basic_map_flatten_domain.restype = c_void_p
isl.isl_basic_map_flatten_range.restype = c_void_p
isl.isl_basic_map_gist.restype = c_void_p
isl.isl_basic_map_free.argtypes = [c_void_p]
isl.isl_basic_map_to_str.argtypes = [c_void_p]
isl.isl_basic_map_to_str.restype = POINTER(c_char)

class union_set:
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and args[0].__class__ is basic_set:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_set_from_basic_set(isl.isl_basic_set_copy(args[0].ptr))
            return
        if len(args) == 1 and args[0].__class__ is set:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_set_from_set(isl.isl_set_copy(args[0].ptr))
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_union_set_read_from_str(self.ctx, args[0])
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_union_set_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_union_set_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.union_set("%s")' % str(self)
    def identity(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_identity(isl.isl_union_set_copy(arg0.ptr))
        return union_map(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_detect_equalities(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_affine_hull(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def polyhedral_hull(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_polyhedral_hull(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def coalesce(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_coalesce(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def lexmin(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_lexmin(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_lexmax(isl.isl_union_set_copy(arg0.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def subtract(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_subtract(isl.isl_union_set_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_intersect(isl.isl_union_set_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def intersect_params(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            raise
        res = isl.isl_union_set_intersect_params(isl.isl_union_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_gist(isl.isl_union_set_copy(arg0.ptr), isl.isl_union_set_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def gist_params(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            raise
        res = isl.isl_union_set_gist_params(isl.isl_union_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def apply(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_map:
                arg1 = union_map(arg1)
        except:
            raise
        res = isl.isl_union_set_apply(isl.isl_union_set_copy(arg0.ptr), isl.isl_union_map_copy(arg1.ptr))
        return union_set(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        res = isl.isl_union_set_is_empty(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_is_subset(arg0.ptr, arg1.ptr)
        return res
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_is_equal(arg0.ptr, arg1.ptr)
        return res
    def is_strict_subset(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is union_set:
                arg1 = union_set(arg1)
        except:
            raise
        res = isl.isl_union_set_is_strict_subset(arg0.ptr, arg1.ptr)
        return res
    def foreach_set(arg0, arg1):
        try:
            if not arg0.__class__ is union_set:
                arg0 = union_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is stat (isl_set *, void *):
                arg1 = stat (isl_set *, void *)(arg1)
        except:
            raise
        exc_info = [None]
        fn = CFUNCTYPE(c_int, c_void_p, c_void_p)
        def cb_func(cb_arg0, cb_arg1):
            cb_arg0 = set(ctx=arg0.ctx, ptr=cb_arg0)
            try:
                arg1(cb_arg0)
            except:
                import sys
                exc_info[0] = sys.exc_info()
                return -1
            return 0
        cb = fn(cb_func)
        res = isl.isl_union_set_foreach_set(arg0.ptr, cb, None)
        if exc_info[0] != None:
            raise exc_info[0][0], exc_info[0][1], exc_info[0][2]
        return res

isl.isl_union_set_from_basic_set.restype = c_void_p
isl.isl_union_set_from_basic_set.argtypes = [c_void_p]
isl.isl_union_set_from_set.restype = c_void_p
isl.isl_union_set_from_set.argtypes = [c_void_p]
isl.isl_union_set_read_from_str.restype = c_void_p
isl.isl_union_set_read_from_str.argtypes = [Context, c_char_p]
isl.isl_union_set_identity.restype = c_void_p
isl.isl_union_set_detect_equalities.restype = c_void_p
isl.isl_union_set_affine_hull.restype = c_void_p
isl.isl_union_set_polyhedral_hull.restype = c_void_p
isl.isl_union_set_coalesce.restype = c_void_p
isl.isl_union_set_lexmin.restype = c_void_p
isl.isl_union_set_lexmax.restype = c_void_p
isl.isl_union_set_subtract.restype = c_void_p
isl.isl_union_set_intersect.restype = c_void_p
isl.isl_union_set_intersect_params.restype = c_void_p
isl.isl_union_set_gist.restype = c_void_p
isl.isl_union_set_gist_params.restype = c_void_p
isl.isl_union_set_apply.restype = c_void_p
isl.isl_union_set_free.argtypes = [c_void_p]
isl.isl_union_set_to_str.argtypes = [c_void_p]
isl.isl_union_set_to_str.restype = POINTER(c_char)

class set(union_set):
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_set_read_from_str(self.ctx, args[0])
            return
        if len(args) == 1 and args[0].__class__ is basic_set:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_set_from_basic_set(isl.isl_basic_set_copy(args[0].ptr))
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_set_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_set_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.set("%s")' % str(self)
    def lexmin(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_lexmin(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_lexmax(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def sample(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_sample(isl.isl_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_detect_equalities(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_affine_hull(isl.isl_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def polyhedral_hull(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_polyhedral_hull(isl.isl_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def union(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).union(arg1)
        res = isl.isl_set_union(isl.isl_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).intersect(arg1)
        res = isl.isl_set_intersect(isl.isl_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def intersect_params(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).intersect_params(arg1)
        res = isl.isl_set_intersect_params(isl.isl_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def subtract(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).subtract(arg1)
        res = isl.isl_set_subtract(isl.isl_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def complement(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_complement(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def apply(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is map:
                arg1 = map(arg1)
        except:
            return union_set(arg0).apply(arg1)
        res = isl.isl_set_apply(isl.isl_set_copy(arg0.ptr), isl.isl_map_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_is_empty(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).is_subset(arg1)
        res = isl.isl_set_is_subset(arg0.ptr, arg1.ptr)
        return res
    def is_strict_subset(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).is_strict_subset(arg1)
        res = isl.isl_set_is_strict_subset(arg0.ptr, arg1.ptr)
        return res
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).is_equal(arg1)
        res = isl.isl_set_is_equal(arg0.ptr, arg1.ptr)
        return res
    def is_disjoint(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).is_disjoint(arg1)
        res = isl.isl_set_is_disjoint(arg0.ptr, arg1.ptr)
        return res
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is set:
                arg1 = set(arg1)
        except:
            return union_set(arg0).gist(arg1)
        res = isl.isl_set_gist(isl.isl_set_copy(arg0.ptr), isl.isl_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def coalesce(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_coalesce(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def foreach_basic_set(arg0, arg1):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is stat (isl_basic_set *, void *):
                arg1 = stat (isl_basic_set *, void *)(arg1)
        except:
            return union_set(arg0).foreach_basic_set(arg1)
        exc_info = [None]
        fn = CFUNCTYPE(c_int, c_void_p, c_void_p)
        def cb_func(cb_arg0, cb_arg1):
            cb_arg0 = basic_set(ctx=arg0.ctx, ptr=cb_arg0)
            try:
                arg1(cb_arg0)
            except:
                import sys
                exc_info[0] = sys.exc_info()
                return -1
            return 0
        cb = fn(cb_func)
        res = isl.isl_set_foreach_basic_set(arg0.ptr, cb, None)
        if exc_info[0] != None:
            raise exc_info[0][0], exc_info[0][1], exc_info[0][2]
        return res
    def identity(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_identity(isl.isl_set_copy(arg0.ptr))
        return map(ctx=arg0.ctx, ptr=res)
    def is_wrapping(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_is_wrapping(arg0.ptr)
        return res
    def flatten(arg0):
        try:
            if not arg0.__class__ is set:
                arg0 = set(arg0)
        except:
            raise
        res = isl.isl_set_flatten(isl.isl_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)

isl.isl_set_read_from_str.restype = c_void_p
isl.isl_set_read_from_str.argtypes = [Context, c_char_p]
isl.isl_set_from_basic_set.restype = c_void_p
isl.isl_set_from_basic_set.argtypes = [c_void_p]
isl.isl_set_lexmin.restype = c_void_p
isl.isl_set_lexmax.restype = c_void_p
isl.isl_set_sample.restype = c_void_p
isl.isl_set_detect_equalities.restype = c_void_p
isl.isl_set_affine_hull.restype = c_void_p
isl.isl_set_polyhedral_hull.restype = c_void_p
isl.isl_set_union.restype = c_void_p
isl.isl_set_intersect.restype = c_void_p
isl.isl_set_intersect_params.restype = c_void_p
isl.isl_set_subtract.restype = c_void_p
isl.isl_set_complement.restype = c_void_p
isl.isl_set_apply.restype = c_void_p
isl.isl_set_gist.restype = c_void_p
isl.isl_set_coalesce.restype = c_void_p
isl.isl_set_identity.restype = c_void_p
isl.isl_set_flatten.restype = c_void_p
isl.isl_set_free.argtypes = [c_void_p]
isl.isl_set_to_str.argtypes = [c_void_p]
isl.isl_set_to_str.restype = POINTER(c_char)

class basic_set(set):
    def __init__(self, *args, **keywords):
        if "ptr" in keywords:
            self.ctx = keywords["ctx"]
            self.ptr = keywords["ptr"]
            return
        if len(args) == 1 and type(args[0]) == str:
            self.ctx = Context.getDefaultInstance()
            self.ptr = isl.isl_basic_set_read_from_str(self.ctx, args[0])
            return
        raise Error
    def __del__(self):
        if hasattr(self, 'ptr'):
            isl.isl_basic_set_free(self.ptr)
    def __str__(self):
        ptr = isl.isl_basic_set_to_str(self.ptr)
        res = str(cast(ptr, c_char_p).value)
        libc.free(ptr)
        return res
    def __repr__(self):
        return 'isl.basic_set("%s")' % str(self)
    def intersect(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).intersect(arg1)
        res = isl.isl_basic_set_intersect(isl.isl_basic_set_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def intersect_params(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).intersect_params(arg1)
        res = isl.isl_basic_set_intersect_params(isl.isl_basic_set_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def apply(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_map:
                arg1 = basic_map(arg1)
        except:
            return set(arg0).apply(arg1)
        res = isl.isl_basic_set_apply(isl.isl_basic_set_copy(arg0.ptr), isl.isl_basic_map_copy(arg1.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def affine_hull(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_affine_hull(isl.isl_basic_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def sample(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_sample(isl.isl_basic_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def detect_equalities(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_detect_equalities(isl.isl_basic_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def is_equal(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).is_equal(arg1)
        res = isl.isl_basic_set_is_equal(arg0.ptr, arg1.ptr)
        return res
    def lexmin(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_lexmin(isl.isl_basic_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def lexmax(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_lexmax(isl.isl_basic_set_copy(arg0.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def union(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).union(arg1)
        res = isl.isl_basic_set_union(isl.isl_basic_set_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return set(ctx=arg0.ctx, ptr=res)
    def is_empty(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_is_empty(arg0.ptr)
        return res
    def is_subset(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).is_subset(arg1)
        res = isl.isl_basic_set_is_subset(arg0.ptr, arg1.ptr)
        return res
    def gist(arg0, arg1):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        try:
            if not arg1.__class__ is basic_set:
                arg1 = basic_set(arg1)
        except:
            return set(arg0).gist(arg1)
        res = isl.isl_basic_set_gist(isl.isl_basic_set_copy(arg0.ptr), isl.isl_basic_set_copy(arg1.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)
    def is_wrapping(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_is_wrapping(arg0.ptr)
        return res
    def flatten(arg0):
        try:
            if not arg0.__class__ is basic_set:
                arg0 = basic_set(arg0)
        except:
            raise
        res = isl.isl_basic_set_flatten(isl.isl_basic_set_copy(arg0.ptr))
        return basic_set(ctx=arg0.ctx, ptr=res)

isl.isl_basic_set_read_from_str.restype = c_void_p
isl.isl_basic_set_read_from_str.argtypes = [Context, c_char_p]
isl.isl_basic_set_intersect.restype = c_void_p
isl.isl_basic_set_intersect_params.restype = c_void_p
isl.isl_basic_set_apply.restype = c_void_p
isl.isl_basic_set_affine_hull.restype = c_void_p
isl.isl_basic_set_sample.restype = c_void_p
isl.isl_basic_set_detect_equalities.restype = c_void_p
isl.isl_basic_set_lexmin.restype = c_void_p
isl.isl_basic_set_lexmax.restype = c_void_p
isl.isl_basic_set_union.restype = c_void_p
isl.isl_basic_set_gist.restype = c_void_p
isl.isl_basic_set_flatten.restype = c_void_p
isl.isl_basic_set_free.argtypes = [c_void_p]
isl.isl_basic_set_to_str.argtypes = [c_void_p]
isl.isl_basic_set_to_str.restype = POINTER(c_char)
