const Axis = Union{NamedTuple, Tuple}
const NoAxis = Union{NamedTuple{(), Tuple{}}, Tuple{}}
const LBroadcasted = Broadcast.Broadcasted{Broadcast.ArrayStyle{A}} where A <: LabeledArray
Base.BroadcastStyle(A::Type{<:LabeledArray}) = Broadcast.ArrayStyle{A}()
Base.copy(bc::LBroadcasted) = bc
function Base.Broadcast.instantiate(bc::LBroadcasted{A}) where A
    axs = axes(bc)
    return LBroadcasted{A}(bc.f, bc.args, axs)
end
Base.similar(bc::LBroadcasted) = similar(LabeledArray{T}, axes(bc))
@inline Base.axes(bc::LBroadcasted) = _axes(bc, bc.axes)
_labeled_axes(::Broadcast.Broadcasted, axes::Axis) = axes
@inline function _axes(bc::Broadcast.Broadcasted, ::Nothing)
    broadcast_shapes(map(_label_axes, Base.Broadcast.cat_nested(bc)))
end
_label_axes(array::LabeledArray) = labeled_axes(array)
_label_axes(array::Any) = axes(array)
function broadcast_shapes(args)
    nts = tuple((u for u in args if u isa NamedTuple)...)
    nt = reduce(combine_axes, nts; init=NamedTuple())
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
    ts = Base.Broadcast.broadcast_shape((u for u in args if !(u isa NamedTuple))...)
    if length(ts) > max(i, 1)
        throw(DimensionMismatch("Cannot reconcile labeled and unlabeled axes"))
    end
    NamedTuple{keys(nt)}(Base.Broadcast.broadcast_shape(values(nt), ts))
end
combine_axes(left::NamedTuple, ::NamedTuple{(), Tuple{}}) = left
combine_axes(::NamedTuple{(), Tuple{}}, right::NamedTuple) = right
function combine_axes(left::NamedTuple, right::NamedTuple)
    others = setdiff(keys(right), keys(left))
    NamedTuple{(keys(left)..., others...)}((
        (Base.Broadcast._bcs1(v, n in propertynames(right) ? getproperty(right, n) : 1)
         for (n, v) in pairs(left))...,
        (Base.Broadcast._bcs1(1, getproperty(right, name)) for name in others)...
    ))
end

