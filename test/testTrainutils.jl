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

    @testset "Radii-generating functions" begin
        radii1 = expRadius().(5.0, 0.5, Vector(1:10), 10)
        radii2 = expRadius(-10.0).(10.0, 0.1, Vector(1:20), 20)
        radii3 = linearRadius.(50.0, 0.001, Vector(1:30), 30)
        @test isapprox(radii1[1], 5.0)
        @test isapprox(radii1[10], 0.5)
        @test isapprox(radii2[1], 10.0)
        @test isapprox(radii2[20], 0.1)
        @test isapprox(radii3[1], 50.0)
        @test isapprox(radii3[30], 0.001)
        @test all(isapprox.(radii1[1:9]./radii1[2:10], radii1[1]/radii1[2]))
        #note: radius2 is adjusted and thus not really exponential
        @test all(isapprox.(radii3[1:29].-radii3[2:30], radii3[1]-radii3[2]))
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
