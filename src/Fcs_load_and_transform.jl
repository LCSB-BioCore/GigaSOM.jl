# Load and transform
# build the general workflow to have the data ready

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#

# Pkg.add("FCSFiles")
# Pkg.add("DataFrames")
# Pkg.add("CSV")
# Pkg.add("StatsPlots")
# Pkg.add("Statistics")
# Pkg.add("MultivariateStats")

using FileIO
using FCSFiles
using CSV
using DataFrames
using StatsPlots
using Statistics
using MultivariateStats

using JuliaInterpreter

include("Fcs_helper.jl")
include("Plotting.jl")
include("GigaSOM.jl")

# cd("/home/ohunewald/work/GigaSOM_data/test_data")
cd("/home/ohunewald/work/GigaSOM_data/PBMC8_fcs_files")

# could not load library libGR.so
# ENV["GRDIR"]=""
# Pkg.build("GR")

# md = CSV.File("metadata.csv", types=[String, String, String, String]) |> DataFrame
# md = CSV.File("PBMC8_metadata.csv") |> DataFrame
md = CSV.File("PBMC8_metadata_large.csv") |> DataFrame
print(md)

# load panel data
# panel = CSV.File("panel.csv") |> DataFrame
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
cleannames!(fcs_raw)

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
