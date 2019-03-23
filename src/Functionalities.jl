Base.dataids(a::LabeledArray) = Base.dataids(parent(a))
function Base.permutedims(array::LabeledArray, axes::Any)
    names = indexin(axes, collect(labels(array)))
    autos = indexin(axes, collect(AUTO_AXIS_NAMES))
    dims = [u === nothing ? (autos[i] === nothing ? axes[i] : autos[i]) : u
            for (i, u) in enumerate(names)]
    data = permutedims(parent(array), dims)
    LabeledArray(data, tuple(collect(labels(array))[dims]...))
end

function Base.similar(array::LabeledArray, 
                      dims::Union{Integer, AbstractUnitRange}...)
    similar(array, eltype(array), dims)
end
function Base.similar(array::LabeledArray, T::Type,
                      dims::Union{Integer, AbstractUnitRange}...)
    similar(array, T, dims)
end
function Base.similar(array::LabeledArray, dims::Tuple)
    similar(array, eltype(array), dims)
end
function Base.similar(array::LabeledArray, T::Type, dims::Tuple)
    LabeledArray{labels(array)}(similar(parent(array), T, dims))
end
function Base.similar(array::LabeledArray, T::Type, dims::NTuple{N, Int64}) where N
    LabeledArray{labels(array)}(similar(parent(array), T, dims))
end
function Base.similar(array::LabeledArray, T::Type, dims::Axes)
    LabeledArray{keys(dims)}(similar(parent(array), T, dims...))
end
Base.similar(a::LabeledArray, dims::Axes) = similar(a, eltype(a), dims)
Base.similar(array::LabeledArray; kwargs...) = similar(array, kwargs.data)
function Base.similar(array::LabeledArray, ::NoAxes)
    similar(array, eltype(array), size(array)...)
end
Base.similar(array::LabeledArray, T::Type; kwargs...) = similar(array, T, kwargs.data)
function Base.similar(a::LabeledArray, T::Type, ::NoAxes)
    similar(a, T, size(a))
end
function Base.similar(::Type{LabeledArray{T}}; kwargs...) where T
    similar(LabeledArray{T}, kwargs.data)
end
function Base.similar(::Type{LabeledArray}, T::Type; kwargs...)
    similar(LabeledArray{T}, kwargs.data)
end
function Base.similar(::Type{<: LabeledArray{T}}, dims::Axes) where T
    LabeledArray{keys(dims)}(similar(Array{T}, values(dims)))
end
function Base.similar(::Type{<: LabeledArray{T, N, A}}, dims::Axes) where {T, N, A}
    LabeledArray{keys(dims)}(similar(A, T, values(dims)))
end

for op in (:+, :-)
    @eval begin
        function (::typeof($op))(
                a::LabeledArray{T, N, A, Names},
                b::LabeledArray{TT, N, AA, Names}) where {T, TT, N, A, AA, Names}
            LabeledArray{labels(a)}($op(parent(a), parent(b)))
        end
        function (::typeof($op))(
                a::LabeledArray{T, 2, A, M},
                b::LabeledArray{TT, 2, AA, MM}) where {T, TT, A, AA, M, MM}
            if Set(labels(a)) != Set(labels(b))
                throw(DimensionMismatch("Array labels do not match"))
            end
            LabeledArray{labels(a)}($op(parent(a), transpose(parent(b))))
        end
        function (::typeof($op))(
                a::LabeledArray{T, N, A, M},
                b::LabeledArray{TT, N, AA, MM}) where {T, TT, N, A, AA, M, MM}
            if Set(labels(a)) != Set(labels(b))
                throw(DimensionMismatch("Array labels do not match"))
            end
            result = similar(a, promote_type(eltype(a), eltype(b)))
            for ic in eachindex(IndexCartesian(), result)
                result[ic] = $op(a[ic], b[NamedTuple{labels(a)}(ic)])
            end
            result
        end
    end
end

for (op, final) in [(:isequal, true), (:!=, false)]
    @eval begin
        function (::typeof($op))(a::LabeledArray, b::LabeledArray)
            Set(labels(a)) != Set(labels(b)) && return !$final
            if labels(a) == labels(b)
                return $op(parent(a), parent(b))
            elseif ndims(a) == ndims(b) == 2
                return $op(parent(a), transpose(parent(b)))
            end
            for ic in eachindex(IndexCartesian(), result)
                if a[ic] != b[NamedTuple{labels(a)}(ic)]
                    return !$final
                end
            end
            $final
        end
    end
end

function Base.isapprox(a::LabeledArray, b::LabeledArray; kwargs...)
    Set(labels(a)) != Set(labels(b)) && return false
    if labels(a) == labels(b)
        return isapprox(parent(a), parent(b); kwargs...)
    elseif ndims(a) == ndims(b) == 2
        return isapprox(parent(a), transpose(parent(b)); kwargs...)
    end
    for ic in eachindex(IndexCartesian(), result)
        if !isapprox(a[ic], b[NamedTuple{labels(a)}(ic)], kwargs...)
            return false
        end
    end
    true
end

for op in (:*, :/)
    @eval begin 
        function (::typeof($op))(scalar::Number, a::LabeledArray)
            LabeledArray{labels(a)}($op(scalar, parent(a)))
        end
        function (::typeof($op))(a::LabeledArray, scalar::Number)
            LabeledArray{labels(a)}($op(parent(a), scalar))
        end
    end
end

Base.eachindex(::IndexLabeledCartesian, A::AbstractArray) = CartesianIndices(axes(A))
Base.eachindex(::IndexLabeledCartesian, A::LabeledArray) = LabeledCartesianIndices(axes(A))

unlabel(array::LabeledArray) = parent(array)

function Base.reverse(array::LabeledArray; dims::Integer)
    LabeledArray{labels(A)}(reverse(parent(A); dims=dims))
end
