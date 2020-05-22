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

include("base/structs.jl")

include("base/dataops.jl")
include("base/distributed.jl")
include("base/trainutils.jl")

include("analysis/core.jl")
include("analysis/embedding.jl")

include("io/dio.jl")
include("io/input.jl")
include("io/process.jl")
include("io/splitting.jl")

# include visualization files
# include("visualization/plotting.jl")

#core
export initGigaSOM, trainGigaSOM, mapToGigaSOM

#trainutils
export linearRadius, expRadius, gaussianKernel, bubbleKernel, thresholdKernel, distMatrix

#embedding
export embedGigaSOM

# structs
export Som, LoadedDataInfo

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
    distributeFileVector

#io/splitting
export slicesof, vcollectSlice, collectSlice

#io/process
export cleanNames!, getMetaData, getMarkerNames

# plotting
export plotCounts, plotPCA

#dataops (higher-level operations on data)
export dcopy,
    dselect,
    dapply_cols,
    dapply_rows,
    dstat,
    dstat_buckets,
    dcount,
    dcount_buckets,
    dscale,
    dtransform_asinh,
    dmedian,
    dmedian_buckets,
    mapbuckets,
    catmapbuckets

#distributed data tools
export save_at,
    get_from,
    get_val_from,
    remove_from,
    distribute_array,
    distribute_darray,
    undistribute,
    distributed_transform,
    distributed_mapreduce,
    distributed_foreach,
    distributed_collect,
    distributed_export,
    distributed_import,
    distributed_unlink


end # module
