module LabeledArrays
using Random

export LabeledArray
export labels

struct LabeledArray{T, N, A <: AbstractArray{T, N}, Names} <: AbstractArray{T, N}
    data::A
end

function LabeledArray(data::AbstractArray{T, N1},
                      names::NTuple{N2, Symbol}) where {T, N1, N2}
    LabeledArray{T, N1, typeof(data), generate_axis_names(names, Val{N1}())}(data)
end
LabeledArray(data::AbstractArray) = LabeledArray(data, labels(data))

const LabelledArray = LabeledArray # for the brit inside each of us

Base.IndexStyle(array::LabeledArray) = Base.IndexStyle(array.data)
function Base.IndexStyle(array::Type{<: LabeledArray{T, N, A}}) where {T, N, A}
    Base.IndexStyle(A)
end

Base.size(array::LabeledArray) = size(array.data)
function Base.size(array::LabeledArray, axis::Symbol)
    getproperty(NamedTuple{labels(array), NTuple{ndims(array), Int}}(size(array.data)),
                axis)
end
Base.getindex(array::LabeledArray; kwargs...) = getindex(array, kwargs.data)
Base.ndims(array::LabeledArray{T, N}) where {T, N} = N
""" Labels attached to the axis of an array """
@inline labels(array::LabeledArray{T, N, A, S}) where {T, N, A, S} = S
@inline labels(array::Type{LabeledArray{T, N, A, S}}) where {T, N, A, S} = S
@inline labels(array::AbstractArray) = AUTO_AXIS_NAMES[1:ndims(array)]

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
function fullindices(array::LabeledArray, indices::NamedTuple)
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

@inline Base.getindex(array::LabeledArray, index::Int) = getindex(array.data, index)
function Base.getindex(array::LabeledArray, I...)
    indices = NamedTuple{generate_axis_names(array, Val{length(I)}()), typeof(I)}(I)
    getindex(array, indices)
end
function Base.getindex(array::LabeledArray, indices::NamedTuple)
    fullinds = fullindices(array, indices)
    newdata = getindex(array.data, values(fullinds)...)
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



end # module
