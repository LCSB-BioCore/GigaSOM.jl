using GigaSOM, FileIO, Test, Serialization, FCSFiles, DataFrames

include("satellites.jl")

location = ENV["HOME"]*"/Archive_AF_files"
binFileType = ".jls"
mdFileName = location*"/metadata.xlsx"

# read the directory and their metadata
fileDir = readdir(location)
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

# read in all the files in 1 go and concatenate
fileNames = []
for f in sort(md.file_name)
    push!(fileNames, location * "/" * f)
end
inSet = readFlowset(fileNames)

inConcat = DataFrame()
for key in sort(collect(keys(inSet)))
    global inConcat
    inConcat = vcat(inConcat, inSet[key])
end

# multiple workers
# ====================================================================
nWorkers = 12

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

# read in all the generated files
yConcat = DataFrame()
for k in 1:nWorkers
    global yConcat
    y = open(deserialize, "input-$k.jls")
    yConcat = vcat(yConcat, y[1])
end

#@test yConcat == inConcat

# remove all the files
for k in 1:nWorkers
    rmFile("input-$k.jls")
end

# simple concatenation
# ====================================================================
nWorkers = 1

localStartVect, localEndVect = generateIO(location, md, nWorkers, true, 0, true)
@test sum(localEndVect - localStartVect) + length(localEndVect) == totalSize

@test localStartVect == [1, 1, 1, 1, 1, 1, 1, 1]
@test localEndVect == inSize

# read in all the generated files
yConcat = DataFrame()
for k in 1:nWorkers
    global yConcat
    y = open(deserialize, "input-$k.jls")
    yConcat = vcat(yConcat, y[1])
end

@test yConcat == inConcat

# remove all the files
for k in 1:nWorkers
    rmFile("input-$k.jls")
end