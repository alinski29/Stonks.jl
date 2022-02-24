using Chain: @chain
using Dates
using JSON3: JSON3

export Either, Success, Failure, UpdatableSymbol
export split_tickers_in_batches, get_minimum_dates

JSONContent = Union{JSON3.Object,JSON3.Array}
Symbols = Union{
  String,Vector{String},Vector{Tuple{String,Date}},Vector{Tuple{String,Date,Date}}
}

struct UpdatableSymbol
  ticker::String
  from::Union{Date,Missing}
  to::Union{Date,Missing}
end

function UpdatableSymbol(ticker; from=missing, to=missing)
  dt_from = isa(from, String) ? tryparse(Date, from) : from
  dt_to = isa(to, String) ? tryparse(Date, to) : to
  return UpdatableSymbol(ticker, dt_from, dt_to)
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
  Container that holds either a value or an error. 
"""
struct Either{T,E<:Exception}
  value::Union{T,Nothing}
  err::Union{E,Nothing}
end

Success(x::T) where {T} = Either{T,Exception}(x, nothing)
Failure(::Type{T}, e::E) where {T,E<:Exception} = Either{T,E}(nothing, e)

function Base.promote_rule(
  ::Type{Either{S1,E1}}, ::Type{Either{S2,E2}}
) where {S1,E1<:Exception,S2,E2<:Exception}
  return Either{promote_type(S1, S2),promote_type(E1, E2)}
end

function Base.show(io::IO, r::Either{T,E}) where {T,E<:Exception}
  return if isnothing(r.err)
    print(io, "Failure($T, $(r.err))")
  else
    print(io, "Success($T, $(r.value))")
  end
end

"""
Utility function used to group multiple tickers inside a single reuqest if the API endpoint allows it (based on APIResource.tickers_per_query value)
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
