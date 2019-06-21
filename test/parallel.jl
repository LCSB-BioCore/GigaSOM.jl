#fix the seed
Random.seed!(1)

p = addprocs(2)
@everywhere using DistributedArrays
@everywhere using GigaSOM

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

som2 = trainGigaSOM(som2, dfSom, epochs = 2, r = 6.0)

winners = mapToGigaSOM(som2, dfSom)

winners = mapToGigaSOM(som2, dfSom)

@testset "Parallel" begin
    codes = som2.codes
    @test size(codes) == (100,10)

    dfCodes = DataFrame(codes)
    names!(dfCodes, Symbol.(som2.colNames))
    CSV.write(genDataPath*"/parallelDfCodes.csv", dfCodes)
    CSV.write(genDataPath*"/parallelWinners.csv", winners)

    # load the ref data
    refParallelDfCodes = CSV.File(refDataPath*"/refParallelDfCodes.csv") |> DataFrame
    refParallelWinners = CSV.File(refDataPath*"/refParallelWinners.csv") |> DataFrame

    # load the generated data
    parallelDfCodes = CSV.File(genDataPath*"/parallelDfCodes.csv") |> DataFrame
    parallelWinners = CSV.File(genDataPath*"/parallelWinners.csv") |> DataFrame

    # test the generated data against the reference data
    @test refParallelWinners == parallelWinners
    @test refParallelDfCodes == parallelDfCodes

    #test parallel
    for (i, j) in zip(parallelDfCodes[:,1], refParallelDfCodes[:,1])
        @test isapprox(i, j; atol = 0.001)
    end

end
