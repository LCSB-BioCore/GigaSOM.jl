using GigaSOM
using Test
using Random

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



#BATCH & PARALLEL

# only use lineage_markers for clustering
(lineage_markers,)= getMarkers(panel)

cc = map(Symbol, lineage_markers)

df_som = daf.fcstable[:,cc]
df_som_large = vcat(df_som,df_som)
df_som_large = vcat(df_som_large, df_som)
# topology is now always rectangular

som2 = initGigaSOM(df_som, 10, 10)

# using batch som with epochs
@time som2 = trainGigaSOM(som2, df_som_large, epochs = 1)

@time mywinners = mapToSOM(som2, df_som)

codes = som2.codes
df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write(genDataPath*"/batch_df_codes.csv", df_codes)
CSV.write(genDataPath*"/batch_mywinners.csv", mywinners)

refDataPath = cwd*"/refData"

@info genDataPath
@info refDataPath

ref_batch_df_codes = CSV.File(refDataPath*"/ref_batch_df_codes.csv") |> DataFrame
ref_batch_mywinners = CSV.File(refDataPath*"/ref_batch_mywinners.csv") |> DataFrame
batch_df_codes = CSV.File(genDataPath*"/batch_df_codes.csv") |> DataFrame
batch_df_codes_test = first(batch_df_codes, 10)
batch_mywinners = CSV.File(genDataPath*"/batch_mywinners.csv") |> DataFrame
batch_mywinners_test = first(batch_mywinners, 10)

@test ref_batch_df_codes == batch_df_codes_test
@test ref_batch_mywinners == batch_mywinners_test


include("parallel.jl")
