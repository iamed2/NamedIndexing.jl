using Test
using NamedIndexing

@testset "NamedIndexing" begin

@testset "axisnames" begin
    A = NamedAxisArray(rand(-10:10, (3, 2)), (:foo, :bar))
    @test axisnames(A) == (:foo, :bar)
end

@testset "indexing" begin

    A = NamedAxisArray(rand(-10:10, (3, 2)), (:foo, :bar))

    colons = [(foo=:, bar=:), (bar=:, foo=:), (bar=:,), (foo=:,), (bar=:, axis3=1)]
    @testset "colons: $nt" for nt in colons
        subarray = @inferred getindex(A; collect(zip(keys(nt), values(nt)))...)
        @test axisnames(subarray) == axisnames(A)
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
             (:foo, NamedIndexing.AUTO_AXIS_NAMES[3]) => (1:1, 2, 1:1)]
    end
    @testset "standard indexing: $args" for (labels, args) in cases
        subarray = @inferred A[args...]
        @test labels == axisnames(subarray)
        @test subarray.data == A.data[args...]
    end


    @testset "labeled indexing" begin
        @test @inferred(A[bar=1, foo=2]) == A.data[2, 1]
        @test @inferred(A[foo=2, bar=1]) == A.data[2, 1]
        @test @inferred(A[foo=1:2, bar=1]) == A.data[1:2, 1]
        @test axisnames(A[foo=1:2, bar=1]) == (:foo, )
        @test @inferred(A[foo=1:2]) == A.data[1:2, :]
        @test axisnames(A[foo=1:2]) == (:foo, :bar)
        @test @inferred(A[foo=1:2, bear=1:1]) == A.data[1:2, :, 1:1]
        @test axisnames(A[foo=1:2, bear=1:1]) == (:foo, :bar, :bear)
        @test @inferred(A[foo=1:2, bear=1]) == A.data[1:2, :, 1]
        @test axisnames(A[foo=1:2, bear=1]) == (:foo, :bar)
        @test @inferred(A[foo=1:2, bear=:]) == A.data[1:2, :, :]
        @test axisnames(A[foo=1:2, bear=:]) == (:foo, :bar, :bear)
    end

    @testset "check relabelling" begin
        args = [:bar=>1:2, :foo=>2, NamedIndexing.AUTO_AXIS_NAMES[1]=>:]
        subarray = @inferred getindex(A; args...)
        @test subarray.data == A.data[2, 1:2, :]
        @test axisnames(subarray) == (:bar, NamedIndexing.AUTO_AXIS_NAMES[3])
    end

end

end
