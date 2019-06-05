using GigaSOM
using Test
using Random
# cd("..")

#fix the seed
Random.seed!(1)

include("Fcs_load_and_transform.jl")

# #test cleannames
# for i in eachindex(lineage_markers)
#         test_clean = @test !in("-",i)
#         return test_clean
# end



(lineage_markers,)= getMarkers(panel)


#BATCH & PARALLEL

# p = addprocs(2)
# only use lineage_markers for clustering
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]
df_som_large = vcat(df_som,df_som)
# df_som_large = vcat(df_som_large, df_som)
# topology is now always rectangular
# som2 = initSOM_parallel(df_som, 10, 10)
som2 = initSOM_parallel(df_som, 10, 10)

# using batch som with epochs
@time som2 = trainSOM_parallel(som2, df_som, size(df_som)[1], epochs = 1)
# som2 = trainSOM_parallel(som2, df_som_large, size(df_som_large)[1], epochs = 2)

@time mywinners = mapToSOM(som2, df_som)
CSV.write("../test/gendata/batch_cell_clustering_som.csv", mywinners)

# myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)

codes = som2.codes
df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write("../test/gendata/batch_df_codes.csv", df_codes)
CSV.write("../test/gendata/batch_mywinners.csv", mywinners)
# CSV.write("myfreqs.csv", myfreqs)

# ref_batch_df_codes = CSV.File("../test/refdata/ref_batch_df_codes.csv") |> DataFrame
batch_df_codes_test = CSV.File("../test/gendata/batch_df_codes.csv") |> DataFrame

# ref_batch_mywinners = CSV.File("../test/refdata/ref_batch_mywinners.csv") |> DataFrame
batch_mywinners_test = CSV.File("../test/gendata/batch_mywinners.csv") |> DataFrame


# @test ref_batch_df_codes == batch_df_codes_test
# @test ref_batch_mywinners == batch_mywinners_test

rm("../test/data", recursive=true)
rm("../test/gendata", recursive=true)
