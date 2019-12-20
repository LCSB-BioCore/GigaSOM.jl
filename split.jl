location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
cd(location)
fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"

using GigaSOM, FileIO, Test, Serialization, FCSFiles
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

include("satellites.jl")

# determin the total size, the vector with sizes, and their running sum
totalSize, inSize, runSum = getTotalSize(md, 1)

# determine the size of each file
fileL, lastFileL = splitting(totalSize, nWorkers)


#function generateIO(fileNames, nWorkers, generateFiles=true)

# saving the variables for testing purposes
localStartVect = []
localEndVect = []

# establish an index map
fileEnd = 1
out = Dict()
slack = 0
openNewFile = true
fileNames = md.file_name

for worker in 1:nWorkers
    global inFile, openNewFile, slack, fileEnd, fileNames

    ioFiles, iStart, iEnd = getFiles(worker, nWorkers, fileL, lastFileL)

    for k in ioFiles

        localStart, localEnd = detLocalPointers(k, inSize, runSum, iStart, iEnd, slack)

        # save the variables
        push!(localStartVect, localStart)
        push!(localEndVect, localEnd)

        @info " > Reading from file $k -- File: $(fileNames[k]) $localStart to $localEnd (Total: $(inSize[k]))"

        # open/close the local file
        ocLocalFile(worker, k, inSize, localStart, localEnd, fileNames, openNewFile)
    end

    # output the file per worker
    open(f -> serialize(f,out), "input-$worker.jls", "w")
    printstyled("[ Info:  > File input-$worker.jls written.\n", color=:green, bold=true)
end

#= split the file properly speaking
open(f -> serialize(f,out), "out.jls", "w")
y = open(deserialize, "out.jls")
@test y == outa
=#
