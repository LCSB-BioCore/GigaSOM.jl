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

xRange = generateIO(dataPath, fn, nWorkers, true, 1, true)

R =  Vector{Any}(undef,nWorkers)

@sync for (idx, pid) in enumerate(workers())
    @async R[idx] = fetch(@spawnat pid loadData(idx, "input-$idx.jls"))
end

@testset "check ranges" begin
    @test length(xRange) == nWorkers
end

@testset "compare the first rows of splitting and loading vs manual load" begin
    Array(df_firstLine) == R[1].x[1,:]
end

rmprocs(workers())