using Test
using NamedIndexing

@testset "NamedIndexing" begin

    @testset "Get index" begin
        A = NamedAxisArray(rand(1:10, (3, 2)), (:foo, :bar))
        @test axisnames(A) == (:foo, :bar)

        Acolons = A[foo=:, bar=:]
        @test axisnames(Acolons) == axisnames(A)
        @test Acolons.data == A.data

        i, j = rand(1:size(A, 1)), rand(1:size(A, 2))
        @test @inferred(A[i, j]) == A.data[i, j]

        i = rand(1:length(A))
        @test A[i] == A.data[i]

        @test all(A[foo=1] .== A.data[1, :])
        @test axisnames(A[foo=1]) == (:bar, )
        @test all(A[bar=2] .== A.data[:, 2])
        @test axisnames(A[bar=2]) == (:foo, )
    end

    @testset "Set index" begin
        A = NamedAxisArray(rand(1:10, (3, 2)), (:foo, :bar))

        i, j = rand(1:size(A, 1)), rand(1:size(A, 2))
        A[i, j] = 0
        @test A.data[i, j] == 0
        A[i, j] = 1
        @test A.data[i, j] == 1

        i = rand(1:length(A))
        A[i] = 0
        @test A.data[i] == 0
        A[i] = 1
        @test A.data[i] == 1
    end
end
