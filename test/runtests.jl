using Test
using LabeledArrays

@testset "LabeledArrays" begin

@testset "labels" begin
    A = LabeledArray(rand(-10:10, (3, 2)), (:foo, :bar))
    @test labels(A) == (:foo, :bar)
end

@testset "indexing" begin

    A = LabeledArray(rand(-10:10, (3, 2)), (:foo, :bar))

    colons = [(foo=:, bar=:), (bar=:, foo=:), (bar=:,), (foo=:,), (bar=:, axis3=1)]
    @testset "colons: $nt" for nt in colons
        subarray = @inferred getindex(A; collect(zip(keys(nt), values(nt)))...)
        @test labels(subarray) == labels(A)
        @test subarray.data == A.data
    end

    cases = [(1,), (1, 1, 1), (1, 2)]
    @testset "standard indexing: $args" for args in cases
        subarray = @inferred A[args...]
        @test subarray isa Integer
        @test subarray == A.data[args...]
    end

    cases = begin
        [(:foo,) => (1:1, 2), (:bar,) => (1, 1:1), (:foo, :bar) => (1:1, 1:1),
             (:foo, LabeledArrays.AUTO_AXIS_NAMES[3]) => (1:1, 2, 1:1)]
    end
    @testset "standard indexing: $args" for (axisnames, args) in cases
        subarray = @inferred A[args...]
        @test axisnames == labels(subarray)
        @test subarray.data == A.data[args...]
    end


    @testset "labeled indexing" begin
        @test @inferred(A[bar=1, foo=2]) == A.data[2, 1]
        @test @inferred(A[foo=2, bar=1]) == A.data[2, 1]
        @test @inferred(A[foo=1:2, bar=1]) == A.data[1:2, 1]
        @test labels(A[foo=1:2, bar=1]) == (:foo, )
        @test @inferred(A[foo=1:2]) == A.data[1:2, :]
        @test labels(A[foo=1:2]) == (:foo, :bar)
        @test @inferred(A[foo=1:2, bear=1:1]) == A.data[1:2, :, 1:1]
        @test labels(A[foo=1:2, bear=1:1]) == (:foo, :bar, :bear)
        @test @inferred(A[foo=1:2, bear=1]) == A.data[1:2, :, 1]
        @test labels(A[foo=1:2, bear=1]) == (:foo, :bar)
        @test @inferred(A[foo=1:2, bear=:]) == A.data[1:2, :, :]
        @test labels(A[foo=1:2, bear=:]) == (:foo, :bar, :bear)
    end

    @testset "check relabeling" begin
        args = [:bar=>1:2, :foo=>2, LabeledArrays.AUTO_AXIS_NAMES[1]=>:]
        subarray = @inferred getindex(A; args...)
        @test subarray.data == A.data[2, 1:2, :]
        @test labels(subarray) == (:bar, LabeledArrays.AUTO_AXIS_NAMES[3])
    end

end

@testset "setindex!" begin
    A = LabeledArray(rand(-10:10, (3, 4)), (:foo, :bar))
    B = rand(-10:10, (2, 3))
    @inferred setindex!(A, B; foo=2:3, bar=1:3)
    @test A[foo=2:3, bar=1:3] == B
    @test A[CartesianIndex(1, 2)] == A.data[CartesianIndex(1, 2)]

    A = LabeledArray(rand(-10:10, (3, 4, 5)), (:a, :b, :c))
    B = LabeledArray(rand(-10:10, (5, 3, 4)), (:c, :a, :b))
    @inferred setindex!(A, B[a=1:2, b=2, c=1:3]; a=2:3, b=1, c=2:4)
    @test A[a=2:3, b=1, c=2:4].data == B[a=1:2, b=2, c=1:3].data'

    A = LabeledArray(rand(-10:10, (3, 4, 5)), (:a, :b, :c))
    B = LabeledArray(rand(-10:10, (5, 3, 4)), (:c, :a, :b))
    A[a=2:3, c=2:4] = B[a=1:2, c=1:3]
    @test A[a=2:3, c=2:4].data == permutedims(B[a=1:2, c=1:3].data, (2, 3, 1))

    A = LabeledArray(rand(-10:10, (3, 4, 5)), (:a, :b, :c))
    B = LabeledArray(rand(-10:10, (5, 3, 4)), (:c, :a, :b))
    A[a=2:3, b=:, c=2:4] = B[a=1:2, c=1:3]
    @test A[a=2:3, c=2:4].data == permutedims(B[a=1:2, b=:, c=1:3].data, (2, 3, 1))

    @test_throws DimensionMismatch A[a=2:3, b=1:2, c=2:4] = B[a=1:2, b=2, c=1:3]
    @test_throws DimensionMismatch A[a=2:3, b=1, c=2:4] = B[a=1:2, b=2:4, c=1:3]
    @test_throws DimensionMismatch A[a=2:3, b=1, c=2:4] = B[a=1:2, b=2, c=1:4]
