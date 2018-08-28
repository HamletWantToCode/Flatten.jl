using Flatten, BenchmarkTools, Tags, Unitful, Test
import Flatten: flattenable

struct Foo{T}
    a::T
    b::T
    c::T
end

struct Nest{T1, T2}
    nf::Foo{T1}
    nb::T2
    nc::T2
end

struct NestTuple{T1, T2, T3, T4}
    nf::Tuple{Foo{T1},Nest{T2,T3}}
    nb::T4
    nc::T4
end

mutable struct MuFoo{T}
    a::T
    b::T
    c::T
end

mutable struct MuNest{T1, T2}
    nf::MuFoo{T1}
    nb::T2
    nc::T2
end


foo = Foo(1.0, 2.0, 3.0)
nest = Nest(Foo(1,2,3), 4.0, 5.0)
nesttuple = NestTuple((foo, nest), 9, 10)

@test flatten(Vector, Foo(1,2,3)) == Int[1,2,3]
@test typeof(flatten(Vector, Foo(1,2,3))) == Array{Int, 1}
@test flatten(Tuple, Foo(1,2,3)) == (1,2,3)
@test flatten(Tuple, ((1,2,3), (4,5))) == (1,2,3,4,5)
@test flatten(Tuple, Nest(Foo(1,2,3),4,5)) == (1,2,3,4,5)
@test flatten(Tuple, (Nest(Foo(1,2,3),4,5), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4,5,6,7,8,9,10)
@test flatten(Tuple, Nest(Foo(1,2,3), (4,5), (6,7))) == (1,2,3,4,5,6,7)

@test flatten(Vector, reconstruct(foo, flatten(Vector, foo))) == flatten(Vector, foo)
@test flatten(Tuple, reconstruct(foo, flatten(Tuple, foo))) == flatten(Tuple, foo)

mufoo = MuFoo(1.0, 2.0, 3.0)
@test flatten(Tuple, update!(mufoo, flatten(Tuple, mufoo) .* 7)) == (7.0, 14.0, 21.0)
munest = MuNest(MuFoo(1,2,3), 4.0, 5.0)
@test flatten(update!(munest, flatten(munest) .* 7)) == (7.0, 14.0, 21.0, 28.0, 35.0)

# Test nested types and tuples
@test flatten(Vector, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == Float64[1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0]
@test flatten(Tuple, (Nest(Foo(1,2,3),4.0,5.0), Nest(Foo(6,7,8), 9, 10))) == (1,2,3,4.0,5.0,6,7,8,9,10)
@test flatten(Tuple, reconstruct(nest, flatten(Tuple, nest))) == flatten(Tuple, nest)
@test flatten(Tuple, reconstruct((nest, nest), flatten(Tuple, (nest, nest)))) == flatten(Tuple, (nest, nest))
@test flatten(Tuple, reconstruct(nesttuple, flatten(Tuple, nesttuple))) == flatten(Tuple, nesttuple)

@test typeof(reconstruct(foo, flatten(Tuple, foo))) <: Foo
@test typeof(reconstruct(nest, flatten(Tuple, nest))) <: Nest


# Partial fields with @flattenable

@tag foobar :nobar

@flattenable @foobar struct Partial{T}
    " Field a"
    a::T | :foo | Include()
    " Field b"
    b::T | :foo | Include()
    " Field c"
    c::T | :foo | Exclude()
end

@flattenable @foobar struct NestedPartial{P,T}
    " Field np"
    np::P | :bar | Include()
    " Field nb"
    nb::T | :bar | Include()
    " Field nc"
    nc::T | :bar | Exclude()
end

partial = Partial(1.0, 2.0, 3.0)
nestedpartial = NestedPartial(Partial(1.0, 2.0, 3.0), 4, 5) 
Flatten.flatten_inner(typeof(nestedpartial))
@test flatten(Vector, nestedpartial) == [1.0, 2.0, 4.0]
@test flatten(Tuple, nestedpartial) === (1.0, 2.0, 4)
# It's not clear if this should actually work or not.
# It may just be that fields sharing a type both need to be Include() or Exclude()
# and mixing is disallowed for Vector.
@test_broken flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flattenable(nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)


# Tag flattening
@test tagflatten(partial, foobar) == (:foo, :foo)
@test tagflatten(nestedpartial, foobar) == (:foo, :foo, :bar)
@test tagflatten((nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test tagflatten(Tuple, (nestedpartial, partial), foobar) == (:foo, :foo, :bar, :foo, :foo)
@test tagflatten(Vector, (nestedpartial, partial), foobar) == [:foo, :foo, :bar, :foo, :foo]
@test tagflatten(Vector, (nestedpartial, partial), fieldname_tag) == [:a, :b, :nb, :a, :b]
@test tagflatten(Vector, (nestedpartial, partial), fieldparenttype_tag) == DataType[Partial{Float64}, Partial{Float64}, NestedPartial{Partial{Float64},Int64}, Partial{Float64}, Partial{Float64}]
@test tagflatten(Vector, (nestedpartial, partial), fieldparent_tag) == Symbol[:Partial, :Partial, :NestedPartial, :Partial, :Partial]
@test tagflatten(Vector, (nestedpartial, partial), fieldtype_tag) == [Float64, Float64, Int64, Float64, Float64]


# Updating tags updates flattened fields
@reflattenable @refoobar struct Partial{T}
    a::T | :bar | Exclude()
    b::T | :bar | Exclude()
    c::T | :foo | Include()   
end

@reflattenable @refoobar struct NestedPartial{P,T}
    nb::T | :bar | Exclude() 
    nc::T | :foo | Include()    
end

@test flatten(Vector, nestedpartial) == [3.0, 5.0]
@test flatten(Tuple, nestedpartial) == (3.0, 5.0)
@test flatten(Vector, reconstruct(nestedpartial, flatten(Vector, nestedpartial))) == flatten(Vector, nestedpartial)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)
@inferred flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial)))

