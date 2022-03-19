@testset "High-level operations on distributed data" begin

    W = addprocs(2)
    @everywhere using GigaSOM

    Random.seed!(1)
    dd = rand(11111, 5)
    buckets = rand([1, 2, 3], 11111)

    di1 = scatter_array(:test1, dd, W[1:1])
    di2 = scatter_array(:test2, dd, W)
    buckets1 = scatter_array(:buckets1, buckets, W[1:1])
    buckets2 = scatter_array(:buckets2, buckets, W)

    dc = gather_array(di1)
    dc[:, 1:2] = asinh.(dc[:, 1:2] ./ 1.23)
    dtransform_asinh(di1, [1, 2], 1.23)
    dtransform_asinh(di2, [1, 2], 1.23)

    @testset "dtransform_asinh" begin
        @test isapprox(gather_array(di1), dc)
        @test isapprox(gather_array(di2), dc)
    end

    unscatter(di1)
    unscatter(di2)
    rmprocs(W)
end
