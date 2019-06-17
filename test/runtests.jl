using GigaSOM
using Test
using Random
using Distributed

#fix the seed
Random.seed!(1)

include("io.jl")

#test cleannames
@testset "cleannames" begin
    for i in eachindex(lineage_markers)
            test_clean = @test !in("-",i)
            return test_clean
    end

    for i in eachindex(functional_markers)
            test_clean = @test !in("-",i)
            return test_clean
    end

    for (k,v) in fcs_raw
        colnames = names(v)
        for i in eachindex(colnames)
            test_clean = @test !in("-",i)
            return test_clean
        end
    end
end



# only use lineage_markers for clustering
(lineage_markers,)= getMarkers(panel)
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

#BATCH
som2 = initGigaSOM(df_som, 10, 10)

@testset "GigaSOM initialisation" begin
    @testset "Type test" begin
        @test typeof(som2) == GigaSOM.Som
        @test som2.toroidal == false
        @test typeof(som2.grid) == Array{Float64,2}
    end
    @testset "Dimensions Test" begin
        @test size(som2.codes) == (100,10)
        @test som2.xdim == 10
        @test som2.ydim == 10
        @test som2.numCodes == 100
    end
end

# using batch som with epochs
@time som2 = trainGigaSOM(som2, df_som, epochs = 1)

@time mywinners = mapToGigaSOM(som2, df_som)

codes = som2.codes
@test size(codes) == (100,10)

df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write(genDataPath*"/batch_df_codes.csv", df_codes)
CSV.write(genDataPath*"/batch_mywinners.csv", mywinners)

#TEST BATCH

refDataPath = cwd*"/refData"

@info genDataPath
@info refDataPath

#preparing batch for testing
ref_batch_df_codes = CSV.File(refDataPath*"/ref_batch_df_codes.csv") |> DataFrame
ref_batch_mywinners = CSV.File(refDataPath*"/ref_batch_mywinners.csv") |> DataFrame
batch_df_codes = CSV.File(genDataPath*"/batch_df_codes.csv") |> DataFrame
batch_df_codes_test = first(batch_df_codes, 10)
batch_mywinners = CSV.File(genDataPath*"/batch_mywinners.csv") |> DataFrame
batch_mywinners_test = first(batch_mywinners, 10)

#test batch
@testset "refData_batch" begin
    for (i, j) in zip(batch_df_codes_test[:,1], ref_batch_df_codes[:,1])
        test_batch_df = @test isapprox(i, j; atol = 0.000001)
        return test_batch_df
    end
    @test ref_batch_mywinners == batch_mywinners_test
end

include("parallel.jl")
