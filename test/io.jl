

# Load and transform
# build the general workflow to have the data ready

# ENV["PYTHON"] = Sys.which("PYTHON")
ENV["PYTHON"] = "/usr/local/bin/python3.6"

using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON, PyCall

fcsparser = pyimport("fcsparser")

dataPath = ("../data_felD1")
# dataPath = ("../PBMC8_fcs_files")
cd(dataPath)
md = DataFrame(XLSX.readtable("metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers = vec(panel.Antigen[panel.Lineage .== 1, : ])
cleanNames!(lineageMarkers)
functionalMarkers = vec(panel.Antigen[panel.Functional .== 1, : ])
cleanNames!(functionalMarkers)

# check if all lineageMarkers are in markers
# issubset(lineageMarkers, markers)
# issubset(functionalMarkers, markers)

fcsRaw = readFlowset(md, fcsparser)

# create daFrame file
daf = createDaFrame(fcsRaw, md, panel, lineageMarkers, functionalMarkers)
CSV.write("daf.csv", daf.fcstable)
