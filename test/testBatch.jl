
@testset "Single-CPU batch processing" begin

    som = initGigaSOM(pbmc8_data, 10, 10, seed = 1234)

    #check whether the distributed version works the same
    save_at(1, :test, pbmc8_data)
    som2 = initGigaSOM(LoadedDataInfo(:test, [1]), 10, 10, seed = 1234)
    @test som.codes == som2.codes
    remove_from(1, :test)

    @testset "Check SOM dimensions" begin
        @test size(som.codes) == (100, 10)
        @test som.xdim == 10
        @test som.ydim == 10
        @test som.numCodes == 100
    end

    som = trainGigaSOM(som, pbmc8_data, epochs = 1)

    winners = mapToGigaSOM(som, pbmc8_data)

    embed = embedGigaSOM(som, pbmc8_data, k = 10, smooth = 0.1, adjust = 2.3, m = 4.5)

    @testset "Check results" begin
        codes = som.codes
        @test size(codes) == (100, 10)

        dfCodes = DataFrame(codes)
        rename!(dfCodes, Symbol.(antigens))
        dfEmbed = DataFrame(embed)
        CSV.write(genDataPath * "/batchDfCodes.csv", dfCodes)
        CSV.write(genDataPath * "/batchWinners.csv", winners)
        CSV.write(genDataPath * "/batchEmbedded.csv", dfEmbed)

        #load the ref data
        refBatchDfCodes = CSV.File(refDataPath * "/refBatchDfCodes.csv") |> DataFrame
        refBatchWinners = CSV.File(refDataPath * "/refBatchWinners.csv") |> DataFrame
        refBatchEmbedded = CSV.File(refDataPath * "/refBatchEmbedded.csv") |> DataFrame

        #load the generated data
        batchDfCodes = CSV.File(genDataPath * "/batchDfCodes.csv") |> DataFrame
        batchDfCodesTest = first(batchDfCodes, 10)
        batchWinners = CSV.File(genDataPath * "/batchWinners.csv") |> DataFrame
        batchWinnersTest = first(batchWinners, 10)
        batchEmbedded = CSV.File(genDataPath * "/batchEmbedded.csv") |> DataFrame
        batchEmbeddedTest = first(batchEmbedded, 10)

        # test the generated data against the reference data
        @test refBatchWinners == batchWinnersTest
        @test Matrix{Float64}(refBatchDfCodes) ≈ Matrix{Float64}(batchDfCodesTest) atol =
            1e-4
        @test Matrix{Float64}(refBatchEmbedded) ≈ Matrix{Float64}(batchEmbeddedTest) atol =
            1e-4
    end

end
