using Documenter, Literate, GigaSOM

examples = sort(
    filter(
        x -> endswith(x, ".jl"),
        readdir(joinpath(@__DIR__, "src", "tutorials"), join = true),
    ),
)

for example in examples
    Literate.markdown(
        example,
        joinpath(@__DIR__, "src"),
        repo_root_url = "https://github.com/LCSB-BioCore/GitaSOM.jl/blob/master",
    )
end

example_mds = first.(splitext.(basename.(examples))) .* ".md"

withenv("COLUMNS" => 150) do
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
            "Tutorials" => example_mds,
            "Tutorial (old)" => [
                "Introduction" => "tutorials-old/basicUsage.md",
                "Cytometry data" => "tutorials-old/processingFCSData.md",
                "Advanced distributed processing" => "tutorials-old/distributedProcessing.md",
                "Conclusion" => "tutorials-old/whereToGoNext.md",
            ],
            "Reference" => "reference.md",
        ],
    )
end

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
)
