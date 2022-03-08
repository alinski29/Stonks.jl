module Stores

using CSV
using Chain
using DataFrames

using Stonks.Models: AbstractStonksRecord, AssetInfo, AssetPrice, ExchangeRate

export AbstractStore, FileStore, load, save, update

abstract type AbstractStore end

writer_csv(df::AbstractDataFrame, path::String) = CSV.write(path, df)
reader_csv(path::String) = DataFrame(CSV.File(path))
ensure_path(path::String) = isabspath(path) ? path : joinpath(@__DIR__, path)

"""
    FileStore{T<:AbstractStonksRecord}

Container holding all information for data persistance.

### Fields 
- `path::String`: absolute or relative path 
- `ids::AbstractVector{AbstractString}`: list of identifiers. maximum 2 identifiers.
- `format::String`: file format. all files will have the ending like "data.{format}"
- `partitions::AbstractVector{AbstractString}`: columns used for data partitioning. columns have to be members of T.
- `time_colum::Union{AbstractString, Missing}`: column representing time dimension.
- `reader::Function`: `reader(path::String) -> DataFrame`
- `writer::Function`: `writer(df::AbstractDataFrame, path::String) -> DataFrame`

### Constructor
```julia
function FileStore{T}(;
  path,
  ids,
  format="csv",
  partitions=[],
  time_column=missing,
  reader=reader_csv(path::String) = DataFrame(CSV.File(path)),
  writer=writer_csv(path::String) = CSV.write(path, df),
) where {T<:AbstractStonksRecord}
  return FileStore{T}(
    ensure_path(path),
    map(String, ids),
    format,
    map(String, partitions),
    time_column,
    reader,
    writer,
  )
end
```

### Examples 
```julia 
using Stonks
dest = joinpath(@__DIR__, "data/stonks")
FileStore{AssetInfo}(; path=dest, ids=["symbol"])
FileStore{AssetPrice}(; path=dest, ids=["symbol"], time_column="date")
FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"], time_column ="date")

using Arrow
read = read_arrow(path::String) = Arrow.Table(path) |> DataFrame
write = write_arrow(df::AbstractDataFrame, path::String) = open(path, "w") do io Arrow.write(io, df) end
FileStore{ExchangeRate}(; path=dest, ids=[:base, :target], time_column=:date, reader=read, writer=write)
```
"""
struct FileStore{T<:AbstractStonksRecord,R,W} <: AbstractStore
  path::String
  ids::AbstractVector{AbstractString}
  format::String
  partitions::AbstractVector{AbstractString}
  time_column::Union{AbstractString,Missing}
  reader::R
  writer::W
  function FileStore{T}(
    path,
    ids,
    format="csv",
    partitions=[],
    time_column=missing,
    reader=reader_csv,
    writer=writer_csv,
  ) where {T<:AbstractStonksRecord}
    @chain [ids, partitions, [time_column]] begin
      filter(!isempty, _)
      foreach(x -> if !ismissing(first(x))
        check_type_membership(T, x)
      end, _)
    end
    length(ids) > 2 && throw(DomainError("`ids` must contain at most 2 items."))
    return new{T,typeof(reader),typeof(writer)}(
      ensure_path(path),
      map(String, ids),
      format,
      map(String, partitions),
      ismissing(time_column) ? infer_time_column(T) : time_column,
      reader,
      writer,
    )
  end
end

function infer_time_column(::Type{T})::Union{String,Missing} where {T<:AbstractStonksRecord}
  T_fields = [String(x) for x in fieldnames(T)]
  T === AssetInfo && return missing
  if T === AssetPrice || T === ExchangeRate
    "date" in T_fields && return "date"
    "timestamp" in T_fields && return "timestamp"
  end
  return missing
end

# function infer_ids(::Type{T}) where {T<:AbstractStonksRecord}
#   T_fields = [String(x) for x in fieldnames(T)]
#   if T === AssetPrice || T === AssetInfo
#     "symbol" in T_fields && return ["symbol"]
#   end
#   if T === ExchangeRate
#     "base" in T_fields && return ["base", "target"]
#   end
#   return missing
# end

function check_type_membership(
  ::Type{T}, fields::Vector{String}
) where {T<:AbstractStonksRecord}
  T_fields = [String(x) for x in fieldnames(T)]
  for field in map(String, fields)
    !(field in T_fields) && throw(DomainError("$field not a member of $T"))
  end
end

# kwargs constructor
function FileStore{T}(;
  path,
  ids,
  format="csv",
  partitions=[],
  time_column=missing,
  reader=reader_csv,
  writer=writer_csv,
) where {T<:AbstractStonksRecord}
  return FileStore{T}(
    ensure_path(path),
    map(String, ids),
    format,
    map(String, partitions),
    time_column,
    reader,
    writer,
  )
end

include("stores/utils.jl")
include("stores/atomic_write.jl")
include("stores/interface.jl")

end