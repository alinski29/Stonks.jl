module Stores

using CSV
using Chain

using Stonks.Models: AbstractStonksRecord, AssetInfo, AssetPrice, ExchangeRate
using Stonks: to_table

export AbstractStore, FileStore, load, save, update

"""
Abstract type to be subtyped by all types of Stores, like `FileStore`. `DatabaseStore`.
"""
abstract type AbstractStore{T <: AbstractStonksRecord} end

function writer_csv(data::Vector{T}, path::String) where {T<:AbstractStonksRecord} 
  isempty(data) ? CSV.write(path, to_table(data)) : CSV.write(path, data)
end

function reader_csv(path::String, ::Type{T}) where {T<:AbstractStonksRecord} 
  apply_schema(CSV.File(path), T)
end 

ensure_path(path::String) = isabspath(path) ? path : joinpath(@__DIR__, path)

"""
    FileStore{T<:AbstractStonksRecord}

Stores all information needed for data storage and retrieval.

### Fields 
- `path::String`: absolute or relative path 
- `ids::AbstractVector{AbstractString}`: list of identifiers. maximum 2 identifiers
- `format::String`: file format. all files will have the ending like "data.{format}". default = "csv"
- `partitions::AbstractVector{AbstractString}`: columns used for data partitioning. columns have to be members of T
- `time_colum::Union{AbstractString, Missing}`: column representing time dimension. Can be skipped for `AssetPrice` and `ExchangeRate`.
- `reader::Function`: reader(path::String) -> Vector{AbstractStonksRecord}
- `writer::Function`: writer(data::Vector{<:AbstractStonksRecord}, path::String)

### Constructors
```julia
FileStore{<:AbstractStonksRecord}(;
  path,
  ids,
  format="csv",
  partitions=[],
  time_column=missing,
  reader=reader_csv,
  writer=writer_csv,
)

# where,
reader_csv(path::String) = apply_schema(CSV.File(path), T<:AbstractStonksRecord)
writer_csv(data::Vector{<:AbstractStonksRecord}, path::String) = CSV.write(path, data)
```

### Examples 
```julia 
using Stonks
dest = joinpath(@__DIR__, "data/stonks")
FileStore{AssetInfo}(; path=dest, ids=["symbol"])
FileStore{AssetPrice}(; path=dest, ids=["symbol"], time_column="date")
FileStore{AssetPrice}(; path=dest, ids=[:symbol], partitions=[:symbol], time_column ="date")

using Arrow
read = read_arrow(path::String) = Arrow.Table(path)
write = write_arrow(data, path::String) = open(path, "w") do io Arrow.write(io, data) end
FileStore{ExchangeRate}(; path=dest, ids=[:base, :target], time_column="date", reader=read, writer=write)
```
"""
struct FileStore{T<:AbstractStonksRecord,R,W} <: AbstractStore{T}
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