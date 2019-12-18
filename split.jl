location = ENV["HOME"]*"/artificial_data_cytof"
binFileType = ".jls"
nWorkers = 5

fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"
panelFileName = location*"/panel.xlsx"

using GigaSOM, FileIO, Test, Serialization
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(panelFileName, "Sheet1")...)

# read in the entire dataset
fileNames = md.file_name
in = readFlowset(fileNames)

@info " > Input: $(length(fileNames)) files"

# get the total size of the data set
totalSize = 0
inSize = []
for name in fileNames
    global totalSize
    totalSize += size(in[name])[1]
    push!(inSize, size(in[name])[1])
end

# determine the size per file
fileL = Int(floor(totalSize/nWorkers))

# determine the size of the last (residual) file
lastFileL = Int(fileL + totalSize - nWorkers * fileL)

@info " > # of workers: $nWorkers"
@info " > Regular row count: $fileL cells"
@info " > Last file row count: $lastFileL cells"
@info " > Total row count: $totalSize cells"

# determine the running sum of the file sizes
runSum = []
tmpSum = 0
for indivSize in inSize
    global tmpSum
    tmpSum += indivSize
    push!(runSum, tmpSum)
end

# establish an index map
limitFileIndex = 0
fileEnd = 1
out = Dict()
for worker in 1:nWorkers
    global limitFileIndex, md, fileEnd, fileNames
    iStart = Int((worker - 1) * fileL + 1)
    iEnd = Int(worker * fileL)

    if worker == nWorkers
        iEnd = iStart + lastFileL - 1
    end
    @info ""
    @info " -----------------------------"
    @info " >> Generating input-$worker.jls"
    @info " -----------------------------"
    @info " > iStart: $iStart; iEnd: $iEnd"

    # find which files are relevant to be extracted
    ub = findall(runSum .>= iStart)
    lb = findall(runSum .<= iEnd)

    # push an additional index for last file if there is spill-over
    if iEnd  > runSum[lb[end]]
        push!(lb, lb[end]+1)
    end

    # determine the relevant files
    ioFiles = intersect(lb, ub)

    for k in ioFiles
        begPointer = 1
        endPointer = runSum[k]
        if k > 1
            begPointer = runSum[k-1]
        end

        # limit the file pointers with the limits
        if iStart > begPointer
            begPointer = iStart - 1
        end
        if iEnd < endPointer
            endPointer = iEnd
        end

        #local indices
        localStart = 1
        localEnd = endPointer - begPointer
        if begPointer == 1
            localEnd = endPointer
        end

        # output
        @info " > Reading from file $k -- File: $(fileNames[k]) from $begPointer to $endPointer ($localStart:$localEnd)"

        # concatenate the array
        if length(out) > 0 && issubset(worker, collect(keys(out)))
            out[worker] = [out[worker]; in[fileNames[k]][localStart:localEnd, :]]
        else
            out[worker] = in[fileNames[k]][localStart:localEnd, :]
        end
    end

    # output the file per worker
    open(f -> serialize(f,out), "input-$worker.jls", "w")
    @info " > File input-$worker.jls written."
end

#= split the file properly speaking
open(f -> serialize(f,out), "out.jls", "w")
y = open(deserialize, "out.jls")
@test y == outa
=#
