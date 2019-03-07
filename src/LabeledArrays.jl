module LabeledArrays
using Random

export LabeledArray
export labels

struct LabeledArray{T, N, A <: AbstractArray{T, N}, Names} <: AbstractArray{T, N}
    data::A
end

function LabeledArray{Names}(data::AbstractArray{T, N}) where {T, N, Names}
    names = generate_axis_names(Names, Val{ndims(data)}())
    LabeledArray{T, N, typeof(data), names}(data)
end
function LabeledArray(data::AbstractArray{T, N1},
                      names::NTuple{N2, Symbol}) where {T, N1, N2}
    LabeledArray{T, N1, typeof(data), generate_axis_names(names, Val{N1}())}(data)
end
LabeledArray(data::AbstractArray) = LabeledArray(data, labels(data))

const LabelledArray = LabeledArray # for the brit inside each of us

Base.IndexStyle(array::LabeledArray) = Base.IndexStyle(parent(array))
function Base.IndexStyle(array::Type{<: LabeledArray{T, N, A}}) where {T, N, A}
    Base.IndexStyle(A)
end

""" Original array wrapped by the LabeledArray. """
Base.parent(array::LabeledArray) = array.data
Base.parent(::Type{LabeledArray{T, N, A, M}}) where {T, N, A, M} = A
Base.size(array::LabeledArray) = size(parent(array))
labeled_size(array::LabeledArray) = NamedTuple{labels(array)}(size(parent(array)))
Base.size(a::LabeledArray, axis::Symbol) = getproperty(labeled_size(a), axis)
labeled_axes(array::LabeledArray) = NamedTuple{labels(array)}(axes(parent(array)))
Base.axes(a::LabeledArray, axis::Symbol) = getproperty(labeled_axes(a), axis)

""" Labels attached to the axis of an array """
@inline labels(array::LabeledArray{T, N, A, S}) where {T, N, A, S} = S
@inline labels(array::Type{LabeledArray{T, N, A, S}}) where {T, N, A, S} = S
@inline labels(array::AbstractArray) = AUTO_AXIS_NAMES[1:ndims(array)]
@inline labels(array::LabeledArray{T, N, A, S}, i::Integer) where {T, N, A, S} = S[i]
@inline labels(array::Type{LabeledArray{T, N, A, S}}, i::Integer) where {T, N, A, S} = S[i]
@inline labels(array::AbstractArray, i::Integer) = AUTO_AXIS_NAMES[i]
@inline labels(i::Integer) = AUTO_AXIS_NAMES[i]

abstract type IndexType end
struct DecayingIndex  <: IndexType end
struct VectorIndex  <: IndexType end

""" Trait defining whether an index decays the dimension of the array """
IndexType(array::AbstractArray, scalar::Any) = IndexType(typeof(array), typeof(scalar))
IndexType(::Type{<:AbstractArray}, ::Type) = VectorIndex()
IndexType(::Type{<:AbstractArray}, ::Type{<:Number}) = DecayingIndex()
IndexType(::Type{<:AbstractArray}, ::Type{<:AbstractString}) = DecayingIndex()
IndexType(::Type{<:AbstractArray}, ::Type{<:AbstractChar}) = DecayingIndex()
IndexType(::Type{<:AbstractArray}, ::Type{<:Symbol}) = DecayingIndex()

""" Tuple of remaining axes

Also relables automated names to their location in the auto label list.
"""
function remaining_labels(array::Type{<:AbstractArray}, axes::Type{<:NamedTuple})
    names = fieldnames(axes)
    types = fieldtypes(axes)
    tuple((n in AUTO_AXIS_NAMES ? AUTO_AXIS_NAMES[i] : n
           for (i, (n, t)) in enumerate(zip(names, types))
           if IndexType(array, t) isa VectorIndex)...)
end

""" Auto-generated axis name.

In practice, each name is paired with a single axis number. E.g. axis 1 will always have the
same name across a session. However, form one session to the next, the names may change.
"""
const AUTO_AXIS_NAMES = let
    names = ("lapin", "rat", "corbeau", "cochon", "saumon", "cafard", "dauphin")
    attributes = ("rose", "noir", "abile", "séché", "salubre", "émue", "sucré")
    a = [Symbol("_" * name * "_" * attribute) for name in names, attribute in attributes]
    tuple(shuffle(a)...)
end

""" Creates the full set of indices for the array """
function Base.to_indices(array::LabeledArray, indices::NamedTuple)
    if @generated
        inames = fieldnames(indices)

        getname(name, i) = begin
            if name in inames
                :($name = indices.$name)
            elseif AUTO_AXIS_NAMES[i] in inames
                :($name = indices.$(AUTO_AXIS_NAMES[i]))
            else
                :($name = Colon())
            end
        end

        items = [getname(name, i) for (i, name) in enumerate(labels(array))]
        extras = [:($name=indices.$name) for name in inames if !(name in labels(array))]
        Expr(:tuple, items..., extras...)
    else
        Names = labels(array)
        N = ndims(array)
        merge(
            NamedTuple{Names, NTuple{N, Colon}}(ntuple((_) -> (:), Val{N}())),
            indices
        )
    end
