# How to contribute to/develop GigaSOM

If you want to contribute to the `GigaSOM` package, please fork the present
repository by following [these instructions](https://help.github.com/en/articles/fork-a-repo).

## Step 1: Retrieve a local version of GigaSOM

There are two ways that you can retrieve a local copy of the package: one is to
manually clone the forked repository, and the second one is to use the
intergrated Julia package manager.

### Option 1: Manually clone your fork

:warning: Please make sure to have forked the repository as described above.

You can do this as follows from the command line:

```bash
$ git clone git@github.com:yourUsername/GigaSOM.jl.git GigaSOM.jl
$ cd GigaSOM.jl
$ git checkout -b yourNewBranch origin/develop
```

where `yourUsername` is your Github username and `yourNewBranch` is the name of a new branch.

Then, in order to develop the package, you can install your cloned version as
follows (make sure you are in the `GigaSOM.jl` directory):

```julia
(v1.1) pkg> add .
```

This adds the `GigaSOM.jl` package and all its dependencies. You can verify
that the installation worked by typing:

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

When you are used to using the Julia package manager for developing or
contributing to packages, you can type:

```julia
(v1.1) pkg> dev GigaSOM
```

This will install the `GigaSOM` package locally and check it out for
development. You can check the location of the package with:

```julia
(v1.1) pkg> status
    Status `~/.julia/environments/v1.1/Project.toml`
  [a03a9c34] GigaSOM v0.0.5 [`~/.julia/dev/GigaSOM`]
```

The default location of the package is `~/.julia/dev/GigaSOM`.

You can then set your remote by executing these commands in a regular shell:

```bash
$ cd ~/.julia/dev/GigaSOM
$ git remote rename origin upstream # renames the origin as upstream
$ git remote add origin git@github.com:yourUsername/GigaSOM.jl.git
$ git fetch origin
```

where `yourUsername` is your Github username.

:warning: Please make sure that your fork exists under `github.com/yourUsername/GigaSOM.jl`.

Then, checkout a branch `yourNewBranch`:

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

:warning: Please note that you cannot use the dependencies of GigaSOM directly,
unless they are installed separately or the environment has been activated:

```julia
(v1.1) pkg> activate .
(GigaSOM) pkg> instantiate
```

Now, the environment is activated (you can see it with the prompt change
`(GigaSOM) pkg>`). Now, you can use the dependency. For instance:

```julia
julia> using DataFrames
```

:warning: If you do not  `activate` the environment before using any of the dependencies, you will see a red error messages prompting you to install the dependency explicity.
