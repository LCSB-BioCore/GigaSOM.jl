
# This loads the PBMC8 dataset that is used for later tests

checkDir()

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

refDataPath = cwd*"/refData"
cd(dataPath)

# verify the data consistency using the stored checksums
fileNames = readdir()
csDict = Dict{String, Any}()
for f in fileNames
    if  f[end-3:end] == ".fcs" || f[end-4:end] == ".xlsx"
        cs = bytes2hex(sha256(f))
        csDict[f] = cs
    end
end
csTest = JSON.parsefile(cwd*"/checkSums/csTest.json")
if csDict == csTest
    @error "Downloaded dataset does not match expectations, perhaps it is corrupted?"
    error("dataset checksum error")
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

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

antigens=panel[panel[:,:Lineage].==1, :Antigen]
_,fcsParams = loadFCSHeader(md[1,:file_name])
_,fcsAntigens = getMarkerNames(getMetaData(fcsParams))
cleanNames!(antigens)
cleanNames!(fcsAntigens)

di=loadFCSSet(:fcsData, md[:,:file_name], [myid()])

#prepare the data a bit
dselect(di, fcsAntigens, antigens)
cols=Vector(1:length(antigens))
dtransform_asinh(di, cols, 5)
dscale(di, cols)

pbmc8_data = distributed_collect(di)
undistribute(di)

