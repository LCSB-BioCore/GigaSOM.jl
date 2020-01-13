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
    using FCSFiles
    using FileIO
    using DistributedArrays
    using XLSX
    using NearestNeighbors
    using Serialization

    include("structs.jl")
    include("core.jl")
    include("satellites.jl")
    include("embedding.jl")

    # include IO files
    include("io/input.jl")
    include("io/process.jl")

    # include visualization files
    # include("visualization/plotting.jl")

    export #core
        initGigaSOM,
        trainGigaSOM,
        mapToGigaSOM,
        linearRadius,
        expRadius

    export #embedding
        embedGigaSOM

    export # structs
        daFrame

    export #input
        readFlowset,
        readFlowFrame,
        loadData,
        generateIO

    export #satellites
        cleanNames!,
        createDaFrame,
        getMarkers,
        checkDir

    export # plotting
        plotCounts,
        plotPCA

end # module
