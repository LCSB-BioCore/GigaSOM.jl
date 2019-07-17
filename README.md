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

```julia
(v1.1) pkg> test GigaSOM
```

:warning: It is not advised to run indivual test files separately without expliciting activating the environment and loading the dependencies.
If this is required for debugging purposes, please activate the environment first and run the commands of the `test/runtests.jl` file sequentially.


## How to contribute

If you want to contribute to the `GigaSOM` package, please fork the present repository and create a new branch from the `develop` branch.
There are 2 ways that you can develop the package:

### Way 1: clone and activate

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

Now, you can readily start using the `GigaSOM` module.

:warning: Please note that you cannot use the dependencies of GigaSOM directly, unless they are installed separately or the environment has been activated:

```julia
(v1.1) pkg> activate .
```

Now, the environment is activated (you can see it with the prompt change `(GigaSOM) pkg>`). Now, you can use the dependency. For instance:

```julia
julia> using DataFrames
```

:warning: If you do not  `activate` the environment before using any of the dependencies, you will see a red error messages prompting you to install the dependency explicity.

### Way 2: Use the Julia package manager