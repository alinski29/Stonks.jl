using Chain
using Dates
using Logging

using Stonks: AbstractStonksRecord, Symbols, UpdatableSymbol
using Stonks: construct_updatable_symbols,last_workday, get_data
using Stonks.APIClients: APIClient, APIResource, get_resource
using Stonks.Stores: FileStore

"""
    load(ds, [partitions]) -> Union{Vector{<:AbstractStonksRecord}, Exception}

Read data from an `FileStore` instance into a Vector{:<AbstractStonksRecord}. If there is no data at `ds.path`, a file with 0 records and the correct types with be created. 

### Arguments
- `ds::FileStore{<:AbstractStonksRecord}`: a `FileStore` instance
- `[partitions]::Dict{String, Vector{String}}`: a dict of column => values, used for partition pruning. default = `missing`

### Examples
```julia
dest = joinpath(@__DIR__, "data/prices")
ds = FileStore{AssetPrice}(; path=dest, ids=[:symbol], partitions=[:symbol], time_column="date")
data = load(ds)
2-element Vector{AssetPrice}:
 AssetPrice("AAPL", Date("2022-03-01"), 163.2, 164.695, 166.6, 161.97, missing, 83474425)
 AssetPrice("AAPL", Date("2022-02-28"), 165.12, 163.06, 165.42, 162.43, missing, 95056629)
```
"""
function load(
  ds::FileStore{T},
  partitions::Union{Dict{String,Vector{String}},Missing}=missing
)::Union{Vector{T},Exception} where {T<:AbstractStonksRecord}

  !isdir(ds.path) && init(ds)
  all_files = list_nested_files(ds.path)
  p_files = !ismissing(partitions) ? filter_files(ds, partitions) : []
  if typeof(all_files) <: Exception
    return all_files
  end
  if isempty(all_files)
    return ErrorException("No files found at dir '$(ds.path)'")
  end

  files = String[]
  if !ismissing(partitions) && !isempty(ds.partitions)
    if typeof(p_files) <: Exception
      return p_files
    elseif isempty(intersect(all_files, p_files))
      return T[]
    else
      @info "partition filter will be applied: $partitions"
      append!(files, p_files)
    end
  else
    append!(files, all_files)
  end

  try
    # non-partitioned dataset
    if length(files) == 1
      return ds.reader(first(files), T)
    end
    # partitioned dataset
    frames = Channel(length(files))
    @sync for file in files
      Threads.@spawn begin
        push!(frames, ds.reader(file, T))
      end
    end
    close(frames)
    return vcat(frames...)
    # return data
  catch err
    return err
  end

end

"""
    save(ds, data) -> Union{Nothing, Exception}

Writes data using the information provided in the FileStore (path, format,  partitions, writer)
In case of a `FileStore` with partitions, the partition values where `data` has records will be overwritten.

### Arguments
- `ds::FileStore`
- `data::Vector{<:AbstractStonksRecord}`

### Examples
```julia-repl
julia> dest = joinpath(@__DIR__, "data/prices")
julia> ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"], time_column="date")
julia> data
2-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-03-04"), 289.86, missing, missing, missing, missing, missing)
 AssetPrice("TSLA", Date("2022-03-04"), 838.29, missing, missing, missing, missing, missing)
julia> save(ds, data)
julia> readdir(ds.path)
2-element Vector{String}:
 "symbol=MSFT"
 "symbol=TSLA"
```
"""
function save(ds::FileStore{T}, data::Vector{T}) where {T<:AbstractStonksRecord}
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(data, ds.format)], ds.format, ds.path)
    status, err = execute(tr, ds.writer)
    return status ? nothing : err
  end
  partitions = generate_partition_pairs(data, ds.partitions)
  if isa(partitions, ErrorException)
    return partitions
  end
  trs = @chain partitions begin
    map(p -> WriteOperation(p.data, ds.format, p.key), _)
    WriteTransaction(_, ds.format, ds.path)
  end
  status, err = execute(trs, ds.writer)
  return status ? nothing : err
end

