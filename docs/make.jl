using Pkg
Pkg.activate("../")
push!(LOAD_PATH,"../")

using Documenter

makedocs(
    sitename="ACOS Goddard",
    remotes=nothing,
    pages = [
        "Main" => "index.md",
        "Important" => "important.md",
        "Known Issues" => "known_issues.md"
    ]
)

deploydocs(;
    repo = "github.com/PeterSomkuti/ACOS-Goddard.git",
    versions = ["stable" => "v^", "v#.#", "dev" => "main"],
    push_preview = false,
)