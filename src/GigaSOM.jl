"""
Main module for `GigaSOM.jl` - Huge-scale, high-performance flow cytometry clustering

The documentation is here: http://LCSB-BioCore.github.io/GigaSOM.jl

"""

module GigaSOM

    using CSV
    using DataFrames
    using Distances
    using Distributed
    using Distributions
    using FileIO
    using DistributedArrays

    # using MultivariateStats
    # using Statistics
    # using StatsBase
    # using StatsPlots
    # using FCSFiles
    # using JuliaInterpreter
    # using LinearAlgebra
    # using ProgressMeter
    # using TensorToolbox

    include("types.jl")
    include("helpers.jl")
    include("parallel_som.jl")

    # include IO files
    include("io/Fcs_helper.jl")

    # include visualization files
    # include("visualization/Plotting.jl")

    export # ext/som
        initSOM,
        trainSOM,
        mapToSOM,
        initSOM_parallel,
        trainSOM_parallel

    export # Fcs_helper
        cleannames!,
        readflowset,
        create_daFrame,
        getMarkers,
        daFrame

    export # Plotting
        plotcounts,
        plotPCA

end # module
