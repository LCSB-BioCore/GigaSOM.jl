![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

# GigaSOM.jl <br> Huge-scale, high-performance flow cytometry clustering


| **Coverage** | **[ARTENOLIS](http://opencobra.github.io/artenolis)** |
|:------------:|:--------------------------:|
| [![coverage status](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl/coverage.svg?branch=master)](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl?branch=master) | [![linux](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/badge/icon)](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/) |

# How to get started

## Prerequisites

- Use Linux (Debian and centOS), macOS X, or Windows 10 as your operating system. `GigaSOM` has been tested on these systems.
- In order to use `GigaSOM`, you need to install Julia 1.0 or higher. You can find the download and installation instructions for Julia [here](https://julialang.org/downloads/).

Once `julia` has been installed, follow [these
instructions](https://docs.julialang.org/en/v1/manual/getting-started/) to get
started.

:bulb: If you are a complete beginner with Julia, it is advised that you familiarize youself
with the [full documentation](https://docs.julialang.org). You should also have a
closer look at the [Julia package manager](https://julialang.github.io/Pkg.jl/v1/getting-started/).

## Installation

At the Julia prompt, add the `GigaSOM` package:

```julia
julia> import Pkg; Pkg.add("GigaSOM");
```

Use the `GigaSOM` module by running:

```julia
julia> using GigaSOM
```

## Test the installation

`GigaSOM` has been tested on Linux (Ubuntu and centOS), macOS, and Windows.

You may test the package as follows:

```julia
julia> import Pkg; Pkg.test("GigaSOM");
```

Alternatively, you can use the package manager by hitting `]`:

```julia
(v1.1) pkg> test GigaSOM
```

:warning: It is not advised to run indivual test files separately without
expliciting activating the environment and loading the dependencies.  If this
is required for debugging purposes, please activate the environment first and
run the commands of the `test/runtests.jl` file sequentially.
