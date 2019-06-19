#fix the seed
Random.seed!(1)

# only use lineage_markers for clustering
(lineage_markers,)= getMarkers(panel)
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

som2 = initGigaSOM(df_som, 10, 10)

@testset "Dimensions - batch" begin
    @test size(som2.codes) == (100,10)
    @test som2.xdim == 10
    @test som2.ydim == 10
    @test som2.numCodes == 100
end

# using batch som with epochs
som2 = trainGigaSOM(som2, df_som, epochs = 1)

mywinners = mapToGigaSOM(som2, df_som)

#test batch
@testset "Batch" begin
    codes = som2.codes
    @test size(codes) == (100,10)

    df_codes = DataFrame(codes)
    names!(df_codes, Symbol.(som2.colNames))
    CSV.write(genDataPath*"/batch_df_codes.csv", df_codes)
    CSV.write(genDataPath*"/batch_mywinners.csv", mywinners)


    #preparing batch for testing
    ref_batch_df_codes = CSV.File(refDataPath*"/ref_batch_df_codes.csv") |> DataFrame
    ref_batch_mywinners = CSV.File(refDataPath*"/ref_batch_mywinners.csv") |> DataFrame
    batch_df_codes = CSV.File(genDataPath*"/batch_df_codes.csv") |> DataFrame
    batch_df_codes_test = first(batch_df_codes, 10)
    batch_mywinners = CSV.File(genDataPath*"/batch_mywinners.csv") |> DataFrame
    batch_mywinners_test = first(batch_mywinners, 10)

    for (i, j) in zip(batch_df_codes_test[:,1], ref_batch_df_codes[:,1])
        @test isapprox(i, j; atol = 0.001)
    end
    @test ref_batch_mywinners == batch_mywinners_test
end
