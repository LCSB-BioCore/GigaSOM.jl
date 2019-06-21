## Script  to visualize the test dataset
## In order to get the same layout as in the original described
## workflow, we use their heatmap processing

install.packages("readxl")
library(readxl)
library(flowCore)

rm(list=ls())
setwd("C:/Users/vasco.verissimo/ownCloud/PhD Vasco/CyTOF Project/CyTOF Data")

metadata_filename <- "PBMC8_metadata.csv"

md <- read_excel(metadata_filename)

## Make sure condition variables are factors with the right levels
md$condition <- factor(md$condition, levels = c("Ref", "BCRXL"))
head(data.frame(md))

## Define colors for conditions
color_conditions <- c("#6A3D9A", "#FF7F00")
names(color_conditions) <- levels(md$condition)

fcsRaw <- read.flowSet(md$file_name, transformation = FALSE,
                        truncate_max_range = FALSE)
fcsRaw

panel_filename <- "PBMC8_panel.csv"
panel <- read_excel(panel_filename)
head(data.frame(panel))

# Replace problematic characters
panel$fcs_colname <- gsub("-", "_", panel$Antigen)

panel_fcs <- pData(parameters(fcsRaw[[1]]))
head(panel_fcs)

# Replace problematic characters
panel_fcs$desc <- gsub("-", "_", panel_fcs$desc)

# Lineage markers
(lineageMarkers <- panel$fcs_colname[panel$Lineage == 1])

# Functional markers
(functionalMarkers <- panel$fcs_colname[panel$Functional == 1])

# Spot checks
all(lineageMarkers %in% panel_fcs$desc)

all(functionalMarkers %in% panel_fcs$desc)

## arcsinh transformation and column subsetting
fcs <- fsApply(fcsRaw, function(x, cofactor=5){
  colnames(x) <- panel_fcs$desc
  expr <- exprs(x)
  expr <- asinh(expr[, c(lineageMarkers, functionalMarkers)] / cofactor)
  exprs(x) <- expr
  x
})
fcs

## Extract expression
expr <- fsApply(fcs, exprs)
dim(expr)

library(matrixStats)
rng <- colQuantiles(expr, probs = c(0.01, 0.99))
expr01 <- t((t(expr) - rng[, 1]) / (rng[, 2] - rng[, 1]))
expr01[expr01 < 0] <- 0
expr01[expr01 > 1] <- 1

## Generate sample IDs corresponding to each cell in the 'expr' matrix
sample_ids <- rep(md$sample_id, fsApply(fcsRaw, nrow))
library(ggplot2)
library(reshape2)
ggdf <- data.frame(sample_id = sample_ids, expr)
ggdf <- melt(ggdf, id.var = "sample_id",
             value.name = "expression", variable.name = "antigen")
mm <- match(ggdf$sample_id, md$sample_id)
ggdf$condition <- md$condition[mm]


library(dplyr)
# Get the median marker expression per sample
expr_median_sample_tbl <- data.frame(sample_id = sample_ids, expr) %>%
  group_by(sample_id) %>% summarize_all(funs(median))
expr_median_sample <- t(expr_median_sample_tbl[, -1])
colnames(expr_median_sample) <- expr_median_sample_tbl$sample_id
library(limma)
mds <- plotMDS(expr_median_sample, plot = FALSE)
library(ggrepel)
ggdf <- data.frame(MDS1 = mds$x, MDS2 = mds$y,
                   sample_id = colnames(expr_median_sample))
mm <- match(ggdf$sample_id, md$sample_id)
ggdf$condition <- md$condition[mm]


library(RColorBrewer)
library(pheatmap)

cc_som <- read.csv("cell_clustering_som.csv")
cc_som <- cc_som$index
cell_clustering_som <- as.numeric(cc_som)
# cell_clustering_som <- som$map$mapping[,1]

## Metaclustering into 20 clusters with ConsensusClusterPlus

dfCodes <- read.csv("dfCodes.csv")
codes <- as.matrix(dfCodes)
daf <- read.csv("daf.csv")
dafcolnames <- colnames(daf)

daf <- daf[1:(length(daf)-1)]
daf_lineage <- c("CD3.110.114.Dd", "CD45.In115.Dd", "CD4.Nd145.Dd", "CD20.Sm147.Dd",
                 "CD33.Nd148.Dd", "CD123.Eu151.Dd", "CD14.Gd160.Dd", "IgM.Yb171.Dd",
                 "HLA_DR.Yb174.Dd", "CD7.Yb176.Dd")

