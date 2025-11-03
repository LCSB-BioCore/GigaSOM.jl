
import GigaSOM: read_csv_size, read_csv_sizes

@testset "CSV loading" begin
    files = [refDataPath * "/refBatchDfCodes.csv", refDataPath * "/refParallelDfCodes.csv"]

    rows, cols = read_csv_size(files[1], header = true)
    @test rows == 10
    @test cols == 10

    data1 = load_csv(files[1], header = true)
    data2 = load_csv(files[2], header = true)
    @test typeof(data1) == Matrix{Float64}
    @test size(data1) == (10, 10)

    sizes = read_csv_sizes(files, header = true)
    @test sizes == [10, 10]

    W = addprocs(3)
    @everywhere using GigaSOM
    di = load_csv_distributed(:csvTest, files, W, header = true)
    @test gather_array(di) == vcat(data1, data2)
    sizes = dmapreduce(di, size, vcat)
    dims = map(last, sizes)
    counts = map(first, sizes)
    @test all(dims .== 10)
    @test minimum(counts) + 1 >= maximum(counts)
    rmprocs(W)
end
