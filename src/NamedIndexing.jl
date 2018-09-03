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

is_scalar_index(::Type{<:Number}) = true
is_scalar_index(::Type{Symbol}) = true
is_scalar_index(::Type{<:AbstractChar}) = true
is_scalar_index(::Type{<:AbstractString}) = true
is_scalar_index(a::Any) = is_scalar_index(typeof(a))
is_scalar_index(::Type) = false


const ScalarTypes = Union{Number, Symbol, Char, AbstractString}
function _reduced_names(names::NamedTuple{N, T}) where {N, T}
    if @generated
        newnames = Tuple(n for (n, t) in zip(N, T.parameters) if !is_scalar_index(t))
        :($newnames)
    else
        Tuple(n for (n, t) in zip(N, T.parameters) if !is_scalar_index(t))
    end
end
_from_data_and_names(data::Any, ::Tuple{}) = data
function _from_data_and_names(data::AbstractArray, names::Tuple)
    NamedAxisArray(data, names)
end

function Base.getindex(AA::NamedAxisArray{T, N, A, Names},
                       axinds::NamedTuple) where {T, N, A, Names}
    fullinds = merge(
                     NamedTuple{Names, NTuple{N, Colon}}(ntuple((_) -> (:), Val{N}())),
                     axinds
                    )

    fullkeys = keys(fullinds)
    if fullkeys != Names
        throw(ArgumentError("Unexpected named indexes $(setdiff(fullkeys, Names))"))
    end

    newdata = getindex(AA.data, fullinds...)
    newnames = _reduced_names(fullinds)
    _from_data_and_names(newdata, newnames)
end

Base.getindex(AA::NamedAxisArray; kwargs...) = getindex(AA, kwargs.data)
Base.getindex(AA::NamedAxisArray, i::Integer...) = getindex(AA.data, i...)
Base.setindex!(AA::NamedAxisArray, value, i::Integer...) = setindex!(AA.data, value, i...)

axisnames(AA::NamedAxisArray{T, N, A, Names}) where {T, N, A, Names} = Names

end # module
