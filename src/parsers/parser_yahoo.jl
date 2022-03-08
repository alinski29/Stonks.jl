using Chain: @chain
using Dates
using JSON3: JSON3

using Stonks: JSONContent, APIResponseError, ContentParserError
using Stonks.Models: AssetPrice, AssetInfo, ExchangeRate

function parse_yahoo_info(
  content::AbstractString; kwargs...
)::Union{Vector{AssetInfo},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_info_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  return [
    AssetInfo(;
      symbol=js.quoteType["symbol"],
      currency=js.price["currency"],
      name=get(js.quoteType, "longName", missing),
      type=get(js.quoteType, "quoteType", missing),
      exchange=get(js.quoteType, "exchange", missing),
      country=get(js.assetProfile, "country", missing),
      industry=get(js.assetProfile, "industry", missing),
      sector=get(js.assetProfile, "sector", missing),
      timezone=get(js.quoteType, "timeZoneFullName", missing),
      employees=get(js.assetProfile, "fullTimeEmployees", missing),
    ),
  ]
end

function parse_yahoo_price(
  content::AbstractString; kwargs...
)::Union{Vector{AssetPrice},Exception}
  maybe_js = validate_yahoo_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  args = Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  prices = @chain js begin
    [parse_price_record(v) for (k, v) in _]
    filter(x -> isa(x, Vector{AssetPrice}), _)
  end
  if isempty(prices)
    return ContentParserError("Couldn't constrct Vector{AssetPrice} from the json object")
  end
  return @chain prices begin
    isa(from, Date) ? map(price -> filter(row -> row.date >= from, price), _) : _
    isa(to, Date) ? map(price -> filter(row -> row.date <= to, price), _) : _
    vcat(_...)
    unique
  end
end

function parse_yahoo_exchange_rate(
  content::AbstractString; kwargs...
)::Union{Vector{ExchangeRate},Exception}
  maybe_js = validate_yahoo_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js, args = maybe_js, Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  rates = @chain js begin
    [parse_exchange_record(v) for (k, v) in _]
    filter(x -> isa(x, Vector{ExchangeRate}), _)
  end
  if isempty(rates)
    return ContentParserError("Couldn't constrct Vector{ExchangeRate} from the json object")
  end
  return @chain rates begin
    isa(from, Date) ? map(xrate -> filter(row -> row.date >= from, xrate), _) : _
    isa(to, Date) ? map(xrate -> filter(row -> row.date <= to, xrate), _) : _
    vcat(_...)
    unique
  end
end

function parse_price_record(js_value::JSONContent)::Union{Vector{AssetPrice},Nothing}
  _keys = [String(k) for k in keys(js_value)]
  if !isempty(setdiff(["symbol", "timestamp", "close"], _keys))
    return nothing
  end
  isempty(js_value["timestamp"]) && return nothing
  nrows = length(js_value["timestamp"])
  ticker = js_value["symbol"]
  return [
    AssetPrice(;
      symbol=ticker,
      date=Date(unix2datetime(js_value["timestamp"][i])),
      close=Float64(js_value["close"][i]),
    ) for i in 1:nrows
  ]
end

function parse_exchange_record(js_value::JSONContent)::Union{Vector{ExchangeRate},Nothing}
  _keys = [String(k) for k in keys(js_value)]
  if !isempty(setdiff(["symbol", "timestamp", "close"], _keys))
    return nothing
  end
  isempty(js_value["timestamp"]) && return nothing
  nrows = length(js_value["timestamp"])
  base, target = @chain js_value begin
    replace(_["symbol"], "=X" => "")
    (_[1:3], _[4:length(_)])
  end
  return [
    ExchangeRate(;
      base=base,
      target=target,
      date=Date(unix2datetime(js_value["timestamp"][i])),
      rate=Float64(js_value["close"][i]),
    ) for i in 1:nrows
  ]
end

function validate_yahoo_response(content::AbstractString)::Union{JSONContent,Exception}
  maybe_js = JSON3.read(content)
  maybe_js === nothing && return error("Content could not be parsed as JSON")
  js = maybe_js
  error_idx = findfirst(x -> contains(lowercase(x), "error"), [String(k) for k in keys(js)])
  error_in_response = error_idx !== nothing ? isa(js["error"], String) : false
  if error_in_response
    error_msg = [String(v) for (k, v) in js][error_idx]
    return APIResponseError(error_msg)
  end
  return js
end

function unpack_info_response(js::Union{JSON3.Object,Exception})
  !isa(js, JSON3.Object) && return js
  !in("quoteSummary", keys(js)) &&
    return ContentParserError("expected key 'quoteSummary' not found in API response")
  js["quoteSummary"]["error"] !== nothing &&
    return ContentParserError("API response contains erro")
  res = first(js["quoteSummary"]["result"])
  ismissing(res["quoteType"]) && return ContentParserError("quoteType key is missing")
  ismissing(res["price"]) && return ContentParserError("price key is missing")
  return (
    assetProfile=get(res, "assetProfile", Dict()),
    quoteType=get(res, "quoteType", Dict()),
    price=get(res, "price", Dict()),
  )
end
