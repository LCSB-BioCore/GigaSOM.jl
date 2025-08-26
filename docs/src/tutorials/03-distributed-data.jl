
# # Tutorial 3: Distributed data processing and statistics

# If you can get the data on a single machine, computation of various
# statistics can be performed using standard Julia functions. With large
# datasets that do not fit on a computer, things get more complicated. Luckily,
# many statistics and algorithms possess parallel, map-reduce-style
# implementations that can be used to address this problem.
#
# Here, we show how to use DistributedData package to run various operations on
# the datasets scattered over many computation nodes. For demonstration, we use
# a dataset that contains the "hypercube of clusters":

using DistributedData
using Distributed

import Random #src
Random.seed!(12345) #src
d = randn(10000, 4) .+ rand(0:1, 10000, 4) .* 10;

# First, we distribute the dataset over the available workers to obtain a
# "handle":

di = scatter_array(:distributed_d, d, workers())

# There are many functions to work with such data by "handles". For example,
# the `dstat` function computes sample statistics without fetching all data to
# a single node. You can use it in a way similar to aforementioned `dselect`
# and `dtransform_asinh`. The following code extracts means and standard
# deviations from the first 3 columns of a dataset distributed as `di`:

dstat(di, [1, 2, 3])
#
# ## Manual work with the DistributedData.jl package
#
# We will first show how to use the general framework to compute per-cluster
# statistics. DistributedData.jl exports the `dmapreduce` function that can be
# used as a very effective basic building block for running such computations.
# For example, you can efficiently compute a distributed mean of all your data
# as such:

dmapreduce(di, sum, +) / dmapreduce(di, length, +)

# The parameters of `dmapreduce` are, in order:
# - `di`, the dataset
# - `sum` or `length`, an unary "map" function -- during the computation, each
#   piece of distributed data is first _paralelly_ processed by this function
# - `+`, a binary "reduction" or "folding" function -- the pieces of information
#   processed by the map function are successively joined in pairs using this
#   function, until there is only a single result left. This final result is
#   also what `dmapreduce` returns.
#
# Above example thus reads: Sum all data on all workers, add up the intermediate
# results, and divide the final number to the sum of all lengths of data on the
# workers.
#
# Column-wise mean (as produced by `dstat`) is slightly more useful; we only need
# to split the computation on columns:

dmapreduce(di, d -> mapslices(sum, d, dims = 1), +) ./ dmapreduce(di, x->size(x, 1), +)

# Finally, for distributed computation of per-cluster mean, the clustering
# information needs to be distributed as well (Fortunately, that is easy,
# because the distributed `assign` does exactly that).
#
# First, compute the clustering:
som = init(di, 10, 10, seed = 12345)
train(som, di)
mapping = assign(som, di)

# Given a metaclustering (as produced in the [flow cytometry
# tutorial](02-flow-data.md), we can transform the mapping to SOM clusters to
# the mapping to metaclusters. (For simplicity, we use a random metaclustering
# here.)

meta_clusters = rand(1:5, 100)
dtransform(mapping, m -> meta_clusters[m])

# The computation is automatically run over the 2 distributed partitions of the
# dataset.
#
# To aggregate some statistic information about the clusters, we use a helper
# function `mapbuckets` which provides bucket-wise execution of any
# statistics-generating function, in a way very similar to `mapslices`. (In the
# example, we actually use `catmapbuckets` that concatenates the result into a
# nice array.) The following code produces a matrix of tuples `(sum, count)`,
# for separate clusters (in rows) and data columns (in columns):

sums_counts = dmapreduce(
    [di, mapping],
    (d, mapping) -> DistributedData.catmapbuckets(
        (_, clust) -> (sum(clust), length(clust)),
        d,
        5,
        mapping,
    ),
    (a, b) -> (((as, al), (bs, bl)) -> ((as+bs), (al+bl))).(a, b),
)

# With a bit of extra programming, the gathered information can be aggregated
# to produce actual per-cluster means:
cluster_means = [sum/count for (sum, count) in sums_counts]

# Finally, we can remove the temporary data from workers to create free memory
# for other analyses:
unscatter(mapping)

# ## Convenience statistical functions
#
# Notably, several of the most used statistical functions are available in
# DistributedData.jl in a form that can cope with distributed data.
#
# For example, you can run a distributed median computation as such:
dmedian(di, [1, 2, 3, 4])

# In the hypercube dataset, the medians are slightly off-center because there
# is a lot of empty space between the clusters.

# `dstat` function has a bucketed variant that can split the statistics among
# different clusters. This computes the per-cluster standard deviations of the
# dataset:

dstat_buckets(di, 10, mapping, [1, 2, 3, 4])[2]

# In the result, we can count 4 "nice" clusters, and 6 clusters that span 2 of
# the original clusters, totally giving 16. (Hypercube validation succeeded!)
#
# A similar bucketed version is available for computation of medians:
dmedian_buckets(di, 10, mapping, [1, 2, 3, 4])

# Note that the cluster medians are similar to means, except for the cases when
# the cluster is formed by 2 actual data aggregations (e.g. on the second row),
# where medians dodge the empty space in the middle of the data:
