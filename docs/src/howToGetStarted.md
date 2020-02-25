
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
som = initGigaSOM(d, 20, 20)   #this requires random numbers, use Random.seed!() for reproducibility
som = trainGigaSOM(som, d)
```

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

(With a different SOM initialization and dataset, the cluster assignment and
results will be different. For clustering to a smaller number of clusters, you
can use `som.codes` for metaclustering, as in FlowSOM.)

Finally, you can create a 2D picture of the result using EmbedSOM:
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

This can be plotted out using any of the plotting libraries:
```julia
using Gadfly
import Cairo
draw(PNG("test.png",20cm,20cm), plot(x=e[:,1], y=e[:,2], color=d[:,1]))
```

In the result, you should be able to see all 16 gaussian clusters colored by
the first dimension in the original space.

## Loading FCS data

You can load an FCS file using [`loadFCS`](@ref) function. For example, the
Levine dataset ([obtainable here](https://flowrepository.org/id/FR-FCM-ZZPH))
may be loaded as such:

```
params, data = loadFCS("Levine_13dim.fcs")
```

`params` will now contain the list of FCS parameters; you can parse a lot of
interesting information from that using the [`getMetaData`](@ref) function:

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

`data` is the usual matrix with expressions; you can use it instead of `d` in the above example.

## Working with distributed data

To load multiple FCS files, use [`loadFCSSet`](@ref). This function is designed
for the situation when the data is too big to fit into memory, and attempts to
split them into available workers. For that purpose, it needs a **dataset
name** that will be used to uniquely identify your loaded data in the cluster.
The identifiers are julia symbols, basically variable names starting with a `:`
colon.

This way you create the `levine` dataset:

```julia
datainfo = loadFCSSet(:levine, ["Levine_13dim.fcs"])
```

Expectably, you can pass in any number of files you have, e.g. a whole study.

The resulting `datainfo` carries informaton about dataset name and distribution
among the cluster, and can be used just as the "data" parameter in all
SOM-related functions again, instead of `d`.

The following code exploits the possibility to actually split the data and
processes the Levine dataset parallelly on 2 workers:

```julia
using Distributed
addprocs(2)                 # add any number of CPUs/tasks/workers you have available
@everywhere using GigaSOM   # load GigaSOM also on the workers

datainfo = loadFCSSet(:levine, ["Levine_13dim.fcs"]) # add more files as needed

dselect(datainfo, Vector(1:13))   # only these cols contain expression information, col 14 contains labels
som = initGigaSOM(datainfo, 20, 20)
som = trainGigaSOM(som, datainfo)
```

As a side effect (and again to prevent memory overload), results of the
per-cell operations are stored in datainfo objects. In this case, this does the
embedding but leaves the data safely scattered among the cluster:
```julia
e = embedGigaSOM(som, datainfo)
```

If you are sure you have enough RAM (in case with Levine13 dataset you probably
have enough RAM), you can collect the data to the master node to get the
coordinates viable for plotting:
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

## Working with realistic datasets

In this example we will use a subset of the Cytometry data from Bodenmiller et al.
(Bodenmiller et al., 2012). This data-set contains samples from peripheral blood
mononuclear cells (PBMCs) in unstimulated and stimulated conditions for 8 healthy donors.

10 cell surface markers (lineage markers) are used to identify different cell populations. The dataset is described in two files:

- `PBMC8_panel.xlsx` (with antigen names categorized as lineage markers and functional markers)
- `PBMC8_metadata.xlsx` (file names, sample IDs, condition IDs and patient IDs)

### Preparing the dataset

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

The metadata is present in external files; we read it into a DataFrame and
extract information about FCS data columns from there:

```julia
using GigaSOM

# Read the dataset description in XLSX files as DataFrames
md = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1")...)
panel = GigaSOM.DataFrame(GigaSOM.XLSX.readtable("PBMC8_panel.xlsx", "Sheet1")...)

# Get the parameters structure from the first FCS files
_, fcsParams = loadFCSHeader(md[1, :file_name])

# See what antigens are saved in there
_, fcsAntigens = getMarkerNames(getMetaData(fcsParams))

# See which antigens we want to use (assume we want only the lineage markers
antigens = panel[panel[:,:Lineage].==1, :Antigen]

# Make the names a bit more Julia-friendly and predictable:
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
# select only the antigens that correspond to lineage markers (as prepared above)
dselect(di, fcsAntigens, antigens)

cols=Vector(1:length(antigens)) # shortcut for "all rows"

# perform asinh transformation on all data in the dataset, '5' is the cofactor
dtransform_asinh(di, cols, 5)

# normalize all dataset columns to mean=0 sdev=1
dscale(di, cols)
```

### Creating a Self Organizing MAP (SOM)

With the data prepared, running the SOM algorithm is almost the same as in
previous cases:

```julia
# randomly initialize the SOM
som = initGigaSOM(di, 16, 16)

