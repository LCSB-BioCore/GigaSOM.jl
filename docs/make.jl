using Documenter

makedocs(modules = [Documenter],
         sitename="GigaSOM.jl")

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
)
