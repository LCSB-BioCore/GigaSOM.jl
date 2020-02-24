
@testset "Parallel processing" begin

W = addprocs(2)
@everywhere using GigaSOM

Random.seed!(1)
som = initGigaSOM(pbmc8_data, 10, 10)

@testset "Check SOM dimensions" begin
    @test size(som.codes) == (100,10)
    @test som.xdim == 10
    @test som.ydim == 10
    @test som.numCodes == 100
end

som = trainGigaSOM(som, pbmc8_data, epochs = 2, rStart = 6.0)

winners = mapToGigaSOM(som, pbmc8_data)

embed = embedGigaSOM(som, pbmc8_data, k=10, smooth=0.1, adjust=2.3, m=4.5)

@testset "Check results" begin
    codes = som.codes
    @test size(codes) == (100,10)

    dfCodes = DataFrame(codes)
    rename!(dfCodes, Symbol.(antigens))
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
    @test Matrix{Float64}(refParallelDfCodes) ≈ Matrix{Float64}(parallelDfCodesTest)
    @test Matrix{Float64}(refParallelEmbedded) ≈ Matrix{Float64}(parallelEmbeddedTest) atol=1e-4
end

rmprocs(W)

end