end

""" Generate a tuple of labels of length N2

Auto generates name or truncates initial tuple, as required.
"""
function generate_axis_names(initial::NTuple{N1, Symbol},
                             ::Val{N2})::NTuple{N2, Symbol} where {N1, N2}
    if @generated
        Expr(:tuple,
             (:(initial[$i]) for i in 1:min(N2, N1))...,
             (QuoteNode(AUTO_AXIS_NAMES[i]) for i in N1 + 1:N2)...
        )
    elseif N1 == N2
        initial
    elseif N1 < N2
        tuple(initial..., AUTO_AXIS_NAMES[N1 + 1:N2]...)
    else
        initial[1:N2]
    end
end

function generate_axis_names(array::LabeledArray, val::Val)
    generate_axis_names(labels(array), val)
end

Base.getindex(array::LabeledArray; kwargs...) = getindex(array, kwargs.data)
function Base.getindex(array::LabeledArray, index::Union{Int, CartesianIndex})
    getindex(parent(array), index)
end
function Base.getindex(array::LabeledArray, I...)
    indices = NamedTuple{generate_axis_names(array, Val{length(I)}())}(I)
    getindex(array, indices)
end
function Base.getindex(array::LabeledArray, indices::NamedTuple)
    fullinds = to_indices(array, indices)
    newdata = getindex(parent(array), values(fullinds)...)
    _get_index(array, newdata, fullinds)
end
_get_index(array::LabeledArray{T}, newdata::T, ::NamedTuple) where T = newdata
function _get_index(array::LabeledArray, newdata::AbstractArray, indices::NamedTuple)
    if @generated
        names = remaining_labels(array, indices)
        T  = eltype(newdata)
        :(LabeledArray{$T, $(ndims(newdata)), $newdata, $names}(newdata))
    else
        LabeledArray(newdata, remaining_labels(typeof(array), typeof(indices)))
    end
end

Base.view(array::LabeledArray; kwargs...) = view(array, kwargs.data)
Base.view(array::LabeledArray, index::Int) = view(parent(array), index)
function Base.view(array::LabeledArray, I...)
    indices = NamedTuple{generate_axis_names(array, Val{length(I)}())}(I)
    view(array, indices)
end
function Base.view(array::LabeledArray, indices::NamedTuple)
    fullinds = to_indices(array, indices)
    newdata = view(parent(array), values(fullinds)...)
    _view(array, newdata, fullinds)
end
function _view(array::LabeledArray, newdata::AbstractArray, indices::NamedTuple)
    if @generated
        names = remaining_labels(array, indices)
        T  = eltype(newdata)
        :(LabeledArray{$T, $(ndims(newdata)), $newdata, $names}(newdata))
    else
        LabeledArray(newdata, remaining_labels(typeof(array), typeof(indices)))
    end
end

Base.setindex!(array::LabeledArray, v::Any; kwargs...) = setindex!(array, v, kwargs.data)
function Base.setindex!(array::LabeledArray, v::Any, i::Union{Int, CartesianIndex})
    setindex!(parent(array), v, i)
end
function Base.setindex!(array::LabeledArray, v::Any, indices::NamedTuple)
    fullinds = to_indices(array, indices)
    setindex!(parent(array), v, values(fullinds)...)
end
function Base.setindex!(array::LabeledArray, v::LabeledArray, indices::NamedTuple)
    lbls = to_indices(array, indices)
    @boundscheck begin
        checkbounds(parent(array), values(lbls)...)
        for (axis, index) in pairs(lbls)
            shared_axis = axis in labels(v)
            len = index isa Colon ? size(array, axis) : length(index)
            if (!shared_axis) &&  len != 1
                msg = "Axis $axis missing from right-hand-side and has length > 1."
                throw(DimensionMismatch(msg))
            end
            if shared_axis && len != size(v, axis)
                x = NamedTuple{labels(v), typeof(axes(v))}(axes(v))
                msg = "Axes of right-hand-side, $lbls, and left-hand-side do not match, $x."
                throw(DimensionMismatch(msg))
            end
        end
        if !issubset(labels(v), keys(lbls))
            lv = labels(v)
            msg = "At least on axis of $lv missing from left-hand-side $(keys(lbls))."
            throw(DimensionMismatch(msg))
        end
    end
    is = indexin(keys(lbls), collect(labels(v)))
    rhs_names = tuple((labels(v, i) for i in is if i !== nothing)...)
    rhs_index = (axes(v, i) for i in rhs_names)
    iters = (v isa Colon ? axes(array, k) : v for (k, v) in pairs(lbls))
    for (left, right) in zip(Iterators.product(iters...), Iterators.product(rhs_index...))
        @inbounds value = getindex(v, NamedTuple{rhs_names, typeof(right)}(right))
        @inbounds setindex!(array, value, left...)
    end
