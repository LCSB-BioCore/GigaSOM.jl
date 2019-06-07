# Load and transform
# build the general workflow to have the data ready

#=
using FCSFiles for loading
as this function is only the basic parsing of the binary
FCS, we need to see what functionality is missing and
extend this in the original package
=#


using GigaSOM, DataFrames, XLSX, CSV

cwd = pwd()

#create gendata folder
gendatapath = mktempdir()

#create data folder and change dir to it
dataPath = mktempdir()
cd(dataPath)

# fetch the required data for testing
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_metadata.xlsx", "PBMC8_metadata.xlsx")
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_panel.xlsx", "PBMC8_panel.xlsx")

# download the zip archive and unzip it
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_fcs_files.zip", "PBMC8_fcs_files.zip")
run(`unzip PBMC8_fcs_files.zip`)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)
panel[:Isotope] = map(string, panel[:Isotope])
panel[:Metal] = map(string, panel[:Metal])
panel[:Antigen] = map(string, panel[:Antigen])
panel.Metal[1]=""
insertcols!(panel,4,:fcs_colname => map((x,y,z)->x.*"(".*y.*z.*")".*"Dd",panel[:Antigen],panel[:Metal],panel[:Isotope]))
print(panel.fcs_colname)

lineage_markers, functional_markers = getMarkers(panel)

fcs_raw = readflowset(md.file_name)
cleannames!(fcs_raw)

# subset the data
# transform the data
# create daFrame file
daf = create_daFrame(fcs_raw, md, panel)
CSV.write(gendatapath*"/daf.csv", daf.fcstable)

# change the directory back to the current directory
cd(cwd)
