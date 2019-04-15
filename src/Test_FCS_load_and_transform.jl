# Load and transform
# build the general workflow to have the data ready
# for processing with GigaSOM

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#


Pkg.add("FCSFiles")
Pkg.add("DataFrames")
Pkg.add("CSV")
Pkg.add("StatsPlots")
Pkg.add("Statistics")


Pkg.add("MultivariateStats")

# cd("/home/ohunewald/work/GigaSOM_data/test_data")
cd("/home/ohunewald/work/GigaSOM_data/PBMC8_fcs_files")

using FileIO
using FCSFiles
using DataFrames
using CSV
using StatsPlots
using Statistics
using MultivariateStats
include("MyFunctions.jl")


# TODO: implement function
"applies a function to all data sets in this frame"
function fsApply(args)
    body
end

# TODO: write functions exprs (original from flowCore package)
# which returns the data matrix. Find if we can use some
# kind of named matrix with column names and rownumbers
"returns the data matrix of a flow files"
function exprs(args)
    body
end



" This function is a workaround for R's match"
# this is a helper to find which sampleid has which condition
function matched(v1::Array, v2::Array)
    # tb implemented
end

####################################################
# this is part of the original workflow in R
####################################################
# materialize a csv file as a DataFrame
# md = CSV.File("metadata.csv") |> DataFrame
md = CSV.File("PBMC8_metadata.csv") |> DataFrame
print(md)

# load panel data
# panel = CSV.File("panel.csv") |> DataFrame
panel = CSV.File("PBMC8_panel.csv") |> DataFrame
print(panel.Antigen)

# extract lineage markers
lineage_markers = panel.Antigen[panel.Lineage .== 1, : ]

# for whatever reason lineage_markers are cast into 2d array,
# flatten this array by using vec:
lineage_markers = vec(lineage_markers)

# remove critical characters
lineage_markers = [replace(i, "-"=>"_") for i in lineage_markers]
# place a '_' in front of each marker, as column names cannot start with a number
lineage_markers = [("_$i") for i in lineage_markers]

# fcs = readflowset(md.file_name)
fcs = readflowset2(md.file_name)
# compare state of transfromation
# file1data = fcs["file1.fcs"]["data"] # control before transfrom
# transform_ff(fcs, "ar")
transform_ff2(fcs, "ar")
# file2dat = fcs["file1.fcs"]["data"] # control after transform

# add sample_id as last column to DataFrame to keep track of samples
# not by default to keep readflowset more generic
for i in eachindex(md.file_name)
    df = fcs[md.file_name[i]]
    df[:sample_id] = string(md.sample_id[i])
end

# check last columns
# file1data = fcs["file2.fcs"]["data"]
file1data = fcs["PBMC8_30min_patient1_BCR-XL.fcs"]
print(file1data[95:100, 32:36])


########################################################
# Barplot sample size
########################################################
df_barplot = DataFrame(filename = String[], size = Int[], condition = String[])

for (k,v) in fcs
    sid = md.sample_id[k .== md.file_name]
    condition = md.condition[k .== md.file_name]
    push!(df_barplot, (sid[1], size(v)[1], condition[1]) )
end
sort!(df_barplot)
bar(df_barplot.filename, df_barplot.size, title="Numer of Cells", group=df_barplot.condition,xrotation=60)


####################################################################
# PCA plot
# create DF with sample ids as columns, median expression per sample
####################################################################
# put all df from dict into array
dfall = []
# some performance measures:
# iterate over dict in for loop is much faster than using
# list comprehension:
#  0.000090 seconds (67 allocations: 2.266 KiB)
#  0.079576 seconds (79.39 k allocations: 3.957 MiB)
@time for (k,v) in fcs
    push!(dfall,v)
end

# @time [push!(dfall,v) for (k,v) in fcs]

dfall = vcat(dfall...)

# reduce the dataset to lineage (and later) functional (state) markers
cc = map(Symbol, lineage_markers)
# cc = map(Symbol, ["_CD3(110:114)Dd", "_CD7(Yb176)Dd"])
push!(cc, :sample_id)
dfall = dfall[:, cc]

dfall_median = aggregate(dfall, :sample_id, median)

T = convert(Matrix, dfall_median)
samples_ids = T[:,1]
T_reshaped = permutedims(convert(Matrix{Float32}, T[:, 2:10]), [2, 1])

my_pca = fit(PCA, T_reshaped)

yte = MultivariateStats.transform(my_pca,T_reshaped)

df_pca = DataFrame(yte')
df_pca[:sample_id] = samples_ids

# get the condition per sample id and add in DF
v1= df_pca.sample_id; v2=md.sample_id
idxs = indexin(v1, v2)
df_pca[:condition] = md.condition[idxs]

StatsPlots.@df df_pca scatter(:x1, :x2, group=:condition)


# classical_mds(T_reshaped,4)

# names!(file1data, [Symbol("_$i") for i in 1:36])


# TODO: call fsApply  subset and transform to arcsinh
# this is the original part in R:
#
## arcsinh transformation and column subsetting
# fcs <- fsApply(fcs_raw, function(x, cofactor=5){
#   # browser()
#   colnames(x) <- panel_fcs$desc
#   expr <- exprs(x)
#   # use unique function because markers can be lineage AND functional
#   expr <- asinh(expr[, unique(c(lineage_markers, functional_markers))] / cofactor)
#   exprs(x) <- expr
#   x
# })
# fcs






##################################################
# subselect columns and do arcsinh transformation
##################################################


# keys(flowrun.data) == panel.Antigen
# all(lineage_markers .== keys(flowrun.data))


v1 = [8,6,7,11]; v2 = -10:10
using JuliaInterpreter