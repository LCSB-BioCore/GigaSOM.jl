![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

*GigaSOM.jl - Huge-scale, high-performance flow cytometry clustering in Julia*
=========

With GigaSOM.jl, our novel contribution will be allowing the analysis of huge-scale clinical studies,
scaling down software limitations. In order to do so, we will implement the parallelization of the FlowSOM algorithm
using HPC and increase the maximum number of cells that can be processed simultaneously by the algorithm.

## Package Features

- Analysis and clustering of huge-scale flow cytometry data.
- HPC-ready to handle very large datasets.
- Supports Julia `1.0`.
- Load and transform `.fcs` data files accordingly.
- GigaSOM algorithm maps high-dimensional vectors into a lower-dimensional grid.
- Automatically determine the required number of cell populations using parallel computing.

Check the [Background](@ref) section for some insights on the theory behind our package

The [Tutorial](@ref) section provides a thorough guide explaining how to get started on GigaSOM.jl package.

See the [Functions](@ref) section for the complete list of documented functions and types.

## Contents

```@contents
Pages = ["index.md", "background.md", "tutorial.md", "functions.md"]
```
