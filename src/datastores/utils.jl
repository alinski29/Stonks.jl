using Chain
using DataFrames
using Dates

using Stonx: AbstractStonxRecord, Symbols, SchemaValidationError, UpdatableSymbol
using Stonx:
  construct_updatable_symbols,
  create_typed_dataframe,
  last_workday,
  get_data,
  to_dataframe
using Stonx.APIClients: APIClient, APIResource, get_resource
using Stonx.Datastores: FileDatastore

function validate_schema(::Type{T}, data::DataFrame) where {T<:AbstractStonxRecord}
  get_type_param(::Vector{S}) where {S} = S
  ds_types = [
    (name=String(name), type=type) for (name, type) in zip(fieldnames(T), T.types)
  ]
  df_types = [(name=col, type=get_type_param(data[:, col])) for col in names(data)]
  if length(df_types) != length(ds_types)
    return SchemaValidationError("Length of column names of $T != data")
  end
  for i in 1:length(ds_types)
    if ds_types[i].name != df_types[i].name || ds_types[i].type !== df_types[i].type
      return SchemaValidationError(
        "$(ds_types[i].name), $(ds_types[i].type) != $(df_types[i].name), $(df_types[i].type)",
      )
    end
  end
  return true
end

function apply_schema(::Type{T}, data::DataFrame) where {T<:AbstractStonxRecord}
  ds_types = [
    (name=String(name), type=type) for (name, type) in zip(fieldnames(T), T.types)
  ]
  if length(ds_types) != length(names(data))
    return SchemaValidationError("Length of column names of $T != data")
  end
  for (name, CT) in ds_types
    data[!, name] = convert.(CT, data[:, name])
  end
  empty_df = create_typed_dataframe(T)
  return vcat(empty_df, data)
end

function init(ds::FileDatastore{T}) where {T<:AbstractStonxRecord}
  df = create_typed_dataframe(T)
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(df, ds.format)], ds.format, ds.path)
    return execute(tr, ds.writer)
  end
  tr = @chain ds.partitions begin
    map(p -> WriteOperation(df, ds.format, "$p=__init__"), _)
    WriteTransaction(_, ds.format, ds.path)
  end
  return execute(tr, ds.writer)
end

# TODO can be done recursively
function list_nested_files(dir::String)::Vector{String}
  nested_files = []
  for (root, dirs, files) in walkdir(dir)
    foreach(file -> push!(nested_files, joinpath(root, file)), files)
  end
  return nested_files
end

function list_partition_nesting(dir::String)::Vector{String}
  partitions = []
  for (root, dirs, files) in walkdir(dir)
    isempty(dirs) && continue
    d = first(dirs)
    !(isdir(joinpath(root, d)) && contains(d, "=")) && continue
    p = first(split(d, "="))
    !in(p, partitions) ? push!(partitions, p) : continue
  end
  return partitions
end

function generate_partition_pairs(df::DataFrame, cols::Vector{AbstractString})
  df_cols = names(df)
  diff = setdiff(cols, df_cols)
  if length(diff) > 0
    cols_excl = join(filter(x -> !in(x, df_cols), cols), ", ")
    return ErrorException(
      "There are partition columns not present in the dataframe: '$cols_excl'"
    )
  end
  gdf = groupby(df, cols)
  partitions = [
    (key=join(map(x -> "$(x[1])=$(x[2])", zip(names(key), values(key))), "/"), data=subdf)
    for (key, subdf) in pairs(gdf)
  ]
  return partitions
end

function find_update_candidates(
  df::Union{AbstractDataFrame,Nothing},
  symbols::Symbols;
  keys::Vector{AbstractString},
  time_column::String="date",
  ref_date=today(),
)::Vector{UpdatableSymbol}
  tickers = construct_updatable_symbols(symbols)
  if !isa(df, AbstractDataFrame)
    return tickers
  end
  df_filt = filter(Symbol(first(keys)) => in(map(x -> x.ticker, tickers)), df)
  if nrow(df_filt) == 0
    return tickers
  end
  last_working_day = minimum([last_workday(), ref_date])
  df_maxdates = @chain df_filt begin
    groupby(_, map(Symbol, keys)) # @TODO - need to dynamically know the the key
    combine(_, Symbol(time_column) => maximum)
    transform(_, Symbol("$(time_column)_maximum") => ByRow(d -> d + Dates.Day(1)) => :lower_limit)
  end
  needs_update = filter(:lower_limit => <(last_working_day), df_maxdates)
  u1 = @chain needs_update begin
    map(
      row -> UpdatableSymbol(row[Symbol(first(keys))], Date(row[:date_maximum]), ref_date),
      eachrow(_),
    )
  end
  df_keys = @chain unique(df[:, Symbol(first(keys))]) map(String, _)
  u2 = filter(t -> !in(t.ticker, df_keys) ,tickers)
  return vcat(u1, u2)
end
