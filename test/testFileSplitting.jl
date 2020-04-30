@testset "File splitting" begin

W = addprocs(8)
@everywhere using GigaSOM

# re-use the PBMC8 data:
# try load it by parts of different size and scrutinize the parts

for splitSize in 1:8
    di = loadFCSSet(:test, md[:,:file_name], W[1:splitSize])
    dselect(di, fcsAntigens, antigens)
    cols=Vector(1:length(antigens))
    dtransform_asinh(di, cols, 5)
    dscale(di, cols)
    @test isapprox(pbmc8_data, distributed_collect(di), atol=1e-4)
    
    splits = distributed_mapreduce(di, d->size(d,1), vcat)
    @test sum(splits)==size(pbmc8_data, 1)
    @test minimum(splits)+1 >= maximum(splits)

    sizes = loadFCSSizes(md[:,:file_name])
    dis = distributeFCSFileVector(:testF, md[:,:file_name], W[1:splitSize])
    @test dcount(length(sizes), dis) == sizes
    @test dcount_buckets(length(sizes), dis, length(sizes),dis) ==
            Matrix{Int}(LinearAlgebra.Diagonal(sizes))
end

rmprocs(W)
end
