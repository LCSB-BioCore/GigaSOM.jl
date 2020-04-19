![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

# GigaSOM.jl - Huge-scale, high-performance flow cytometry clustering in Julia


GigaSOM.jl allows painless analysis of huge-scale clinical studies, scaling down the software limitations that usually prevent work with large datasets. It can be viewed as a work-alike of FlowSOM, suitable for loading billions of cells and running the analyses in parallel on distributed computer clusters, to gain speed. Most importantly, GigaSOM.jl scales horizontally -- data volume limitations and memory limitations can be solved just by adding more computers to the cluster. That makes it extremely easy to exploit HPC environments, which are becoming increasingly common in computational biology.

```@raw html
<style type="text/css">
.evo {
    width: 250px;
    margin: 1em;
    border-radius: 50%;
    -webkit-border-radius: 50%;
    -moz-border-radius: 50%;
}
</style>
<div align="center">
    <img class="evo" src="https://prince.lcsb.uni.lu/GigaSOM.jl/img/evolution.gif">
    <br/>
    <b>Evolution of the GigaSOM.jl repository (2019-2020)</b>
</div>
```

### Features

- Horizontal scalability to literal giga-scale datasets (``10^9`` cells!)
- HPC-ready, support for e.g. Slurm
- Standard support for distributed loading, scaling and transforming the FCS3 files
- Batch-SOM based GigaSOM algorithm for clustering
- EmbedSOM for visualizations

### Background

You can learn more about the background of GigaSOM.jl in these sections:

```@contents
Pages = ["background.md"]
```

### How to get started?

You can follow our extensive tutorials here:

```@contents
Pages = ["tutorials/basicUsage.md",
        "tutorials/processingFCSData.md",
        "tutorials/distributedProcessing.md",
        "tutorials/whereToGoNext.md"
]
```

### Functions

A full reference to all functions is given here:

```@contents
Pages = ["functions.md"]
```

### How to contribute?

If you want to contribute, please read these guidelines first:

```@contents
Pages = ["howToContribute.md"]
```