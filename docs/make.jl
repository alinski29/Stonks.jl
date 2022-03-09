push!(LOAD_PATH,"../src/")

using Documenter
using Stonks

DocMeta.setdocmeta!(Stonks, :DocTestSetup, :(using Stonks); recursive=true)

makedocs(
    sitename = "Stonks.jl",
    format = Documenter.HTML(
      prettyurls = false,
    ),
    modules = [Stonks],
    pages = [
      "Home" => "index.md",
      "User guide" => [
        "basic_usage.md"
        "advanced_usage.md"
      ],
      "API" => [
        "Types" => "api_types.md"
        "Functions" => "api_functions.md"
      ],
      "Contributing" => "contributing.md",
    ],
)

deploydocs(
    repo = "github.com/alinski29/Stonks.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
    devbranch = "main"
)