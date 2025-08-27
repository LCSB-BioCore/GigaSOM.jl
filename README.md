
<div align="center">
    <img src="docs/src/assets/logo.svg?maxAge=0" width="20%">
</div>

# GigaSOM.jl: Huge-scale, high-performance flow cytometry clustering

[docs-img-stable]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-url-stable]: https://lcsb-biocore.github.io/GigaSOM.jl
[docs-img-dev]: https://img.shields.io/badge/docs-latest-0af.svg
[docs-url-dev]: https://lcsb-biocore.github.io/GigaSOM.jl/dev/
[docs-img-tutorials]: https://img.shields.io/badge/docs-tutorial-0dd.svg
[docs-url-tutorials]: https://lcsb-biocore.github.io/GigaSOM.jl/stable/tutorials/

[ci-img]: https://github.com/LCSB-BioCore/GigaSOM.jl/actions/workflows/ci.yml/badge.svg?branch=master
[ci-url]: https://github.com/LCSB-BioCore/GigaSOM.jl/actions/workflows/ci.yml

[cov-img]: https://codecov.io/gh/LCSB-BioCore/GigaSOM.jl/branch/master/graph/badge.svg?token=H3WSWOBD7L
[cov-url]: https://codecov.io/gh/LCSB-BioCore/GigaSOM.jl

[rrid-img]: https://img.shields.io/badge/RRID-SCR__019020-72c02c
[rrid-url]: https://scicrunch.org/resolver/RRID:SCR_019020

| **Documentation** | **Test Coverage** | **CI** | **SciCrunch RRID** |
|:-----------------:|:-----------------:|:-----------------------------------------------------:|:--------:|
| [![stable documentation][docs-img-stable]][docs-url-stable] [![dev documentation][docs-img-dev]][docs-url-dev]  [![tutorials][docs-img-tutorials]][docs-url-tutorials] | [![coverage status][cov-img]][cov-url] | [![CI status][ci-img]][ci-url] | [![rrid][rrid-img]][rrid-url] |

GigaSOM is a Julia toolkit for clustering and visualisation of really large datasets from flow cytometry. In overview, it can load FCS files, perform transformation and cleaning operations in their contents, run FlowSOM-style clustering, and visualize and export the results. GigaSOM is distributed and parallel in nature, which makes processing of huge datasets a breeze -- a few hundred of millions of cells with a few dozen parameters may be clustered and visualized in minutes.

If you use GigaSOM.jl and want to refer to it in your work, use the following citation format (also available as BibTeX in [gigasom.bib](gigasom.bib)):

> Miroslav Kratochvíl, Oliver Hunewald, Laurent Heirendt, Vasco Verissimo, Jiří Vondrášek, Venkata P Satagopam, Reinhard Schneider, Christophe Trefois, Markus Ollert. *GigaSOM.jl: High-performance clustering and visualization of huge cytometry datasets.* GigaScience, Volume 9, Issue 11, November 2020, giaa127, https://doi.org/10.1093/gigascience/giaa127

# How to get started

As a major prerequisite, you will need to be able to run [Julia](https://julialang.org/). The environment is quite similar to other languages (R, Python, Matlab) and it is usually quite easy to start by following the [official user guide]().

## Installation

To install Julia, you can [download it from the official website](https://julialang.org/downloads/) or use your system's package manager to install one. Aim for using Julia version at least 1.6.

To install GigaSOM.jl, start Julia and type:
```julia
import Pkg; Pkg.add("GigaSOM");
```

After the installation finishes, you should be able to load GigaSOM package using:
```julia
using GigaSOM
```

The first loading of the GigaSOM package may take some time (a few minutes) to complete due to precompilation of the sources, especially if your Julia installation is new.

### Test the installation

If you run a non-standard platform (e.g. a customized operating systems), or if you added any modifications to GigaSOM source code, you may want to run the test suite to ensure that everything works as expected:

```julia
import Pkg; Pkg.test("GigaSOM");
```

For debugging, it is sometimes very useful to enable the `@debug` messages from the source, as such:
```julia
using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))
```

## How to use GigaSOM

A comprehensive documentation is [available online](https://lcsb-biocore.github.io/GigaSOM.jl/); several [introductory tutorials](https://lcsb-biocore.github.io/GigaSOM.jl/latest/tutorials/) of increasing complexity are also included.

A very basic dataset (Levine13 from [FR-FCM-ZZPH](https://flowrepository.org/id/FR-FCM-ZZPH)) can be loaded, clustered and visualized as such:

```julia
using GigaSOM

params, fcsmatrix = loadFCS("Levine_13dim.fcs")  # load the FCS file

exprs = fcsmatrix[:,1:13]  # extract only the data columns with expression values

som = initGigaSOM(exprs, 20, 20)    # random initialization of the SOM codebook
som = trainGigaSOM(som, exprs)      # SOM training
clusters = mapToGigaSOM(som, exprs) # extraction of per-cell cluster IDs
e = embedGigaSOM(som, exprs)        # EmbedSOM projection to 2D
```

The example loads the data, runs the SOM training (as in FlowSOM) and computes a 2D projection of the dataset (using EmbedSOM); the total computation time (excluding the possible precompilation of the libraries) should be around 15 seconds.

The results can be visualized e.g. with [GigaScatter](https://github.com/LCSB-BioCore/GigaScatter.jl#usage-with-gigasomjl) which we developed for this purpose, or by exporting the data and plotting them with any other programming language. For example, to save an embedding with highlighted expression of CD4, you can install and use GigaScatter as such:

```julia
import Pkg; Pkg.add("GigaScatter")
using GigaScatter

savePNG("Levine13-CD4.png",
  solidBackground(rasterize((500,500),        # bitmap size
    Matrix{Float64}(e'),                      # the embedding coordinates
    expressionColors(
      scaleNorm(Array{Float64}(exprs[:,5])),  # 5th column contains CD4 expressions
      expressionPalette(100, alpha=0.5)))))   # colors for plotting (based on RdYlBu)
```

The output may look like this (blue is negative expresison, red is positive):

![Levine13 embedding with CD4 highlighted](docs/src/assets/Levine13-CD4.png "Levine13/CD4")
