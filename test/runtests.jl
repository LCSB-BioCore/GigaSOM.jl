using GigaSOM
using Test
using Random
# cd("..")

#fix the seed
Random.seed!(1)

include("Fcs_load_and_transform.jl")


(lineage_markers,)= getMarkers(panel)
# only use lineage_markers for clustering
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

som2 = initSOM(df_som, 10, 10, topol = :rectangular)

# using classical som training without epochs
@time som2 = trainSOM(som2, df_som, 100000)

@time mywinners = mapToSOM(som2, df_som)
CSV.write("../test/gendata/cell_clustering_som.csv", mywinners)

# myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)

codes = som2.codes
df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write("../test/gendata/df_codes.csv", df_codes)
CSV.write("../test/gendata/mywinners.csv", mywinners)
# CSV.write("myfreqs.csv", myfreqs)


df_codes_test = CSV.File("../test/gendata/df_codes.csv") |> DataFrame
ref_df_codes = CSV.File("../test/refdata/ref_df_codes.csv") |> DataFrame

mywinners_test = CSV.File("../test/gendata/mywinners.csv") |> DataFrame
ref_mywinners = CSV.File("../test/refdata/ref_mywinners.csv") |> DataFrame

@test ref_df_codes == df_codes_test

@test ref_mywinners == mywinners_test
