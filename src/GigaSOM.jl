"""
Main module for `GigaSOM.jl` - Huge-scale, high-performance flow cytometry clustering

The documentation is here: http://LCSB-BioCore.github.io/GigaSOM.jl

"""

module GigaSOM

    using CSV
    using DataFrames
    using Distributed
    using FileIO
    # using MultivariateStats
    # using Statistics
    # using StatsBase
    # using StatsPlots

    # using Distances
    # using DistributedArrays
    # using Distributions
    # using FCSFiles
    # using JuliaInterpreter
    # using LinearAlgebra
    # using ProgressMeter
    # using TensorToolbox

    include("../ext/SOM.jl/types.jl")
    include("../ext/SOM.jl/api.jl")
    include("../ext/SOM.jl/helpers.jl")
    include("batch_som.jl")
    include("parallel_som.jl")

    # include IO files
    include("io/Fcs_helper.jl")

    # include visualization files
    # include("visualization/Plotting.jl")

    export # ext/som
        initSOM,
        trainSOM,
        mapToSOM

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