# train the SOM for 20 epochs (10 is default but nothing will happen if the
# epochs are slightly overdone)
som = trainGigaSOM(som, di, epochs = 20)
```

Finally, calculate the clustering:

```julia
somClusters = mapToGigaSOM(som, di)
```

### FlowSOM-style metaclustering

One disadvantage of SOMs is that they output tremendous amount of small
clusters that are relatively hard to interpret manually. FlowSOM has decided to
run a "clustering on clusters" (metaclustering) that address the main problems:

- it is much faster than running a normal clustering algorithm on the whole
  dataset
- the clusters are much more interpretable than SOM-defined Voronoi cells

FlowSOM uses the consensus clustering to categorize SOM codes into groups; but
in fact any clustering algorithm can be used with pretty good results.

In this case, we demonstrate how to get 10 clusters out of the 16x16 SOMs,
using the standard hierarchical clustering:

```julia
using Clustering
import Distances
metaClusters =
  cutree(k=10,
         hclust(linkage=:average,
                GigaSOM.distMatrix(Distances.Euclidean())(som.codes)))
```

The `metaClusters` represent membership of the SOM codes in cluster; which can
be expanded to membership of all cells using [`mapToGigaSOM`](@ref):

```julia
mapping = distributed_collect(mapToGigaSOM(som, di), free=true)
clusters = metaClusters[mapping]
```

`clusters` now contain an integer from `1` to `10` with a classification of
each cell in the dataset.

(The argument `free=true` of `distributed_collect` automatically removes the
distributed data from workers after collecting, which may sometimes save a lot
of memory.)

### Getting per-cluster statistics in a distributed way

If you can get the data on a single machine, computation of various statistics
is done simply, using standard Julia functions. In distributed settings that
may become slightly more complicated. Luckily, many algorithms possess a
map-reduce implementation that can be used to address this. The [`dstat`](@ref)
function is one example.

We will show how to use the general framework to compute per-cluster
statistics. GigaSOM exports the [`distributed_mapreduce`](@ref) function that
can be used as a basic building block for running the computations. For
example, you can efficiently compute a distributed mean of all your data using
this code:

```julia
distributed_mapreduce(di, sum, +) / distributed_mapreduce(di, length, +)
```
The second parameter of `distributed_mapreduce` describes the "map" step
(summing/measuring the large matrix), the third is the "reduce" step, which
takes two intermediate results from 2 workers and reduces it to one.

Row-wise mean (if you don't want to use `dstat`) is slightly more useful (and a
bit more complicated):

```julia
distributed_mapreduce(di, d -> mapslices(sum, d, dims=1), +) ./ distributed_mapreduce(di, length, +)
```

Finally, for distributed computation of per-cluster mean, the clustering
information needs to be distributed as well (Fortunately, that is easy, because
the distributed `mapToGigaSOM` does exactly that).

```julia
mapping = mapToGigaSOM(som, mapping)

# Optionally, we can transform the mapping to metaclustering with 10 clusters, as above
metaClustering = cutree(k=10, .....)
distributed_transform(mapping, m -> metaClusters[m])

# Run the distributed computation
sums, counts = distributed_mapreduce(:($(di.val), $(mapping.val)), # combine the distributed variable names
    ((d, cl)::Tuple) ->
        ([mapslices(sum, d[cl.==ci,:], dims=1) for ci in 1:10], # per-cluster sums
         count.([cl.==ci for ci in 1:10])), # cluster cell counts
    ((s1,c1),(s2,c2)) ->
        (s1+s2, c1+c2), # combine sums and counts
    di.workers) # run on workers where the dataset is distributed (mapToGigaSOM preserves this)

clusterMeans = sums ./ counts

# remove the temporary data from workers
undistribute(mapping)
```

If this is used for the first hypercube dataset, you will see many obvious
hypercube clusters (although not all, because `k=10` is not enough to capture
all the actual clusters:

```julia
clusterMeans
```

```
10-element Array{Array{Float64,2},1}:
 [10.030517727720023 4.969835206294571 -0.002550714707511989 -0.04645512428786515]
 [-0.05756988211396393 9.989581063057557 0.0070989183907681185 0.007732728630400461]
 [0.06642788133290563 0.012891136200321923 0.007461465448833184 0.011347000311884337]
 [-0.01661781514179996 4.926105824766316 10.008631852601253 0.04138709838816687]
 [0.019056476274056117 -0.01733512062946413 4.756495890572492 9.961501755505]
 [9.995998375509929 9.994349888060675 9.960178331885636 -0.0023545779355493087]
 [9.999826927398248 -0.04498249059714222 10.001950728982699 -0.07043172174629345]
 [0.01655170597672653 9.987304613751386 5.1417740549113065 10.018189676094703]
 [10.012585740990803 4.960617697782793 10.054247289887263 10.042549640024358]
 [10.027515119157513 5.060174747324343 -0.06042755838171319 9.988939846372283]
```
