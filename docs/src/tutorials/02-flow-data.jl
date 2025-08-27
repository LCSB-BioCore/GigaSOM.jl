
# # Tutorial 2: Working with cytometry data
#
# You can load any FCS file using [`load_fcs`](@ref) function. For example, the
# Levine dataset ([obtainable here](https://flowrepository.org/id/FR-FCM-ZZPH))
# may be loaded as such:

using GigaSOM
import Downloads: download

isfile("Levine_13dim.fcs") || download(
    "https://github.com/lmweber/benchmark-data-Levine-13-dim/raw/refs/heads/master/data/Levine_13dim.fcs",
    "Levine_13dim.fcs",
)

params, data = load_fcs("Levine_13dim.fcs")

@test length(params)==111 #src
@test size(data)==(167044, 14) #src

# `params` will now contain the list of FCS parameters; you can parse a lot of
# interesting information from it using the [`fcs_column_metadata`](@ref)
# function:

fcs_column_metadata(params)

@test fcs_column_metadata(params).N[14] == "label" #src

# `data` is a matrix with cell expressions, one cell per row, one marker per
# column. If you want to run SOM analysis on it, you can cluster and visualize
# it just as in the previous tutorial, with one exception- we start with
# cutting off the `label` column that contains `NaN` values:

data = data[:, 1:13]
som = init(data, 16, 16, seed = 12345)
som = train(som, data)
clusters = assign(som, data)
e = embed(som, data)

# ... etc, you can save the results and plot them as needed.
#
# ## Working with distributed data
#
# Usual experiments produce multiple FCS files, and distributed or parallel
# processing is very helpful in crunching through all the data.
#
# To load multiple FCS files, use [`load_fcs_distributed`](@ref). This function
# works well in the "usual" single-process environment, but additionally it is
# designed to handle situations when the data is too big to fit into memory,
# and attempts to split them into available distributed workers workers.
#
# For the purpose of data distribution, you need to identify each dataset by an
# unique **dataset name** that will be used for identifying your loaded data in
# the cluster environment.  The dataset name is a simple Julia symbols;
# basically a variable name that is prefixed with a `:` colon.
#
# For example, we can load the Levine13 dataset as such:

datainfo = load_fcs_distributed(:levine, ["Levine_13dim.fcs"])

# Expectably, if you have more files, just write their names into the array and
# the function will handle the rest.
#
# The result `datainfo` carries informaton about your selected dataset name and
# its distribution among the cluster. It can be used just as the "data"
# parameter in all SOM-related functions again; e.g. as `train(som, datainfo)`.
#
# The following example exploits the possibility to actually split the data,
# and processes the Levine dataset parallelly on 2 workers:

using Distributed, DistributedData
addprocs(2)                 # add any number of CPUs/tasks/workers you have available
@everywhere using GigaSOM   # load GigaSOM also on the workers

datainfo = load_fcs_distributed(:levine, ["Levine_13dim.fcs"])

# We select only columns that contain expressions (in the dataset, column 14
# contains labels):
dselect(datainfo, Vector(1:13))

# Training may continue as usual:
som = init(datainfo, 20, 20)
som = train(som, datainfo)

# To prevent memory overload of the "master" computation node, the results of
# all per-cell operations are also stored in distributed "data info" objects.
# In this case, the following code does the embedding, but leaves the resulting
# data safely scattered among the cluster:
e = embed(som, datainfo)

# If you are sure you have enough RAM, you can collect the data to the master
# node. (In case of the relatively small Levine13 dataset, you very probably
# have the required 2.5MB of RAM, but there are many larger datasets.)
e = gather_array(e)

# ## Working with larger datasets
#
# In this example we will use a subset of the Cytometry data [by Bodenmiller et
# al.](https://doi.org/10.1038/nbt.2317). This dataset contains samples from
# peripheral blood mononuclear cells (PBMCs) in unstimulated and stimulated
# conditions for 8 healthy donors.
#
# 10 cell surface markers (lineage markers) are used to identify different cell
# populations. The dataset is described in two files:
#
# - `PBMC8_panel.xlsx` (with antigen names categorized as lineage markers and
#    functional markers)
# - `PBMC8_metadata.xlsx` (file names, sample IDs, condition IDs and patient
#    IDs)

