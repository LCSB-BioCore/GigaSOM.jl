location = ENV["HOME"]*"/Archive_AF_files" #"/artificial_data_cytof" #"/Archive_AF_files"
binFileType = ".jls"
nWorkers = 12
cd(location)
fileDir = readdir(location)

mdFileName = location*"/metadata.xlsx"

using GigaSOM, FileIO, Test, Serialization, FCSFiles
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable(mdFileName, "Sheet1")...)

# read in the entire dataset
fileNames = md.file_name
#in = readFlowset(fileNames)

@info " > Input: $(length(fileNames)) files"

# get the total size of the data set
totalSize = 0
inSize = []
for f in fileNames
    global totalSize
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
        @info "   + Filename: $f - #cells: $numberCells"
    end
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
slug = 0
openNewFile = true
for worker in 1:nWorkers
    global openNewFile, slug, limitFileIndex, md, fileEnd, fileNames, localEnd
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
    if length(lb) == 0
        lb = [1]
    end
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
            begPointer = iStart
        end
        if iEnd < endPointer
            endPointer = iEnd
        end

        # redefine the local start based on the previous index (chunk)
        #if @isdefined localEnd
        #    if localEnd != inSize[k]
        #        localStart =  1
        #        localEnd = localStart + endPointer - begPointer
        #    end
        #else

        # define the local end
        localStart = 1 + slug
        localEnd = slug + endPointer - begPointer + 1
        if localEnd > inSize[k]
            localEnd = inSize[k]
        end
        # make sure that the localStart pointer is not further than the actual end
        #if localStart > localEnd
        #    localStart = 1
       # end
        # make sure that the end pointer
        #if begPointer == 1
        #    localEnd = endPointer
        #end
        # output
        @info " > Reading from file $k -- File: $(fileNames[k]) $localStart to $localEnd (Total: $(inSize[k]))"


        if localEnd >= inSize[k]
            prevFileOpen = false
            slug = 0
        else
            prevFileOpen = true
            slug = localEnd
        end

        if  openNewFile
            @info " ... Opening file $(fileNames[k])"
        #    inFile = readSingleFlowFrame(fileNames[k])
        end

        if prevFileOpen
            printstyled(" ++ file $(fileNames[k]) is open ($slug)\n", color=:yellow)
            openNewFile = false
        else
            printstyled(" ++ file $(fileNames[k]) is closed ($slug)\n", color=:green)
            openNewFile = true
        end
        #=
        # concatenate the array
        if length(out) > 0 && issubset(worker, collect(keys(out)))
            out[worker] = [out[worker]; inFile[localStart:localEnd, :]]
        else
            out[worker] = inFile[localStart:localEnd, :]
        end
        =#
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
