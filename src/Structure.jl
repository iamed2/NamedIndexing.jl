struct LabeledArray{T, N, A <: AbstractArray{T, N}, Labels} <: AbstractArray{T, N}
    data::A
end

function LabeledArray{Labels}(data::AbstractArray{T, N}) where {T, N, Labels}
    if N > length(Labels)
        throw(DimensionMismatch("Too few labels on input"))
    end
    lbls = first(Base.IteratorsMD.split(Labels, Val{N}()))
    LabeledArray{T, N, typeof(data), lbls}(data)
end
function LabeledArray(data::AbstractArray{T, N}, names::NTuple{N, Symbol}) where {T, N}
    LabeledArray{T, N, typeof(data), names}(data)
end
LabeledArray(data::AbstractArray) = LabeledArray(data, labels(data))
function LabeledArray{T, N, A, Labels}(
                        ::UndefInitializer, dims::Tuple) where {T, N, A, Labels}
    LabeledArray{Labels}(A(UndefInitializer(), dims))
end

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
@inline labels(array::LabeledArray{T, N, A, S}, i::Integer) where {T, N, A, S} = S[i]
@inline labels(array::Type{LabeledArray{T, N, A, S}}, i::Integer) where {T, N, A, S} = S[i]

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

""" Tuple of non-scalar axes. """
function remaining_labels(array::Type{<:AbstractArray}, axes::Type{<:NamedTuple})
    names = fieldnames(axes)
    types = fieldtypes(axes)
    tuple((n for (n, t) in zip(names, types) if IndexType(array, t) isa VectorIndex)...)
end
Base.@propagate_inbounds remaining_labels(array::AbstractArray, axes::NoAxes) = ()
Base.@propagate_inbounds function remaining_labels(array::AbstractArray, axes::Axes)
    if IndexType(array, first(axes)) isa VectorIndex
        (first(labels(axes)), remaining_labels(array, Base.tail(axes))...)
    else
        remaining_labels(array, Base.tail(axes))
    end
end

""" Creates the full set of indices for the array """
Base.to_indices(a::LabeledArray, inds::LabeledArray) = to_indices(array, parent(inds))
function Base.to_indices(array::LabeledArray, indices::Axes)
    if @generated
        inames = labels(indices)

        getname(name, i) = begin
            if name in inames
                :($name = indices.$name)
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

Base.getindex(array::LabeledArray; kwargs...) = getindex(array, kwargs.data)
function Base.getindex(array::LabeledArray, index::Union{Int, CartesianIndex})
    getindex(parent(array), index)
end
Base.@propagate_inbounds @inline function Base.getindex(array::LabeledArray, I...)
    if length(I) > ndims(array)
        msg = ("Cannot index labeled array with more than "
               * "$(ndims(array)) unlabeled indices.")
        throw(DimensionMismatch(msg))
    end
    lbls = first(Base.IteratorsMD.split(labels(array), Val{length(I)}()))
    getindex(array, NamedTuple{lbls}(I))
end
function Base.getindex(array::LabeledArray, indices::Axes)
    fullinds = to_indices(array, indices)
    newdata = getindex(parent(array), values(fullinds)...)
    _getindex(array, newdata, fullinds)
end
_getindex(array::LabeledArray{T}, newdata::T, ::Axes) where T = newdata
function _getindex(array::LabeledArray, data::AbstractArray, inds::NamedTuple)
    if @generated
        names = remaining_labels(data, inds)
        T  = eltype(data)
        :(LabeledArray{$T, $(ndims(data)), $data, $names}(data))
    else
        LabeledArray{remaining_labels(data, inds)}(data)
    end
end

Base.view(array::LabeledArray; kwargs...) = view(array, kwargs.data)
Base.view(array::LabeledArray, index::Int) = view(parent(array), index)
function Base.view(array::LabeledArray, I...)
    if length(I) > ndims(array)
        msg = ("Cannot index labeled array with more than "
               * "$(ndims(array)) unlabeled indices.")
        throw(DimensionMismatch(msg))
    end
    lbls = first(Base.IteratorsMD.split(labels(array), Val{length(I)}()))
    view(array, NamedTuple{lbls}(I))
end
function Base.view(array::LabeledArray, indices::Axes)
    fullinds = to_indices(array, indices)
    newdata = view(parent(array), values(fullinds)...)
    _view(array, newdata, fullinds)
end
function _view(array::LabeledArray, newdata::AbstractArray, indices::NamedTuple)
    if @generated
        names = remaining_labels(newdata, indices)
        T  = eltype(newdata)
        :(LabeledArray{$T, $(ndims(newdata)), $newdata, $names}(newdata))
    else
        LabeledArray{remaining_labels(newdata, indices)}(newdata)
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
