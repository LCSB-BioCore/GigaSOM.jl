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
                "Home" => "index.md",
                "Tutorial" => "tutorials/tutorial.md",
                "API" => Any[
                        "Functions" => "api/functions.md"
                        ]
                ],
        )

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
    deps = nothing,
    make = nothing
    )
