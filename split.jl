location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
cd(location)
fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"

using GigaSOM, FileIO, Test, Serialization, FCSFiles
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

function getTotalSize(md, printLevel = 0)
    global totalSize, tmpSum

    # define the file names
    fileNames = md.file_name

    # out the number of files
    if printLevel > 0
        @info " > Input: $(length(fileNames)) files"
    end

    # get the total size of the data set
    totalSize = 0
    inSize = []
    for f in fileNames
        open(f) do io
            # retrieve the offsets
            offsets = FCSFiles.parse_header(io)
            text_mappings = FCSFiles.parse_text(io, offsets[1], offsets[2])
            FCSFiles.verify_text(text_mappings)

            # get the number of parameters
            n_params = parse(Int, text_mappings["\$PAR"])

            # determine the number of cells
            numberCells = Int((offsets[4] - offsets[3] + 1) / 4 / n_params)

            totalSize += numberCells
            push!(inSize, numberCells)
            if printLevel > 0
                @info "   + Filename: $f - #cells: $numberCells"
            end
        end
    end

    # determine the running sum of the file sizes
    runSum = []
    tmpSum = 0
    for indivSize in inSize
        tmpSum += indivSize
        push!(runSum, tmpSum)
    end

    return totalSize, inSize, runSum
end

function splitting(totalSize, nWorkers, printLevel = 0)
    # determine the size per file
    fileL = Int(floor(totalSize/nWorkers))

    # determine the size of the last (residual) file
    lastFileL = Int(fileL + totalSize - nWorkers * fileL)

    if printLevel > 0
        @info " > # of workers: $nWorkers"
        @info " > Regular row count: $fileL cells"
        @info " > Last file row count: $lastFileL cells"
        @info " > Total row count: $totalSize cells"
    end

    return fileL, lastFileL
end

# determin the total size, the vector with sizes, and their running sum
totalSize, inSize, runSum = getTotalSize(md, 1)

# determine the size of each file
fileL, lastFileL = splitting(totalSize, nWorkers)

# establish an index map
fileEnd = 1
out = Dict()
slack = 0
openNewFile = true

for worker in 1:nWorkers
    global inFile, openNewFile, slack, fileEnd, fileNames

    # define the global indices per worker
    iStart = Int((worker - 1) * fileL + 1)
    iEnd = Int(worker * fileL)

    # treat the last file separately
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

    # make sure that there is at least one entry
    if length(ub) == 0
        ub = [1]
    end
    if length(lb) == 0
        lb = [1]
    end

    # push an additional index for last file if there is spill-over
    if iEnd  > runSum[lb[end]]
        push!(lb, lb[end]+1)
    end

    # determine the relevant files
    ioFiles = intersect(lb, ub)

    for k in ioFiles

        # determine global pointers
        begPointer = 1
        endPointer = runSum[k]
        if k > 1
            begPointer = runSum[k-1]
        end

        # limit the file pointers with the limits
        if iStart > begPointer
            begPointer = iStart
        end
        if iEnd < endPointer
            endPointer = iEnd
        end

        # define the local end
        localStart = 1 + slack
        localEnd = slack + endPointer - begPointer + 1

        # avoid that the local end pointer is larger than the actual file size
        if localEnd > inSize[k]
            localEnd = inSize[k]
        end

        @info " > Reading from file $k -- File: $(fileNames[k]) $localStart to $localEnd (Total: $(inSize[k]))"

        # determine if a new file shall be opened
        if localEnd >= inSize[k]
            prevFileOpen = false
            slack = 0
        else
            prevFileOpen = true
            slack = localEnd
        end

        # open the file properly speaking
        if openNewFile
            @info " > Opening file $(fileNames[k]) ..."
            inFile = readSingleFlowFrame(fileNames[k])
        end

        # set a flag to open a new file or not
        if prevFileOpen
            printstyled("[ Info:  + file $(fileNames[k]) is open ($slack)\n", color=:cyan)
            openNewFile = false
        else
            printstyled("[ Info:  - file $(fileNames[k]) is closed ($slack)\n", color=:magenta)
            openNewFile = true
        end

        # concatenate the array
        if length(out) > 0 && issubset(worker, collect(keys(out)))
            out[worker] = [out[worker]; inFile[localStart:localEnd, :]]
        else
            out[worker] = inFile[localStart:localEnd, :]
        end
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
