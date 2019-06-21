using Documenter, GigaSOM

makedocs(modules = [GigaSOM],
        clean = false,
        format = Documenter.HTML(prettyurls = !("local" in ARGS),
                canonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
                assets = ["assets/gigasomlogotransp.ico"]),
        sitename = "GigaSOM.jl",
        authors = "The developers of GigaSOM.jl",
        linkcheck = !("skiplinks" in ARGS),
        pages = [
                "Home" => "index.md",
                "Background" => "background.md",
                "Tutorial" => "tutorial.md",
                "Functions" => "functions.md"
                ],
        )

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
    )
