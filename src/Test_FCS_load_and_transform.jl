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
Pkg.add("XLSX")
Pkg.add("DataFrames")
Pkg.add("CSV")

cd("/home/ohunewald/work/GigaSOM_data/test_data")

# import XLSX
using XLSX, DataFrames
using CSV

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

# load the first fcs file in the metadata list
flowrun = load(md.file_name[1])
flowrun.params

# flowrun.data[("164Dy_CD15_SSEA_1_", "174Yb_CD4")]
get(flowrun.data, "164Dy_CD15_SSEA_1_",5)

fcs = readflowset(md.file_name)
# remove critical characters in keys from flowrun


# from R:
# # Replace problematic characters
# panel_fcs$desc <- gsub("-", "_", panel_fcs$desc)
# =#
# for k in keys(flowrun.data)
#     k = replace(k, "-"=>"_") for k in
#
# end

##################################################
# subselect columns and do arcsinh transformation
##################################################


# keys(flowrun.data) == panel.Antigen
# all(lineage_markers .== keys(flowrun.data))
