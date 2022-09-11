using MolecularEvolution
using Documenter
using Phylo
using Plots
using FASTX

DocMeta.setdocmeta!(
    MolecularEvolution,
    :DocTestSetup,
    :(using MolecularEvolution);
    recursive = true,
)

makedocs(;
    modules = [MolecularEvolution],
    authors = "Ben Murrell <benjamin.murrell@ki.se> and contributors",
    repo = "https://github.com/MurrellGroup/MolecularEvolution.jl/blob/{commit}{path}#{line}",
    sitename = "MolecularEvolution.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://MurrellGroup.github.io/MolecularEvolution.jl",
        edit_link = "main",
        assets = ["assets/favicon.ico"],
    ),
    pages = [
        "Home" => "index.md",
        "framework.md",
        "examples.md",
        "IO.md",
        "models.md",
        "simulation.md",
        "optimization.md",
        "ancestors.md",
        "viz.md",
    ],
)

deploydocs(; repo = "github.com/MurrellGroup/MolecularEvolution.jl", devbranch = "main")
