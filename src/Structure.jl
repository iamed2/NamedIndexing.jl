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
Base.IndexStyle(array::Type{<: LabeledArray}) = Base.IndexStyle(parent(array))

""" Original array wrapped by the LabeledArray. """
Base.parent(array::LabeledArray) = array.data
Base.parent(::Type{LabeledArray{T, N, A, M}}) where {T, N, A, M} = A
Base.size(array::LabeledArray) = LabeledAxes{labels(array)}(size(parent(array)))
Base.size(a::LabeledArray, axis::Symbol) = getproperty(size(a), axis)
Base.axes(array::LabeledArray) = LabeledAxes{labels(array)}(axes(parent(array)))
Base.axes(array::LabeledArray, c::Symbol) = getproperty(axes(array), c)
Base.print_array(io::IO, a::LabeledArray) = Base.print_array(io, parent(a))
Base.LinearIndices(a::LabeledAxes) = LinearIndices(values(a))
Base.CartesianIndices(a::LabeledAxes) = CartesianIndices(values(a))
function Base.checkbounds(::Type{Bool}, A::LabeledArray, I...)
    Base.@_inline_meta
    Base.checkbounds_indices(Bool, values(axes(A)), I)
end

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
Base.to_indices(a::LabeledArray, inds::LabeledArray) = to_indices(array, parent(inds))
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
function Base.getindex(array::LabeledArray, indices::Axes)
    fullinds = to_indices(array, indices)
    newdata = getindex(parent(array), values(fullinds)...)
    _get_index(array, newdata, fullinds)
end
_get_index(array::LabeledArray{T}, newdata::T, ::Axes) where T = newdata
function _get_index(array::LabeledArray, data::AbstractArray, inds::NamedTuple)
    if @generated
        names = remaining_labels(array, inds)
        T  = eltype(data)
        :(LabeledArray{$T, $(ndims(data)), $data, $names}(data))
    else
        LabeledArray(data, remaining_labels(typeof(array), typeof(inds)))
    end
end

Base.view(array::LabeledArray; kwargs...) = view(array, kwargs.data)
Base.view(array::LabeledArray, index::Int) = view(parent(array), index)
function Base.view(array::LabeledArray, I...)
    indices = NamedTuple{generate_axis_names(array, Val{length(I)}())}(I)
    view(array, indices)
end
function Base.view(array::LabeledArray, indices::Axes)
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
function Base.setindex!(array::LabeledArray, v::Any, indices::Axes)
    fullinds = to_indices(array, indices)
    setindex!(parent(array), v, values(fullinds)...)
end
function Base.setindex!(array::LabeledArray, v::LabeledArray, indices::Axes)
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
                x = axes(v)
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
        @inbounds value = getindex(v, NamedTuple{rhs_names}(right))
        @inbounds setindex!(parent(array), value, left...)
    end
end
