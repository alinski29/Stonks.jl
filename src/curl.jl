using Chain: @chain
using Dates: today, Day

using Stonks: UpdatableSymbol, Symbols, construct_updatable_symbols, build_fx_pair
using Stonks.APIClients: APIClient, APIResource, get_resource, get_type_param
using Stonks.Models:
  AbstractStonksRecord, AssetPrice, AssetInfo, ExchangeRate, IncomeStatement
using Stonks.Parsers: AbstractContentParser
using Stonks.Requests: optimistic_request_resolution, prepare_requests, materialize_request

"""
    get_price(
      symbols, [client], [T<:AbstractStonksRecord];
      [interval] = "1d", [from] = missing, [to] = missing, [kwargs...]
    ) -> Union{Vector{T}, Exception}

Retrieves historical time series price data from the configured API client.

### Arguments
- `symbols` can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client::APIClient]`: can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T<:AbstractStonksRecord]`: data type used for parsing. Change it only if you want to use your custom model. default = `AssetPrice`

### Keywords
- `[interval]`: values = [1d, 1wk, 1mo]. Frequency lower than daily is not supported. default = 1d
- `[from]`: a Date oject indicating lower date limit. default = `missing`
- `[to]`: a Date objject indicating upper date limit. default = `missing`
- `[kwargs...]`: use it to pass keyword arguments if you have url / query parameters that need to be resolved at runtime.

### Examples
```julia-repl
julia> today = Dates.today()
2022-02-18
julia> length(ENV["YAHOOFINANCE_TOKEN"]) # value will be used to create a client
40
julia> get_price("AAPL", from = today - Dates.Day(1))
1-element Vector{AbstractStonksRecord}
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> from = today - Dates.Day(2)
2022-02-16
julia> prices = get_price(["AAPL", "MSFT"], from = from)
AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing)
AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing
AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing
AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> prices = get_price([
  ("AAPL", Date("2022-02-17")),
  ("MSFT", Date("2022-02-18"))
  ])
3-element Vector{AbstractStonksRecord}:
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing)

julia> prices = get_price([
  ("AAPL", Date("2022-02-15"), Date("2022-02-16")),
  ("MSFT", Date("2022-02-14"), Date("2022-02-15"))
  ])
5-element Vector{AbstractStonksRecord}:
 AssetPrice("MSFT", Date("2022-02-14"), 295.0, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-15"), 300.47, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-15"), 172.79, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing)
```
"""
function get_price(
  symbols::Symbols,
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=AssetPrice;
  interval="1d",
  from=missing,
  to=missing,
  kwargs...,
)::Union{Vector{T},Exception} where {T<:AbstractStonksRecord}
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers; interval=interval, from=from, to=to, kwargs...)
end

"""
    get_info(symbols, [client], [T<:AbstractStonksRecord]) -> Union{Vector{T}, Exception}

Retrieves general information about `symbols`.

### Arguments
- `symbols::Union{String, Vector{String}}`
- `[client]::APIClient` : can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T<:AbstractStonksRecord]` : data type used for parsing. Change it only if you want to use your custom model. default = `AssetInfo`

### Examples
```julia-repl
julia> get_info(client, "AAPL")
1-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States",
  "Consumer Electronics", "Technology", "America/New_York", 100000)

julia> length(ENV["YAHOOFINANCE_TOKEN"]) # value will be used to create a client
40
julia> get_info(["AAPL", "MSFT"])
2-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States",
  "Consumer Electronics", "Technology", "America/New_York", 100000)
 AssetInfo("MSFT", "USD", "Microsoft Corporation", "EQUITY", "NMS", "United States",
  "Software—Infrastructure", "Technology", "America/New_York", 181000)
```
"""
function get_info(
  symbols::Union{String,Vector{String}},
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=AssetInfo;
  kwargs...,
) where {T<:AbstractStonksRecord}
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers, kwargs...)
end

"""
    get_exchange_rate(
      symbols, [client], [T<:AbstractStonksRecord]; 
      [from] = missing, [to] = missing
    ) -> Union{Vector{T}, Exception}

Retrieves historical exchange rate information

### Arguments
- `symbols` can be:
    - `String` formated as base/quote, each having exactly 3 characters, e.g.: 'EUR/USD', 'USD/CAD'
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client]::APIClient` can be omitted if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T<:AbstractStonksRecord]` is the data type used for parsing. Change it only if you want to use your custom model. default = `ExchangeRate`

### Keywords
- `[from]`: a Date object. default = `missing`
- `[to]`: a Date object. default = `missing`

### Examples
```julia-repl
julia> get_exchange_rate("EUR/USD", from=ref_date-Day(1), to=ref_date)
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-18"), 1.13203)
 ExchangeRate("EUR", "USD", Date("2022-02-17"), 1.13592)
julia> get_exchange_rate(["EUR/USD", "USD/CAD"], from=ref_date-Day(1), to=ref_date)
# 4-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-18"), 1.13203)
 ExchangeRate("EUR", "USD", Date("2022-02-17"), 1.13592)
 ExchangeRate("USD", "CAD", Date("2022-02-18"), 1.2748)
 ExchangeRate("USD", "CAD", Date("2022-02-17"), 1.2707)
# Also works with []Tuple{String, Date} or []Tuple{String, Date, Date}
julia>get_exchange_rate([
  ("EUR/USD", Date("2022-02-15"), Date("2022-02-16")),
  ("USD/CAD", Date("2022-02-14"), Date("2022-02-15")),
])
4-element Vector{ExchangeRate}:
...
```
"""
function get_exchange_rate(
  symbols::Symbols,
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=ExchangeRate;
  interval="1d",
  from::Union{Date,Missing}=missing,
  to::Union{Date,Missing}=missing,
  kwargs...,
)::Union{Vector{T},Exception} where {T<:AbstractStonksRecord}
  invalid_pairs = @chain symbols begin
    isa(_, String) ? [_] : _
    map(build_fx_pair, _)
    filter(s -> typeof(s) <: Exception, _)
  end
  !isempty(invalid_pairs) && return first(invalid_pairs)
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers; interval=interval, from=from, to=to, kwargs...)
end

