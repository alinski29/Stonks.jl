using Chain
using Stonks.Models: AbstractStonksRecord

"""
    to_dict(data::Vector{<:AbstractStonksRecord}) -> Dict{Symbol, Vector}

Converts an object of type `Vector{<:AbstractStonksRecord}` to a `Dict`.

### Examples
```julia-repl
julia> data
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-23"), 280.27, 290.18, 291.7, 280.1, missing, 37811167)
 AssetPrice("MSFT", Date("2022-02-22"), 287.72, 285.0, 291.54, 284.5, missing, 41569319)
 AssetPrice("AAPL", Date("2022-02-23"), 160.07, 165.54, 166.15, 159.75, missing, 90009247)
 AssetPrice("AAPL", Date("2022-02-22"), 164.32, 164.98, 166.69, 162.15, missing, 90457637)
julia> data |> to_dict
Dict{Symbol, Vector} with 8 entries:
  :symbol         => ["MSFT", "MSFT", "AAPL", "AAPL"]
  :volume         => [37811167, 41569319, 90009247, 90457637]
  :close_adjusted => [missing, missing, missing, missing]
  :high           => [291.7, 291.54, 166.15, 166.69]
  :open           => [290.18, 285.0, 165.54, 164.98]
  :low            => [280.1, 284.5, 159.75, 162.15]
  :date           => [Date("2022-02-23"), Date("2022-02-22"), Date("2022-02-23"), Date("2022-02-22")]
  :close          => [280.27, 287.72, 160.07, 164.32]

julia> data
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-16"), 1.13721)
 ExchangeRate("EUR", "USD", Date("2022-02-15"), 1.1358)
 ExchangeRate("EUR", "USD", Date("2022-02-14"), 1.13052)
julia> data |> to_dict
Dict{Symbol, Vector} with 4 entries:
  :base   => ["EUR", "EUR", "EUR"]
  :target => ["USD", "USD", "USD"]
  :date   => [Date("2022-02-16"), Date("2022-02-15"), Date("2022-02-14")]
  :rate   => [1.13721, 1.1358, 1.13052]

```
"""
function to_dict(data::Vector{T}) where {T<:AbstractStonksRecord}
  return Dict([name => map(item -> getfield(item, name), data) for name in fieldnames(T)])
end


"""
    to_table(data::Vector{<:AbstractStonksRecord}) -> NamedTuple{Symbol, Vector}

Converts an object of type `Vector{<:AbstractStonksRecord}` to a `NamedTuple`, satisfying the Table.jl interface.
The types of the data model are preserverd.

### Examples
```julia-repl
julia> data
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-23"), 280.27, 290.18, 291.7, 280.1, missing, 37811167)
 AssetPrice("MSFT", Date("2022-02-22"), 287.72, 285.0, 291.54, 284.5, missing, 41569319)
 AssetPrice("AAPL", Date("2022-02-23"), 160.07, 165.54, 166.15, 159.75, missing, 90009247)
 AssetPrice("AAPL", Date("2022-02-22"), 164.32, 164.98, 166.69, 162.15, missing, 90457637)
julia> data |> to_table
(
  symbol = ["MSFT", "MSFT", "AAPL", "AAPL"],
  date = [Date("2022-02-23"), Date("2022-02-22"), Date("2022-02-23"), Date("2022-02-22")],
  close = [280.27, 287.72, 160.07, 164.32], 
  open = Union{Missing, Float64}[290.18, 285.0, 165.54, 164.98], 
  high = Union{Missing, Float64}[291.7, 291.54, 166.15, 166.69], 
  low = Union{Missing, Float64}[280.1, 284.5, 159.75, 162.15], 
  close_adjusted = Union{Missing, Float64}[missing, missing, missing, missing], 
  volume = Union{Missing, Integer}[37811167, 41569319, 90009247, 90457637]
)
"""
function to_table(data::Vector{T}) where {T<:AbstractStonksRecord}
  pairs = @chain fieldnames(T) begin 
    map(field -> (field => map(row -> getfield(row, field), data)), _)
    NamedTuple
  end
  return NamedTuple{fieldnames(T), Tuple{map(type -> Vector{type}, T.types)...}}(pairs)
end
