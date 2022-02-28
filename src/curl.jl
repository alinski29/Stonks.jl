using Chain: @chain
using Dates: today, Day

using Stonx: UpdatableSymbol, Symbols, construct_updatable_symbols
using Stonx.APIClients: APIClient, APIResource, get_resource, get_type_param
using Stonx.Models: AbstractStonxRecord, AssetPrice, AssetInfo, ExchangeRate
using Stonx.Parsers: AbstractContentParser
using Stonx.Requests: optimistic_request_resolution, prepare_requests, materialize_request

"""
    get_time_series(symbols, [client], [T <: AbstractStonxRecord] = AssetPrice; [interval] = "1d", [from] = missing, [to] = missing, [kwargs...])

Retrieves historical time series price data from the configured API client.

### Arguments
- `symbols` can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client::APIClient]`: can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T <: AbstractStonxRecord]`: data type used for parsing. Change it only if you want to use your custom model. default = `AssetPrice`

### Keywords
- `[interval]`: values = 1d, 1wk, 1mo. Frequency lower than daily is not supported. default = 1d
- `[from]`: a Date oject indicating lower date limit. default = `missing`
- `[to]`: a Date objject indicating upper date limit. default = `missing`
- `[kwargs...]`: use it to pass keyword arguments if you have url / query parameters that need to be resolved at runtime.

### Examples
```julia-repl
julia> today = Dates.today()
2022-02-18
julia> length(ENV["YAHOOFINANCE_TOKEN"]) # value will be used to create a client
40
julia> get_time_series("AAPL", from = today - Dates.Day(1))
1-element Vector{AbstractStonxRecord}
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> from = today - Dates.Day(2)
2022-02-16
julia> prices = get_time_series(["AAPL", "MSFT"], from = from)
AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing)
AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing
AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> prices = get_time_series([
  ("AAPL", Date("2022-02-17")),
  ("MSFT", Date("2022-02-18"))
  ])
3-element Vector{AbstractStonxRecord}:
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing)

julia> prices = get_time_series([
  ("AAPL", Date("2022-02-15"), Date("2022-02-16")),
  ("MSFT", Date("2022-02-14"), Date("2022-02-15"))
  ])
5-element Vector{AbstractStonxRecord}:
 AssetPrice("MSFT", Date("2022-02-14"), 295.0, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-15"), 300.47, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-15"), 172.79, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing)
```
"""
function get_time_series(
  symbols::Symbols,
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=AssetPrice;
  interval="1d",
  from=missing,
  to=missing,
  kwargs...,
)::Union{Vector{T},Exception} where {T<:AbstractStonxRecord}
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers; interval=interval, from=from, to=to, kwargs...)
end

"""
    get_info(symbols, [client], [T <: AbstractStonxRecord] = AssetInfo)

Retrieves general information about `symbols`.

### Arguments
- `symbols::Union{String, Vector{String}}`
- `[client]::APIClient` : can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T <: AbstractStonxRecord]` : data type used for parsing. Change it only if you want to use your custom model. default = `AssetInfo`

### Examples

```julia-repl
julia> length(ENV["YAHOOFINANCE_TOKEN"]) # value will be used to create a client
40
julia> get_info(client, "AAPL")
1-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)

julia> get_info(["AAPL", "MSFT"])
2-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)
 AssetInfo("MSFT", "USD", "Microsoft Corporation", "EQUITY", "NMS", "United States", "Software—Infrastructure", "Technology", "America/New_York", 181000)
```
"""
function get_info(
  symbols::Union{String,Vector{String}},
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=AssetInfo;
  kwargs...,
) where {T<:AbstractStonxRecord}
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers, kwargs...)
end

"""
    get_exchange_rate([client], [T <: AbstractStonxRecord]; base, target, from = missing, to = missing)

Retrieves historical exchange rate information

### Arguments
- `[client]::APIClient` can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T <: AbstractStonxRecord]` is the data type used for parsing. Change it only if you want to use your custom model. default = `ExchangeRate`

### Keywords
- `base` REQUIRED - 3 letter currency code 
- `target` REQUIRED - 3letter currency code of target / quotation currency
- `[from]` - a Date object. default = missing
- `[to]` - a Date object. default = missing

### Examples
```julia-repl
julia> length(ENV["YAHOOFINANCE_TOKEN"]) # value will be used to create a client
40
julia> get_exchange_rate(base = "EUR", target = "USD", from = Date("2022-02-14"), to = Date("2022-02-16"))
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-14"), 1.1365)
 ExchangeRate("EUR", "USD", Date("2022-02-15"), 1.1306)
 ExchangeRate("EUR", "USD", Date("2022-02-16"), 1.1357)
```
"""
function get_exchange_rate(
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=ExchangeRate;
  interval="1d",
  base::String,
  target::String,
  from::Union{Date,Missing}=missing,
  to::Union{Date,Missing}=missing,
  kwargs...,
)::Union{Vector{T},Exception} where {T<:AbstractStonxRecord}
  @chain begin
    get_resource(client, T)
    get_data(
      _,
      [UpdatableSymbol(base)];
      interval=interval,
      base=base,
      target=target,
      from=from,
      to=to,
      kwargs...,
    )
  end
end

# TODO: Need to implement batching for exchange rates
# function get_exchange_rate(
#   client::Union{APIClient,Nothing} = nothing,
#   ::Type{T} = ExchangeRate;
#   interval = "1d",
#   pairs::Vector{Tuple{String, String}},
#   from::Union{Date,Missing} = missing,
#   to::Union{Date,Missing} = missing,
#   kwargs...,
# ) where {T<:AbstractStonxRecord}
#   tickers = map(pair -> UpdatableSymbol(pair[1], from = from, to = to), pairs)
#   @chain begin
#     get_resource(client, T)
#     get_data(
#       _,
#       tickers,
#       interval = interval,
#       base = base,
#       target = target,
#       from = from,
#       to = to,
#       kwargs...,
#     )
#   end
# end

function get_data(
  resource::Union{APIResource,Exception}, tickers::Vector{UpdatableSymbol}; kwargs...
)#::Union{Vector{AbstractStonxRecord},Exception}
  typeof(resource) <: Exception && return resource
  requests = prepare_requests(tickers, resource; kwargs...)
  typeof(requests) <: Exception && return requests
  responses = Channel(length(requests))
  @sync begin
    for rp in requests
      Threads.@spawn begin
        res = materialize_request(rp, resource.parser; from=rp.from, to=rp.to)
        push!(responses, (params=rp, err=res.err, value=res.value))
      end
    end
  end
  close(responses)
  return optimistic_request_resolution(get_type_param(resource), responses)
end

# function get_data(
#   client::APIClient,
#   tickers::Vector{UpdatableSymbol},
# )::Dict{String,Union{Vector{AbstractStonxRecord},Exception}}
#   responses = Channel(length(client.endpoints))
#   @sync begin
#     for (k, resource) in client.endpoints
#       Threads.@spawn begin
#         resp = get_data(resource, tickers)
#         push!(responses, (endpoint = k, value = resp))
#       end
#     end
#   end
#   close(responses)
#   collect_results(responses)
# end

function collect_results(c::Channel)
  result = Dict()
  for item in c
    has_value = isa(item.value, Vector{AbstractStonxRecord})
    if haskey(result, item.endpoint) && has_value
      append!(result[item.endpoint], item.value)
    elseif has_value
      result[item.endpoint] = item.value
    else
      result[item.endpoint] = item.value
    end
  end
  return result
end
