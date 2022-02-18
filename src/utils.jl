import JSON3
import Dates: Date
import Pipe: @pipe

JSONContent = Union{JSON3.Object, JSON3.Array}

struct UpdatableSymbol
  ticker::String
  from::Union{Date, Missing}
  to::Union{Date, Missing}
end

function UpdatableSymbol(ticker; from=missing, to=missing) 
  dt_from = isa(from, String) ? tryparse(Date, from) : from 
  dt_to = isa(to, String) ? tryparse(Date, to) : to 
  UpdatableSymbol(ticker, dt_from, dt_to)
end

struct Either{T, E <: Exception}
  value::Union{T, Nothing}
  err:: Union{E, Nothing}
end

# Constructur functions. Use this in the API instead of result
Success(x:: T) where {T} = Either{T, Exception}(x, nothing)
Failure(::Type{T}, e::E) where {T, E <: Exception} = Either{T, E}(nothing, e)

function Base.promote_rule(
    ::Type{Either{S1, E1}},
    ::Type{Either{S2, E2}},
) where {S1, E1 <: Exception, S2, E2 <: Exception}
    return Either{promote_type(S1, S2), promote_type(E1, E2)}
end

Base.convert(::Type{Either{S, E}}, r::Either{S, E}) where {S, E <: Exception} = r
Base.convert(::Type{Either{S, E}}, r::Either) where {S, E <: Exception} = promote_type(Either{S, E}, typeof(r))(r.value, r.err)
# for automatic conversions - the return values will be wrapped inside Result (e.g)
Base.convert(::Type{Either{S, E}}, x::T) where {T, S, E <: Exception} = Either{S, E}(convert(S, x), nothing)
Base.convert(::Type{Either{T, E}}, e::E) where {T, E <: Exception} = Either{T, E}(nothing, e)
Base.convert(::Type{Either{T, E}}, e::E2) where {T, E <: Exception, E2 <: Exception} = Either{T,E}(nothing, convert(E, e))

function Base.show(io::IO, r::Either{T, E}) where {T, E <: Exception}
    if !isa(r.err, Nothing)
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
function split_tickers_in_batches(tickers::Vector{UpdatableSymbol}, max_size::Integer)::Vector{Vector{UpdatableSymbol}}
  valid_dates = @pipe tickers |> map(x -> x.from, _) |> skipmissing 
  unique_dates = unique(valid_dates)
  ticker_missing_dates = @pipe tickers |> filter(t -> ismissing(t.from), _)
  ticker_valid_dates = @pipe tickers |> filter(t -> !ismissing(t.from), _)
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
  batches
end

function create_batches(tickers::Vector{UpdatableSymbol}, max_size::Integer)
  stop = length(tickers)
  tickers_batched = begin 
    if stop > max_size
      @pipe range(1, step=max_size, stop=stop) |>
      map(i -> tickers[i:min((i+max_size-1), stop)], _)
    else
      return [tickers]
    end
  end
  return tickers_batched
end

