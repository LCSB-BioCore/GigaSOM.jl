
# How to get started

For the installation of Julia or GigaSOM.jl please refer to the installation
instructions.

## High-level overview

GigaSOM provides functions that allow straightforward loading of FCS files into
matrices, preparing these matrices for analysis, and running SOM and related
function on the data.

The main functions, listed by category:

- [`loadFCS`](@ref) and [`loadFCSSet`](@ref) for loading the data
- [`getMetaData`](@ref) and [`getMarkerNames`](@ref) for accessing the
  information about data columns stored in FCS files
- [`dselect`](@ref), [`dtransform_asinh`](@ref), [`dscale`](@ref) and similar
  functions for transforming, scaling and preparing the data
- [`initGigaSOM`](@ref) for initializing the self-organizing map,
  [`trainGigaSOM`](@ref) for running the SOM training, [`mapToGigaSOM`](@ref)
  for classification using the trained SOM, and [`embedGigaSOM`](@ref) for
  dimensionality reduction to 2D

Multiprocessing is done using the `Distributed` package -- if you add
more "workers" using the `addprocs` function, GigaSOM will
automatically react to that situation, split the data among the processes and
run parallel versions of all algorithms.

### Horizontal scaling

While all functions work well on simple data matrices, the main aim of GigaSOM
is to let the users enjoy the cluster-computing resources. All functions also
work on data that are "scattered" among workers (i.e. each worker only holds a
portion of the data loaded in the memory). This dataset description is stored
in [`LoadedDataInfo`](@ref) structure. Most of the functions above in fact
accept the `LoadedDataInfo` as argument, and often return another
`LoadedDataInfo` that describes the scattered result.

Most importantly, using `LoadedDataInfo` **prevents memory exhaustion at the
master node**, which is a critical feature required to handle huge datasets.

You can always collect the scattered data back into a matrix (if it fits to
your RAM) with [`distributed_collect`](@ref), and utilize many other functions
to manipulate it, including e.g. [`distributed_mapreduce`](@ref) for easily
running parallel computations, or [`distributed_export`](@ref) for saving and
restoring the dataset paralelly.

## Minimal working example

First, load GigaSOM:

```julia
using GigaSOM
```

We will create a bit of randomly generated data for this purpose. This code
generates a 4D hypercube of size 10 with gaussian clusters at vertices:

```julia
d = randn(10000,4) .+ rand(0:1, 10000, 4).*10
```

The SOM (of size 20x20) is created and trained as such:

```julia
som = initGigaSOM(d, 20, 20)
som = trainGigaSOM(som, d)
```

(Note that SOM initialization is randomized; if you want to get the same
results everytime, use e.g. `Random.seed!(1)`.)

You can now see the SOM codebook (your numbers will vary):

```julia
som.codes
```

```
400×4 Array{Float64,2}:
 -0.361681    -0.57191     0.140438   9.99224
 -1.111        1.60277    -0.209706   9.96805
 -1.23305      7.58148    -0.445886   9.76316
 -0.285692     9.80184    -1.12107    9.85507
 -0.197007    10.8793     -0.649294   9.89448
 -0.334737    11.0858      0.213889   9.93479
  0.00282155  11.0725      0.718114  10.2714
 -0.333398    10.1315      1.14412   10.564
 -0.0124202    1.48128     8.35741   10.72
 -0.0084074    0.0150858   9.91007   11.5361
  ⋮
```

This information can be used to categorize the dataset into clusters:

```julia
mapToGigaSOM(som, d)
```

In the result, `index` is a cluster ID for the original datapoint from `d` at
the same row.
```
10000×1 DataFrames.DataFrame
│ Row   │ index │
│       │ Int64 │
├───────┼───────┤
│ 1     │ 381   │
│ 2     │ 178   │
│ 3     │ 348   │
│ 4     │ 379   │
│ 5     │ 80    │
│ 6     │ 146   │
│ 7     │ 57    │
⋮
```

(As in the previous case, your numbers may differ.)

Finally, you can use EmbedSOM dimensionality reduction to convert all
multidimensional points to 2D; which can eventually be used to create a
good-looking 2D scatterplot.
```julia
e = embedGigaSOM(som,d)
```

```
10000×2 Array{Float64,2}:
  1.41575  18.5282
 17.4483    7.4137
  6.88243  17.5722
 17.654    18.0348
 17.594     3.15645
  5.27181   8.61096
 15.9708    2.8124
  6.19637   9.05302
  1.49358   7.19198
 16.596     7.75608
  ⋮
```

