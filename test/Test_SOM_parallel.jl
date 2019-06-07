using Distributed

p = addprocs(2)

# @everywhere using Pkg
# @everywhere Pkg.add("DistributedArrays")
# @everywhere Pkg.add("DataFrames")
# @everywhere Pkg.add("Distances")

@everywhere using DistributedArrays
@everywhere using GigaSOM
# @everywhere using DataFrames
# @everywhere using Distances
# @everywhere using Revise

# only use lineage_markers for clustering
cc = map(Symbol, lineage_markers)
df_som = daf.fcstable[:,cc]

# concatenate the dataset for performance testing
# df_som = vcat(df_som, df_som)
# n = 5
# for i in 1:n
#     # df_som = vcat(df_som, df_som)
# end


som2 = initSOM_parallel(df_som, 10, 10)

@time som2 = trainSOM_parallel(som2, df_som, size(df_som)[1], epochs = 10)

mywinners = mapToSOM(som2, df_som)
CSV.write("cell_clustering_som.csv", mywinners)

# myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)

codes = som2.codes
df_codes = DataFrame(codes)
names!(df_codes, Symbol.(som2.colNames))
CSV.write("df_codes.csv", df_codes)
CSV.write("mywinners.csv", mywinners)
# CSV.write("myfreqs.csv", myfreqs)
