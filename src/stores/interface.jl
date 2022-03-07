using Chain
using Dates
using DataFrames
using Logging

using Stonx: AbstractStonxRecord, Symbols, UpdatableSymbol
using Stonx:
  construct_updatable_symbols, create_typed_dataframe, last_workday, get_data, to_dataframe
using Stonx.APIClients: APIClient, APIResource, get_resource
using Stonx.Stores: FileStore

"""
    load(ds, [partitions]=missing) -> DataFrame

Read data from a `Store` instance into a DataFrame. If there is no data at `ds.path`, a file with 0 records and the correct types with be created. 

### Arguments
- `ds::FileStore{AbstractStonxRecord}`: a `FileStore` instance
- `[partitions]::Dict{String, Vector{String}}`: a dict of column => values, used for partition prunning. default = `missing`
"""
function load(
  ds::FileStore{T}, partitions::Union{Dict{String,Vector{String}},Missing}=missing
)::Union{DataFrame,Exception} where {T<:AbstractStonxRecord}
  !isdir(ds.path) && init(ds)
  files = ismissing(partitions) ? list_nested_files(ds.path) : filter_files(ds, partitions)
  if typeof(files) <: Exception
    return files
  end
  if isempty(files)
    return ErrorException("No files found at dir '$(ds.path)'")
  end
  try
    # non-partitioned dataset
    if length(files) == 1
      data = ds.reader(first(files))
      return apply_schema(T, data)
    end
    # partitioned dataset
    frames = Channel(length(files))
    @sync for file in files
      Threads.@spawn begin
        maybe_df = ds.reader(file)
        isa(maybe_df, DataFrame) && push!(frames, maybe_df)
      end
    end
    close(frames)
    data = vcat(frames...)
    return apply_schema(T, data)
  catch err
    return err
  end
end

"""
    save(ds, data)

Writes data to a location.

### Arguments
- `ds::FileStore`
- `data`::Union{AbstractDataFrame, Vector{AbstractStonxRecord}}

### Examples
```julia-repl
julia> using Stonx, Dates
julia> dest = joinpath(@__DIR__, "data/prices")
julia> ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"], time_column="date")
julia> data = get_time_series(["MSFT", "TSLA"]; from = Date("2022-03-03"), to = Date("2022-03-07"))
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-03-03"), 295.92, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-03-04"), 289.86, missing, missing, missing, missing, missing)
 AssetPrice("TSLA", Date("2022-03-03"), 839.29, missing, missing, missing, missing, missing)
 AssetPrice("TSLA", Date("2022-03-04"), 838.29, missing, missing, missing, missing, missing)
julia> save(ds, data)
julia> readdir(ds, path)
2-element Vector{String}:
 "symbol=MSFT"
 "symbol=TSLA"
```
"""
function save(
  ds::FileStore, data::Union{AbstractDataFrame,Vector{T}}
) where {T<:AbstractStonxRecord}
  df = typeof(data) <: AbstractDataFrame ? data : to_dataframe(data)
  get_type_param(::FileStore{S}) where {S} = S
  valid_schema = validate_schema(get_type_param(ds), df)
  if isa(valid_schema, SchemaValidationError)
    return valid_schema
  end
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(df, ds.format)], ds.format, ds.path)
    status, err = execute(tr, ds.writer)
    return status ? nothing : err
  end
  partitions = generate_partition_pairs(df, ds.partitions)
  if isa(partitions, ErrorException)
    return partitions
  end
  tr = @chain partitions begin
    map(p -> WriteOperation(p.data, ds.format, p.key), _)
    WriteTransaction(_, ds.format, ds.path)
  end
  #return execute(tr, ds.writer)
  status, err = execute(tr, ds.writer)
  return status ? nothing : err
end

"""
    update(ds, [symbols], [client]; force = false)

Updates or inserts all data in the datastore. 
If symbols is not provided, the updates will be infered based on `ds.ids` and `ds.time_column`.

### Arguments 
- `ds::FileStore` 
- `[symbols::Symbol]`. Default = missing.  Can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client::APIClient]`: can be ommited if one of the correct ENV variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)

### Examples
```julia-repl
using Chain, Dates
julia> Dates.today()
Date("2022-02-05")
data = load(ds)
julia> @chain data to_dataframe groupby(_, :symbol) combine(_, :date => maximum) show
2×2 DataFrame
 Row │ symbol  date_maximum 
     │ String  Date         
─────┼──────────────────────
   1 │ MSFT    2022-03-02
   2 │ AAPL    2022-03-02

julia> update(ds) 
julia> df_upd = load(ds_new)
julia> @chain df_upd groupby(_, :symbol) combine(_, :date => maximum) show
2×2 DataFrame
 Row │ symbol  date_maximum 
     │ String  Date         
─────┼──────────────────────
   1 │ AAPL    2022-03-04
   2 │ MSFT    2022-03-04
```
"""
function update(
  ds::FileStore{T},
  symbols::Union{Symbols,Nothing}=nothing,
  client::Union{APIClient,Nothing}=nothing;
  interval::String="1d",
  force::Bool=false,
)::Union{FileStore{T},ErrorException} where {T<:AbstractStonxRecord}
  # Must implement for partitioned data as well
  df = (
    if !isnothing(symbols) && length(ds.ids) == 1
      tickers = construct_updatable_symbols(symbols)
      partitions = Dict(first(ds.ids) => map(t -> t.ticker, tickers))
      @info "partition filter will be applied: $partitions"
      load(ds, partitions)
    else
      load(ds)
    end
  )
  if typeof(df) <: Exception
    return df
  end
  if nrow(df) == 0 && isnothing(symbols)
    return ErrorException("Can't update an empty dataframe without any `symbols` parameter")
  end
  if ismissing(ds.time_column) && isnothing(symbols) && !force
    @warn "Can't incrementally update a Store without a time_column and no symbols. If you wish to overwrite all data, use force=true keyword argument."
    return ds
  end
  if ismissing(ds.time_column) && isnothing(symbols) && force
    @warn "Got force=true. This will fetch and overwrite all data"
  end
  candidates = find_update_candidates(df, symbols; ids=ds.ids, time_column=ds.time_column)
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
  new_df = force ? to_dataframe(updates) : vcat(df, to_dataframe(updates))
  _, err = save(ds, new_df)
  if typeof(err) <: Exception
    return err
  end
  return ds
end
