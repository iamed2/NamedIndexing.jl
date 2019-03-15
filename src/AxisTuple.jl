""" Wraps a named tuple to avoid type piracy """

struct LabeledAxes{Names, Ts}
    axs::NamedTuple{Names, Ts}
end

NamedTuple(nt::LabeledAxes) = nt.axs
LabeledAxes{Names}(t::Tuple) where Names = LabeledAxes(NamedTuple{Names}(t))
Base.summary(io::IO, axs::LabeledAxes) = write(io, "LabeledAxes")
Base.show(io::IO, axs::LabeledAxes) = (summary(io, axs); show(io, axs.axs))
Base.getindex(axs::LabeledAxes, i::Integer) = axs.axs[i]
Base.convert(::Type{LabeledAxes{names,T}}, nt::LabeledAxes{names,T}) where {names,T<:Tuple} = nt
Base.convert(::Type{LabeledAxes{names}}, nt::LabeledAxes{names}) where {names} = nt
function Base.convert(::Type{LabeledAxes{names,T}}, nt::LabeledAxes{names}) where {names,T<:Tuple}
   LabeledAxes{names,T}(NamedTuple{names, T}(nt))
end
Base.get(nt::LabeledAxes, key::Union{Integer, Symbol}, default) = get(nt.axs, key, default)
Base.get(f::Base.Callable, nt::LabeledAxes, key::Union{Integer, Symbol}) = get(f, nt.axes, key)
Base.hash(x::LabeledAxes, h::UInt64)  = hash(x.axs, h)
Base.haskey(nt::LabeledAxes, key::Union{Integer, Symbol}) = haskey(nt.axs, key)
Base.iterate(t::LabeledAxes, iter) = iterate(t.axs, iter)
function Base.map(f, nt::LabeledAxes{name}, nts::Union{LabeledAxes, NamedTuple}...) where name
	map(f∘NamedTuple, nt, nts...)
end
for func in (:firstindex, :lastindex, :length, :pairs, :keys, :values, :isempty, :iterate)
	@eval Base.$func(a::LabeledAxes) = $func(a.axs)
end
for func in (:isless, :isequal, :merge, :(==))
	@eval Base.$func(a::LabeledAxes, b::LabeledAxes) = $func(a.axs, b.axs)
	@eval Base.$func(a::NamedTuple, b::LabeledAxes) = $func(a, b.axs)
	@eval Base.$func(a::LabeledAxes, b::NamedTuple) = $func(a.axs, b)
end
