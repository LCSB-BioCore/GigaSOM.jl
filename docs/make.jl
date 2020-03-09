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
                "Tutorial 1: Intro" => "basicUsage.md",
                "Tutorial 2: Cytometry data" => "processingFCSData.md",
                "Tutorial 3: Advanced distributed processing" => "distributedProcessing.md",
                "Tutorial conclusion" => "whereToGoNext.md",
                "Functions" => "functions.md",
                "How to contribute" => "howToContribute.md",
                ],
        )

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "origin/develop",
    versions = "stable" => "v^",
    )
