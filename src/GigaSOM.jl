"""
    module GigaSOM

Huge-scale, high-performance flow cytometry data clustering.

See documentation at: <http://LCSB-BioCore.github.io/GigaSOM.jl>
"""
module GigaSOM

using DocStringExtensions

using CSV
using DataFrames
using Distances
using Distributed
using DistributedData
using Distributions
using FCSFiles
using FileIO
using NearestNeighbors
using Serialization
using StableRNGs

include("structs.jl")

include("som.jl")
include("som_utils.jl")
include("embedding.jl")

include("load.jl")
include("split.jl")

include("utils.jl")
include("data_utils.jl")


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
