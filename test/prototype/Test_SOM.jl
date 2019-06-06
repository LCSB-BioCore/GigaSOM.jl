
# # only use lineage_markers for clustering
# cc = map(Symbol, lineage_markers)
# df_som = daf.fcstable[:,cc]
#
# som2 = initSOM(df_som, 10, 10, topol = :rectangular)

# using classical som training without epochs
# @time som2 = trainSOM(som2, df_som, 100000)
#
# @time mywinners = mapToSOM(som2, df_som)
# CSV.write("../test/gendata/cell_clustering_som.csv", mywinners)
#
# # myfreqs = SOM.classFrequencies(som2, daf.fcstable, :sample_id)
#
# codes = som2.codes
# df_codes = DataFrame(codes)
# names!(df_codes, Symbol.(som2.colNames))
# CSV.write("../test/gendata/df_codes.csv", df_codes)
# CSV.write("../test/gendata/mywinners.csv", mywinners)
# # CSV.write("myfreqs.csv", myfreqs)
#
#
# df_codes_test = CSV.File("../test/gendata/df_codes.csv") |> DataFrame
# ref_df_codes = CSV.File("../test/refdata/ref_df_codes.csv") |> DataFrame
#
# mywinners_test = CSV.File("../test/gendata/mywinners.csv") |> DataFrame
# ref_mywinners = CSV.File("../test/refdata/ref_mywinners.csv") |> DataFrame
#
# @test ref_df_codes == df_codes_test
# @test ref_mywinners == mywinners_test

#=
R"install.packages('BiocManager','https://CRAN.R-project.org/package=BiocManager')"
@rlibrary("BiocManager")
@rlibrary("ConsensusClusterPlus")

mc = ConsensusClusterPlus_2(transpose(codes), maxK = 20, reps = 100,
                           pItem = 0.9, pFeature = 1, title = "plot_outdir", plot = "png",
                           clusterAlg = "hc", innerLinkage = "average", finalLinkage = "average",
                           distance = "euclidean", seed = 1234)

mc = [x for x in mc]

## Get cluster ids for each cell
cell_clustering1 = mc[mywinners.index]
xcluster = hcat(df_som, cell_clustering1)
expr_median = aggregate(xcluster, :x1, median)


# Calculate cluster frequencies
# using FreqTables
# clustering_table = freqtable(cell_clustering1)
#
# x=clustering_table / sum(clustering_table) * 100
# clustering_prop = round.(x, digits=2) # couldn't combine these two functions
#
#
# using Distances
# euclidean.(Matrix(expr_median))
#
#
# R = pairwise.(euclidean, Matrix(expr_median), dims=2)
#
#
#
# one7d = rand(7)
# two7d = rand(7)
# dist = euclidean(one7d,two7d)



# Sort the cell clusters with hierarchical clustering
# d <- dist(expr_median[, colnames(expr)], method = "euclidean")
# cluster_rows <- hclust(d, method = "average")
# expr_heat <- as.matrix(expr_median[, colnames(expr)])
# rownames(expr_heat) <- expr_median$cell_clustering

using PyPlot

pyplot()
ys = [string("y", i) for i = 1:20]
xs=[string(i) for i in cc]

Plots.heatmap(xs,ys,Matrix(expr_median[:, 2:11]), xtickfont = font(4, "Courier"))




using Plotly
my_plot = plot([scatter(x=[1,2], y=[3,4])], Layout(title="My plot"))



# Calculate cluster frequencies
clustering_table <- as.numeric(table(cell_clustering))
clustering_prop <- round(clustering_table / sum(clustering_table) * 100, 2)
# Sort the cell clusters with hierarchical clustering
d <- dist(expr_median[, colnames(expr)], method = "euclidean")
cluster_rows <- hclust(d, method = "average")
expr_heat <- as.matrix(expr_median[, colnames(expr)])
rownames(expr_heat) <- expr_median$cell_clustering







code_clustering1 <- mc[[nmc]]$consensusClass
cell_clustering1 <- code_clustering1[cell_clustering_som]
=#
