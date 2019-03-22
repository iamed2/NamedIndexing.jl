""" Wraps a named tuple to avoid type piracy """

struct LabeledAxes{Labels, Ts}
    axs::NamedTuple{Labels, Ts}
end
const Axes{N, T} = Union{NamedTuple{N, T}, LabeledAxes{N, T}} where {N, T}
const NoAxes = Union{NamedTuple{(), Tuple{}},
                     LabeledAxes{(), Tuple{}},
                     Tuple{}}

LabeledAxes(; kwargs...) = LabeledAxes(kwargs.data)
@inline Base.parent(axs::LabeledAxes) = getfield(axs, :axs)
@inline Base.parent(::Type{LabeledAxes{N, T}}) where {N, T} = NamedTuple{N, T}
NamedTuple(nt::LabeledAxes) = parent(nt)
LabeledAxes{Labels}(t::Tuple) where Labels = LabeledAxes(NamedTuple{Labels}(t))
labels(::LabeledAxes{Labels}) where Labels = Labels
labels(::NamedTuple{Labels}) where Labels = Labels
labels(::Type{<: NamedTuple{Labels}}) where Labels = Labels
labels(::Type{<: LabeledAxes{Labels}}) where Labels = Labels
function dims2string(inds::NamedTuple)
    if length(inds) < 0
        return "0-dimensional"
    elseif length(inds) == 1
        return "$(keys(inds)[1])=$(values(inds)[1])"
    end
    return join(map(x -> "($(x[1])=$(x[2]))", zip(keys(inds), values(inds))), '×')
end
function Base.summary(io::IO, inds::LabeledAxes)
    write(io, "LabeledAxes")
end
function Base.summary(io::IO, a, inds::LabeledAxes{Lbls, T}) where {
              Lbls, T <: Tuple{Vararg{Base.OneTo}}}
    print(io, dims2string(NamedTuple{Lbls}(length.(inds))), " ")
    Base.showarg(io, a, true)
end
Base.show(io::IO, axs::LabeledAxes) = (summary(io, axs); show(io, parent(axs)))
Base.getindex(axs::LabeledAxes, i::Integer) = parent(axs)[i]
function Base.convert(::Type{LabeledAxes{Labels, T}},
                      nt::LabeledAxes{Labels, T}) where {Labels, T<:Tuple} 
    nt
end
function Base.convert(::Type{LabeledAxes{Labels}},
                      nt::LabeledAxes{Labels}) where {Labels}
    nt
end
function Base.convert(::Type{LabeledAxes{Labels,T}},
                      nt::LabeledAxes{Labels}) where {Labels,T<:Tuple}
   LabeledAxes{Labels,T}(NamedTuple{Labels, T}(nt))
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
@inline unlabel(ax::LabeledAxes) = parent(ax)
@inline unlabel(ax) = ax

function Base.map(f::Function, nt::LabeledAxes{name}, nts::Axes...) where name
    map(f∘unlabel, unlabel(nt), nts...)
end

for func in (:firstindex, :lastindex, :length, :pairs,
             :keys, :values, :isempty, :iterate)
	@eval Base.$func(a::LabeledAxes) = $func(parent(a))
end

Base.tail(a::LabeledAxes) = LabeledAxes{Base.tail(labels(a))}(Base.tail(values(a)))

for f in (:isless, :isequal, :merge, :(==))
	@eval begin
        Base.$f(a::LabeledAxes, b::LabeledAxes) = $f(parent(a), parent(b))
	    Base.$f(a::NamedTuple, b::LabeledAxes) = $f(a, parent(b))
	    Base.$f(a::LabeledAxes, b::NamedTuple) = $f(parent(a), b)
	    Base.$f(a::Tuple, b::LabeledAxes) = $f(a, values(b))
	    Base.$f(a::LabeledAxes, b::Tuple) = $f(values(a), b)
    end
end

Base.getindex(ax::LabeledAxes, s::Symbol) = getproperty(ax, s)

function Base.checkbounds_indices(::Type{Bool}, ax::LabeledAxes, I)
    Base.checkbounds_indices(Bool, values(ax), I)
end

function Base.checkbounds_indices(::Type{Bool}, ax::LabeledAxes, inds::Axes)
    for (key, value) in pairs(ax)
        i = auto_axis_index(key)
        if i !== nothing
            right = i <= lengths(inds) ? inds[i] : 1
            Base.checkindex(Bool, value, right) == false && return false
        elseif haskey(inds, key) && checkindex(Bool, value, inds[key]) == false
            return false
        end
    end
    for (key, value) in pairs(inds)
        i = auto_axis_index(key)
        if i !== nothing
            left = i <= lengths(ax) ? ax[i] : Base.OneTo(1)
            Base.checkindex(Bool, left, value) == false && return false
        elseif (!haskey(ax, key)) && Base.checkindex(Bool, 1:1, value) == false
            return false
        end
    end
    true
end

function _checkbounds_indices(::Type{Bool}, ax::LabeledAxes, inds::Axes)
    _check_left(ax, inds) && _check_right(ax, inds)
end
_check_left(ax::NoAxes, inds::Axes) = true
_check_left(ax::NoAxes, inds::NoAxes) = true
_check_right(ax::LabeledAxes, inds::NoAxes) = true
_check_right(ax::NoAxes, inds::NoAxes) = true
function _check_right(ax::NoAxes, inds::Axes)
    error("This makes no sense. It's just to ward off ambiguities")
end
function _check_left(ax::LabeledAxes, inds::Axes)
    rest = Base.tail(ax)   
    name, value = first(labels(ax)), first(ax)
    i = auto_axis_index(name)
    if i !== nothing && i <= length(inds)
        Base.checkindex(Bool, value, inds[i]) && _check_left(rest, inds)
    elseif i !== nothing
        Base.checkindex(Bool, value, 1) && _check_left(rest, inds)
    elseif haskey(inds, name)
        Base.checkindex(Bool, value, inds[name]) && _check_left(rest, inds)
    else
        _check_left(rest, inds)
    end
end
function _check_right(ax::LabeledAxes, inds::Axes)
    rest = Base.tail(inds)   
    name, value = first(labels(inds)), first(inds)
    i = auto_axis_index(name)
    if i !== nothing && i <= length(ax)
        Base.checkindex(Bool, ax[i], value) && _check_right(ax, rest)
    elseif i !== nothing
        Base.checkindex(Bool, Base.OneTo(1), value) && _check_right(ax, rest)
    elseif haskey(ax, name)
        Base.checkindex(Bool, ax[name], value) && _check_right(ax, rest)
    else
        _check_right(ax, rest)
    end
end
