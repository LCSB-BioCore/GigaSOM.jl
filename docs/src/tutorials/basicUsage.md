
# Tutorial 1: Intro & basic usage

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
in [`Dinfo`](@ref) structure. Most of the functions above in fact
accept the `Dinfo` as argument, and often return another
`Dinfo` that describes the scattered result.

Most importantly, using `Dinfo` **prevents memory exhaustion at the
master node**, which is a critical feature required to handle huge datasets.

You can always collect the scattered data back into a matrix (if it fits to
your RAM) with `gather_array`, and utilize many other functions to manipulate
it, including e.g. `dmapreduce` for easily running parallel computations, or
`dstore` for saving and restoring the dataset paralelly.

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
