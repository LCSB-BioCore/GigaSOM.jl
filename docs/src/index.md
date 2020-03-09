![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

# GigaSOM.jl - Huge-scale, high-performance flow cytometry clustering in Julia


GigaSOM.jl allows painless analysis of huge-scale clinical studies, scaling down the software limitations that usually prevent work with large datasets. It can be viewed as a work-alike of FlowSOM, suitable for loading billions of cells and running the analyses in parallel on distributed computer clusters, to gain speed. Most importantly, GigaSOM.jl scales horizontally -- data volume limitations and memory limitations can be solved just by adding more computers to the cluster. That makes it extremely easy to exploit HPC environments, which are becoming increasingly common in computational biology.

## Features

- Horizontal scalability to literal giga-scale datasets (10^9 cells!)
- HPC-ready, support for e.g. Slurm
- Standard support for distributed loading, scaling and transforming the FCS3 files
- Batch-SOM based GigaSOM algorithm for clustering
- EmbedSOM for visualizations

Check the [Background](@ref) section for some insights on the theory behind the package

See the [Functions](@ref) section for the complete list of documented functions and types.

## Contents

```@contents
Pages = [
  "index.md",
  "background.md",
  "basicUsage.md",
  "processingFCSData.md",
  "distributedProcessing.md",
  "whereToGoNext.md",
  "functions.md",
  "howToContribute.md"]
```
