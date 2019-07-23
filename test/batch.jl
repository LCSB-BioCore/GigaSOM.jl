
checkDir()
cwd = pwd()
#fix the seed
Random.seed!(1)

# only use lineageMarkers for clustering
(lineageMarkers,)= getMarkers(panel)
cc = map(Symbol, lineageMarkers)
dfSom = daf.fcstable[:,cc]

som2 = initGigaSOM(dfSom, 10, 10)

@testset "Dimensions - batch" begin
    @test size(som2.codes) == (100,10)
    @test som2.xdim == 10
    @test som2.ydim == 10
    @test som2.numCodes == 100
end

# using batch som with epochs
som2 = trainGigaSOM(som2, dfSom, epochs = 1)

winners = mapToGigaSOM(som2, dfSom)

#test batch
@testset "Batch" begin
    codes = som2.codes
    @test size(codes) == (100,10)

    dfCodes = DataFrame(codes)
    names!(dfCodes, Symbol.(som2.colNames))
    CSV.write(genDataPath*"/batchDfCodes.csv", dfCodes)
    CSV.write(genDataPath*"/batchWinners.csv", winners)

    #load the ref data
    refBatchDfCodes = CSV.File(refDataPath*"/refBatchDfCodes.csv") |> DataFrame
    refBatchWinners = CSV.File(refDataPath*"/refBatchWinners.csv") |> DataFrame

    #load the generated data
    batchDfCodes = CSV.File(genDataPath*"/batchDfCodes.csv") |> DataFrame
    batchDfCodesTest = first(batchDfCodes, 10)
    batchWinners = CSV.File(genDataPath*"/batchWinners.csv") |> DataFrame
    batchWinnersTest = first(batchWinners, 10)

    # test the generated data against the reference data
    @test refBatchWinners == batchWinnersTest
    @test refBatchDfCodes == batchDfCodesTest

    for (i, j) in zip(batchDfCodesTest[:,1], refBatchDfCodes[:,1])
        @test isapprox(i, j; atol = 0.001)
    end
    @test refBatchWinners == batchWinnersTest
end
