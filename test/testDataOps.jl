@testset "High-level operations on distributed data" begin

W=addprocs(2)
@everywhere using GigaSOM

Random.seed!(1)
dd = rand(11111,5)

di1 = distribute_array(:test1, dd, W[1:1])
di2 = distribute_array(:test2, dd, W)

@testset "Distribution works as expected" begin
    @test distributed_collect(di1) == dd
    @test distributed_collect(di2) == dd
end

subsel=[1,3,4]
dd=dd[:,subsel]
dselect(di1, subsel)
dselect(di2, subsel)

@testset "dselect" begin
    @test distributed_collect(di1) == dd
    @test distributed_collect(di2) == dd
end

di3=dcopy(di2, :test3)

@testset "dcopy" begin
    @test di2.workers == di3.workers
    @test dd == distributed_collect(di3)
end

undistribute(di3)

(means1, sds1) = dstat(di1, [1,3])
(means2, sds2) = dstat(di2, [1,3])

@testset "dstat" begin
    @test length(means1)==2
    @test length(sds1)==2
    @test isapprox(means1, means2, atol=1e-8)
    @test isapprox(sds1, sds2, atol=1e-8)
    @test all([isapprox(0.5, m, atol=0.1) for m in means1])
    @test all([isapprox(0.29, s, atol=0.1) for s in sds1])
end

dscale(di1, [2,3])
dscale(di2, [2,3])
(means1, sds1) = dstat(di1, [1,2,3])
(means2, sds2) = dstat(di2, [1,2,3])

@testset "dscale" begin
    @test isapprox(means1, means2, atol=1e-8)
    @test isapprox(sds1, sds2, atol=1e-8)
    @test isapprox(0.5, means1[1], atol=0.1)
    @test all([isapprox(0.0, m, atol=1e-3) for m in means1[2:3]])
    @test all([isapprox(1.0, s, atol=1e-3) for s in sds1[2:3]])
end

dc = distributed_collect(di1)
dc[:,1:2]=asinh.(dc[:,1:2]./1.23)
dtransform_asinh(di1, [1,2], 1.23)
dtransform_asinh(di2, [1,2], 1.23)

@testset "dtransform_asinh" begin
    @test isapprox(distributed_collect(di1), dc)
    @test isapprox(distributed_collect(di2), dc)
end

undistribute(di1)
undistribute(di2)
rmprocs(W)

d=ones(Float64, 2,2)
di = distribute_array(:test, d, [1])
dscale(di, [1,2])
@testset "dscale does not produce NaNs on sdev==0" begin
    @test distributed_collect(di)==zeros(Float64, 2,2)
end
undistribute(di)

end
