using Documenter, GigaSOM

makedocs(modules = [GigaSOM],
        clean = false,
        format = Documenter.HTML(prettyurls = !("local" in ARGS),
                canonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
                assets = ["assets/icongigasom.ico"]),
        sitename = "GigaSOM.jl",
        authors = "The developers of GigaSOM.jl",
        linkcheck = !("skiplinks" in ARGS),
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
        )

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    julia = "1.1.0",
    osname = "linux",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
    deps = nothing,
    make = nothing
    )
