![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

GigaSOM.jl - Huge-scale, high-performance flow cytometry clustering in Julia
=========

# Introduction

Flow cytometry clustering for several hundred million cells has long been hampered by software implementations.
Julia allows us to go beyond these limits. Through the high-performance GigaSOM.jl package, we gear up for
huge-scale flow cytometry analysis, softening these limitations with an innovative approach on the existing algorithm
by implementing parallel computing with stable and robust mathematical models that would run with an HPC cluster,
allowing us to run cytometry datasets as big as 500 million cells.

## Immunology

Immunology is a very important branch of the medical and biological sciences that focuses,
as the name suggests, on the study of the immune system.
The immune system is a complex system of structures and processes that protect us from disease and infection
and is composed by molecular and cellular components that can be organised in two different groups,
according to their function: innate and adaptive immunity.
Innate immunity is the non-specific first line of defence, which basically means that the response is the same,
regardless of the potential pathogen. Adaptive immunity is the second line of defence with a specific response
to the pathogen due to the memory of previously encountered infections.
Advances in immunology research are very important because Immunology has changed the face of modern medicine,
and its understanding is essential for clinical applications to facilitate the discovery of new diagnostics and treatments
for many different diseases, for example to allow a better management of allergies, one of the most common immune dysfunctions.
Allergies are hypersensitivity disorders that occur when the body’s immune system reacts unnecessarily against harmless substances (allergens),
like pollens, insect venom or food, and can be either immunoglobulin-E (IgE) mediated or non-IgE mediated.
In addition, immunological research has provided critically important research techniques and tools, such as flow cytometry.

## Flow Cytometry

The use of flow cytometry has grown substantially in the past decade, mainly due to the development of smaller,
user-friendly and less expensive instruments, but also to the increase of clinical applications, like cell counting,
cell sorting, detection of biomarkers or protein engineering.
Flow cytometry is an immunophenotyping technique used to identify and quantify the cells of the immune system
by analysing their physical and chemical characteristics in a fluid. These cells are stained with specific,
fluorescently labelled antibodies and then analysed with a flow cytometer, where the fluorescence intensity is measured using lasers and photodetectors.[1]
More recently, a variation of flow cytometry called mass cytometry (CyTOF) was introduced, in which antibodies
are labelled with heavy metal ion tags rather than fluorochromes, breaking the limit of multiplexing capability
of FACS (fluorescence-activated cell sorting) and allowing the simultaneous quantification of 40+ protein parameters within each single cell.[2]
The ability of flow cytometry and mass cytometry to analyse individual cells at high-throughput scales makes them ideal for multi-parameter cell analysis and high-speed sorting.

## Self-organising maps

Self-organising maps (also referred to as SOMs or *Kohonen* maps) are
artificial neural networks introduced by Teuvo Kohonen in the 1980s.
Despite of their age, SOMs are still widely used as an easy and robust
unsupervised learning technique
for analysis and visualisation of high-dimensional data.
The SOM algorithm maps high-dimensional vectors into a lower-dimensional grid. Most often
the target grid is two-dimensional, resulting into  intuitively interpretable maps.
After initializing a SOM grid of size n*n, each node is initialized with a random sample (row)
from the dataset (training data). For each input vector (row) in the training data the distance
to each node in the grid is calculated, using Chebyshev distance or Euclidean distance equations,
where the closest node is called BMU (best matching unit). The row is subsequently assigned to the
BMU making it move closer to the input data, influenced by the learning rate and neighborhood Gaussian
function, whilst the neighborhood nodes are also adjusted closer to the BMU. This training step is
repeated for each  row in the complete dataset. After each iteration (epoch) the radius of the
neighborhood function is reduced. After n epochs, clusters of nodes should have formed and as a
final step, consensus cluster is used to reduce the data (SOM nodes) into m clusters. [9]

## GigaSOM.jl Package

With GigaSOM.jl, our novel contribution to this workflow will be allowing the analysis of huge-scale clinical studies,
scaling down software limitations. In order to do so, we will implement the parallelization of the FlowSOM algorithm
using HPC and increase the maximum number of cells that can be processed simultaneously by the algorithm.

## Installation

For installation please refer to the README @github:
<https://github.com/LCSB-BioCore/GigaSOM.jl>


## API

```@contents
```

## Index

```@index
```
