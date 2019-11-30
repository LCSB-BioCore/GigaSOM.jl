# Testing Functions

@testset "Test Satellite Functions" begin

    @testset "gridRectangular" begin
        grid = GigaSOM.gridRectangular(5,5)
        @test size(grid) == (25, 2)
    end

    @testset "Kernel fun" begin
        using Distributions

        @test isapprox(GigaSOM.gaussianKernel(1, 6.0), 0.17603266; atol = 0.001)
    end

    @testset "distMatrix" begin
        g = GigaSOM.gridRectangular(2,2)
        dm = GigaSOM.distMatrix(g, false)
        @test size(dm) == (4,4)
    end

    @testset "normTrainData" begin
        g = zeros(2,2)
        x, normParams = GigaSOM.normTrainData(g, :none)
        # Test if none keeps the data unchanged
        @test x == g
    end

    @testset "convertTrainingData" begin
        df = DataFrame(Col1 = rand(5), Col2 = rand(5), Col3 = rand(5))
        df = GigaSOM.convertTrainingData(df)
        @test typeof(df) == Array{Float64,2}
    end
end