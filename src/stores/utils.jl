using Chain
using Dates

using Stonks
using Stonks: AbstractStonksRecord, Symbols, SchemaValidationError, UpdatableSymbol
using Stonks:
  construct_updatable_symbols, last_workday, get_data, select, transform, groupby
using Stonks.APIClients: APIClient, APIResource, get_resource
using Stonks.Stores: FileStore

function apply_schema(data::AbstractVector, ::Type{T})::Union{Vector{T}, Exception} where {T<:AbstractStonksRecord}
  isempty(data) && return T[]
  try
    map(row -> T(; NamedTuple(row)...), data)
  catch e 
    return e
  end
end

function init(ds::FileStore{T}) where {T<:AbstractStonksRecord}
  data = T[]
  if isempty(ds.partitions)
    tr = WriteTransaction([WriteOperation(data, ds.format)], ds.format, ds.path)
    return execute(tr, ds.writer)
  end
  tr = @chain ds.partitions begin
    map(p -> "$p=__init__", _)
    reduce(joinpath, _)
    [WriteOperation(data, ds.format, _)]
    WriteTransaction(_, ds.format, ds.path)
  end
  return execute(tr, ds.writer)
end

function filter_files(
  ds::FileStore{T}, partitions::Dict{String,Vector{String}}
) where {T<:AbstractStonksRecord}
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

function generate_partition_pairs(data::AbstractVector{T}, cols::Vector{AbstractString}) where {T<:AbstractStonksRecord}
  
  col_diff = setdiff(map(Symbol, cols), [x for x in fieldnames(T)])
  if !isempty(col_diff)
    cols_excl = join(filter(x -> !in(x, [x for x in fieldnames(T)]), map(Symbol, cols)), ", ")
    return ErrorException("There are partition columns not present in the data: '$cols_excl'")
  end

  return @chain data begin 
    Stonks.groupby(_, map(Symbol, cols))
    # Stonks.aggregate(_, [Symbol(first(cols)) => unique => :values]) 
    [(data = collect(v), key = String(first(cols)) * "=" * String(first(k))) for (k, v) in _ ]
  end

end

function get_symbols(
  data::Vector{T},
  ids::Vector{Symbol};
  time_column::AbstractString,
  ref_date::Date=last_workday(),
) where {T<:AbstractStonksRecord}

  groups = @chain data begin 
    groupby(_, ids)
    Stonks.aggregate(_, [Symbol(String(time_column)) => maximum => Symbol((String(time_column) * "_max"))])
    Stonks.transform(_, Dict(:lower_limit => x -> getfield(x, Symbol("$(String(time_column))_max" )) + Dates.Day(1)))
    filter(x -> x.lower_limit < ref_date ,_)
  end
  isempty(groups) && return nothing
  
  id_lengths = map(id -> map(g -> length(getfield(g, id)), groups), ids)
  if length(ids) > 1
    if all(l -> l == 3, first(id_lengths)) && all(l -> l == 3, id_lengths[2])
      return [
        ("$(row[ids[1]])/$(row[ids[2]])", row[:lower_limit], ref_date) for row in groups
      ]
    else
      return nothing
    end
  end
  return [(row[Symbol(first(ids))], row[:lower_limit], ref_date) for row in groups]

end 


function find_update_candidates(
  data::Vector{T},
  symbols::Union{Symbols,Nothing};
  ids::AbstractVector{S},
  time_column::Union{AbstractString,Missing},
  ref_date=last_workday(),
)::Vector{UpdatableSymbol} where {T<:AbstractStonksRecord, S<:AbstractString}
  if isnothing(symbols) && isempty(data)
    return []
  elseif isnothing(symbols) && !ismissing(time_column)
    smb = get_symbols(data, map(Symbol, ids); time_column=time_column, ref_date=ref_date)
    return !isnothing(smb) ? construct_updatable_symbols(smb) : []
  elseif isnothing(symbols) && ismissing(time_column) && length(ids) == 1
    unique_vals = unique(map(x -> getfield(x, Symbol(String(first(ids)))), data))
    return construct_updatable_symbols(unique_vals)
  elseif isnothing(symbols) && ismissing(time_column) && length(ids) == 2
    fx_pairs = @chain data begin
       Stonks.select(_, map(Symbol, ids))
      ["$(row[1])$(row[2])=X" for row in unique(_)]
      construct_updatable_symbols(_)
    end
    return fx_pairs
  else
    ()
  end
  tickers = construct_updatable_symbols(symbols)
  if all(map(t -> isa(t.from, Date) || isa(t.to, Date), tickers))
    return tickers
  end
  unique_vals = unique(Stonks.select(data, map(Symbol, ids)))

  if all(map(t -> !ismissing(t.fx_pair), tickers)) && length(ids) == 2
    g1 = map(t -> first(t.fx_pair), tickers)
    g2 = map(t -> last(t.fx_pair), tickers)
    fx_pairs = map(t -> (t.fx_pair[1], t.fx_pair[2]), tickers)
    g_diff = [
      "$(base)/$(target)" for (base, target) in fx_pairs if
      !(
        base in map(x -> getfield(x, Symbol(first(ids))), select(unique_vals, [Symbol(first(ids))])) &&
        target in map(x -> getfield(x, Symbol(last(ids))), select(unique_vals, [Symbol(ids[2])]))
      )
    ]
    data_filt = filter(row -> getfield(row, Symbol(first(ids))) in g1 && getfield(row, Symbol(last(ids))) in g2, data)
    smb = (
      if !isempty(data_filt) && !ismissing(time_column)
        get_symbols(data_filt, map(Symbol, ids); time_column=time_column, ref_date=ref_date)
      elseif ismissing(time_column) && !isempty(fx_pairs)
        ["$(base)/$(target)" for (base, target) in fx_pairs]
      else
        nothing
      end
    )
    tickers_old = !isnothing(smb) ? construct_updatable_symbols(smb) : nothing
    tickers_diff = !isempty(g_diff) ? construct_updatable_symbols(g_diff) : nothing
    return vcat(
      !isnothing(tickers_old) ? tickers_old : [], !isnothing(tickers_diff) ? tickers_diff : []
    )
  else
    g1 = map(x -> x.ticker, tickers)
    g_diff = [
      t for t in map(t -> t.ticker, tickers) if 
        !(t in map(x -> getfield(x, Symbol(first(ids))), Stonks.select(unique_vals, [Symbol(first(ids))])))
    ]
    data_filt = filter(row -> getfield(row, Symbol(first(ids))) in g1, data)
    smb = (
      if !isempty(data_filt) && !ismissing(time_column)
        get_symbols(data_filt, map(Symbol, ids); time_column=time_column, ref_date=ref_date)
      elseif ismissing(time_column) && !isempty(tickers)
        map(t -> t.ticker, tickers)
      else
        nothing
      end
    )
    tickers_old = !isnothing(smb) ? construct_updatable_symbols(smb) : nothing
    tickers_diff = !isempty(g_diff) ? construct_updatable_symbols(g_diff) : nothing
    return vcat(
      !isnothing(tickers_old) ? tickers_old : [], !isnothing(tickers_diff) ? tickers_diff : []
    )
  end
end
