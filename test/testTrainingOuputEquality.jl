Random.seed!(1)

cd(dataPath)

md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
# take only the first 2 files for testing
md = md[1:2, :]
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)

cd(genDataPath)

lineageMarkers, functionalMarkers = getMarkers(panel)

nWorkers = 2
addprocs(nWorkers, topology=:master_worker)
@everywhere using GigaSOM, FCSFiles

R, _ = loadData(dataPath, md, nWorkers, panel=panel, reduce=true, transform=true)

som = initGigaSOM(R, 10, 10)
# get a copy of the inititalized som object for the second training
som2Codes = deepcopy(som.codes)

cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

som = trainGigaSOM(som, R)
winners = mapToGigaSOM(som, R)
embed = embedGigaSOM(som, R, k=10, smooth=0.0, adjust=0.5)

# Load the data again using the "classic serial approach"
cd(dataPath)
fileNames = sort(md.file_name)
fcsRaw = readFlowset(fileNames)
cleanNames!(fcsRaw)

# create daFrame file
cd(genDataPath)
daf = createDaFrame(fcsRaw, md, panel)
dfSom = daf.fcstable[:,cc]

# don't init GigaSOM again, use the initial som from the 1st run
# to get the same starting som grid for training
som2 = initGigaSOM(dfSom, 10, 10)
som2.codes = som2Codes
som2 = trainGigaSOM(som2, dfSom)
winners2 = mapToGigaSOM(som2, dfSom)
embed2 = embedGigaSOM(som2, dfSom, k=10, smooth=0.0, adjust=0.5)

@testset "Compare first row of concatenated train dataset between loading methods" begin
    t1 = R[1].x[1,:]
    t2 = dfSom[1,:]
    @test Array{Float32,1}(t2) == t1
end

@testset "Compare output classic vs new winners output" begin
    @test winners == winners2
end

rmprocs(workers())