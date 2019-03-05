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

    A = LabeledArray(rand(-10:10, (3, 4, 5)), (:a, :b, :c))
    B = LabeledArray(rand(-10:10, (5, 3, 4)), (:c, :a, :b))
    A[a=2:3, b=1, c=2:4] = B[a=1:2, b=2, c=1:3]
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

end
