


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
