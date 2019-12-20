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


function getFiles(worker, nWorkers, fileL, lastFileL)
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

    return ioFiles, iStart, iEnd
end
