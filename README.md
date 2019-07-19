![GigaSOM.jl](https://prince.lcsb.uni.lu/GigaSOM.jl/img/logo-GigaSOM.jl.png?maxAge=0)

# GigaSOM.jl <br> Huge-scale, high-performance flow cytometry clustering


| **Coverage** | **[ARTENOLIS](http://opencobra.github.io/artenolis)** |
|:------------:|:--------------------------:|
| [![coverage status](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl/coverage.svg?branch=master)](http://codecov.io/github/LCSB-BioCore/GigaSOM.jl?branch=master) | [![linux](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/badge/icon)](https://prince.lcsb.uni.lu/jenkins/job/GigaSOM.jl-branches-auto-linux/) |

# How to get started

## Prerequisites

- Use Linux (Debian and centOS), macOS X, or Windows 10 as your operating system. `GigaSOM` has been tested on these systems.
- In order to use `GigaSOM`, you need to install Julia 1.0 or higher. You can find the download and installation instructions for Julia [here](https://julialang.org/downloads/).

Once `julia` has been installed, follow [these instructions](https://docs.julialang.org/en/v1/manual/getting-started/) to get started.

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

:warning: It is not advised to run indivual test files separately without expliciting activating the environment and loading the dependencies.
If this is required for debugging purposes, please activate the environment first and run the commands of the `test/runtests.jl` file sequentially.


# How to contribute to/develop GigaSOM

If you want to contribute to the `GigaSOM` package, please fork the present repository. Instructions how to this can be found [here](https://help.github.com/en/articles/fork-a-repo).

## Step 1: Retrieve a local version of GigaSOM

There are 2 ways that you can retrieve a local copy of the package: one is to manually clone the forked repository, and the second one is to use the intergrated Julia package manager.

### Option 1: Manually clone the fork

You can do this as follows from the command line:

```bash
$ git clone git@github.com:yourUsername/GigaSOM.jl.git GigaSOM.jl
$ cd GigaSOM.jl
$ git checkout -b yourNewBranch origin/develop
```

where `yourUsername` is your Github username and `yourNewBranch` is the name of a new branch.

Then, in order to develop the package, you can install your cloned version as follows (make sure you are in the `GigaSOM.jl` directory):

```julia
(v1.1) pkg> add .
```

This adds the `GigaSOM.jl` package and all its dependencies. You can verify that the installation worked by typing:

```julia
(v1.1) pkg> status
```

If everything went smoothly, this should print something similar to:

```julia
(v1.1) pkg> status
    Status `~/.julia/environments/v1.1/Project.toml`
  [a03a9c34] GigaSOM v0.0.5 #yourNewBranch (.)
```

Now, you can readily start using the `GigaSOM` module:

```julia
julia> using GigaSOM
```

### Option 2: Use the Julia package manager

When you are used to using the  Julia package manager for developing or contributing to packages, you can type:

```julia
(v1.1) pkg> dev GigaSOM
```

This will install the `GigaSOM` package locally and check it out for development. You can check the location of the package with:

```julia
(v1.1) pkg> status
    Status `~/.julia/environments/v1.1/Project.toml`
  [a03a9c34] GigaSOM v0.0.5 [`~/.julia/dev/GigaSOM`]
```

The default location of the package is `~/.julia/dev/GigaSOM`.

You can then set your remote by:

```bash
$ cd ~/.julia/dev/GigaSOM
$ git remote rename origin upstream # renames the origin as upstream
$ git remote add origin git@github.com:yourUsername/GigaSOM.jl.git
```

where `yourUsername` is your Github username. Then, checkout a branch `yourNewBranch`:

```bash
$ cd ~/.julia/dev/GigaSOM
$ git checkout -b yourNewBranch origin/develop
```

Then, you can readily use the `GigaSOM` package:

```julia
julia> using GigaSOM
```

After making changes, precompile the package:

```julia
(v1.1) pkg> precompile
```

## Step 2: Activate GigaSOM

:warning: Please note that you cannot use the dependencies of GigaSOM directly, unless they are installed separately or the environment has been activated:

```julia
(v1.1) pkg> activate .
(GigaSOM) pkg> instantiate
```

Now, the environment is activated (you can see it with the prompt change `(GigaSOM) pkg>`). Now, you can use the dependency. For instance:

```julia
julia> using DataFrames
```

:warning: If you do not  `activate` the environment before using any of the dependencies, you will see a red error messages prompting you to install the dependency explicity.
