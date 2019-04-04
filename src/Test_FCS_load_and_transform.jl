# Load and transform
# build the general workflow to have the data ready
# for processing with GigaSOM

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#

using FileIO
Pkg.add("FCSFiles")
Pkg.add("DataFrames")
Pkg.add("CSV")

cd("/home/ohunewald/work/GigaSOM_data/test_data")

using DataFrames
using CSV
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


"data transformation, currently only asinh"
function transform_ff(flowset, method = "asinh", cofactor = 5)

    # loop through every file in dict
    # get the dataframe
    # convert to matrix
    # arcsinh transformation
    # convert back to dataframe
    for (k,v) in flowset
        single_fcs = flowset[k]
        colnames = names(single_fcs["data"]) # keep the column names
        dMatrix = Matrix(single_fcs["data"])
        # single_fcs["data"] = [(asinh(x)/cofactor) for x in dMatrix]
        dMatrix = [(asinh(x)/cofactor) for x in dMatrix]

        ddf = DataFrame(dMatrix)

        names!(ddf, Symbol.(colnames))
        single_fcs["data"] = ddf
        flowset[k] = single_fcs
    end
end

####################################################
# this is part of the original workflow in R
####################################################
# materialize a csv file as a DataFrame
md = CSV.File("metadata.xlsx") |> DataFrame
print(md)

# load panel data
panel = CSV.File("panel.csv") |> DataFrame
print(panel.Antigen)

# extrect lineage markers
lineage_markers = panel.Antigen[panel.Lineage .== 1, : ]
# remove critical characters
lineage_markers = [replace(i, "-"=>"_") for i in lineage_markers]

# TODO: remove critical characters in keys from flowrun
# implement as core function in readflowset? or manually
# as in original R workflow?
#
# for k in keys(flowrun.data)
#     k = replace(k, "-"=>"_") for k in
#
# end


fcs = readflowset(md.file_name)

# compare state of transfromation
file1data = fcs["file1.fcs"]["data"] # control before transfrom
transform_ff(fcs, "ar")
file2dat = fcs["file1.fcs"]["data"] # control after transform

# add sample_id as last column to DataFrame to keep track of samples
# not by default to keep readflowset more generic
for i in eachindex(md.Column1)
    df = fcs[md.file_name[i]]["data"]
    df[:sample_id] = string(md.sample_id[i])
# Do something with i and/or A[i]
end
# check last columns
file1data = fcs["file2.fcs"]["data"]
print(file1data[95:100, 32:36])


# TODO: barplot for samplesize
# create DF with sample ids and cells counts and conditon


# TODO: pca plot
# create DF with sample ids as columns, median expression per sample
dfall = vcat(fcs["file1.fcs"]["data"],fcs["file2.fcs"]["data"])
# by(dfall, :sample_id, :1 => mean)
aggregate(dfall, :sample_id, median)

select all except the last column
dfall[:, 1:(size(dfall,2)-1)]


transpose(dfall)


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
