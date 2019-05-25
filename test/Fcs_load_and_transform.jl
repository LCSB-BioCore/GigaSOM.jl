# Load and transform
# build the general workflow to have the data ready

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#
using DataFrames
using FileIO
using FCSFiles
using CSV
using DataFrames
using StatsPlots
using Statistics
using MultivariateStats
using JuliaInterpreter


include("../src/io/Fcs_helper.jl")
include("../src/visualization/Plotting.jl")
include("../src/GigaSOM.jl")


cd("C:/Users/vasco.verissimo/ownCloud/PhD Vasco/CyTOF Project/CyTOF Data")

md = CSV.File("PBMC8_metadata.csv") |> DataFrame
# md = CSV.File("PBMC8_metadata_large.csv") |> DataFrame
print(md)

# load panel data
panel = CSV.File("PBMC8_panel.csv") |> DataFrame
print(panel.Antigen)

# extract lineage markers
lineage_markers = panel.Antigen[panel.Lineage .== 1, : ]
functional_markers = panel.Antigen[panel.Functional .== 1, :]

# lineage_markers are 2d array,
# flatten this array by using vec:
lineage_markers = vec(lineage_markers)
functional_markers = vec(functional_markers)
cleannames!(lineage_markers)
cleannames!(functional_markers)

fcs_raw = readflowset(md.file_name)
# cleannames!(fcs_raw)

####################################
# barplot of cell counts per sample
####################################
plotcounts(fcs_raw, md)

# subset the data
# transform the data
# create daFrame file
daf = create_daFrame(fcs_raw, md, panel)

CSV.write("daf.csv", daf.fcstable)
####################################################################
# PCA plot
####################################################################
plotPCA(daf)
