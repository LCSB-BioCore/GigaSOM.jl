"""
Main module for `GigaSOM.jl` - Huge-scale, high-performance flow cytometry clustering

The documentation is here: http://LCSB-BioCore.github.io/GigaSOM.jl

"""

module GigaSOM

    using Distributed
    using DataFrames
    using Distributions

    include("errors.jl")
    include("helpers.jl")
    include("grids.jl")
    include("kernels.jl")

end # module
