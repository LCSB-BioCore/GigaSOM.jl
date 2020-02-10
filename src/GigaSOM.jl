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
    include("distributed.jl")
    include("core.jl")
    include("trainutils.jl")
    include("embedding.jl")

    # input/output handling
    include("io/input.jl")
    include("io/process.jl")
    include("io/splitting.jl")

    # include visualization files
    # include("visualization/plotting.jl")

    export #core
        initGigaSOM,
        trainGigaSOM,
        mapToGigaSOM

    export #trainutils
        linearRadius,
        expRadius,
        gaussianKernel,
        bubbleKernel

    export #embedding
        embedGigaSOM

    export # structs
        daFrame

    export #io/input
        readFlowset,
        readFlowFrame,
        loadData

    export #io/splitting
        generateIO

    export #io/process
        cleanNames!,
        createDaFrame,
        getMarkers,
        checkDir

    export # plotting
        plotCounts,
        plotPCA

end # module
