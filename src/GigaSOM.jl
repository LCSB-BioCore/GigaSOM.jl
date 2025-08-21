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

end # module
