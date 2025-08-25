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

tutorial_mds = first.(splitext.(basename.(examples))) .* ".md"

withenv("COLUMNS" => 150) do
    makedocs(
        modules = [GigaSOM],
        format = Documenter.HTML(
            ansicolor = true,
            canonical = "https://lcsb-biocore.github.io/GigaSOM.jl/stable/",
            assets = ["assets/gigasomlogotransp.ico"],
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
