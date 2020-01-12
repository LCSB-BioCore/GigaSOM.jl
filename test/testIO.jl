# Load and transform
# build the general workflow to have the data ready

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

# fetch the required data for testing and download the zip archive and unzip it
dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
            rm("PBMC8_fcs_files.zip", force=true)
        end
    else
    end
end

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)

fcsRaw = readFlowset(md.file_name)
cleanNames!(fcsRaw)

# create daFrame file
daf = createDaFrame(fcsRaw, md, panel)

@testset "Single FCS file support (to be deprecated)" begin
    # call readFlowFrame with an array
    filename = md.file_name[1]
    ff = readFlowFrame([filename])
    cleanNames!(ff)
    dafsingle = createDaFrame(ff, md, panel)

    # return type is a Dict{} with 1 element
    @test typeof(ff) == Dict{Any,Any}
    @test length(ff) == 1
    @test typeof(dafsingle) == daFrame
end

@testset "Single FCS file support" begin
    # call readFlowFrame with a string
    filename = md.file_name[1]
    ff = readFlowFrame(filename)
    cleanNames!(ff)
    dafsingle = createDaFrame(ff, md, panel)

    # return type is a DataFrame
    @test typeof(ff) == DataFrame
    @test typeof(dafsingle) == daFrame
end

@testset "Sort and reduce test" begin

    df = DataFrame(Col1 = rand(5), Col2 = rand(5), None = rand(5))
    namesDF = names(df)
    cc = [:Col1, :Col2]

    # testing reduce by column names
    dfReduce = GigaSOM.sortReduce(df, cc, true, true)
    @test namesDF != names(dfReduce)

    # testing :None removal
    df = DataFrame(Col1 = rand(5), Col2 = rand(5), None = rand(5))
    dfNoneRemoved = GigaSOM.sortReduce(df, cc, false, true)
    @test cc == names(dfNoneRemoved)

    # testing column sorting and none removing
    df = DataFrame(Col2 = rand(5), Col1 = rand(5), None = rand(5))
    dfSorted = GigaSOM.sortReduce(df, cc, false, true)
    @test names(dfSorted) == cc

end

# change the directory back to the current directory
cd(cwd)

#check if the markers from panel file are the same as loaded from the fcs file

CSV.write(genDataPath*"/daf.csv", daf.fcstable)

@testset "Checksums" begin
    cd(dataPath)
    fileNames = readdir()
    csDict = Dict{String, Any}()
    for f in fileNames
        if  f[end-3:end] == ".fcs" || f[end-4:end] == ".xlsx"
            cs = bytes2hex(sha256(f))
            csDict[f] = cs
        end
    end
    cd(cwd*"/checkSums")
    csTest = JSON.parsefile("csTest.json")
    @test csDict == csTest
    cd(cwd)
end

cd(cwd)
