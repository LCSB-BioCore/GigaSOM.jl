"""
    checkDir()

Checks if the `pwd()` is the `/test` directory, and if not it changes to it.

"""
function checkDir()

    files = readdir()
    if !in("runtests.jl", files)
        cd(dirname(dirname(pathof(GigaSOM))))
    end
end

"""
    getTotalSize(loc, md)

Get the total size of all the files specified in the metadata file
and at the given location.

# INPUTS

- `loc`: Absolute path of the files specified in the metadata file
- `md`: Metadata table

# OUTPUTS

- `totalSize`: (integer) Total size of the full data set
- `inSize`: Vector with the lengths of each file within the input data set
- `runSum`: Running sum of the `inSize` vector (`runSum[end] == totalSize`)
"""
function getTotalSize(loc, md::Any)
    global totalSize, tmpSum

    if md == typeof(String)
        filenames = [md]
    else
        # define the file names
        fileNames = sort(md.file_name)
    end

    # out the number of files
    @debug ">> Input: $(length(fileNames)) files"

    # get the total size of the data set
    totalSize = 0
    inSize = []
    for f in fileNames
        f = loc * Base.Filesystem.path_separator * f
        open(f) do io
            # retrieve the offsets
            offsets = FCSFiles.parse_header(io)
            text_mappings = FCSFiles.parse_text(io, offsets[1], offsets[2])
            FCSFiles.verify_text(text_mappings)

            # get the number of parameters
            n_params = parse(Int, text_mappings["\$PAR"])

            # determine the number of cells
            numberCells = Int(round((offsets[4] - offsets[3] + 1) / 4 / n_params))

            totalSize += numberCells
            push!(inSize, numberCells)
            @debug " + file $f ($numberCells cells)"
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


"""
    splitting(totalSize, nWorkers)

Determine the size of each file (including the last one)
given the total size and the number of workers

# INPUTS

- `totalSize`: Total size of the data set
- `nWorkers`: Number of workers

# OUTPUTS

- `fileL`: Length of each file apart from the last one
- `lastFileL`: Length of the last file
"""
function splitting(totalSize, nWorkers)
    # determine the size per file
    fileL = div(totalSize, nWorkers)

    # determine the remainder
    extras = rem(totalSize,nWorkers)

    # determine the size of the last (residual) file
    lastFileL = Int(fileL + totalSize - nWorkers * fileL)

    @debug "Splitting: $nWorkers workers, $fileL cells, $lastFileL remaining, $totalSize total"

    # determine the ranges
    nchunks = fileL > 0 ? nWorkers : extras
    chunks = Vector{UnitRange{Int}}(undef, nchunks)
    lo = 1
    for i in 1:nchunks
        hi = lo + fileL - 1
        if extras > 0
            hi += 1
            extras -= 1
        end
        chunks[i] = lo:hi
        lo = hi+1
    end

    return fileL, lastFileL, chunks
end

"""
    getFiles(worker, nWorkers, fileL, lastFileL, runSum)

Determine which files need to be opened and read from

# INPUTS

- `worker`: ID of the worker
- `nWorkers`: Number of workers
- `fileL`: Length of each file apart from the last one
- `lastFileL`: Length of the last file
- `runSum`: running sum

# OUTPUTS

- `ioFiles`: Vector with the indices of the files that need to be opened
- `iStart`: Global start index
- `iEnd`: Global end index
"""
function getFiles(worker, nWorkers, fileL, lastFileL, runSum)
    # define the global indices per worker
    iStart = Int((worker - 1) * fileL + 1)
    iEnd = Int(worker * fileL)

    # treat the last file separately
    if worker == nWorkers
        iEnd = iStart + lastFileL - 1
    end

    @debug "Generating data for input-$worker.jls ($iStart -- $iEnd)"

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

"""
    detLocalPointers(k, inSize, runSum, iStart, iEnd, slack, fileNames)

Determine the local pointers

# INPUTS

- `worker`: ID of the worker
- `nWorkers`: Number of workers
- `fileL`: Length of each file apart from the last one
- `lastFileL`: Length of the last file

# OUTPUTS

- `ioFiles`: Vector with the indices of the files that need to be opened
- `iStart`: Global start index
- `iEnd`: Global end index
"""
function detLocalPointers(k, inSize, runSum, iStart, iEnd, slack, fileNames)
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

    @debug "Read file [$k] ($(fileNames[k])): $localStart -- $localEnd, $(inSize[k]) total"

    return localStart, localEnd
end

