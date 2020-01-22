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

R, = loadData(dataPath, fn, nWorkers, transform=true)

@testset "compare ranges and first rows of splitting and loading vs manual load" begin
    @test length(R) == nWorkers
    @test Array(df_firstLine) == R[1].x[1,:]
end

rmprocs(workers())