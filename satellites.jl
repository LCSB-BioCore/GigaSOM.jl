"""
    getTotalSize(location, md, printLevel=0)

Get the total size of all the files specified in the metadata file
and at the given location.

# INPUTS

- `location`: absolute path of the files specified in the metadata file
- `md`: Metadata table
- `printLevel`: Verbose level (0: mute)

# OUTPUTS

- `totalSize`: (integer) Total size of the full data set
- `inSize`: Vector with the lengths of each file within the input data set
- `runSum`: Running sum of the `inSize` vector (`runSum[end] == totalSize`)
"""
function getTotalSize(location, md, printLevel=0)
    global totalSize, tmpSum

    # define the file names
    fileNames = sort(md.file_name)

    # out the number of files
    if printLevel > 0
        @info " > Input: $(length(fileNames)) files"
    end

    # get the total size of the data set
    totalSize = 0
    inSize = []
    for f in fileNames
        f = location * "/" * f
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


function splitting(totalSize, nWorkers, printLevel=0)
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


function getFiles(worker, nWorkers, fileL, lastFileL, printLevel=0)
    # define the global indices per worker
    iStart = Int((worker - 1) * fileL + 1)
    iEnd = Int(worker * fileL)

    # treat the last file separately
    if worker == nWorkers
        iEnd = iStart + lastFileL - 1
    end

    if printLevel > 0
        @info ""
        @info " -----------------------------"
        @info " >> Generating input-$worker.jls"
        @info " -----------------------------"
        @info " > iStart: $iStart; iEnd: $iEnd"
    end

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

    return ioFiles, iStart, iEnd
end

function detLocalPointers(k, inSize, runSum, iStart, iEnd, slack, fileNames, printLevel=0)
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

        if printLevel > 0
            @info " > Reading from file $k -- File: $(fileNames[k]) $localStart to $localEnd (Total: $(inSize[k]))"
        end

        return localStart, localEnd
end


function ocLocalFile(out, worker, k, inSize, localStart, localEnd, slack, filePath, fileNames, openNewFile, printLevel=0)
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
        if printLevel > 0
            @info " > Opening file $(fileNames[k]) ..."
        end
        inFile = readSingleFlowFrame(filePath*"/"*fileNames[k])
    end

    # set a flag to open a new file or not
    if prevFileOpen
        if printLevel > 0
            printstyled("[ Info:  + file $(fileNames[k]) is open ($slack)\n", color=:cyan)
        end
        openNewFile = false
    else
        if printLevel > 0
            printstyled("[ Info:  - file $(fileNames[k]) is closed ($slack)\n", color=:magenta)
        end
        openNewFile = true
    end

    # concatenate the array
    if length(out) > 0 && issubset(worker, collect(keys(out)))
        out[worker] = vcat(out[worker], inFile[localStart:localEnd, :])
    else
        out[worker] = inFile[localStart:localEnd, :]
    end

    return out, slack
end


function generateIO(filePath, md, nWorkers, generateFiles=true, printLevel=0, saveIndices=false)

    # determin the total size, the vector with sizes, and their running sum
    totalSize, inSize, runSum = getTotalSize(location, md, printLevel)

    # determine the size of each file
    fileL, lastFileL = splitting(totalSize, nWorkers, printLevel)

    # saving the variables for testing purposes
    if saveIndices
        localStartVect = []
        localEndVect = []
    end

    # establish an index map
    fileEnd = 1
    out = Dict()
    slack = 0
    openNewFile = true
    fileNames = sort(md.file_name)

    for worker in 1:nWorkers
        ioFiles, iStart, iEnd = getFiles(worker, nWorkers, fileL, lastFileL, printLevel)
        for k in ioFiles
            localStart, localEnd = detLocalPointers(k, inSize, runSum, iStart, iEnd, slack, fileNames, printLevel)

            # save the variables
            if saveIndices
                push!(localStartVect, localStart)
                push!(localEndVect, localEnd)
            end

            # open/close the local file
            out, slack = ocLocalFile(out, worker, k, inSize, localStart, localEnd, slack, filePath, fileNames, openNewFile, printLevel)
        end

        # output the file per worker
        if generateFiles
            open(f -> serialize(f,out), "input-$worker.jls", "w")
            if printLevel > 0
                printstyled("[ Info:  > File input-$worker.jls written.\n", color=:green, bold=true)
            end
        end
    end

    if saveIndices
        return localStartVect, localEndVect
    end
end

function rmFile(fileName, printLevel = 1)
    try
        if printLevel > 0
            printstyled("> Removing $fileName ... ", color=:yellow)
        end
        rm(fileName)
        if printLevel > 0
            printstyled("Done.\n", color=:green)
        end
    catch
        if printLevel > 0
            printstyled("(file $fileName does not exist - skipping).\n", color=:red)
        end
    end
end