end

function Base.permutedims(array::LabeledArray, axes::Any)
    names = indexin(axes, collect(labels(array)))
    autos = indexin(axes, collect(AUTO_AXIS_NAMES))
    dims = [u === nothing ? (autos[i] === nothing ? axes[i] : autos[i]) : u
            for (i, u) in enumerate(names)]
    data = permutedims(parent(array), dims)
    LabeledArray(data, tuple(collect(labels(array))[dims]...))
end

function Base.similar(array::LabeledArray, 
                      dims::Union{Integer, AbstractUnitRange}...)
    similar(array, eltype(array), dims)
end
function Base.similar(array::LabeledArray, T::Type,
                      dims::Union{Integer, AbstractUnitRange}...)
    similar(array, T, dims)
end
function Base.similar(array::LabeledArray, dims::Tuple)
    similar(array, eltype(array), dims)
end
function Base.similar(array::LabeledArray, T::Type, dims::Tuple)
    LabeledArray{labels(array)}(similar(parent(array), T, dims))
end
function Base.similar(array::LabeledArray, T::Type, dims::NTuple{N, Int64}) where N
    LabeledArray{labels(array)}(similar(parent(array), T, dims))
end
function Base.similar(array::LabeledArray, T::Type, dims::NamedTuple)
    LabeledArray{keys(dims)}(similar(parent(array), T, dims...))
end
Base.similar(a::LabeledArray, dims::NamedTuple) = similar(a, eltype(a), dims)
Base.similar(array::LabeledArray; kwargs...) = similar(array, kwargs.data)
function Base.similar(array::LabeledArray, ::NamedTuple{(), Tuple{}})
    similar(array, eltype(array), size(array)...)
end
Base.similar(array::LabeledArray, T::Type; kwargs...) = similar(array, T, kwargs.data)
function Base.similar(a::LabeledArray, T::Type, ::NamedTuple{(), Tuple{}})
    similar(a, T, size(a))
end

for op in (:+, :-)
    @eval begin
        function (::typeof($op))(
                a::LabeledArray{T, N, A, Names},
                b::LabeledArray{TT, N, AA, Names}) where {T, TT, N, A, AA, Names}
            LabeledArray{labels(a)}($op(parent(a), parent(b)))
        end
        function (::typeof($op))(
                a::LabeledArray{T, 2, A, M},
                b::LabeledArray{TT, 2, AA, MM}) where {T, TT, A, AA, M, MM}
            if Set(labels(a)) != Set(labels(b))
                throw(DimensionMismatch("Array labels do not match"))
            end
            NamedTuple{labels(a)}($op(parent(a), transpose(parent(b))))
        end
        function (::typeof($op))(
                a::LabeledArray{T, N, A, M},
                b::LabeledArray{TT, N, AA, MM}) where {T, TT, N, A, AA, M, MM}
            if Set(labels(a)) != Set(labels(b))
                throw(DimensionMismatch("Array labels do not match"))
            end
            result = similar(a, promote_type(eltype(a), eltype(b)))
            for ic in eachindex(IndexCartesian(), result)
                result[ic] = $op(a[ic], b[NamedTuple{labels(a)}(ic)])
            end
            result
        end
    end
end

for (op, final) in [(:isequal, true), (:!=, false)]
    @eval function (::typeof($op))(a::LabeledArray, b::LabeledArray)
        Set(labels(a)) != Set(labels(b)) && return !$final
        if labels(a) == labels(b)
            return $op(parent(a), parent(b))
        elseif ndims(a) == ndims(b) == 2
            return $op(parent(a), transpose(parent(b)))
        end
        for ic in eachindex(IndexCartesian(), result)
            if a[ic] != b[NamedTuple{labels(a)}(ic)]
                return !$final
            end
        end
        $final
    end
end

function Base.isapprox(a::LabeledArray, b::LabeledArray; kwargs...)
    Set(labels(a)) != Set(labels(b)) && return false
    if labels(a) == labels(b)
        return isapprox(parent(a), parent(b); kwargs...)
    elseif ndims(a) == ndims(b) == 2
        return isapprox(parent(a), transpose(parent(b)); kwargs...)
    end
    for ic in eachindex(IndexCartesian(), result)
        if !isapprox(a[ic], b[NamedTuple{labels(a)}(ic)], kwargs...)
            return false
        end
    end
    true
end

for op in (:*, :/)
    @eval begin 
        function (::typeof($op))(scalar::Number, a::LabeledArray)
            LabeledArray{labels(a)}($op(scalar, parent(a)))
        end
        function (::typeof($op))(a::LabeledArray, scalar::Number)
            LabeledArray{labels(a)}($op(parent(a), scalar))
        end
    end
end
end # module
