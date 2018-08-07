module NamedIndexing

export NamedAxisArray
export axisnames

struct NamedAxisArray{T, N, A<:AbstractArray{T, N}, Names} <: AbstractArray{T, N}
    data::A
end

function NamedAxisArray(data::A, names::NTuple{N, Symbol}) where {T, N, A<:AbstractArray{T, N}}
    NamedAxisArray{T, N, A, names}(data)
end

Base.size(AA::NamedAxisArray) = size(AA.data)

function Base.getindex(AA::NamedAxisArray{T, N, A, Names}, axinds::IndAx) where {T, N, A, Names, IndAx<:NamedTuple}
    fullinds = merge(
        NamedTuple{Names, NTuple{N, Colon}}(ntuple((_) -> (:), Val{N}())),
        axinds
    )

    fullkeys = keys(fullinds)
    if fullkeys != Names
        throw(ArgumentError("Unexpected named indexes $(setdiff(fullkeys, Names))"))
    end

    newdata = getindex(AA.data, fullinds...)

    # falls apart if you do APL-style reshaping with indexes
    NamedAxisArray{T, N, A, Names}(newdata)
end

Base.getindex(AA::NamedAxisArray; kwargs...) = getindex(AA, kwargs.data)

axisnames(AA::NamedAxisArray{T, N, A, Names}) where {T, N, A, Names} = Names

end # module
