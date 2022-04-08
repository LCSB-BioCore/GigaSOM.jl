
# Tutorial 2: Working with cytometry data

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
just as in the previous tutorial, with one exception- we start with cutting off
the `label` column that contains `NaN` values:

```

data = data[:,1:13]
som = initGigaSOM(data, 16, 16)
som = trainGigaSOM(som, data)
clusters = mapToGigaSOM(som, data)
e = embedGigaSOM(som, data)

# ... save/plot results, etc...
```

## Work with distributed data

Usual experiments produce multiple FCS files, and distributed or parallel
processing is very helpful in crunching through all the data.

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
e = gather_array(e)
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

## Working with larger datasets

In this example we will use a subset of the Cytometry data [by Bodenmiller et
al.](https://doi.org/10.1038/nbt.2317). This data-set contains samples
from peripheral blood mononuclear cells (PBMCs) in unstimulated and stimulated
conditions for 8 healthy donors.

10 cell surface markers (lineage markers) are used to identify different cell
populations. The dataset is described in two files:

- `PBMC8_panel.xlsx` (with antigen names categorized as lineage markers and functional markers)
- `PBMC8_metadata.xlsx` (file names, sample IDs, condition IDs and patient IDs)

### Download and prepare the dataset

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
using XLSX
md = GigaSOM.DataFrame(readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes=true)...)
panel = GigaSOM.DataFrame(readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes=true)...)
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

### Load and prepare the data

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

### Create a Self Organizing MAP (SOM)

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
mapping = gather_array(mapToGigaSOM(som, di), free=true)
clusters = metaClusters[mapping]
```

`clusters` now contain an integer from `1` to `10` with a classification of
each cell in the dataset.

(The argument `free=true` of `gather_array` automatically removes the
distributed data from workers after collecting, which saves their memory for
other datasets.)