@test tagflatten(foo, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include())
@test tagflatten(nest, flattenable) == (Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include(), Flatten.Include())
@test tagflatten(partial, foobar) == (:foo,)
@test tagflatten(nestedpartial, foobar) == (:foo, :foo)

@test tagflatten(foo, fieldname_tag) == (:a, :b, :c)
@test tagflatten(nest, fieldname_tag) == (:a, :b, :c, :nb, :nc)
@test tagflatten(nestedpartial, fieldname_tag) == (:c, :nc)


# Test non-parametric types
mutable struct AnyPoint
    x
    y
end
anypoint = AnyPoint(1,2)
@test flatten(Tuple, anypoint) == (1,2)
@test flatten(Tuple, reconstruct(anypoint, (1,2))) == (1,2)


# With units
partialunits = Partial(1.0u"s", 2.0u"s", 3.0u"s")
nestedunits = NestedPartial(Partial(1.0u"km", 2.0u"km", 3.0u"km"), 4.0u"g", 5.0u"g") 
@test flatten(Vector, partialunits) == [3.0]
@test flatten(Vector, reconstruct(partialunits, flatten(Vector, partialunits))) == flatten(Vector, partialunits)
@test flatten(Tuple, reconstruct(partialunits, flatten(Tuple, partialunits))) == flatten(Tuple, partialunits)
@test flatten(Vector, reconstruct(nestedunits, flatten(Vector, nestedunits))) == flatten(Vector, nestedunits)
@test flatten(Tuple, reconstruct(nestedunits, flatten(Tuple, nestedunits))) == flatten(Tuple, nestedunits)
@inferred flatten(Tuple, reconstruct(nestedunits, flatten(Tuple, nestedunits))) == flatten(Tuple, nestedunits)
@test flatten(Tuple, reconstruct(nestedpartial, flatten(Tuple, nestedpartial))) == flatten(Tuple, nestedpartial)

# With void
nestvoid = Nest(Foo(1,2,3), nothing, nothing)
@test flatten(Tuple, nestvoid) == (1,2,3)
@test flatten(Tuple, (Nest(Foo(1,2,3), nothing, nothing), Nest(Foo(nothing, nothing, nothing), 9, 10))) == (1,2,3,9,10)
@test flatten(Tuple, reconstruct(nestvoid, flatten(Tuple, nestvoid))) == flatten(Tuple, nestvoid) 

##############################################################################
# Benchmarks

function flatten_naive_vector(obj)
    v = Vector{Float64}(length(fieldnames(typeof(obj))))
    for (i, field) in enumerate(fieldnames(typeof(obj)))
        v[i] = getfield(obj, field)
    end
    v
end

function flatten_naive_tuple(obj)
    v = (map(field -> getfield(obj, field), fieldnames(typeof(obj)))...,)
end

function construct_vector_naive(T, data)
    T(data...)
end

@test flatten_naive_vector(foo) == flatten(Vector, foo)
@test flatten_naive_tuple(foo) == flatten(Tuple, foo)

foo = Foo(1.0, 2.0, 3.0)
datavector = flatten(Vector, foo)
datatuple = flatten(Tuple, foo)

print("flatten to vector: ")
@btime flatten(Vector, $foo)
print("flatten to vector naive: ")
@btime flatten_naive_vector($foo)
print("flatten to tuple: ")
@btime flatten(Tuple, $foo)
print("flatten to tuple naive: ")
@btime flatten_naive_tuple($foo)
print("reconstruct vector: ")
@btime reconstruct($foo, $datavector)
print("reconstruct vector naive: ")
@btime construct_vector_naive(Foo{Float64}, $datavector)
