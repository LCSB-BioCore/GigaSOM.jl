using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA, JSON
using FileIO, Serialization, FCSFiles, DataFrames

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
    include("testDistributed.jl")
    include("testDataOps.jl")
    include("testTrainutils.jl")
    include("testSplitting.jl")

    #this loads the PBMC dataset required for the following tests
    include("testLoadPBMC8.jl")

    include("testBatch.jl")
    include("testParallel.jl")
    #include("testTrainingOuputEquality.jl")
    #include("testSingleFileSplitting.jl")
    #include("testLoadData.jl")
end

cd(owd)
