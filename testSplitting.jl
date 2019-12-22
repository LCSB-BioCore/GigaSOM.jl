using GigaSOM, FileIO, Test, Serialization, FCSFiles, DataFrames

function rmFile(fileName)
    try
        printstyled("> Removing $fileName ... ", color=:yellow)
        rm(fileName)
        printstyled("Done.\n", color=:green)
    catch
        printstyled("(file $fileName does not exist - skipping).\n", color=:red)
    end
end

location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
#cd(location)
mdFileName = location*"/metadata.xlsx"

# read the directory and their metadata
fileDir = readdir(location)
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

include("satellites.jl")

# test the sizes
totalSize, inSize, runSum = getTotalSize(location, md, 0)

@test totalSize == 3295
@test inSize == [150, 200, 290, 330, 400, 500, 625, 800]
@test runSum == [150, 350, 640, 970, 1370, 1870, 2495, 3295]

localStartVect, localEndVect = generateIO(location, md, nWorkers, true, 1, true)

# test if the differences between the local indices correspond
@test sum(localEndVect - localStartVect) + length(localEndVect) == totalSize

@test localStartVect == [1, 1, 126, 1, 200, 1, 184, 1, 128, 1, 275, 1, 50, 324, 598, 1, 247, 521]
@test localEndVect == [150, 125, 200, 199, 290, 183, 330, 127, 400, 274, 500, 49, 323, 597, 625, 246, 520, 800]

# test if the data corresponds
fileNames = []
for f in sort(md.file_name)
    push!(fileNames, location * "/" * f)
end
inSet = readFlowset(fileNames)

# remove all the files
for k in 1:nWorkers
    rmFile("input-$k.jls")
end

# simple concatenation
nWorkers = 1

localStartVect, localEndVect = generateIO(location, md, nWorkers, true, 0, true)
@test sum(localEndVect - localStartVect) + length(localEndVect) == totalSize

@test localStartVect == [1, 1, 1, 1, 1, 1, 1, 1]
@test localEndVect == inSize

inConcat = DataFrame()
for key in sort(collect(keys(inSet)))
    global inConcat
    inConcat = vcat(inConcat, inSet[key])
end

# read the generated file
y = open(deserialize, "input-1.jls")
@test y[1] == inConcat

# remove the single file
rmFile("input-1.jls")