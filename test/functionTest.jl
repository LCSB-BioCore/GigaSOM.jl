# Testing 


@testset "Test Satellite Functions" begin

    @testset "gridRectangular" begin
        grid = GigaSOM.gridRectangular(5,5)
        @test size(grid) == (25, 2)
    end

    @testset "Kernel fun" begin
        using Distributions

        @test isapprox(GigaSOM.gaussianKernel(1, 6.0), 0.17603266; atol = 0.001)
    end
end