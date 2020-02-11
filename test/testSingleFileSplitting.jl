cd(dataPath)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
# take only the first 2 files for testing
md = md.file_name[1,:]
fn = md[1]
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

lineageMarkers, functionalMarkers = getMarkers(panel)

# load the file manually
df = readFlowFrame(fn)
df = GigaSOM.transformData(df, "asinh", 5)
df_firstLine = df[1,:]

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

dinfo = loadData(:testCase, dataPath, fn, workers(), transform=true)

@testset "load data from a single file" begin
    @test typeof(dinfo)==LoadedDataInfo
end

@testset "compare ranges and first rows of splitting and loading vs manual load" begin
    @test length(dinfo.workers) == nWorkers
    @test dinfo.val == :testCase
    @test Array(df_firstLine) == get_val_from(dinfo.workers[1], :testCase)[1,:]
end

@testset "unloading data" begin
    @test_nowarn unloadData(dinfo)
end

rmprocs(workers())
