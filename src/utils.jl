using Chain: @chain
using Dates
using JSON3: JSON3

JSONContent = Union{JSON3.Object,JSON3.Array}
Symbols = Union{
  String,Vector{String},Vector{Tuple{String,Date}},Vector{Tuple{String,Date,Date}}
}

struct UpdatableSymbol
  ticker::String
  fx_pair::Union{Tuple{String,String},Missing}
  from::Union{Date,Missing}
  to::Union{Date,Missing}
end

function UpdatableSymbol(ticker; from=missing, to=missing)
  dt_from = isa(from, String) ? tryparse(Date, from) : from
  dt_to = isa(to, String) ? tryparse(Date, to) : to
  try_fx = build_fx_pair(ticker)
  fx = typeof(try_fx) <: Exception ? missing : (first(try_fx), last(try_fx))
  tick = !ismissing(fx) ? "$(first(fx))$(last(fx))=X" : ticker
  return UpdatableSymbol(tick, fx, dt_from, dt_to)
end

function build_fx_pair(symbol::String; delim="/")::Union{Tuple{String,String},Exception}
  contains(delim, symbol) &&
    return ArgumentError("$symbol does not contain '$delim' delimiter.")
  splits = split(symbol, delim)
  length(splits) != 2 &&
    return ArgumentError("Got more than 2 splits after split($symbol, '$delim')")
  s_len = map(s -> length(s), splits)
  for split in splits
    l = length(split)
    l != 3 && return ArgumentError("$split must have only 3 characters, got $l.")
  end
  return (uppercase(first(splits)), uppercase(last(splits)))
end

function construct_updatable_symbols(symbols::Symbols)::Vector{UpdatableSymbol}
  isa(symbols, String) && return [UpdatableSymbol(symbols)]
  isa(symbols, Vector{String}) && return map(x -> UpdatableSymbol(x), symbols)
  isa(symbols, Vector{Tuple{String,Date}}) &&
    return map(x -> UpdatableSymbol(x[1]; from=x[2]), symbols)
  isa(symbols, Vector{Tuple{String,Date,Date}}) &&
    return map(x -> UpdatableSymbol(x[1]; from=x[2], to=x[3]), symbols)
end

function get_minimum_dates(
  tickers::Vector{UpdatableSymbol};
  from::Union{Date,Missing}=missing,
  to::Union{Date,Missing}=missing,
)
  function get_minimum(field::Symbol, default::Union{Date,Missing})
    @chain tickers begin
      map(x -> getfield(x, field), _)
      skipmissing
      isempty(_) ? default : minimum(_)
    end
  end
  return (from=get_minimum(:from, from), to=get_minimum(:to, to))
end

"""
Utility function used to group multiple tickers inside a single reuqest if the API resource allows it (based on APIResource.tickers_per_query value)
  example: tickers = ["AAPL", "MSFT", "AMZN"]
  max_size = 10 => [ ["AAPL", "MSFT", "AMZN"] ] (all symbols inside the first batch)
  max_size = 1 => [ ["AAPL"], ["MSFT"], ["AMZN"] ] (all symbols in separate batches)
  max_size = 2 => [ ["AAPL", "MSFT"],  ["AMZN"] ] (2 groups of max 2 items, resulting in 2 batches)
"""
function split_tickers_in_batches(
  tickers::Vector{UpdatableSymbol}, max_size::Integer
)::Vector{Vector{UpdatableSymbol}}
  valid_dates = @chain tickers map(x -> x.from, _) skipmissing
  unique_dates = unique(valid_dates)
  ticker_missing_dates = @chain tickers filter(t -> ismissing(t.from), _)
  ticker_valid_dates = @chain tickers filter(t -> !ismissing(t.from), _)
  batches = []
  if !isempty(unique_dates)
    for date_group in unique_dates
      tickers_group = filter(t -> t.from == date_group, ticker_valid_dates)
      if !isempty(tickers_group)
        append!(batches, create_batches(tickers_group, max_size))
      end
    end
  end
  if !isempty(ticker_missing_dates)
    append!(batches, create_batches(ticker_missing_dates, max_size))
  end
  return batches
end

function create_batches(tickers::Vector{UpdatableSymbol}, max_size::Integer)
  stop = length(tickers)
  tickers_batched = begin
    if stop > max_size
      @chain begin
        range(1; step=max_size, stop=stop)
        map(i -> tickers[i:min((i + max_size - 1), stop)], _)
      end
    else
      return [tickers]
    end
  end
  return tickers_batched
end

is_weekday(x) = !(Dates.issaturday(x) | Dates.issunday(x))

function last_sunday()
  td = Dates.today()
  p7d = [td - Dates.Day(i) for i in 1:7]
  return p7d[findfirst(Dates.issunday, p7d)]
end

function last_workday()
  td = Dates.today()
  @chain [td - Dates.Day(i) for i in 1:3] _[findfirst(is_weekday, _)]
end