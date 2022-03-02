module Datastores

using CSV
using DataFrames

using Stonx.Models: AbstractStonxRecord

export load, save, update

abstract type AbstractDatastore end

writer_csv(df::AbstractDataFrame, path::String) = CSV.write(path, df)
reader_csv(path::String) = DataFrame(CSV.File(path))
ensure_path(path::String) = contains(path, pwd()) ? path : joinpath(pwd(), path)

# Interface 
# load(ds) -> DataFrame 
# load(ds, symbols) -> DataFrame , NOT implemented 
# save(ds) -> implemented for partitioned and non-partitioned data
# update(ds) -> FileDatastore
# update(ds, symbols) -> FileDatastore
# update(ds, symbols, client) -> FileDatastore

struct FileDatastore{T<:AbstractStonxRecord,R,W} <: AbstractDatastore
  path::String
  format::String
  keys::Vector{AbstractString}
  partitions::Vector{AbstractString}
  time_column::AbstractString
  reader::R
  writer::W
  #TODO: Constrain thant partitions are fields of T
  function FileDatastore{T}(
    path, format="csv", keys=[], partitions=[], time_column="date", reader=reader_csv, writer=writer_csv
  ) where {T<:AbstractStonxRecord}
    return new{T,typeof(reader),typeof(writer)}(
      ensure_path(path), format, map(String, keys), map(String, partitions), String(time_column), reader, writer
    )
  end
end

# kwargs constructor
function FileDatastore{T}(;
  path, format="csv", keys=[], partitions=[], time_column="date",
  reader=reader_csv, writer=writer_csv
) where {T<:AbstractStonxRecord}
  return FileDatastore{T,typeof(writer)}(
    ensure_path(path), format, map(String, keys), map(String, partitions), String(time_column), reader, writer
  )
end

include("datastores/utils.jl")
include("datastores/atomic_write.jl")
include("datastores/interface.jl")

end