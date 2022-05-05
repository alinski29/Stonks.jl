using Chain
using DataFrames
using Tables
using Stonks.Models: AbstractStonksRecord

"""
    to_dataframe(data::Vecotr{<:AbstractStonksRecord}) -> DataFrame

Converts an object of type `Vector{<:AbstractStonksRecord}` to a `DataFrame`.
The types of the `DataFrame` will match the types of `T`.

### Examples
```julia-repl
julia> data
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-23"), 280.27, 290.18, 291.7, 280.1, missing, 37811167)
 AssetPrice("MSFT", Date("2022-02-22"), 287.72, 285.0, 291.54, 284.5, missing, 41569319)
 AssetPrice("AAPL", Date("2022-02-23"), 160.07, 165.54, 166.15, 159.75, missing, 90009247)
 AssetPrice("AAPL", Date("2022-02-22"), 164.32, 164.98, 166.69, 162.15, missing, 90457637)
julia> data |> to_dataframe
4x8 DataFrame
 Row │ symbol  date        close    open      high      low       close_adjusted  volume   
     │ String  Date        Float64  Float64?  Float64?  Float64?  Float64?        Int64?   
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ MSFT    2022-02-23   280.27    290.18    291.7     280.1          missing  37811167
   2 │ MSFT    2022-02-22   287.72    285.0     291.54    284.5          missing  41569319
   3 │ AAPL    2022-02-23   160.07    165.54    166.15    159.75         missing  90009247
   4 │ AAPL    2022-02-22   164.32    164.98    166.69    162.15         missing  90457637

julia> data
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-16"), 1.13721)
 ExchangeRate("EUR", "USD", Date("2022-02-15"), 1.1358)
 ExchangeRate("EUR", "USD", Date("2022-02-14"), 1.13052)
julia> data |> to_dataframe
3x4 DataFrame
 Row │ base    target  date        rate    
     │ String  String  Date        Float64 
─────┼─────────────────────────────────────
   1 │ EUR     USD     2022-02-16  1.13721
   2 │ EUR     USD     2022-02-15  1.1358
   3 │ EUR     USD     2022-02-14  1.13052
```
"""
function to_dataframe(x::Vector{T}) where {T<:AbstractStonksRecord}
  df = create_typed_dataframe(T)
  pairs = [(name => map(item -> getfield(item, name), x)) for name in fieldnames(T)]
  append!(df, pairs)
  return df
end

function create_typed_dataframe(::Type{T}) where {T}
  return DataFrame([name => S[] for (name, S) in zip(fieldnames(T), T.types)])
end

function to_dict(x::Vector{T}) where {T<:AbstractStonksRecord}
  return Dict([name => map(item -> getfield(item, name), x) for name in fieldnames(T)])
end

function to_namedtuple(data::Vector{T}) where {T<:AbstractStonksRecord}
  pairs = @chain fieldnames(T) begin 
    map(field -> (field => map(row -> getfield(row, field), data)), _)
    NamedTuple
  end
  return NamedTuple{fieldnames(T), Tuple{map(type -> Vector{type}, T.types)...}}(pairs)
end

function to_table(data::Vector{T}) where {T<:AbstractStonksRecord}
  return Tables.rows(to_namedtuple(data))
end