"""
    ocLocalFile(out, worker, k, inSize, localStart, localEnd, slack, filePath, fileNames, openNewFile)

Open and close a local file.

# INPUTS

- `out`: concatenated data table (or Nothing if there is nothing yet)
- `k`: index of the current file
- `inSize`: array with size of all files
- `localStart`: start index of local file
- `localEnd`: end index of local file
- `slack`: remaining part that needs to be read in another process
- `filePath`: path to the file
- `fileNames`: array with names of files
- `openNewFile`: boolean to open a file or not

# OUTPUTS

- `out`: concatenated data table
- `slack`: remaining part that needs to be read in another process
"""
function ocLocalFile(out, k, inSize, localStart, localEnd, slack, filePath, fileNames, openNewFile)
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
        @debug "Reading $(fileNames[k]) ..."
        inFile = readFlowFrame(filePath * Base.Filesystem.path_separator * fileNames[k])
    end

    # set a flag to open a new file or not
    if prevFileOpen
        @debug "File $(fileNames[k]) is OPEN (slack $slack)\n"
        openNewFile = false
    else
        @debug "File $(fileNames[k]) is CLOSED (slack $slack)\n"
        openNewFile = true
    end

    # concatenate the array
    if out === nothing
        out = inFile[localStart:localEnd, :]
    else
        out = vcat(out, inFile[localStart:localEnd, :])
    end

    return out, slack
end

"""
    generateIO(filePath, md, nWorkers, generateFiles=true, saveIndices=false)

Generate binary .jls files given a path to files, their metadata, and the number of workers

# INPUTS

- `filePath`: path to the files
- `md`: Metadata table, or single file String
- `nWorkers`: number of workers
- `generateFiles`: Boolean to actually generate files
- `saveIndices`: Boolean to save the local indices

# OUTPUTS

if `saveIndices` is `true`:
    - `localStart`: start index of local file
    - `localEnd`: end index of local file

if `generateFiles` is `true`:
    `nWorkers` files named `input-<workerID>.jls` saved in the directory `filePath`.

"""
function generateIO(filePath, md::DataFrame, nWorkers, generateFiles=true, saveIndices=false)

    # determin the total size, the vector with sizes, and their running sum
    totalSize, inSize, runSum = getTotalSize(filePath, md)

    # determine the size of each file
    fileL, lastFileL = splitting(totalSize, nWorkers)

    # saving the variables for testing purposes
    if saveIndices
        localStartVect = []
        localEndVect = []
    end

    # establish an index map
    slack = 0
    fileEnd = 1
    openNewFile = true
    fileNames = sort(md.file_name)

    for worker in 1:nWorkers
        out = nothing

        # determine which files should be opened by each worker
        ioFiles, iStart, iEnd = getFiles(worker, nWorkers, fileL, lastFileL, runSum)

        # loop through each file
        for k in ioFiles
            localStart, localEnd = detLocalPointers(k, inSize, runSum, iStart, iEnd, slack, fileNames)

            # save the variables
            if saveIndices
                push!(localStartVect, localStart)
                push!(localEndVect, localEnd)
            end

            # open/close the local file
            out, slack = ocLocalFile(out, k, inSize, localStart, localEnd, slack, filePath, fileNames, openNewFile)
        end

        # output the file per worker
        outputFile(out, "input-$worker.jls", generateFiles)
    end

    if saveIndices
        return localStartVect, localEndVect
    end
end

"""
    generateIO(filePath, fn::String, nWorkers, generateFiles=true, saveIndices=false)

Generate binary .jls files for a single file given a path and the number of workers

# INPUTS

- `filePath`: path to the files
- `fn`: file name
- `nWorkers`: number of workers
- `generateFiles`: Boolean to actually generate files
- `saveIndices`: Boolean to save the local indices

# OUTPUTS

if `saveIndices` is `true`:
    - `chunks`: start index of local file

if `generateFiles` is `true`:
    - `nWorkers` files named `input-<workerID>.jls` saved in the directory `filePath`.

"""
function generateIO(filePath, fn::String, nWorkers, generateFiles=true, saveIndices=false)

    # read the single file and split it according to the number of workers.
    inFile = readFlowFrame(filePath * Base.Filesystem.path_separator * fn)
    _, _, chunks = splitting(size(inFile, 1), nWorkers)

    for i in 1:length(chunks)
        outputFile(inFile[chunks[i], :], "input-$i.jls", generateFiles)
    end

    if saveIndices
        return chunks
    end
end

"""
    rmFile(fileName)

Remove a file.

# INPUTS

- `fileName`: name of file to be removed
"""
function rmFile(fileName)
    try
        rm(fileName)
        @debug "Removed $fileName"
    catch
        @debug "(file $fileName does not exist - skipping)"
    end
end

"""
    outputFile(out, fileName, generateFiles=true)

Generate a file given a name and content.

# INPUTS

- `out`: content of the file
- `fileName`: name of file to be removed
- `generateFiles`: actually write the file
"""
function outputFile(out, fileName, generateFiles)
    if generateFiles
        open(f -> serialize(f, out), fileName, "w")
        @debug "Slice $fileName written."
    end
end
