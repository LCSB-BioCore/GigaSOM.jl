Random.seed!(1)
cd(dataPath)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
md = md[1:2, :]
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)
lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

@testset "Compare raw fcs load, columns and first rows" begin
    fcs = readFlowFrame(md.file_name[1]) # load the first file as reference 

    R, = loadData(dataPath, md, nWorkers)

    @test size(fcs,2) == size(R[1].x, 2)
    @test Array(fcs[1:5,:]) == R[1].x[1:5,:]
end

@testset "Test loading the data and reducing by column index" begin

    cols = [5:15;]
    R, = loadData(dataPath, md, nWorkers, panel=cols, reduce=true)

    @test size(R[1].x, 2) == 11
end

@testset "Test loading the data and reducing by panel file" begin

    fcs = readFlowFrame(md.file_name[1]) 
    cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

    R, = loadData(dataPath, md, nWorkers, panel=panel, reduce=true)

    @test size(R[1].x, 2) == length(cc)
    fcs = fcs[:,cc] # select the same columns and compare the order 
    @test Array(fcs[1:5,:]) == R[1].x[1:5,:]
end

@testset "Test loading the data and asinh transformation" begin

    R, = loadData(dataPath, md, nWorkers)
    rawDataRow = copy(R[1].x[1,:])

    R, = loadData(dataPath, md, nWorkers, transform=true)
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
