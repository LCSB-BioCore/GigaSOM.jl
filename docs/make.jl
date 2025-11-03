using Documenter, Literate, GigaSOM

tutorial_path = joinpath(@__DIR__, "src", "tutorials")

tutorials = sort(filter(x -> endswith(x, ".jl"), readdir(tutorial_path, join = true)))

for tutorial in tutorials
    Literate.markdown(
        tutorial,
        tutorial_path,
        repo_root_url = "https://github.com/LCSB-BioCore/GitaSOM.jl/blob/master",
    )
end

tutorial_mds = "tutorials/" .* first.(splitext.(basename.(tutorials))) .* ".md"

withenv("COLUMNS" => 150) do
    makedocs(
        modules = [GigaSOM],
        format = Documenter.HTML(
            ansicolor = true,
            canonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
            assets = ["assets/gigasomlogotransp.ico"],
            example_size_threshold = nothing,
            size_threshold_warn = 10 * 1024 * 1024,
            size_threshold = nothing,
        ),
        sitename = "GigaSOM.jl",
        pages = [
            "Home" => "index.md",
            "Background" => "background.md",
            "Tutorials" => [
                "Contents" => "tutorials.md"
                tutorial_mds
            ],
            "Further reading" => "nextsteps.md",
            "Reference" => "reference.md",
        ],
        warnonly = [:linkcheck, :cross_references, :missing_docs], #TODO fix
    )
end

deploydocs(
    repo = "github.com/LCSB-BioCore/GigaSOM.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
)
