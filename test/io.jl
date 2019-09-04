

# Load and transform
# build the general workflow to have the data ready

#create genData and data folder and change dir to dataPath
cwd = pwd()
if occursin("jenkins", homedir()) || "TRAVIS" in keys(ENV)
    genDataPath = mktempdir()
    dataPath = mktempdir()
else
    if !occursin("test", cwd)
        cd("test")
        cwd = pwd()
    end
    dataFolders = ["genData", "data"]
    for dir in dataFolders
        if !isdir(dir)
            mkdir(dir)
        end
    end
    genDataPath = cwd*"/genData"
    dataPath = cwd*"/data"
end

# fetch the required data for testing and download the zip archive and unzip it
dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
        end
    else
    end
end

@testset "Checksums" begin
    cd(dataPath)
    filesNames = readdir()
    csDict = Dict()
    for f in filesNames
        cs = bytes2hex(sha256(f))
        csDict[f] = cs
    end
    cd(cwd*"/checkSums")
    csTest = JSON.parsefile("csTest.json")
    @test csDict == csTest
    cd(cwd)
end

dataPath = ("../PBMC8_fcs_files")
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
