![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

GigaSOM.jl - Huge-scale, high-performance flow cytometry clustering in Julia
=========



# Introduction

Flow cytometry clustering for several hundred million cells has long been hampered by software implementations.
Julia allows us to go beyond these limits. Through the high-performance GigaSOM.jl package, we gear up for huge-scale flow cytometry analysis.

Recent advances in single-cell technologies offer an unprecedented opportunity to comprehensively characterize the immune system, revealing a previously unparalleled complexity in the phenotype and function of immune cells. Mass cytometry, also known as CyTOF, was recently implemented to measure up to 40 different markers in several million single cells. A typical clinical study with hundreds of patients can therefore include billions of single cells (rows) and up to 40 markers (features).
Different dimension reduction methods have been implemented in commercial and open-source software, mainly written in R. The machine learning algorithm FlowSOM [1] is based on the famous Kohonen Self Organising Feature Maps (SOM) [2] and has shown various advantages over other methods.
However, all current implementations have a critical limitation on the total number of cells to be analyzed . This limitation often blocks the analysis of large-scale clinical studies with several hundred million cells.
Here, we present the open-source, high-level, and high-performance package GigaSOM.jl <https://github.com/LCSB-BioCore/GigaSOM.jl>, which is HPC-ready and is written to handle very large datasets without limits. Julia is the natural language of choice when it comes to performing huge-scale cytometric analyses. With the GigaSOM.jl package, the possibilities for flow cytometry analysis  are further broadened. The quality of the software package is assured using ARTENOLIS <https://artenolis.lcsb.uni.lu> [3]. Biological validation of the results will be performed on downsampled datasets by comparison to conventional implementations of the FlowSOM package and manual hierarchical analysis.

## Self-organising maps

Self-organising maps (also referred to as SOMs or *Kohonen* maps) are
artificial neural networks introduced by Teuvo Kohonen in the 1980s.
Despite of their age, SOMs are still widely used as an easy and robust
unsupervised learning technique
for analysis and visualisation of high-dimensional data.

The SOM algorithm maps high-dimensional vectors into a lower-dimensional grid. Most often
the target grid is two-dimensional, resulting into  intuitively interpretable maps.



## Installation

For installation please refer to the README @github:
<https://github.com/LCSB-BioCore/GigaSOM.jl>


## Tutorial

```@contents
Pages = ["tutorials/tutorial.md"]
```

## API

```@contents
Pages = ["api/io.md", "api/types.md", "api/soms.md", "api/visualisation.md"]
```

## Index

```@index
```
