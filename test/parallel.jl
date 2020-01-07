
checkDir()
cdw = pwd()

#fix the seed
Random.seed!(1)

if nprocs() <= 2
    p = addprocs(2)
end
@everywhere using DistributedArrays
@everywhere using GigaSOM
@everywhere using Distances


# only use lineageMarkers for clustering
(lineageMarkers,)= getMarkers(panel)
cc = map(Symbol, lineageMarkers)
dfSom = daf.fcstable[:,cc]

# concatenate the dataset for performance testing
n = 0
for i in 1:n
    global dfSom
    dfSom = vcat(dfSom, dfSom)
end

som2 = initGigaSOM(dfSom, 10, 10)

@testset "Dimensions - parallel" begin
    @test size(som2.codes) == (100,10)
    @test som2.xdim == 10
    @test som2.ydim == 10
    @test som2.numCodes == 100
end

som2 = trainGigaSOM(som2, dfSom, epochs = 2, rStart = 6.0)

winners = mapToGigaSOM(som2, dfSom)

embed = embedGigaSOM(som2, dfSom, k=10, smooth=0.0, adjust=0.5)

#test parallel
@testset "Parallel" begin
    codes = som2.codes
    @test size(codes) == (100,10)

    dfCodes = DataFrame(codes)
    names!(dfCodes, Symbol.(som2.colNames))
    dfEmbed = DataFrame(embed)
    CSV.write(genDataPath*"/parallelDfCodes.csv", dfCodes)
    CSV.write(genDataPath*"/parallelWinners.csv", winners)
    CSV.write(genDataPath*"/parallelEmbedded.csv", dfEmbed)

    # load the ref data
    refParallelDfCodes = CSV.File(refDataPath*"/refParallelDfCodes.csv") |> DataFrame
    refParallelWinners = CSV.File(refDataPath*"/refParallelWinners.csv") |> DataFrame
    refParallelEmbedded = CSV.File(refDataPath*"/refParallelEmbedded.csv") |> DataFrame

    # load the generated data
    parallelDfCodes = CSV.File(genDataPath*"/parallelDfCodes.csv") |> DataFrame
    parallelDfCodesTest = first(parallelDfCodes, 10)
    parallelWinners = CSV.File(genDataPath*"/parallelWinners.csv") |> DataFrame
    parallelWinnersTest = first(parallelWinners, 10)
    parallelEmbedded = CSV.File(genDataPath*"/parallelEmbedded.csv") |> DataFrame
    parallelEmbeddedTest = first(parallelEmbedded, 10)

    # test the generated data against the reference data
    @test refParallelWinners == parallelWinnersTest
    @test refParallelDfCodes == parallelDfCodesTest
    @test Array{Float64,2}(refParallelEmbedded) ≈ Array{Float64,2}(parallelEmbeddedTest) atol=1e-4

    #test parallel
    for (i, j) in zip(parallelDfCodes[:,1], refParallelDfCodes[:,1])
        @test isapprox(i, j; atol = 0.001)
    end

end

@testset "single file training (to be deprecated)" begin
    cd(dataPath)
    filename = md.file_name[1]
    ff = readFlowFrame(filename)
    cleanNames!(ff)
    dafsingle = createDaFrame(ff, md, panel)
    dfSom = dafsingle.fcstable[:,cc]
    som2 = initGigaSOM(dfSom, 10, 10)
    som2 = trainGigaSOM(som2, dfSom, epochs = 2, rStart = 6.0)
    winners = mapToGigaSOM(som2, dfSom)
    @test typeof(winners) == DataFrame
end

rmprocs(workers())

cd(cdw)
