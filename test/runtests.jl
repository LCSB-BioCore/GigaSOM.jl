using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed

@testset "GigaSOM test suite" begin
    #load and transform the .fcs data to be ready for computing
    include("io.jl")

    #apply the batch GigaSOM algorithm to the data, train it and test it
    include("batch.jl")

    #apply the parallel GigaSOM algorithm to the data, train it and test it
    include("parallel.jl")
end