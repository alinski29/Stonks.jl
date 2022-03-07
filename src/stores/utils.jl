using Chain
using DataFrames
using Dates

using Stonx: AbstractStonxRecord, Symbols, SchemaValidationError, UpdatableSymbol
using Stonx:
  construct_updatable_symbols, create_typed_dataframe, last_workday, get_data, to_dataframe
using Stonx.APIClients: APIClient, APIResource, get_resource
using Stonx.Stores: FileStore

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

function init(ds::FileStore{T}) where {T<:AbstractStonxRecord}
  df = create_typed_dataframe(T)
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(df, ds.format)], ds.format, ds.path)
    return execute(tr, ds.writer)
  end
  tr = @chain ds.partitions begin
    map(p -> "$p=__init__", _)
    reduce(joinpath, _)
    [WriteOperation(df, ds.format, _)]
    WriteTransaction(_, ds.format, ds.path)
  end
  return execute(tr, ds.writer)
end

function filter_files(
  ds::FileStore{T}, partitions::Dict{String,Vector{String}}
) where {T<:AbstractStonxRecord}
  for p in keys(partitions)
    !(String(p) in map(String, ds.partitions)) &&
      return ErrorException("$p is not a partition key")
  end
  all_files = list_nested_files(ds.path)
  files_to_read = String[]
  for file in all_files
    regex_matches = @chain partitions begin
      [(rmatch=match(Regex("(?<=$p=)[^/]+(?=/)"), file), values=vals) for (p, vals) in _]
      filter(x -> !isnothing(x.rmatch), _)
    end
    if !isempty(regex_matches)
      flags = map(x -> x.rmatch.match in x.values, regex_matches)
      all(flags) && push!(files_to_read, file)
    end
  end
  #@info "After partition filters, got $(length(files_to_read)) / $(length(all_files))."
  return files_to_read
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

function symbols_from_df(
  df::AbstractDataFrame,
  ids::AbstractVector{T};
  time_column::AbstractString,
  ref_date::Date=last_workday(),
)::Union{Symbols,Nothing} where {T<:AbstractString}
  groups = @chain df begin
    groupby(_, map(Symbol, ids))
    combine(_, Symbol(time_column) => maximum)
    transform(
      _, Symbol("$(time_column)_maximum") => ByRow(d -> d + Dates.Day(1)) => :lower_limit
    )
    filter(:lower_limit => <(ref_date), _)
  end
  if nrow(groups) == 0
    return nothing
  end
  if length(ids) > 1
    if maximum(map(length, df[:, first(ids)])) == 3 &&
      maximum(map(length, df[:, ids[2]])) == 3
      return [
        ("$(row[first(ids)])/$(row[ids[2]])", row[:lower_limit], ref_date) for
        row in eachrow(groups)
      ]
    else
      return nothing
    end
  end
  return [(row[Symbol(first(ids))], row[:lower_limit], ref_date) for row in eachrow(groups)]
end

function find_update_candidates(
  df::AbstractDataFrame,
  symbols::Union{Symbols,Nothing};
  ids::AbstractVector{T},
  time_column::Union{AbstractString,Missing},
  ref_date=last_workday(),
)::Vector{UpdatableSymbol} where {T<:AbstractString}
  if isnothing(symbols) && nrow(df) == 0
    return []
  elseif isnothing(symbols) && !ismissing(time_column)
    smb = symbols_from_df(df, ids; time_column=time_column, ref_date=ref_date)
    return construct_updatable_symbols(smb)
  elseif isnothing(symbols) && ismissing(time_column) && length(ids) == 1
    df_vals = unique(df[:, Symbol(first(ids))])
    return construct_updatable_symbols(df_vals)
  elseif isnothing(symbols) && ismissing(time_column) && lenght(ids) == 2
    tickers = @chain begin
      unique(df[:, map(Symbol, ids)])
      ["$(row[1])$(row[2])=X" for row in eachrow(_)]
      construct_updatable_symbols(_)
    end
    return tickers
  else
    ()
  end

  tickers = construct_updatable_symbols(symbols)
  df_vals = unique(df[:, map(Symbol, ids)])
  if all(map(t -> !ismissing(t.fx_pair), tickers)) && length(ids) == 2
    g1 = map(t -> first(t.fx_pair), tickers)
    g2 = map(t -> last(t.fx_pair), tickers)
    fx_pairs = map(t -> (t.fx_pair[1], t.fx_pair[2]), tickers)
    g_diff = [
      "$(p[1])/$(p[2])" for p in fx_pairs if
      !(p[1] in df_vals[:, Symbol(ids[1])] && p[2] in df_vals[:, Symbol(ids[2])])
    ]
    data = filter(row -> row[Symbol(ids[1])] in g1 && row[Symbol(ids[2])] in g2, df)
    smb_df = (
      if !isempty(data) && !ismissing(time_column)
        symbols_from_df(data, ids; time_column=time_column, ref_date=ref_date)
      elseif ismissing(time_column) && !isempty(fx_pairs)
        ["$(p[1])/$(p[2])" for p in fx_pairs]
      else
        nothing
      end
    )
    tickers_df = !isnothing(smb_df) ? construct_updatable_symbols(smb_df) : nothing
    tickers_diff = !isempty(g_diff) ? construct_updatable_symbols(g_diff) : nothing
    return vcat(
      !isnothing(tickers_df) ? tickers_df : [], !isnothing(tickers_diff) ? tickers_diff : []
    )
  else
    g1 = map(x -> x.ticker, tickers)
    g_diff = [
      t for t in map(t -> t.ticker, tickers) if !(t in df_vals[:, Symbol(first(ids))])
    ]
    data = filter(row -> row[Symbol(first(ids))] in g1, df)
    smb_df = (
      if !isempty(data) && !ismissing(time_column)
        symbols_from_df(data, ids; time_column=time_column, ref_date=ref_date)
      elseif ismissing(time_column) && !isempty(tickers)
        map(t -> t.ticker, tickers)
      else
        nothing
      end
    )
    tickers_df = !isnothing(smb_df) ? construct_updatable_symbols(smb_df) : nothing
    tickers_diff = !isempty(g_diff) ? construct_updatable_symbols(g_diff) : nothing
    return vcat(
      !isnothing(tickers_df) ? tickers_df : [], !isnothing(tickers_diff) ? tickers_diff : []
    )
  end
end
