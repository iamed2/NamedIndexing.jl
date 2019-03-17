""" Wraps a named tuple to avoid type piracy """

struct LabeledAxes{Names, Ts}
    axs::NamedTuple{Names, Ts}
end
const Axes{N, T} = Union{NamedTuple{N, T}, LabeledAxes{N, T}} where {N, T}
const NoAxes = Union{NamedTuple{(), Tuple{}},
                     LabeledAxes{(), Tuple{}},
                     Tuple{}}

LabeledAxes(; kwargs...) = LabeledAxes(kwargs.data)
@inline Base.parent(axs::LabeledAxes) = getfield(axs, :axs)
NamedTuple(nt::LabeledAxes) = parent(nt)
LabeledAxes{Names}(t::Tuple) where Names = LabeledAxes(NamedTuple{Names}(t))
Base.summary(io::IO, axs::LabeledAxes) = write(io, "LabeledAxes")
Base.show(io::IO, axs::LabeledAxes) = (summary(io, axs); show(io, parent(axs)))
Base.getindex(axs::LabeledAxes, i::Integer) = parent(axs)[i]
function Base.convert(::Type{LabeledAxes{names,T}},
                      nt::LabeledAxes{names,T}) where {names,T<:Tuple} 
    nt
end
function Base.convert(::Type{LabeledAxes{names}},
                      nt::LabeledAxes{names}) where {names}
    nt
end
function Base.convert(::Type{LabeledAxes{names,T}},
                      nt::LabeledAxes{names}) where {names,T<:Tuple}
   LabeledAxes{names,T}(NamedTuple{names, T}(nt))
end
function Base.get(nt::LabeledAxes, key::Union{Integer, Symbol}, default)
    get(parent(nt), key, default)
end
function Base.get(f::Base.Callable, nt::LabeledAxes, key::Union{Integer, Symbol})
    get(f, nt.axes, key)
end
Base.hash(x::LabeledAxes, h::UInt64)  = hash(parent(x), h)
function Base.haskey(nt::LabeledAxes, key::Union{Integer, Symbol})
    haskey(parent(nt), key)
end
Base.iterate(t::LabeledAxes, iter) = iterate(parent(t), iter)
Base.getproperty(t::LabeledAxes, s::Symbol) = getfield(parent(t), s)
function Base.map(f, nt::LabeledAxes{name},
                  nts::Union{LabeledAxes, NamedTuple}...) where name
	map(f∘NamedTuple, nt, nts...)
end
for func in (:firstindex, :lastindex, :length, :pairs,
             :keys, :values, :isempty, :iterate)
	@eval Base.$func(a::LabeledAxes) = $func(parent(a))
end
for f in (:isless, :isequal, :merge, :(==))
	@eval begin
        Base.$f(a::LabeledAxes, b::LabeledAxes) = $f(parent(a), parent(b))
	    Base.$f(a::NamedTuple, b::LabeledAxes) = $f(a, parent(b))
	    Base.$f(a::LabeledAxes, b::NamedTuple) = $f(parent(a), b)
	    Base.$f(a::Tuple, b::LabeledAxes) = $f(a, values(b))
	    Base.$f(a::LabeledAxes, b::Tuple) = $f(values(a), b)
    end
end
