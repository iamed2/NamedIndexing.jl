const LBroadcasted = Broadcast.Broadcasted{Broadcast.ArrayStyle{A}} where A <: LabeledArray
Base.BroadcastStyle(::Type{<:LabeledArray}) = Broadcast.ArrayStyle{LabeledArray}()
function Base.Broadcast.instantiate(bc::LBroadcasted{A}) where A
    axs = axes(bc)
    return LBroadcasted{A}(bc.f, bc.args, axs)
end
Base.similar(bc::LBroadcasted) = similar(LabeledArray{T}, axes(bc))
@inline Base.axes(bc::Broadcast.Broadcasted{Nothing, <: Axes}) = _lbaxes(bc, bc.axes)
@inline Base.axes(bc::LBroadcasted) = _lbaxes(bc, bc.axes)
_lbaxes(::Broadcast.Broadcasted, axs::Axes) = axs
@inline function _lbaxes(bc::Broadcast.Broadcasted, ::Nothing)
    broadcastshapes(map(axes, Base.Broadcast.cat_nested(bc)))
end
labels(bc::LBroadcasted) = labels(axes(bc))
Broadcast.extrude(x::LabeledArray) = x
function broadcastshapes(args)
    nts = tuple((u for u in args if u isa Axes)...)
    nt = reduce(combine_axes, nts; init=LabeledAxes())
    i :: Int64 = length(nt)
    for axs in nts
        for j in 1:min(i, length(axs))
            if keys(nt)[j] != keys(axs)[j]
                i = j - 1
                break
            end
        end
    end
    length(nts) == length(args) && return nt
    ts = Base.Broadcast.broadcast_shape((u for u in args if !(u isa Axes))...)
    if length(ts) > max(i, 1)
        throw(DimensionMismatch("Cannot reconcile labeled and unlabeled axes"))
    end
    LabeledAxes{keys(nt)}(Base.Broadcast.broadcast_shape(values(nt), ts))
end
combine_axes(left::Axes, ::NoAxes) = left
combine_axes(::NoAxes, right::Axes) = right
function combine_axes(left::Axes, right::Axes)
    others = setdiff(keys(right), keys(left))
    LabeledAxes{(keys(left)..., others...)}((
        (Base.Broadcast._bcs1(v, n in propertynames(right) ? getproperty(right, n) : 1)
         for (n, v) in pairs(left))...,
        (Base.Broadcast._bcs1(1, getproperty(right, name)) for name in others)...
    ))
end

Base.eachindex(bc::LBroadcasted) = _eachindex(axes(bc))
Base.eachindex(bc::Broadcast.Broadcasted{Nothing, <: LabeledAxes}) = _eachindex(axes(bc))
_eachindex(t::Tuple{Any}) = t[1]
_eachindex(t::Tuple) = CartesianIndices(t)
_eachindex(t::Axes) = LabeledCartesianIndices(t)

function Base.similar(bc::LBroadcasted, T::Type)
    ax = axes(bc)
    N = length(ax)
    similar(LabeledArray{T, N, Array{T, N}, labels(ax)}, values(ax))
end

@inline function Base.checkbounds(bc::LBroadcasted, I::CartesianIndex)
    checkbounds(bc, LabeledCartesianIndex{labels(bc)}(I))
end
@inline function Base.checkbounds(bc::LBroadcasted, lci::Axes)
    Base.checkbounds_indices(Bool, axes(bc), lci) || Base.throw_boundserror(bc, lci)
end

Base.@propagate_inbounds function Base.getindex(bc::LBroadcasted,
                                                i1::Integer, i2::Integer,
                                                I::Integer...)
    bc[LabeledCartesianIndex{labels(bc)}((i1, i2, I...))]
end
@inline function Base.getindex(bc::Broadcast.Broadcasted, I::LabeledCartesianIndex)
    @boundscheck checkbounds(bc, I)
    @inbounds Broadcast._broadcast_getindex(bc, I)
end

function Broadcast.newindex(array::LabeledArray, I::LabeledCartesianIndex)
    LabeledCartesianIndex{labels(array)}(Tuple(getproperty(I, s) for s in labels(array)))
end
function Broadcast.newindex(I::LabeledCartesianIndex, keep, Idefault)
    Broadcast.newindex(CartesianIndex(values(I)), keep, Idefault)
end
function Broadcast.newindex(arg::Any, I::LabeledCartesianIndex)
    Broadcast.newindex(CartesianIndex(I))
end
