"""
    module GigaSOM

GigaSOM.jl allows painless analysis of huge-scale flow-cytometry datasets, such
as from large clinical studies. It can be viewed as a work-alike of FlowSOM
package (for R), suitable for loading billions of cells and running the
analyses in parallel on distributed computer clusters, in order to gain speed.

Most importantly, GigaSOM.jl scales horizontally -- data volume limitations and
memory limitations can be solved just by adding more computers to the cluster.
That makes it extremely easy to exploit HPC environments, which are becoming
increasingly common in computational biology.

### Features

- Horizontal scalability to literal giga-scale datasets (``10^9`` cells!)
- HPC-ready, with support for e.g. Slurm
- Standard support for distributed loading, scaling and transforming the FCS3 files
- Batch-SOM based GigaSOM algorithm for clustering
- EmbedSOM for visualizations

"""
module GigaSOM

using DocStringExtensions

using CSV
using DataFrames
using Distances
using Distributed
using DistributedData
using Distributions
using FCSFiles
using FileIO
using NearestNeighbors
using Serialization
using StableRNGs

include("structs.jl")

include("som.jl")
include("som_utils.jl")
include("embed.jl")

include("load.jl")
include("split.jl")
include("data_utils.jl")


#core
export init, train, assign

#trainutils
export radius_linear, radius_exp, kernel_gaussian, kernel_bubble, kernel_threshold, distance_matrix

#embedding
export embed

# structs
export SOM

#io/input
export load_fcs,
    load_fcs_header,
    read_fcs_size,
    read_fcs_sizes,
    load_fcs_distributed,
    select_fcs_columns,
    fcs_filevector_distribute,
    filevector_distribute,
    read_csv_size,
    load_csv,
    read_csv_sizes,
    load_csv_distributed

#io/splitting
export slicesof, vcollect_slice, collect_slice

#io/process
export clean_names!, fcs_column_metadata, fcs_metadata_marker_names

#dataops (higher-level operations on data)
export dtransform_asinh

end # module
