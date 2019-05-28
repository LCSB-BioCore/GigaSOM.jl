# Load and transform
# build the general workflow to have the data ready

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#
using GigaSOM
using CSV
using DataFrames

dataPath = "../data/"

cd(dataPath)

md = CSV.File("PBMC8_metadata.csv") |> DataFrame
print(md)

# load panel data
panel = CSV.File("PBMC8_panel.csv") |> DataFrame
print(panel.Antigen)

fcs_raw = readflowset(md.file_name)
# cleannames!(fcs_raw)

# subset the data
# transform the data
# create daFrame file
daf = create_daFrame(fcs_raw, md, panel)
CSV.write("daf.csv", daf.fcstable)
