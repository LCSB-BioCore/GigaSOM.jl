

# # only use lineage_markers for clustering
# cc = map(Symbol, lineage_markers)
# df_som = daf.fcstable[:,cc]
# df_som_large = vcat(df_som,df_som)
# df_som_large = vcat(df_som_large, df_som)
# # topology is now always rectangular
# # som2 = initSOM_parallel(df_som, 10, 10)
# som2 = initSOM_parallel(df_som, 10, 10)
#
# # using batch som with epochs
# # @time som2 = trainSOM_parallel(som2, df_som, size(df_som)[1], epochs = 10)
# som2 = trainSOM_parallel(som2, df_som_large, size(df_som_large)[1], epochs = 10)
#
# @time mywinners = mapToSOM(som2, df_som)
# CSV.write("cell_clustering_som.csv", mywinners)
#
# # myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)
#
# codes = som2.codes
# df_codes = DataFrame(codes)
# names!(df_codes, Symbol.(som2.colNames))
# CSV.write("df_codes.csv", df_codes)
# CSV.write("mywinners.csv", mywinners)
# # CSV.write("myfreqs.csv", myfreqs)
