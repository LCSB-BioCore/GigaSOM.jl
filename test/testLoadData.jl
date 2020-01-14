using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON
using FileIO, Serialization, FCSFiles, DataFrames

checkDir()

#create genData and data folder and change dir to dataPath
cwd = pwd()
if occursin("jenkins", homedir()) || "TRAVIS" in keys(ENV)
    genDataPath = mktempdir()
    dataPath = mktempdir()
else
    if !occursin("test", cwd)
        cd("test")
        cwd = pwd()
    end
    dataFolders = ["genData", "data"]
    for dir in dataFolders
        if !isdir(dir)
            mkdir(dir)
        end
    end
    genDataPath = cwd*"/genData"
    dataPath = cwd*"/data"
end

refDataPath = cwd*"/refData"
Random.seed!(1)
cd(dataPath)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
md = md[1:2, :]
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)
# load the first file as reference 
lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

@testset "Compare raw fcs load, columns and first rows" begin
    fcs = readFlowFrame(md.file_name[1]) 
    generateIO(dataPath, md, nWorkers, true, 1, true)
    R =  Vector{Any}(undef,nWorkers)
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls"))
    end

    @test size(fcs,2) == size(R[1].x, 2)
    @test Array(fcs[1:5,:]) == R[1].x[1:5,:]
end

@testset "Test loading the data and reducing by column index" begin

    generateIO(dataPath, md, nWorkers, true, 1, true)
    R =  Vector{Any}(undef,nWorkers)
    cols = [5:15;]
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", cols, reduce = true))
    end

    @test size(R[1].x, 2) == 11
end

@testset "Test loading the data and reducing by panel file" begin

    fcs = readFlowFrame(md.file_name[1]) 
    generateIO(dataPath, md, nWorkers, true, 1, true)
    R =  Vector{Any}(undef,nWorkers)
    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", panel, 
                                                    reduce = true))
    end

    @test size(R[1].x, 2) == length(cc)
    fcs = fcs[:,cc] # select the same columns and compare the order 
    @test Array(fcs[1:5,:]) == R[1].x[1:5,:]
end

@testset "Test loading the data and asinh transformation" begin

    generateIO(dataPath, md, nWorkers, true, 1, true)
    R = Vector{Any}(undef,nWorkers)
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls"))
    end
    rawDataRow = copy(R[1].x[1,:])

    generateIO(dataPath, md, nWorkers, true, 1, true)
    R = Vector{Any}(undef,nWorkers)
    @sync for (idx, pid) in enumerate(workers())
        @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", transform=true))
    end
    transformDataRow = copy(R[1].x[1,:])
    @test rawDataRow != transformDataRow
    @test isapprox(asinh(rawDataRow[1] / 5), transformDataRow[1]; atol = 0.001)
end

# @testset "Test loading the data and sorting of the columns" begin

#     fcs = readFlowFrame(md.file_name[1]) # load the first file as reference 
#     generateIO(dataPath, md, nWorkers, true, 1, true)
#     R = Vector{Any}(undef,nWorkers)
#     @sync for (idx, pid) in enumerate(workers())
#         @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls"))
#     end
#     unsortedRow = copy(R[1].x[1,:])

#     generateIO(dataPath, md, nWorkers, true, 1, true)
#     R = Vector{Any}(undef,nWorkers)
#     @sync for (idx, pid) in enumerate(workers())
#         @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls", sort=true))
#     end
#     sortedRow = copy(R[1].x[1,:])
#     @test sortedRow == unsortedRow
# end
