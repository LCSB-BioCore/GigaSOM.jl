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
# Pkg.add("XLSX")
Pkg.add("DataFrames")
Pkg.add("CSV")

cd("/home/ohunewald/work/GigaSOM_data/test_data")

# import XLSX
using DataFrames
using CSV

"reads in FCS files from metada list and retuns a flowset"
function readflowset(f_names)
    flowFrame = Dict()
    # read all FCS files into flowFrame
    for fname in f_names

        flowfile = Dict()
        flowrun = load(fname) # FCS file
        flowfile["params"] = flowrun.params
        # change the data structure into a dataframe
        df = DataFrame()
        for (k,v) in flowrun.data
            df[Symbol(k)] = v
        end
        flowfile["data"] = df

        flowFrame[fname] = flowfile
    end
    return flowFrame
end

# TODO: implement function
"applies a function to all data sets in this frame"
function fsApply(args)
    body
end

# TODO: implement transformation on complete dataset
"data transformation, currently only asinh"
function transform_ff(flowset; method = "asinh")

    # asinh()

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
