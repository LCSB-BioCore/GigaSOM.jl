using GigaSOM, DataFrames, XLSX, CSV, Test, Random, Distributed, SHA


owd = pwd()
# files = readdir()
# if !in("runtests.jl", files) && !in("io.jl", files) && !in("parallel.jl", files)
#     cd("test")
#     cwd = pwd()
# end

checkDir()

@testset "GigaSOM test suite" begin
    #load and transform the .fcs data to be ready for computing
    include("io.jl")

    #apply the batch GigaSOM algorithm to the data, train it and test it
    #include("batch.jl")

    #apply the parallel GigaSOM algorithm to the data, train it and test it
    include("parallel.jl")
end

cd(owd)
