using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON
using FileIO, Serialization, FCSFiles, DataFrames

owd = pwd()

checkDir()

@testset "GigaSOM test suite" begin
    include("testIO.jl")
    include("testBatch.jl")
    include("testParallel.jl")
    include("testSatellites.jl")
    include("testSplitting.jl")
end

cd(owd)
