
# Tutorial 3: Distributed data processing and statistics

If you can get the data on a single machine, computation of various statistics
can be performed using standard Julia functions. With large datasets that do
not fit on a computer, things get more complicated. Luckily, many statistics
and algorithms possess parallel, map-reduce-style implementations that can be
used to address this problem.

For example, the [`dstat`](@ref) function computes sample statistics without
fetching all data to a single node. You can use it in a way similar to
aforementioned `dselect` and `dtransform_asinh`. The following code extracts
means and standard deviations from the first 3 columns of a dataset distributed
as `di`:
```julia
using DistributedData

dstat(di, [1,2,3])
```

## Manual work with the DistributedData.jl package

We will first show how to use the general framework to compute per-cluster
statistics. DistributedData.jl exports the [`dmapreduce`](@ref) function that
can be used as a very effective basic building block for running such
computations. For example, you can efficiently compute a distributed mean of
all your data as such:
```julia
dmapreduce(di, sum, +) / dmapreduce(di, length, +)
```

The parameters of `dmapreduce` are, in order:

- `di`, the dataset
- `sum` or `length`, an unary "map" function -- during the computation, each
  piece of distributed data is first _paralelly_ processed by this function
- `+`, a binary "reduction" or "folding" function -- the pieces of information
  processed by the map function are successively joined in pairs using this
  function, until there is only a single result left. This final result is also
  what `dmapreduce` returns.

Above example thus reads: Sum all data on all workers, add up the intermediate
results, and divide the final number to the sum of all lengths of data on the
workers.

Column-wise mean (as produced by `dstat`) is slightly more useful; we only need
to split the computation on columns:

```julia
dmapreduce(di, d -> mapslices(sum, d, dims=1), +) ./ dmapreduce(di, x->size(x,1), +)
```

Finally, for distributed computation of per-cluster mean, the clustering
information needs to be distributed as well (Fortunately, that is easy, because
the distributed `mapToGigaSOM` does exactly that).

First, compute the clustering:
```julia
mapping = mapToGigaSOM(som, di)
dtransform(mapping, m -> metaClusters[m])
```

Now, the distributed computation is run on 2 scattered datasets. We employ a
helper function `mapbuckets` which provides bucket-wise execution of a
function, in a way very similar to `mapslices`. (In the example, we actually
use `catmapbuckets` that concatenates the result into a nice array.) The
following code produces a matrix of tuples `(sum, count)`, for separate
clusters (in rows) and data columns (in columns):

```julia
sumscounts = dmapreduce([di, mapping],
    (d, mapping) -> catmapbuckets(
        (_,clData) -> (sum(clData), length(clData)),
	d, 10, mapping),
    (a,b) -> (((as,al),(bs,bl)) -> ((as+bs), (al+bl))).(a,b))
```

```
10×4 Array{Tuple{Float64,Int64},2}:
 (5949.71, 1228)  (-21.9789, 1228)  (12231.3, 1228)  (12303.1, 1228)
 (6379.98, 1246)  (12464.3, 1246)   (12427.9, 1246)  (12479.8, 1246)
 (6513.41, 1294)  (12968.8, 1294)   (12960.7, 1294)  (-28.1922, 1294)
 (6312.37, 1236)  (-26.7392, 1236)  (6.74384, 1236)  (12401.7, 1236)
 (6395.73, 1285)  (12867.7, 1285)   (-52.653, 1285)  (-26.9795, 1285)
 (6229.72, 622)   (10.7578, 622)    (6200.1, 622)    (0.882128, 622)
 (6141.97, 612)   (6078.56, 612)    (45.9878, 612)   (6079.3, 612)
 (51.3709, 616)   (23.4306, 616)    (6117.53, 616)   (1.15342, 616)
 (6177.16, 1207)  (-50.4624, 1207)  (48.8023, 1207)  (-5.549, 1207)
 (8.56597, 654)   (6536.1, 654)     (-29.2208, 654)  (6539.94, 654)
```

With a bit of Julia, this can be aggregated to actual per-cluster means:
```julia
clusterMeans = [ sum/count for (sum,count) in sumcounts ]
```

```
10×4 Array{Float64,2}:
  4.84504    -0.0178982   9.96031     10.0188
  5.12037    10.0034      9.97428     10.0159
  5.03354    10.0223     10.016       -0.0217869
  5.10709    -0.0216336   0.00545618  10.0337
  4.97722    10.0138     -0.0409751   -0.0209958
 10.0156      0.0172955   9.968        0.00141821
 10.0359      9.93229     0.0751434    9.9335
  0.0833944   0.0380366   9.93105      0.00187243
  5.11778    -0.0418081   0.0404327   -0.00459735
  0.0130978   9.99403    -0.0446802    9.99991
```

Since we used the data from the hypercube dataset from the beginning of the
tutorial, you should be able to recognize several clusters that perfectly match
the hypercube vertices (although not all, because `k=10` is not enough to
capture all of the actual 16 existing clusters)

Finally, we can remove the temporary data from workers to create free memory for other analyses:
```julia
unscatter(mapping)
```

## Convenience statistical functions

Notably, several of the most used statistical functions are available in
DistributedData.jl in a form that can cope with distributed data.

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
 5.13971   1.02019   0.977637  1.00124
 5.13209   0.974332  1.00058   0.99874
 5.11529   0.998166  1.01825   1.01885
 5.10542   1.01686   0.975993  0.991992
 0.991075  0.993312  1.00667   1.05048
 0.996443  1.02699   0.938742  0.98831
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
  1.97831    -0.0120118    9.98967    10.0161
  7.99438    10.0263       9.9988     10.0033
  3.27907     9.98728     10.0254      0.00444198
  7.91739    -0.0623953   -0.0240277  10.0374
  2.445      10.0101      -0.0471141  -0.0253346
 10.0121      0.00935064   9.94992     0.0459787
 10.0512      9.93359      0.0923141   9.91175
  0.0675462  -0.0142712    9.93406     0.0343599
  8.09972    -0.0217352    0.0575258  -0.010485
 -0.0183372  10.0392      -0.115253   10.0101
```
