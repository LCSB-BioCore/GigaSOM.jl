"""
Main module for `GigaSOM.jl` - Huge-scale, high-performance flow cytometry clustering

The documentation is here: http://LCSB-BioCore.github.io/GigaSOM.jl
"""

module GigaSOM

using CSV
using DataFrames
using Distances
using Distributed
using DistributedData
using Distributions
using FCSFiles
using FileIO
using DistributedArrays
using NearestNeighbors
using Serialization
using StableRNGs

include("base/structs.jl")

include("base/dataops.jl")
include("base/trainutils.jl")

include("analysis/core.jl")
include("analysis/embedding.jl")

include("io/input.jl")
include("io/process.jl")
include("io/splitting.jl")

#core
export initGigaSOM, trainGigaSOM, mapToGigaSOM

#trainutils
export linearRadius, expRadius, gaussianKernel, bubbleKernel, thresholdKernel, distMatrix

#embedding
export embedGigaSOM

# structs
export Som

#io/input
export readFlowset,
    readFlowFrame,
    loadFCS,
    loadFCSHeader,
    getFCSSize,
    loadFCSSizes,
    loadFCSSet,
    selectFCSColumns,
    distributeFCSFileVector,
    distributeFileVector,
    getCSVSize,
    loadCSV,
    loadCSVSizes,
    loadCSVSet

#io/splitting
export slicesof, vcollectSlice, collectSlice

#io/process
export cleanNames!, getMetaData, getMarkerNames

#dataops (higher-level operations on data)
export dtransform_asinh

end # module