The 2D coordinates may be plotted by any standard plotting library. In the
following example we show how to do that with `Gadfly`:
```julia
Pkg.add("Gadfly")
Pkg.add("Cairo")
using Gadfly
import Cairo
draw(PNG("test.png",20cm,20cm), plot(x=e[:,1], y=e[:,2], color=d[:,1]))
```

In the resulting picture, you should be able to see all 16 gaussian clusters
colored by the first dimension in the original space.

## Loading FCS data

You can load any FCS file using [`loadFCS`](@ref) function. For example, the
Levine dataset ([obtainable here](https://flowrepository.org/id/FR-FCM-ZZPH))
may be loaded as such:

```
params, data = loadFCS("Levine_13dim.fcs")
```

`params` will now contain the list of FCS parameters; you can parse a lot of
interesting information from it using the [`getMetaData`](@ref) function:

```julia
getMetaData(params)
```

```
14×8 DataFrames.DataFrame. Omitted printing of 3 columns
│ Row │ E      │ S      │ N      │ RMIN              │ R      │
│     │ String │ String │ String │ String            │ String │
├─────┼────────┼────────┼────────┼───────────────────┼────────┤
│ 1   │ 0,0    │        │ CD45   │ -2.03601189282714 │ 1024   │
│ 2   │ 0,0    │        │ CD45RA │ -2.99700270621007 │ 1024   │
│ 3   │ 0,0    │        │ CD19   │ -3.05850183816765 │ 1024   │
│ 4   │ 0,0    │        │ CD11b  │ -2.99956408593931 │ 1024   │
│ 5   │ 0,0    │        │ CD4    │ -2.22860674361335 │ 1024   │
│ 6   │ 0,0    │        │ CD8    │ -3.29174106765763 │ 1024   │
│ 7   │ 0,0    │        │ CD34   │ -2.74278770893026 │ 1024   │
│ 8   │ 0,0    │        │ CD20   │ -3.40866348184011 │ 1024   │
│ 9   │ 0,0    │        │ CD33   │ -2.31371406643428 │ 1024   │
│ 10  │ 0,0    │        │ CD123  │ -3.02624638359366 │ 1024   │
│ 11  │ 0,0    │        │ CD38   │ -3.14752313833461 │ 1024   │
│ 12  │ 0,0    │        │ CD90   │ -2.55305031846157 │ 1024   │
│ 13  │ 0,0    │        │ CD3    │ -3.52459385416266 │ 1024   │
│ 14  │ 0,0    │        │ label  │ 1                 │ 1024   │
```

`data` is a matrix with cell expressions, one cell per row, one marker per
column. If you want to run SOM analysis on it, you can cluster and visualize it
just as in the previous example:

```
som = initGigaSOM(data, 16, 16)
som = trainGigaSOM(som, data)
clusters = mapToGigaSOM(som, data)
e = embedGigaSOM(som, data)

# ... save/plot results, etc...
```

## Working with distributed data

Usual experiments produce multiple FCS files, and distributed or parallel
processing is very helpful in processing all the data.

To load multiple FCS files, use [`loadFCSSet`](@ref). This function works well
in the "usual" single-process environment, but additionally it is designed to
handle situations when the data is too big to fit into memory, and attempts to
split them into available distributed workers workers.

For the purpose of data distribution, you need to identify each dataset by an
unique **dataset name** that will be used for identifying your loaded data in
the cluster environment.  The dataset name is a simple Julia symbols; basically
a variable name that is prefixed with a `:` colon.

For example, we can load the Levine13 dataset as such:

```julia
datainfo = loadFCSSet(:levine, ["Levine_13dim.fcs"])
```

Expectably, if you have more files, just write their names into the array and
the function will handle the rest.

The result `datainfo` carries informaton about your selected dataset name and
its distribution among the cluster. It can be used just as the "data" parameter
in all SOM-related functions again; e.g. as `trainGigaSOM(som, datainfo)`.

The following example exploits the possibility to actually split the data, and
processes the Levine dataset parallelly on 2 workers:

```julia
using Distributed
addprocs(2)                 # add any number of CPUs/tasks/workers you have available
@everywhere using GigaSOM   # load GigaSOM also on the workers

datainfo = loadFCSSet(:levine, ["Levine_13dim.fcs"]) # add more files as needed

dselect(datainfo, Vector(1:13))   # select columns that contain expressions (column 14 contains labels)
som = initGigaSOM(datainfo, 20, 20)
som = trainGigaSOM(som, datainfo)
```

To prevent memory overload of the "master" computation node, the results of all
per-cell operations are also stored in distributed datainfo objects. In this
case, the following code does the embedding, but leaves the resulting data
safely scattered among the cluster:
```julia
e = embedGigaSOM(som, datainfo)
```

If you are sure you have enough RAM, you can collect the data to the master
node. (In case of the relatively small Levine13 dataset, you very probably have
the required 2.5MB of RAM, but there are many larger datasets.)
```julia
e = distributed_collect(e)
```

```
167044×2 Array{Float64,2}:
 16.8251   11.5002
 18.2608   12.884
 12.0103    5.18401
 18.381    12.3436
 18.357    11.6622
 14.8936   12.0897
 17.6441   12.3652
 17.8752   12.7206
 17.301    11.0767
 14.2055   12.2227
  ⋮
```

## Working with large datasets

In this example we will use a subset of the Cytometry data [by Bodenmiller et
al.](https://dx.doi.org/10.1038%2Fnbt.2317). This data-set contains samples
from peripheral blood mononuclear cells (PBMCs) in unstimulated and stimulated
conditions for 8 healthy donors.

10 cell surface markers (lineage markers) are used to identify different cell
populations. The dataset is described in two files:

- `PBMC8_panel.xlsx` (with antigen names categorized as lineage markers and functional markers)
- `PBMC8_metadata.xlsx` (file names, sample IDs, condition IDs and patient IDs)

### Downloading and preparing the dataset

The example data can be downloaded from [imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/](http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/)

You can fetch the files directly from within Julia:

```julia
# fetch the required data for testing and download the zip archive and unzip it
dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
        end
    end
end
```

The metadata is present in external files; we read it into a `DataFrame` and
extract information about FCS data columns from there. First, we read the
actual content using the XLSX package:

```julia
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)
```

After that, we can get the parameter structure from the first FCS files:
```julia
_, fcsParams = loadFCSHeader(md[1, :file_name])
```

Continue with extracting marker names using the prepared functions:
```julia
_, fcsAntigens = getMarkerNames(getMetaData(fcsParams))
```

Now, see which antigens we want to use (assume we want only the lineage markers):
```julia
antigens = panel[panel[:,:Lineage].==1, :Antigen]
```

Finally, it is often useful to make the names a bit more Julia-friendly and predictable:
```julia
cleanNames!(antigens)
cleanNames!(fcsAntigens)
```

### Loading and preparing the data

Now we have the vector of `fcsAntigens` that the FCS files store, and list of
`antigens` that we want to analyze. We continue by loading the data, reducing
it to the desired antigens and transforming it a bit:

```julia
di = loadFCSSet(:pbmc8, md[:,:file_name])
```

(If data distribution and parallelization is required, you must add parallel
workers using `addprocs` **before** this step.)

Now that the data is loaded, let's prepare them a bit by reducing to actual
interesting columns, transformation and scaling:

```julia
# select only the columns that correspond to the lineage antigens we have prepared before
dselect(di, fcsAntigens, antigens)

cols = Vector(1:length(antigens)) # shortcut for "all rows"

# perform asinh transformation on all data in the dataset, '5' is the cofactor for the transformation
dtransform_asinh(di, cols, 5)

# normalize all dataset columns to mean=0 sdev=1
dscale(di, cols)
```

### Creating a Self Organizing MAP (SOM)

With the data prepared, running the SOM algorithm is straightforward:

```julia
# randomly initialize the SOM
som = initGigaSOM(di, 16, 16)

# train the SOM for 20 epochs (10 is default, but nothing will happen if the
# epochs are slightly overdone)
som = trainGigaSOM(som, di, epochs = 20)
```

Finally, calculate the clustering:

```julia
somClusters = mapToGigaSOM(som, di)
```

### FlowSOM-style metaclustering

One disadvantage of SOMs is that they output a large amount of small
clusters that are relatively hard to interpret manually. FlowSOM improved that
situation by running a "clustering on clusters" (metaclustering) that address
the problem.

In this example, we reduce the original 256 small clusters from 16x16 SOM to
only 10 "metaclusters", using the standard hierarchical clustering:

```julia
using Clustering
import Distances
metaClusters =
  cutree(k=10,
         hclust(linkage=:average,
            GigaSOM.distMatrix(Distances.Euclidean())(som.codes)))
```

The `metaClusters` represent membership of the SOM codes in cluster; these can
be expanded to membership of all cells using [`mapToGigaSOM`](@ref):

```julia
mapping = distributed_collect(mapToGigaSOM(som, di), free=true)
clusters = metaClusters[mapping]
```

`clusters` now contain an integer from `1` to `10` with a classification of
each cell in the dataset.

(The argument `free=true` of `distributed_collect` automatically removes the
distributed data from workers after collecting, which saves their memory for
other datasets.)

### Getting per-cluster statistics in a distributed way

If you can get the data on a single machine, computation of various statistics
can be performed using standard Julia functions. With large datasets that do
not fit on a computer, things get more complicated. Luckily, many statistics and algorithms
possess parallel, map-reduce-style implementations that can be used to address this problem.

For example, the [`dstat`](@ref) function computes sample statistics without
fetching all data to a single node. You can use it in a way similar to
aforementioned `dselect` and `dtransform_asinh`. The following code extracts
means and standard deviations from the first 3 columns of a dataset distributed
as `di`:
```julia
dstat(di, [1,2,3])
```

#### Manual work with the distributed data

We will first show how to use the general framework to compute per-cluster
statistics. GigaSOM exports the [`distributed_mapreduce`](@ref) function that
can be used as a very effective basic building block for running such
computations. For example, you can efficiently compute a distributed mean of
all your data as such:
```julia
distributed_mapreduce(di, sum, +) / distributed_mapreduce(di, length, +)
```

The parameters of `distributed_mapreduce` are, in order:

- `di`, the dataset
- `sum` or `length`, an unary "map" function -- during the computation, each piece of
  distributed data is first _paralelly_ processed by this function
- `+`, a binary "reduction" or "folding" function -- the pieces of information
  processed by the map function are successively joined in pairs using this
  function, until there is only a single result left. This final result is also
  what `distributed_mapreduce` returns.

Above example thus reads: Sum all data on all workers, add up the intermediate
results, and divide the final number to the sum of all lengths of data on the
workers.

Column-wise mean (as produced by `dstat`) is slightly more useful; we only need
to split the computation on columns:

```julia
distributed_mapreduce(di, d -> mapslices(sum, d, dims=1), +) ./ distributed_mapreduce(di, x->size(x,1), +)
```

Finally, for distributed computation of per-cluster mean, the clustering
information needs to be distributed as well (Fortunately, that is easy, because
the distributed `mapToGigaSOM` does exactly that).

First, compute the clustering:
```julia
mapping = mapToGigaSOM(som, di)
distributed_transform(mapping, m -> metaClusters[m])
```

Now, the distributed computation is run on 2 scattered datasets. We employ a
helper function `mapbuckets` which provides bucket-wise execution of a
function, in a way very similar to `mapslices`. (In the example, we actually
use `catmapbuckets` that concatenates the result into a nice array.) The
following code produces a matrix of tuples `(sum, count)`, for separate
clusters (in rows) and data columns (in columns):

sumscounts = distributed_mapreduce([di, mapping],
    (d, mapping) -> catmapbuckets(
        (_,clData) -> (sum(clData), length(clData)),
	d, 10, mapping),
    (a,b) -> (((as,al),(bs,bl)) -> ((as+bs), (al+bl))).(a,b))
```

```
10×4 Array{Tuple{Float64,Int64},2}:
 (5949.71, 1228)  (-21.9789, 1228)  (12231.3, 1228)  (12303.1, 1228)gg
 (6379.98, 1246)  (12464.3, 1246)   (12427.9, 1246)  (12479.8, 1246)gg
 (6513.41, 1294)  (12968.8, 1294)   (12960.7, 1294)  (-28.1922, 1294)
 (6312.37, 1236)  (-26.7392, 1236)  (6.74384, 1236)  (12401.7, 1236)gg
 (6395.73, 1285)  (12867.7, 1285)   (-52.653, 1285)  (-26.9795, 1285)
 (6229.72, 622)   (10.7578, 622)    (6200.1, 622)    (0.882128, 622)gg
 (6141.97, 612)   (6078.56, 612)    (45.9878, 612)   (6079.3, 612)gg
 (51.3709, 616)   (23.4306, 616)    (6117.53, 616)   (1.15342, 616)gg
 (6177.16, 1207)  (-50.4624, 1207)  (48.8023, 1207)  (-5.549, 1207)gg
 (8.56597, 654)   (6536.1, 654)     (-29.2208, 654)  (6539.94, 654)gg
```

With a bit of Julia, this can be aggregated to actual per-cluster means:
```juliagg
clusterMeans = (x->(/)(x...)).(sumcounts)
```

```
10×4 Array{Float64,2}:
  4.84504    -0.0178982   9.96031     10.0188gg
  5.12037    10.0034      9.97428     10.0159gg
  5.03354    10.0223     10.016       -0.0217869gg
  5.10709    -0.0216336   0.00545618  10.0337gg
  4.97722    10.0138     -0.0409751   -0.0209958gg
 10.0156      0.0172955   9.968        0.00141821
 10.0359      9.93229     0.0751434    9.9335gg
  0.0833944   0.0380366   9.93105      0.00187243
  5.11778    -0.0418081   0.0404327   -0.00459735
  0.0130978   9.99403    -0.0446802    9.99991gg
```

Since we used the data from the hypercube dataset from the beginning of the
tutorial, you should be able to recognize several clusters that perfectly match
the hypercube vertices (although not all, because `k=10` is not enough to
capture all of the actual 16 existing clusters)

Finally, we can remove the temporary data from workers to create free memory for other analyses:
```julia
undistribute(mapping)
```

#### Convenience statistical functions

Notably, several of the most used statistical functions are available in
GigaSOM.jl in a form that can cope with distributed data.

For example, you can run a distributed median computation as such:
```julia
dmedian(di, [1,2,3,4])
```

In the hypercube dataset, the medians are slightly off-center because there is
a lot of empty space between the clusters:
```
3-element Array{Float64,1}:
 6.947097488861494
 7.934405685940568
 7.069149844215707
 2.558892109203585
```

`dstat` function has a bucketed variant that can split the statistics among
different clusters. This computes the per-cluster standard deviations of the
dataset:

```julia
dstat_buckets(di, 10, mapping, [1,2,3,4])[2]
```

In the result, we can count 4 "nice" clusters, and 6 clusters that span 2 of
the original clusters, totally giving 16. (Hypercube validation succeeded!)
```
10×4 Array{Float64,2}:
 5.09089   0.997824  1.01815   0.980758
 5.13971   1.02019   0.977637  1.00124gg
 5.13209   0.974332  1.00058   0.99874gg
 5.11529   0.998166  1.01825   1.01885gg
 5.10542   1.01686   0.975993  0.991992
 0.991075  0.993312  1.00667   1.05048gg
 0.996443  1.02699   0.938742  0.98831gg
 0.946917  0.989543  1.0056    0.999609
 5.09963   1.00131   0.978803  0.984435
 1.00892   0.998226  1.05538   0.994829
```

A similar bucketed version is available for computation of medians:
```julia
dmedian_buckets(di, 10, mapping, [1,2,3,4])
```

Note that the cluster medians are similar to means, except for the cases when
the cluster is formed by 2 actual data aggregations (e.g. on the second row),
where medians dodge the empty space in the middle of the data:
```
10×4 Array{Float64,2}:
  1.97831    -0.0120118    9.98967    10.0161gg
  7.99438    10.0263       9.9988     10.0033gg
  3.27907     9.98728     10.0254      0.00444198
  7.91739    -0.0623953   -0.0240277  10.0374gg
  2.445      10.0101      -0.0471141  -0.0253346gg
 10.0121      0.00935064   9.94992     0.0459787gg
 10.0512      9.93359      0.0923141   9.91175gg
  0.0675462  -0.0142712    9.93406     0.0343599gg
  8.09972    -0.0217352    0.0575258  -0.010485gg
 -0.0183372  10.0392      -0.115253   10.0101gg
```

## Where to go next?

You should now have a decent idea of how GigaSOM.jl works internally. With real
data, you may encounter situations that require deeper digging in parameters
and GigaSOM internals. We list several of the most frequently used ones:

- You may want to increase the size of SOM in [`initGigaSOM`](@ref) to get more
  precise clusters.
- You may speed up the computation a lot by using neighborhood-indexing
  structures -- see package `NearestNeighbors` and parameters `knnTreeFun` of
  functions [`trainGigaSOM`](@ref) and [`embedGigaSOM`](@ref)
- It is adviced to try different settings of SOM training -- of the arguments
  of [`trainGigaSOM`](@ref), try modifying the starting/finishing radius
  (`rStart`, `rFinal`), using a different radius decay (parameter `radiusFun`,
  try e.g. `linearRadius`) or try a different neighborhood (`kernelFun` and
  `somDistFun`) or a completely different metric.
- You can get a sharper or smoother embedding by varying the amount of
  neighbors (`k`) and smoothing of the neighborhood (`smooth`) of
  [`embedGigaSOM`](@ref).
- For plotting of really huge data, you may want to try
  [GigaScatter](https://github.com/LCSB-BioCore/GigaScatter.jl).