end

@testset "permutations" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    @test permutedims(A, (1, 3, 2)) == permutedims(A, (1, 3, 2))
    @test permutedims(A, (1, :c, 2)) == permutedims(A, (1, 3, 2))
    ax = LabeledArrays.AUTO_AXIS_NAMES[2]
    @test permutedims(A, (1, :c, ax)) == permutedims(A, (1, 3, 2))
end

@testset "view" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    @test parent(view(A, b=1, a=1:2)) == view(parent(A), 1:2, 1, :)
    @test labels(view(A, b=1, a=1:2)) == (:a, :c)
end

@testset "similar" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))

    @test labels(similar(A)) == (:a, :b, :c)
    @test size(similar(A)) == size(A)
    @test eltype(similar(A)) == eltype(A)

    @test labels(similar(A, bar=2)) == (:bar,)
    @test size(similar(A, bar=2)) == (2,)
    @test eltype(similar(A, bar=2)) == eltype(A)

    @test labels(similar(A, Int8, 2, 3)) == (:a, :b)
    @test size(similar(A, Int8, 2, 3)) == (2, 3)
    @test eltype(similar(A, Int8)) === Int8
end

@testset "addition and substraction" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    B = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    @test labels(A + B) == labels(A)
    @test (A + B).data == A.data + B.data
    @test (A + permutedims(B, (:b, :c, :a))).data == A.data + B.data
    @test labels(A - B) == labels(A)
    @test (A - B).data == A.data - B.data
    @test (A - permutedims(B, (:b, :c, :a))).data == A.data - B.data
end

@testset "equality" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    B = copy(A)
    C = LabeledArray{labels(A)}(2A.data)
    @test A == A
    @test A == B
    @test !(A == C)
    @test !(A != A)
    @test !(A != B)
    @test A != C
end

@testset "scalar multiplication" begin
    A = LabeledArray(rand(-10:10, (3, 4, 2)), (:a, :b, :c))
    @test labels(2A) == labels(A)
    @test labels(A / 2) == labels(A)
    @test 2A == 2A.data
    @test (A / 2).data ≈ A.data / 2 atol=1e-8
end

@testset "Broadcasting" begin
    combine_axes(a...) = LabeledArrays.combine_axes(a...)

    @testset "unify shapes" begin
        @test combine_axes((a=2, b=3, c=4), (a=2, b=3, c=4)) == (a=2, b=3, c=4)
        @test combine_axes((a=2, c=4), (a=2, b=3, c=4)) == (a=2, c=4, b=3)
        @test combine_axes((a=2, c=4), (a=2, b=3)) == (a=2, c=4, b=3)
        @test combine_axes((a=2, b=1, c=4), (a=2, b=3, c=1)) == (a=2, b=3, c=4)
        @test combine_axes((a=2, c=4), NamedTuple()) == (a=2, c=4)
        @test combine_axes(NamedTuple(), (a=2, c=4)) == (a=2, c=4)
        @test_throws DimensionMismatch combine_axes((a=2, c=4), (a=2, c=5)) 
        
        args = ((a=1, b=2), (c=4, d=3), (d=3, a=2, e=2))
        @test LabeledArrays.broadcastshapes(args) == (a=2, b=2, c=4, d=3, e=2)

        args = ((a=1, b=2), (c=4, d=3), (4, ))
        @test LabeledArrays.broadcastshapes(args) == (a=4, b=2, c=4, d=3)

        args = ((a=4, b=2), (c=4, d=3), (4, ))
        @test LabeledArrays.broadcastshapes(args) == (a=4, b=2, c=4, d=3)

        args = ((a=4, b=2), (c=4, d=3), (4, 2))
        @test_throws DimensionMismatch LabeledArrays.broadcastshapes(args)

        args = ((a=4, b=2), (a=4, b=1, c=4, d=3), (4, 2))
        @test LabeledArrays.broadcastshapes(args) == (a=4, b=2, c=4, d=3)
        args = ((a=4, b=2), (a=4, b=1, c=4, d=3), (4, 2, 4))
        @test LabeledArrays.broadcastshapes(args) == (a=4, b=2, c=4, d=3)
        args = ((a=4, b=2), (a=4, c=4, b=1, d=3), (4, 2, 4))
        @test_throws DimensionMismatch LabeledArrays.broadcastshapes(args)
    end

    @testset "check bounds" begin
        la = LabeledAxes(a = 1:3, b=1:1, c=1:4)
        @test Base.checkbounds_indices(Bool, la, (a=1, c=1))
        @test Base.checkbounds_indices(Bool, la, (a=1, c=1, b=2)) == false
        @test Base.checkbounds_indices(Bool, la, (c=1, d=1))
        @test Base.checkbounds_indices(Bool, la, (c=5, d=1)) == false
    end

end

end
