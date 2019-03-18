const LBroadcasted = Broadcast.Broadcasted{Broadcast.ArrayStyle{A}} where A <: LabeledArray
Base.BroadcastStyle(A::Type{<:LabeledArray}) = Broadcast.ArrayStyle{A}()
Base.copy(bc::LBroadcasted) = bc
function Base.Broadcast.instantiate(bc::LBroadcasted{A}) where A
    axs = axes(bc)
    return LBroadcasted{A}(bc.f, bc.args, axs)
end
Base.similar(bc::LBroadcasted) = similar(LabeledArray{T}, axes(bc))
@inline Base.axes(bc::LBroadcasted) = _axes(bc, bc.axes)
_axes(::Broadcast.Broadcasted, axes::Axes) = axes
@inline function _axes(bc::Broadcast.Broadcasted, ::Nothing)
    broadcastshapes(map(axes, Base.Broadcast.cat_nested(bc)))
end
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