"""
    get_income_statement(
      symbols, [client], [T<:AbstractStonksRecord];
      [frequency] = missing, [from] = missing, [to] = missing, [kwargs...]
    ) -> Union{Vector{T}, Exception}

Retrieves main information of income (profit and loss) statement.

### Arguments
- `symbols` can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
- `[client::APIClient]`: can be ommited if one of the correct environmental variable is set (`YAHOOFINANCE_TOKEN` or `ALPHAVANTAGE_TOKEN`)
- `[T<:AbstractStonksRecord]`: data type used for parsing. Change it only if you want to use your custom model. default = `IncomeStatement`

### Keywords
- `[frequency]`: values = [yearly, quarterly]. default = `missing`, which will include both yearly and quarterly frequencies.
- `[from]`: a Date oject indicating lower date limit. default = `missing`
- `[to]`: a Date objject indicating upper date limit. default = `missing`
- `[kwargs...]`: use it to pass keyword arguments if you have url / query parameters that need to be resolved at runtime.

### Examples
```julia
get_income_statement("AAPL")
get_income_statement(["AAPL", "IBM"])
get_income_statement(["AAPL", "IBM"]; frequency="yearly")
get_income_statement([
  ("AAPL", Date("2020-01-01"), Date("2020-12-31")),
  ("MSFT", Date("2020-01-01"), Date("2020-12-31")),
]; frequency="quarterly")
```
"""
function get_income_statement(
  symbols::Symbols,
  client::Union{APIClient,Nothing}=nothing,
  ::Type{T}=IncomeStatement;
  frequency::Union{String,Missing}=missing,
  from::Union{Date,Missing}=missing,
  to::Union{Date,Missing}=missing,
  kwargs...,
)::Union{Vector{T},Exception} where {T<:AbstractStonksRecord}
  resource = get_resource(client, T)
  tickers = construct_updatable_symbols(symbols)
  return get_data(resource, tickers; frequency=frequency, from=from, to=to, kwargs...)
end

"""
    get_data(resource, symbols; kwargs...) -> Union{Vector{<:AbstractStonksRecord}, Exception}

Generic function to get data of type resource{T}. Functions such as get_price, get_info, call this.

### Arguments 
- `resource::APIResource`: instance of an `APIResource`.
- `symbols::Symbol` can be:
    - `String` with one symbol / ticker
    - `Vector{String}` with multiple symbols
    - `Vector{Tuple{String, Date}}`: tuples of form (symbol, from)
    - `Vector{Tuple{String, Date, Date}}`, tuples of form (symbol, from, to)
    - `Vector{UpdatableSymbol}`: type Stonks.UpdatableSymbol(symbol; [from], [to])

### Keywords 
- `[interval]`: values = 1d, 1wk, 1mo. Frequency lower than daily is not supported. default = 1d
- `[from]`: a Date oject indicating lower date limit. default = `missing`
- `[to]`: a Date objject indicating upper date limit. default = `missing`
- `[kwargs...]`: use it to pass keyword arguments if you have url / query parameters that need to be resolved at runtime.
"""
function get_data(
  resource::Union{APIResource,Exception},
  symbols::Union{Vector{UpdatableSymbol},Symbols,Missing}=missing;
  kwargs...,
)#::Union{Vector{AbstractStonksRecord},Exception}
  tickers = (
    if ismissing(symbols)
      [UpdatableSymbol("FOO")]
    elseif isa(symbols, Vector{UpdatableSymbol})
      symbols
    else
      construct_updatable_symbols(symbols)
    end
  )
  typeof(resource) <: Exception && return resource
  requests = prepare_requests(tickers, resource; kwargs...)
  typeof(requests) <: Exception && return requests
  responses = Channel(length(requests))
  @sync begin
    for rp in requests
      Threads.@spawn begin
        symbol = length(rp.tickers) == 1 ? first(rp.tickers).ticker : missing
        res = materialize_request(
          rp, resource.parser; from=rp.from, to=rp.to, symbol=symbol
        )
        err = typeof(res) <: Exception ? res : nothing
        value = typeof(res) <: Exception ? nothing : res
        push!(responses, (params=rp, err=err, value=value))
      end
    end
  end
  close(responses)
  return optimistic_request_resolution(get_type_param(resource), responses)
end

# function get_data(
#   client::APIClient,
#   tickers::Vector{UpdatableSymbol},
# )::Dict{String,Union{Vector{AbstractStonksRecord},Exception}}
#   responses = Channel(length(client.resources))
#   @sync begin
#     for (k, resource) in client.resources
#       Threads.@spawn begin
#         resp = get_data(resource, tickers)
#         push!(responses, (resource = k, value = resp))
#       end
#     end
#   end
#   close(responses)
#   collect_results(responses)
# end

# function collect_results(c::Channel)
#   result = Dict()
#   for item in c
#     has_value = isa(item.value, Vector{AbstractStonksRecord})
#     if haskey(result, item.resource) && has_value
#       append!(result[item.resource], item.value)
#     elseif has_value
#       result[item.resource] = item.value
#     else
#       result[item.resource] = item.value
#     end
#   end
#   return result
# end