### Download and prepare the dataset

# The example data can be downloaded from
# [imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/](http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/).
#
# You can fetch the files directly from within Julia:

dataFiles = ["PBMC8_metadata.xlsx", "PBMC8_panel.xlsx", "PBMC8_fcs_files.zip"]
for f in dataFiles
    if !isfile(f)
        download("http://imlspenticton.uzh.ch/robinson_lab/cytofWorkflow/"*f, f)
        if occursin(".zip", f)
            run(`unzip PBMC8_fcs_files.zip`)
        end
    end
end

# The metadata is present in external files; we read it into a `DataFrame` and
# extract information about FCS data columns from there. First, we read the
# actual content using the XLSX package:

import XLSX
using DataFrames
md = DataFrame(XLSX.readtable("PBMC8_metadata.xlsx", "Sheet1", infer_eltypes = true))
panel = DataFrame(XLSX.readtable("PBMC8_panel.xlsx", "Sheet1", infer_eltypes = true))

# After that, we can get the parameter structure from the first FCS files:
_, fcsParams = GigaSOM.read_fcs_header(md[1, :file_name])

# ...and continue with extracting marker names using the prepared functions:
_, fcsAntigens = GigaSOM.fcs_metadata_marker_names(fcs_column_metadata(fcsParams))

# Now, TO see which antigens we want to use (assume we want only the lineage
# markers):
antigens = panel[panel[:, :Lineage] .== 1, :Antigen]

# Finally, it is often useful to make the names a bit more Julia-friendly and
# predictable:
clean_names!(antigens)
clean_names!(fcsAntigens)

# ### Load and prepare the data
#
# Now we have the vector of `fcsAntigens` that the FCS files store, and list of
# `antigens` that we want to analyze. We continue by loading the data, reducing
# it to the desired antigens and transforming it a bit:
di = load_fcs_distributed(:pbmc8, md[:, :file_name])

# (If data distribution and parallelization is required, you must add parallel
# workers using `addprocs` **before** this step.)

# Now that the data is loaded, let's prepare them a bit by reducing to actual
# interesting columns, transformation and scaling. First, select only the
# columns that correspond to the lineage antigens we have prepared before:
dselect(di, fcsAntigens, antigens)
cols = Vector(eachindex(antigens)) # shortcut for "all rows"

# Perform `asinh` transformation on all data in the dataset, '5' here is the
# cofactor for the transformation:
dtransform_asinh(di, cols, 5)

# Normalize all dataset columns to zero mean and unit variance:
dscale(di, cols)

# ### Train a self-organizing map (SOM)
#
# With the data prepared, running the SOM algorithm is straightforward:
som = init(di, 16, 16, seed = 12345)
som = train(som, di, epochs = 20)

# Finally, we can calculate the clustering:
som_clusters = assign(som, di)

# ### FlowSOM-style metaclustering
#
# One disadvantage of SOMs is that they output a large amount of small clusters
# that are relatively hard to interpret manually. FlowSOM improved that
# situation by running a "clustering on clusters" (metaclustering) that address
# the problem.
#
# In this example, we reduce the original 256 small clusters from 16x16 SOM to
# only 10 "metaclusters", using the standard hierarchical clustering:

using Clustering
import Distances
metaClusters = cutree(
    k = 10,
    hclust(linkage = :average, GigaSOM.distance_matrix(Distances.Euclidean())(som.codes)),
)

# The `metaClusters` represent membership of the SOM codes in cluster; these
# can be expanded to membership of all cells using [`assign`](@ref):

mapping = gather_array(assign(som, di), free = true)
clusters = metaClusters[mapping]

# `clusters` now contain integers from `1` to `10` that classify each cell in
# the dataset.
#
# (The argument `free=true` of `gather_array` automatically removes the
# distributed data from workers after collecting, which saves their memory for
# other datasets.)
