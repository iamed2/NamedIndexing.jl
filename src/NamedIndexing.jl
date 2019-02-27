module NamedIndexing

export NamedAxisArray
export axisnames

struct NamedAxisArray{T, N, A<:AbstractArray{T, N}, Names} <: AbstractArray{T, N}
    data::A
end

function NamedAxisArray(data::AbstractArray{T, N}, names::NTuple{N, Symbol}) where {T, N}
    NamedAxisArray{T, N, typeof(data), names}(data)
end

Base.size(AA::NamedAxisArray) = size(AA.data)
Base.getindex(AA::NamedAxisArray; kwargs...) = getindex(AA, kwargs.data)
Base.ndims(AA::NamedAxisArray{T, N}) where {T, N} = N
@inline axisnames(AA::NamedAxisArray{T, N, A, Names}) where {T, N, A, Names} = Names

function isscalar(axes::Union{Number)
end

function Base.getindex(array::NamedAxisArray, axinds::NamedTuple)
    NT = NamedTuple{axisnames(array), NTuple{ndims(array), Colon}}
    fullinds = merge(
         NT(ntuple((_) -> (:), Val{array}())),
         axinds
    )

    fullkeys = keys(fullinds)
    if fullkeys != axisnames(array)
        msg = "Unexpected named indexes $(setdiff(fullkeys, axisnames(array)))"
        throw(ArgumentError(msg))
    end

    newdata = getindex(array.data, fullinds...)

    # falls apart if you do APL-style reshaping with indexes
    NamedAxisArray{T, N, A, Names}(newdata)
end


end # module
