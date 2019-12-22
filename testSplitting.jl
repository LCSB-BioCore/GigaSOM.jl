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

# test the sizes
@testset "Overall size" begin
    totalSize, inSize, runSum = getTotalSize(location, md, 0)

    @test totalSize == 3295
    @test inSize == [150, 200, 290, 330, 400, 500, 625, 800]
    @test runSum == [150, 350, 640, 970, 1370, 1870, 2495, 3295]
end

# test the i/o functionality properly speaking
@testset "Overall I/O splitting" begin
    for printLevel in [0, 1]
        for nWorkers in 1:17
            # generate the files
            localStartVect, localEndVect = generateIO(location, md, nWorkers, true, printLevel, true)

            # test if the differences between the local indices correspond
            @test sum(localEndVect - localStartVect) + length(localEndVect) == totalSize

            if nWorkers == 1
                @test localStartVect == [1, 1, 1, 1, 1, 1, 1, 1]
                @test localEndVect == inSize
            elseif nWorkers == 3
                @test localStartVect == [1, 1, 1, 1, 1, 130, 1, 1, 328, 1]
                @test localEndVect == [150, 200, 290, 330, 129, 400, 500, 327, 625, 800]
            elseif nWorkers == 5
                @test localStartVect == [1, 1, 1, 1, 21, 1, 350, 1, 1, 109, 1, 143]
                @test localEndVect == [150, 200, 290, 20, 330, 349, 400, 500, 108, 625, 142, 800]
            elseif nWorkers == 12
                @test localStartVect == [1, 1, 126, 1, 200, 1, 184, 1, 128, 1, 275, 1, 50, 324, 598, 1, 247, 521]
                @test localEndVect == [150, 125, 200, 199, 290, 183, 330, 127, 400, 274, 500, 49, 323, 597, 625, 246, 520, 800]
            elseif nWorkers == 17
                @test localStartVect == [1, 1, 45, 1, 38, 231, 1, 134, 327, 1, 190, 383, 1, 176, 369, 1, 62, 255, 448, 1, 16, 209, 402, 595]
                @test localEndVect == [150, 44, 200, 37, 230, 290, 133, 326, 330, 189, 382, 400, 175, 368, 500, 61, 254, 447, 625, 15, 208, 401, 594, 800]
            end

            # read in all the generated files
            yConcat = DataFrame()
            for k in 1:nWorkers
                y = open(deserialize, "input-$k.jls")
                yConcat = vcat(yConcat, y[k])
            end

            # test of data consistency
            @test yConcat == inConcat

            # remove all the files
            for k in 1:nWorkers
                rmFile("input-$k.jls", printLevel)
            end
        end
    end
end