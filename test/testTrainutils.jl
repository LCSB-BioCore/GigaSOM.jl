@testset "SOM training helper functions" begin

    @testset "gridRectangular" begin
        grid = GigaSOM.gridRectangular(5,5)
        @test size(grid) == (25, 2)
    end

    @testset "Kernels" begin
        @test isapprox(
            GigaSOM.gaussianKernel(Vector{Float64}(1:7), 5.0),
            [0.199934, 0.116511, 0.047370, 0.013436, 0.002659, 0.000367, 0.000035],
            atol = 0.001)
        @test isapprox(
            GigaSOM.bubbleKernel(Vector{Float64}(1:6), 5.0),
            [0.979796, 0.916515, 0.8, 0.6, 0, 0],
            atol = 0.001)
    end

    @testset "distMatrix" begin
        g = GigaSOM.gridRectangular(2,2)
        dm = GigaSOM.distMatrix(g, false)
        @test size(dm) == (4,4)
        @test all([dm[i,i]==0 for i in 1:4])
    end

    @testset "convertTrainingData" begin
        df = DataFrame(Col1 = rand(5), Col2 = rand(5), Col3 = rand(5))
        df = GigaSOM.convertTrainingData(df)
        @test typeof(df) == Matrix{Float64}
    end
end