"""
    update(ds, [symbols], [client]; [to], [force]) -> Union{Nothing, FileStore}

Updates or inserts data in the datastore. 
If `symbols` are not provided, the updates will be inferred based on `ds.ids` and `ds.time_column`.
If `symbols` are provided, only the symbols will be updated.

### Arguments 
- `ds::FileStore{<:AbstractStonksRecord}` 
- `[symbols::Symbol]`. Default = missing.  Can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client::APIClient]`: can be omitted if the one of the client can be built from ENV vars

### Keywords
- `[to::Date]`: default = most recent working day. upper date limit.
- `[force::Bool]`: default = `false`. Indicates how to handle the case when `ismissing(ds.time_column) && ismissing(symbols)`:
  - `false` => does nothing
  - `true` => makes requests for all `ds.ids` from the min until max `ds.time_column` and rewrites all data

### Examples
```julia-repl
julia> Dates.today()
Date("2022-02-04")
julia> @chain load(ds) Stonks.groupby(prices, [:symbol]) Stonks.aggregate(_, [:date => maximum => :date_max])
2-element Vector{NamedTuple{(:symbol, :date_max), Tuple{String, Date}}}:
 (symbol = "AAPL", date_max = Date("2022-03-02"))
 (symbol = "MSFT", date_max = Date("2022-03-02"))

julia> update(ds) 
julia>  @chain load(ds) Stonks.groupby(prices, [:symbol]) Stonks.aggregate(_, [:date => maximum => :date_max])
2-element Vector{NamedTuple{(:symbol, :date_max), Tuple{String, Date}}}:
 (symbol = "AAPL", date_max = Date("2022-03-04"))
 (symbol = "MSFT", date_max = Date("2022-03-04"))

julia> update(ds, ["IBM", "AMD"])
julia>  @chain load(ds) Stonks.groupby(prices, [:symbol]) Stonks.aggregate(_, [:date => maximum => :date_max])
4-element Vector{NamedTuple{(:symbol, :date_max), Tuple{String, Date}}}:
 (symbol = "AAPL", date_max = Date("2022-03-04"))
 (symbol = "MSFT", date_max = Date("2022-03-04"))
 (symbol = "IBM", date_max = Date("2022-03-04"))
 (symbol = "AMD", date_max = Date("2022-03-04"))
```
"""
function update(
  ds::FileStore{T},
  symbols::Union{Symbols,Nothing}=nothing,
  client::Union{APIClient,Nothing}=nothing;
  interval::String="1d",
  to::Date=last_workday(),
  force::Bool=false,
)::Union{FileStore{T},Exception} where {T<:AbstractStonksRecord}
  data = (
    if !isnothing(symbols) && length(ds.ids) == 1
      tickers = construct_updatable_symbols(symbols)
      partitions = Dict(first(ds.ids) => map(t -> t.ticker, tickers))
      load(ds, partitions)
    else
      load(ds)
    end
  )

  if typeof(data) <: Exception
    return data
  end
  
  if isempty(data) && isnothing(symbols)
    return ErrorException("Can't update an empty dataset without any `symbols` parameter")
  end
  if ismissing(ds.time_column) && isnothing(symbols) && !force
    @warn "Can't incrementally update a Store without a time_column and no symbols. If you wish to overwrite all data, use force=true keyword argument."
    return ds
  end
  if ismissing(ds.time_column) && isnothing(symbols) && force
    @warn "Got force=true. This will fetch and overwrite all data"
  end
  candidates = find_update_candidates(data, symbols; ids=ds.ids, time_column=ds.time_column, ref_date=to)
  if isempty(candidates)
    @info "No update candidates found, datastore already up to date"
    return ds
  end
  # get candidates
  resource = get_resource(client, T)
  if typeof(resource) <: Exception
    return resource
  end
  updates = get_data(resource, candidates; interval=interval)
  if typeof(updates) <: Exception
    return updates
  end
  new_data = force ? updates : vcat(data, updates)
  
  try_save = save(ds, new_data)
  if typeof(try_save) <: Exception
    return try_save
  end

  return ds

end
