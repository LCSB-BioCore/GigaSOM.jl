using Documenter, GigaSOM

makedocs(
    modules = [GigaSOM],
    format = Documenter.HTML(
        ansicolor = true,
        canonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
        assets = ["assets/gigasomlogotransp.ico"],
    ),
    sitename = "GigaSOM.jl",
    linkcheck = false,
    pages = [
        "Home" => "index.md",
        "Background" => "background.md",
        "Tutorial" => [
            "Introduction" => "tutorials/basicUsage.md",
            "Cytometry data" => "tutorials/processingFCSData.md",
            "Advanced distributed processing" => "tutorials/distributedProcessing.md",
            "Conclusion" => "tutorials/whereToGoNext.md",
        ],
        "Reference" => "reference.md",
    ],
)

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
)