library(ConsensusClusterPlus)

plot_outdir <- "consensus_plots"
nmc <- 20
mc <- ConsensusClusterPlus(t(codes), maxK = nmc, reps = 100,
                           pItem = 0.9, pFeature = 1, title = plot_outdir, plot = "png",
                           clusterAlg = "hc", innerLinkage = "average", finalLinkage = "average",
                           distance = "euclidean", seed = 1234)
## Get cluster ids for each cell
code_clustering1 <- mc[[nmc]]$consensusClass
cell_clustering1 <- code_clustering1[cell_clustering_som]

## Figure 6. Heatmap of the median marker intensities of the 10 lineage markers across the 20 cell populations
## obtained with FlowSOM after the metaclustering step with ConsensusClusterPlus (PBMC data).

# Define cluster colors (here there are 30 colors)
color_clusters <- c("#DC050C", "#FB8072", "#1965B0", "#7BAFDE", "#882E72",
                    "#B17BA6", "#FF7F00", "#FDB462", "#E7298A", "#E78AC3",
                    "#33A02C", "#B2DF8A", "#55A1B1", "#8DD3C7", "#A6761D",
                    "#E6AB02", "#7570B3", "#BEAED4", "#666666", "#999999",
                    "#aa8282", "#d4b7b7", "#8600bf", "#ba5ce3", "#808000",
                    "#aeae5c", "#1e90ff", "#00bfff", "#56ff0d", "#ffff00")

plot_clustering_heatmap_wrapper <- function(expr, expr01,
                                            cell_clustering, color_clusters, cluster_merging = NULL){
  # Calculate the median expression
  expr_median <- data.frame(expr, cell_clustering = cell_clustering) %>%
    group_by(cell_clustering) %>% summarize_all(funs(median))
  expr01_median <- data.frame(expr01, cell_clustering = cell_clustering) %>%
    group_by(cell_clustering) %>% summarize_all(funs(median))

  colnames(expr_median) <- gsub('^X', '', colnames(expr_median))
  colnames(expr01_median) <- gsub('^X', '', colnames(expr01_median))

  # Calculate cluster frequencies
  clustering_table <- as.numeric(table(cell_clustering))
  clustering_prop <- round(clustering_table / sum(clustering_table) * 100, 2)
  # Sort the cell clusters with hierarchical clustering
  d <- dist(expr_median[, colnames(expr)], method = "euclidean")
  cluster_rows <- hclust(d, method = "average")
  expr_heat <- as.matrix(expr01_median[, colnames(expr01)])
  rownames(expr_heat) <- expr01_median$cell_clustering
  # Colors for the heatmap
  color_heat <- colorRampPalette(rev(brewer.pal(n = 9, name = "RdYlBu")))(100)
  legend_breaks = seq(from = 0, to = 1, by = 0.2)
  labels_row <- paste0(expr01_median$cell_clustering, " (", clustering_prop ,"%)")
  # Annotation for the original clusters
  annotation_row <- data.frame(Cluster = factor(expr01_median$cell_clustering))
  rownames(annotation_row) <- rownames(expr_heat)
  color_clusters1 <- color_clusters[1:nlevels(annotation_row$Cluster)]
  names(color_clusters1) <- levels(annotation_row$Cluster)
  annotation_colors <- list(Cluster = color_clusters1)
  # Annotation for the merged clusters
  if(!is.null(cluster_merging)){
    cluster_merging$new_cluster <- factor(cluster_merging$new_cluster)
    annotation_row$Cluster_merging <- cluster_merging$new_cluster
    color_clusters2 <- color_clusters[1:nlevels(cluster_merging$new_cluster)]
    names(color_clusters2) <- levels(cluster_merging$new_cluster)
    annotation_colors$Cluster_merging <- color_clusters2
  }

  pheatmap(expr_heat, color = color_heat, cluster_cols = FALSE,
           cluster_rows = cluster_rows, labels_row = labels_row,
           display_numbers = TRUE, number_color = "black",
           fontsize = 8, fontsize_number = 6, legend_breaks = legend_breaks,
           annotation_row = annotation_row, annotation_colors = annotation_colors)
}

plot_clustering_heatmap_wrapper(expr = daf[, daf_lineage],
                                expr01 = daf[, daf_lineage],
                                cell_clustering = cell_clustering1, color_clusters = color_clusters)
