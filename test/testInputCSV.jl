
@testset "CSV loading" begin
    files = [refDataPath * "/refBatchDfCodes.csv", refDataPath * "/refParallelDfCodes.csv"]

    rows, cols = getCSVSize(files[1], header = true)
    @test rows == 10
    @test cols == 10

    data1 = loadCSV(files[1], header = true)
    data2 = loadCSV(files[2], header = true)
    @test typeof(data1) == Matrix{Float64}
    @test size(data1) == (10, 10)

    sizes = loadCSVSizes(files, header = true)
    @test sizes == [10, 10]

    W = addprocs(3)
    @everywhere using GigaSOM
    di = loadCSVSet(:csvTest, files, W, header = true)
    @test distributed_collect(di) == vcat(data1, data2)
    sizes = distributed_mapreduce(di, size, vcat)
    dims = map(last, sizes)
    counts = map(first, sizes)
    @test all(dims .== 10)
    @test minimum(counts) + 1 >= maximum(counts)
    rmprocs(W)
end
