const LabeledCartesianIndex{Lbls, N} = LabeledAxes{Lbls, NTuple{N, Int64}} where {Lbls, N}
const LCI = LabeledCartesianIndex
struct LabeledCartesianIndices{Labels, N, R} <: AbstractArray{LCI{Labels, N}, N}
    inds::CartesianIndices{N, R}
end
const LCIs = LabeledCartesianIndices

LabeledCartesianIndex{Labels}(x::Tuple) where Labels = LabeledAxes{Labels}(x)
function Base.summary(io::IO, lcis::LabeledCartesianIndices)
    write(io, "LabeledCarteasianIndices{$(labels(lcis))}")
end
function Base.show(io::IO, lcis::LabeledCartesianIndices) 
    summary(io, lcis)
    show(io, parent(lcis))
end

function LabeledCartesianIndices{Labels}(x) where Labels
    LabeledCartesianIndices{Labels}(CartesianIndices(x))
end
function LabeledCartesianIndices{Labels}(x::CartesianIndices{N, R}) where {Labels, N, R}
    LabeledCartesianIndices{Labels, N, R}(x)
end

function LabeledCartesianIndices{Labels}(x::Tuple) where Labels
    LabeledCartesianIndices{Labels}(CartesianIndices(x))
end

Base.parent(lcis::LCIs) = getfield(lcis, :inds)
@inline Base.iterate(iter::LCIs) = _iterate(iterate(parent(iter)))
@inline Base.iterate(iter::LCIs, state) = _iterate(iterate(parent(iter), state))
@inline _iterate(::Nothing) = nothing
@inline _iterate(iter::CartesianIndex, state) = LCI(Tuple(iter)), state

labels(::LCIs{Labels}) where Labels = Labels
labels(::Type{<: LCIs{Labels}}) where Labels = Labels
Base.size(lcis::LCIs) = LabeledAxes{labels(lcis)}(size(parent(lcis)))
Base.length(lcis::LCIs) = length(parent(lcis))
Base.@propagate_inbounds function Base.getindex(lcis::LCIs, indx)
    LCI{labels(lcis)}(Tuple(getindex(parent(lcis), indx)))
end
Base.@propagate_inbounds function Base.getindex(lcis::LCIs, i0, indx...)
    LCI{labels(lcis)}(Tuple(getindex(parent(lcis), i0, indx...)))
end
