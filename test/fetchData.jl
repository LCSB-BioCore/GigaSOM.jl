using DataFrames, XLSX

dataPath = "data"

# create a test folder
mkdir(dataPath)
cd(dataPath)

# fetch the required data for testing
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_metadata.xlsx", "PBMC8_metadata.xlsx")
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_panel.xlsx", "PBMC8_panel.xlsx")

# download the zip archive and unzip it
download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/PBMC8_fcs_files.zip", "PBMC8_fcs_files.zip")
run(`unzip PBMC8_fcs_files.zip`)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)
