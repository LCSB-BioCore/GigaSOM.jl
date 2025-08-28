
# # Starting up
#
# For the installation of Julia or GigaSOM.jl please refer to the installation
# instructions in the
# [README](https://github.com/LCSB-BioCore/GigaSOM.jl?tab=readme-ov-file#installation).
#
# ## High-level overview
# GigaSOM provides functions that allow straightforward loading of FCS files into
# matrices, preparing these matrices for analysis, and running SOM and related
# function on the data.
#
# The main functions, listed by category, include:
#
# - [`load_fcs`](@ref) and [`load_fcs_distributed`](@ref) for loading the data
# - [`fcs_column_metadata`](@ref) and [`fcs_metadata_marker_names`](@ref) for
#   accessing the information about data columns stored in FCS files
# - `dselect`, `dtransform_asinh`, `dscale` and similar functions from
#   [`DistributedData.jl`](https://lcsb-biocore.github.io/DistributedData.jl/stable/)
#   for transforming, scaling and preparing the data
# - [`init`](@ref) for initializing the self-organizing map, [`train`](@ref)
#   for running the SOM training, [`assign`](@ref) for classification using the
#   trained SOM, and [`embed`](@ref) for dimensionality reduction to 2D
#
# Parallel processing is perfurmed using the `Distributed` package -- if you
# add more "workers" using the `addprocs` function, GigaSOM will automatically
# react to that situation, split the data among the processes and run parallel
# versions of all algorithms.
#
# ### Horizontal scaling
#
# While all functions work well on simple data matrices, the main aim of
# GigaSOM is to let the users enjoy the cluster-computing resources. All
# functions also work on data that are "scattered" among workers (i.e. each
# worker only holds a portion of the data loaded in the memory). This dataset
# description is stored in [`Dinfo`](@ref) structure. Most of the functions
# above in fact accept the `Dinfo` as argument, and often return another
# `Dinfo` that describes the scattered result.
#
# Most importantly, using `Dinfo` *prevents memory exhaustion at the
# master node*, which is a critical feature required to handle huge datasets.
#
# You can always collect the scattered data back into a matrix (if it fits to
# your RAM) with `gather_array`, and utilize many other functions to manipulate
# it, including e.g. `dmapreduce` for easily running parallel computations, or
# `dstore` for saving and restoring the dataset paralelly.
#
# ## Minimal working example
#
# First, load GigaSOM:

using GigaSOM

# For the purpose of demonstration, we will create a small random dataset. This
# code generates a 4D hypercube of "size" 10 with gaussian clusters at the
# cube's vertices:

import Random #src
Random.seed!(12345) #src
d = randn(10000, 4) .+ rand(0:1, 10000, 4) .* 10;

# The SOM (of size 20×20) is created and trained as such:

som = init(d, 20, 20)
som = train(som, d)

# (Note that SOM initialization is randomized; if you want to get the same
# results everytime, set the random seed before initialization:

som = init(d, 20, 20, seed = 12345)
som = train(som, d)

# You can now see the SOM codebook (your numbers will likely be different):

som.codes

@test size(som.grid) == (400, 2) #src
@test size(som.codes) == (400, 4) #src
@test minimum(som.codes) > -3 #src
@test maximum(som.codes) < 13 #src

# This information can be used to categorize the dataset into clusters:

assign(som, d)

@test length(assign(som, d)) == 10000 #src

# In the result, `index` is a cluster ID for the original datapoint from `d` at
# the same row.  (As in the previous case, your numbers may differ.)
#
# Finally, you can use EmbedSOM dimensionality reduction to convert all
# multidimensional points to 2D; which can eventually be used to create a
# good-looking 2D scatterplot.
e = embed(som, d)

@test minimum(e) > -3 #src
@test maximum(e) < 22 #src

# The 2D coordinates may be plotted using any standard plotting library. In the
# following example we show how to do that with `Vizagrams.jl`:

using AlgebraOfGraphics, DataFrames

embedded_data = [DataFrame(e, [:x, :y]) DataFrame(d, [:v1, :v2, :v3, :v4])]

draw(data(embedded_data)*mapping(:x, :y, color = :v1)*visual(Scatter, markersize = 2))

# The output shows all 16 ($16 = 2^d$ where $d =4$), colored by their position
# in the 1st dimension in the original space.
#
# For complete clarity on the underlying data structures, we can also plot the
# self-organizing map that "describes" the space:

som_data = [DataFrame(som.grid, [:x, :y]) DataFrame(som.codes, [:v1, :v2, :v3, :v4])]

draw(data(som_data)*mapping(:x, :y, color = :v1)*visual(Scatter, markersize = 20))

# To be completely clear about cluster occupancy, we can also compute the
# assignment counts and highlight them in the plot:
som_data[!, :count] .= 0
for i in assign(som, d)
    som_data[i, :count] += 1
end

draw(data(som_data)*mapping(:x, :y, color = :v1, markersize = :count)*visual(Scatter))
