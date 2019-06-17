using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed

#load and transform the .fcs data to be ready for computing
include("io.jl")

@info genDataPath
@info refDataPath

#apply the batch GigaSOM algorithm to the data, train it and test it
include("batch.jl")

#apply the parallel GigaSOM algorithm to the data, train it and test it
include("parallel.jl")
