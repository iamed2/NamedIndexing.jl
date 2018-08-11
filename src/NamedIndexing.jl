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

is_scalar_index(::Number) = true
is_scalar_index(::Symbol) = true
is_scalar_index(::Char) = true
is_scalar_index(::AbstractString) = true
is_scalar_index(::Any) = false

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

    #  newnames = Tuple(name for (name, index) in zip(Names, fullinds)
                     #  if is_scalar_index(index))
    #  NamedAxisArray(newdata, newnames)
end

Base.getindex(AA::NamedAxisArray; kwargs...) = getindex(AA, kwargs.data)
Base.getindex(AA::NamedAxisArray, i::Integer...) = getindex(AA.data, i...)
Base.setindex!(AA::NamedAxisArray, value, i::Integer...) = setindex!(AA.data, value, i...)

axisnames(AA::NamedAxisArray{T, N, A, Names}) where {T, N, A, Names} = Names

end # module
