using Stonx
using DataFrames, Pkg

function dataframe_dependencies()
  pkgs = map(x -> x.name, values(Pkg.dependencies()))
  if !("DataFrames" in pkgs)
    @info "Package DataFrames required for this operation. Will add it now"
    Pkg.add(name="DataFrames")
  end
end

# DataFrame(x::Vector{T}) where {T<:FinancialData} = to_dataframe(x)

function to_dataframe(x::Vector{T}) where {T<:FinancialData}
  dataframe_dependencies()
  df = [name => S[] for (name, S) in zip(fieldnames(T), T.types)] |> DataFrame
  pairs = [(name => map(item -> getfield(item, name), x)) for name in fieldnames(T)]
  append!(df, pairs)
  df
end

function to_dict(x::Vector{T}) where {T<:FinancialData}
  [name => map(item -> getfield(item, name), x) for name in fieldnames(T)] |> Dict
end
