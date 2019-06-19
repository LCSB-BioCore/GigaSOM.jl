#fix the seed
Random.seed!(1)

p = addprocs(2)
@everywhere using DistributedArrays
@everywhere using GigaSOM

# only use lineage_markers for clustering
(lineage_markers,)= getMarkers(panel)
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

# concatenate the dataset for performance testing
n = 0
for i in 1:n
    global df_som
    df_som = vcat(df_som, df_som)
end

som2 = initGigaSOM(df_som, 10, 10)

@testset "Dimensions - parallel" begin
    @test size(som2.codes) == (100,10)
    @test som2.xdim == 10
    @test som2.ydim == 10
    @test som2.numCodes == 100
end

som2 = trainGigaSOM(som2, df_som, epochs = 2, r = 6.0)

mywinners = mapToGigaSOM(som2, df_som)
CSV.write("cell_clustering_som.csv", mywinners)

mywinners = mapToGigaSOM(som2, df_som)

@testset "Parallel" begin
    codes = som2.codes
    @test size(codes) == (100,10)

    df_codes = DataFrame(codes)
    names!(df_codes, Symbol.(som2.colNames))
    CSV.write(genDataPath*"/parallel_df_codes.csv", df_codes)
    CSV.write(genDataPath*"/parallel_mywinners.csv", mywinners)

    # load the ref data
    ref_parallel_df_codes = CSV.File(refDataPath*"/ref_parallel_df_codes.csv") |> DataFrame
    ref_parallel_mywinners = CSV.File(refDataPath*"/ref_parallel_mywinners.csv") |> DataFrame

    # load the generated data
    parallel_df_codes = CSV.File(genDataPath*"/parallel_df_codes.csv") |> DataFrame
    parallel_mywinners = CSV.File(genDataPath*"/parallel_mywinners.csv") |> DataFrame

    # test the generated data against the reference data
    @test ref_parallel_mywinners == parallel_mywinners
    @test ref_parallel_df_codes == parallel_df_codes

    #test parallel
    for (i, j) in zip(parallel_df_codes[:,1], ref_parallel_df_codes[:,1])
        @test isapprox(i, j; atol = 0.001)
    end

end
