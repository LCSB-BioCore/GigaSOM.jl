using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, DistributedData
using FileIO, DataFrames, Distances
using JSON, SHA
import LinearAlgebra

owd = pwd()

"""
Check if the `pwd()` is the `/test` directory, and if not it changes to it.
"""
function checkDir()
    files = readdir()
    if !in("runtests.jl", files)
        cd(dirname(dirname(pathof(GigaSOM))))
    end
end

checkDir()

@testset "GigaSOM test suite" begin
    include("testDataOps.jl")
    include("testTrainutils.jl")
    include("testSplitting.jl")
    include("testInput.jl")

    #this loads the PBMC dataset required for the batch/parallel tests
    include("testLoadPBMC8.jl")
    include("testBatch.jl")
    include("testParallel.jl")

    #misc tests that require some of the above data too
    include("testInputCSV.jl")
    include("testFileSplitting.jl")
end

cd(owd)
