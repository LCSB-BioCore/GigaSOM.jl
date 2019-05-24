"""
Main module for `GigaSOM.jl` - Huge-scale, high-performance flow cytometry clustering

The documentation is here: http://LCSB-BioCore.github.io/GigaSOM.jl

"""

module GigaSOM

    using DataFrames
    using Distances
    using Distributed
    using DistributedArrays
    using Distributions
    using LinearAlgebra
    using Plots
    using ProgressMeter
    using SOM
    using StatsBase
    using TensorToolbox

    include("errors.jl")
    include("helpers.jl")
    include("grids.jl")
    include("kernels.jl")
    include("gigasoms.jl")
    include("batch_som.jl")
    include("parallel_som.jl")

end # module
