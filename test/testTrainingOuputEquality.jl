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

dinfo = loadData(dataPath, md, nWorkers, panel=panel, reduce=true, transform=true)

som = initGigaSOM(dinfo, 10, 10)
# get a copy of the inititalized som object for the second training
som2Codes = deepcopy(som.codes)

cc = map(Symbol, vcat(lineageMarkers, functionalMarkers))

som = trainGigaSOM(som, dinfo)
winners = mapToGigaSOM(som, dinfo)
embed = embedGigaSOM(som, dinfo, k=10)

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
embed2 = embedGigaSOM(som2, dfSom, k=10)

@testset "Compare first row of concatenated train dataset between loading methods" begin
    @test_nowarn t1 = get_val_from(dinfo.pids[1], dinfo.val)[1,:]
    t2 = dfSom[1,:]
    @test Array{Float32,1}(t2) == t1
end

@testset "Compare output equality" begin
    @test isapprox(som, som2)
    @test isapprox(winners, winners2)
    @test isapprox(embed, embed2)
end

rmprocs(workers())
