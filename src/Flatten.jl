module Flatten

using Tags, Nested, Unitful

export @flattenable, @reflattenable, flattenable, flatten, construct, reconstruct, retype, update!, 
       tagflatten, fieldname_tag, fieldparent_tag, fieldtype_tag, fieldparenttype_tag

@tag flattenable true


flatten_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        flatten(getfield($path, $(QuoteNode(fname))))
    else
        ()
    end
end

flatten_inner(T) = nested(T, :t, flatten_expr)

"Flattening. Flattens a nested type to a Tuple or Vector"
flatten(::Type{V}, t) where V <: AbstractVector = V([flatten(t)...])
flatten(::Type{Tuple}, t) = flatten(t)
flatten(x::Nothing) = ()
flatten(x::Number) = (x,) 
flatten(x::Unitful.Quantity) = (x.val,) 
@generated flatten(t) = flatten_inner(t)


tagflatten_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        tagflatten(getfield($path, $(QuoteNode(fname))), func, $T, Val{$(QuoteNode(fname))})
    else
        ()
    end
end
tagflatten_inner(T::Type) = nested(T, :t, tagflatten_expr)

" Tag flattening. Flattens data attached to a field by methods of a passed in function"
tagflatten(::Type{Tuple}, t, func) = tagflatten(t, func)
tagflatten(::Type{V}, t, func) where V <: AbstractVector = [tagflatten(t, func)...]
tagflatten(x::Nothing, func, P, fname) = ()
tagflatten(x::Number, func, P, fname) = (func(P, fname),)
tagflatten(t, func) = tagflatten(t, func, Nothing, Val{:none})
@generated tagflatten(t, func, P, fname) = tagflatten_inner(t)

# # Helper functions to get field data with tagflatten
fieldname_tag(T, ::Type{Val{N}}) where N = N
fieldtype_tag(T, ::Type{Val{N}}) where N = fieldtype(T, N)
fieldparent_tag(T, ::Type{Val{N}}) where N = T.name.name
fieldparenttype_tag(T, ::Type{Val{N}}) where N = T 


reconstruct_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        val, n = reconstruct(getfield($path, $(QuoteNode(fname))), data, n)
        val
    else
        (getfield($path, $(QuoteNode(fname))),)
    end
end

reconstruct_handler(T, expressions) = :(($(Expr(:call, :($T), expressions...)),), n)
reconstruct_handler(T::Type{<:Tuple}, expressions) = :(($(Expr(:tuple, expressions...)),), n)

reconstruct_inner(::Type{T}) where T = nested(T, :t, reconstruct_expr, reconstruct_handler)

" Reconstruct an object from partial Tuple or Vector data and another object"
reconstruct(t, data) = reconstruct(t, data, 1)[1][1]
reconstruct(::Nothing, data, n) = (nothing,), n
reconstruct(::Number, data, n) = (data[n],), n + 1 
reconstruct(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated reconstruct(t, data, n) = reconstruct_inner(t)

retype_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        val, n = reconstruct(getfield($path, $(QuoteNode(fname))), data, n)
        val
    else
        (getfield($path, $(QuoteNode(fname))),)
    end
end

retype_handler(T, expressions) = :(($(Expr(:call, :($T.name.wrapper), expressions...)),), n)
retype_handler(T::Type{<:Tuple}, expressions) = :(($(Expr(:tuple, expressions...)),), n)

retype_inner(::Type{T}) where T = nested(T, :t, retype_expr, retype_handler)

" Retype an object from partial Tuple or Vector data and another object"
retype(t, data) = retype(t, data, 1)[1][1]
retype(::Nothing, data, n) = (nothing,), n
retype(::Number, data, n) = (data[n],), n + 1 
retype(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated retype(t, data, n) = retype_inner(t)


update_expr(T, path, fname) = quote
    if flattenable($T, Val{$(QuoteNode(fname))})
        val, n = update!(getfield($path, $(QuoteNode(fname))), data, n)
        setfield!($path, $(QuoteNode(fname)), val[1]) 
        ()
    end
end

update_handler(T, expressions) = :($(Expr(:tuple, :t, expressions...)), n)
update_handler(T::Type{<:Tuple}, expressions) = :(($(Expr(:tuple, expressions...)),), n)
update_inner(::Type{T}) where T = nested(T, :t, update_expr, update_handler)

" Update a mutable object with partial Tuple or Vector data"
update!(t, data) = begin
    update!(t, data, 1)
    t
end
update!(::Nothing, data, n) = (nothing,), n
update!(::Number, data, n) = (data[n],), n + 1 
update!(::T, data, n) where T <: Unitful.Quantity = (unit(T) * data[n],), n + 1
@generated update!(t, data, n) = update_inner(t)

end # module
