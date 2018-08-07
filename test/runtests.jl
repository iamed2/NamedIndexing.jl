using Test
using NamedIndexing

@testset "NamedIndexing" begin

@testset "NamedAxisArray" begin
    A = NamedAxisArray(rand(3, 2), (:foo, :bar))
    @test axisnames(A) == (:foo, :bar)

    Acolons = A[foo=:, bar=:]
    @test axisnames(Acolons) == axisnames(A)
    @test Acolons.data == A.data
end

end
