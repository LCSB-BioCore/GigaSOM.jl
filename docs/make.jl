using Documenter, GigaSOM

makedocs(modules = [GigaSOM],
         clean = false,
         format = :html,
         assets = ["assets/icongigasom.ico"],
         sitename = "GigaSOM.jl",
         authors = "The developers of GigaSOM.jl",
         pages = [
                "Introduction" => "index.md",
                "Tutorial" => "tutorials/tutorial.md",
                "API" => Any[
                        "IO" => "api/io.md",
                        "Types" => "api/types.md",
                        "Batch/Parallel SOM" => "api/soms.md",
                        "Visualisation" => "api/visualisation.md"
                        ],
                "License" => "LICENSE.md"
                ],
        html_cannonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
        )

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    julia = "1.1.0",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
)
