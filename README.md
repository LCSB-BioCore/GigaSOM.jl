![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

# GigaSOM.jl <br> Huge-scale, high-performance flow cytometry clustering


| **Coverage** | **[ARTENOLIS](http://opencobra.github.io/artenolis)** |
|:------------:|:--------------------------:|
| [![coverage status](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl/coverage.svg?branch=master)](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl?branch=master) | [![linux](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/badge/icon)](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/) |

# How to get started

## Installation

At the Julia prompt, add the `GigaSOM` package:

```julia
julia> import Pkg; Pkg.add("GigaSOM");
```

Use the `GigaSOM` module by running:

```julia
julia> using GigaSOM
```

## Testing

`GigaSOM` has been tested on Linux (Ubuntu and centOS), macOS, and Windows.

You may test the package as follows:

```julia
julia> import Pkg; Pkg.test("GigaSOM");
```

Alternatively, you can use the package manager by hitting `]`:

```
(v1.1) pkg> test GigaSOM
```

## How to contribute

If you want to contribute to the `GigaSOM` package, please fork the present repository and create a new branch from the `develop` branch.

Then, in order to develop the package locally and test it,
