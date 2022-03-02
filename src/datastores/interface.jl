using Chain
using Dates
using DataFrames
using Logging

using Stonx: AbstractStonxRecord, Symbols, UpdatableSymbol
using Stonx:
  construct_updatable_symbols,
  create_typed_dataframe,
  last_workday,
  get_exchange_rate,
  get_info,
  get_time_series,
  get_data,
  to_dataframe
using Stonx.APIClients: APIClient, APIResource, get_resource
using Stonx.Datastores: FileDatastore

"""
Read data from a `Datastore` instance into a DataFrame
"""
function load(
  ds::FileDatastore{T}
)::Union{DataFrame,Exception} where {T<:AbstractStonxRecord}
  !isdir(ds.path) && init(ds)
  files = list_nested_files(ds.path)
  if isempty(files)
    return ErrorException("No files found at dir '$(ds.path)'")
  end
  try
    if length(files) == 1
      data = ds.reader(first(files))
      return apply_schema(T, data)
    end
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

function save(ds::FileDatastore, df::AbstractDataFrame)
  get_type_param(::FileDatastore{S}) where {S} = S
  valid_schema = validate_schema(get_type_param(ds), df)
  if isa(valid_schema, SchemaValidationError)
    return valid_schema
  end
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(df, ds.format)], ds.format, ds.path)
    return execute(tr, ds.writer)
  end
  partitions = generate_partition_pairs(df, ds.partitions)
  if isa(partitions, ErrorException) 
    return partitions
  end
  tr = @chain partitions begin 
    map(p -> WriteOperation(p.data, ds.format, p.key), _)
    WriteTransaction(_, ds.format, ds.path)
  end
  return execute(tr, ds.writer)
end

function update(
  ds::FileDatastore{T},
  symbols::Union{Symbols,Nothing} = nothing,
  client::Union{APIClient,Nothing} = nothing;
  base=missing,
  target=missing,
  interval="1d",
)::Union{FileDatastore{T},ErrorException} where {T<:AbstractStonxRecord}
  # Must implement for partitioned data as well
  df = load(ds)
  if typeof(df) <: Exception
    return df
  end
  if nrow(df) == 0 && isnothing(symbols)
    return ErrorException("Can't update an empty dataframe without any `symbols` parameter")
  end
  upd_symbols = isnothing(symbols) ? unique(df[:, Symbol(first(ds.keys))]) : symbols
  candidates = find_update_candidates(
    df, upd_symbols; keys=ds.keys, time_column=ds.time_column
  )
  # get candidates
  resource = get_resource(client, T)
  if typeof(resource) <: Exception
    return resource
  end
  # TODO: need from and to kwargs for exchange rate
  updates = get_data(resource, candidates; interval=interval, base=base, target=target)
  if typeof(updates) <: Exception
    return updates
  end
  new_df = vcat(df, to_dataframe(updates))
  success, err = save(ds, new_df)
  if typeof(err) <: Exception
    return err
  end
  return ds
end
