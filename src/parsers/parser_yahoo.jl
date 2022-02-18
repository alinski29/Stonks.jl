import Pipe: @pipe
import Dates: Date, unix2datetime
import JSON3
import Stonx: JSONContent

import ..Models: AssetPrice, AssetInfo

function parse_yahoo_info(content::AbstractString; kwargs...)::Union{Vector{AssetInfo}, Exception}
  maybe_js = @pipe content |> validate_content_as_json |> unpack_info_response
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  [AssetInfo(
    symbol = js.quoteType["symbol"],
    currency = js.price["currency"],
    name = get(js.quoteType, "longName", missing),
    type = get(js.quoteType, "quoteType", missing),
    exchange = get(js.quoteType, "exchange", missing),
    country = get(js.assetProfile, "country", missing),
    industry = get(js.assetProfile, "industry", missing),
    sector = get(js.assetProfile, "sector", missing),
    timezone = get(js.quoteType, "timeZoneFullName", missing),
    employees = get(js.assetProfile, "fullTimeEmployees", missing)
  )]
end

function parse_yahoo_price(content::AbstractString; kwargs...)::Union{Vector{AssetPrice}, Exception}
  
  function _parse(js_value::JSONContent)::Union{Vector{AssetPrice}, Nothing}
    _keys = [String(k) for k in keys(js_value)]
    if !isempty(setdiff(["symbol", "timestamp", "close"], _keys)) 
      return nothing
    end
    nrows = length(js_value["timestamp"])
    nrows == 0 && return nothing
    ticker = js_value["symbol"]
    return [AssetPrice(
        symbol = ticker,
        date = Date(unix2datetime(js_value["timestamp"][i])),
        close = Float64(js_value["close"][i])
    ) for i in 1:nrows]
  end

  maybe_js = validate_content_as_json(content)
  isa(maybe_js, ErrorException) && return maybe_js
  js = maybe_js
  from = get(Dict(kwargs), :from, missing)
  to = get(Dict(kwargs), :to, missing)
  prices = @pipe [_parse(v) for (k, v) in js] |> 
    filter(x -> isa(x, Vector{AssetPrice}), _)
  if length(prices) == 0
    return ErrorException("Couldn't constrct Vector{AssetPrice} from the json object")
  end
  if isa(from, Date)
    prices = @pipe prices |> 
      map(price -> filter(row -> row.date >= from, price), _)
  end
  if isa(to, Date)
    prices = @pipe prices |> 
      map(price -> filter(row -> row.date <= to, price), _)
  end
  return vcat(prices...) |> unique
end

function validate_content_as_json(content::AbstractString)::Union{JSONContent, Exception}
  maybe_js = JSON3.read(content)
  maybe_js === nothing && return error("Content could not be parsed as JSON")
  js = maybe_js
  error_idx = findfirst(x -> contains(lowercase(x), "error"), [String(k) for k in keys(js)]) 
  error_in_response = error_idx !== nothing ? isa(js["error"], String) : false 
  if error_in_response 
    return KeyError("API responded with an error") 
  end
  return js
end

function unpack_info_response(js::Union{JSON3.Object, Exception})
  !isa(js, JSON3.Object) && return js
  !in("quoteSummary", keys(js)) && return KeyError("expected key 'quoteSummary' not found in API response")
  js["quoteSummary"]["error"] !== nothing && return ErrorException("API response contains erro")
  res = first(js["quoteSummary"]["result"])
  ismissing(res["quoteType"]) && return KeyError("quoteType key is missing")
  ismissing(res["price"]) && return KeyError("price key is missing")
  (
    assetProfile = get(res, "assetProfile", Dict()),
    quoteType = get(res, "quoteType", Dict()),
    price = get(res, "price", Dict())
  )
end
