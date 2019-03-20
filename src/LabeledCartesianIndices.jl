const LabeledCartesianIndex{Lbls, N} = LabeledAxes{Lbls, NTuple{N, Int64}} where {Lbls, N}
const LCI = LabeledCartesianIndex

struct LabeledCartesianIndices{Labels, N, R} <: AbstractArray{LCI{Labels, N}, N}
    inds::CartesianIndices{N, R}
end
const LCIs = LabeledCartesianIndices

LabeledCartesianIndex{Labels}(x::Tuple) where Labels = LabeledAxes{Labels}(x)

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
Base.@propagate_inbounds function Base.getindex(lcis::LCIs, indx::Integer)
    LCI{labels(lcis)}(Tuple(getindex(parent(lcis), indx)))
end
Base.@propagate_inbounds function Base.getindex(lcis::LCIs, indx...)
    LCI{labels(lcis)}(Tuple(getindex(parent(lcis), indx...)))
end

""" Cartesian indexing scheme where each dimension is labeled by name rather than number."""
struct IndexLabeledCartesian <: IndexStyle end
function Base.IndexStyle(::IndexLabeledCartesian, ::IndexLabeledCartesian)
    IndexLabeledCartesian()
end
for Indexing in (:IndexCartesian, :IndexLinear)
    @eval begin
        function Base.IndexStyle(::$Indexing, ::IndexLabeledCartesian)
            IndexLabeledCartesian()
        end
        function Base.IndexStyle(::IndexLabeledCartesian, ::$Indexing)
            IndexLabeledCartesian()
        end
    end
end
Base.IndexStyle(::Type{<: LCIs}) = IndexLabeledCartesian()
Base.@propagate_inbounds function Base.to_indices(lcis::LCIs,
                                                  I::Tuple{Any, Vararg{Any}})
    Base.to_indices(parent(lcis), I)
end
function Base.checkbounds_indices(::Type{Bool}, lcis::LCIs, I)
    Base.checkbounds_indices(Bool, parent(lcis), I)
end

unlabel(inds::LabeledCartesianIndices) = parent(inds)

function Base.SubArray(::IndexLabeledCartesian,
                       parent::P, indices::I, nt::NTuple{N,Any}) where {P,I,N}
    Base.@_inline_meta
    Base.SubArray(IndexCartesian(), parent, indices, nt)
end
