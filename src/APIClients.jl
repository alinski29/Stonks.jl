"""
Collection of logic for interfacing with HTTP APIs
"""
module APIClients

using Chain
using Dates

using Stonx: DataClientError
using Stonx.Parsers
using Stonx.Models: AbstractStonxRecord, AssetPrice, AssetInfo, ExchangeRate

export APIClient, APIResource

abstract type AbstractDataClient end
abstract type AbstractAPIClient <: AbstractDataClient end

"""
    APIResource{T<:AbstractStonxRecord}

Container holding all information required to make requests to an API endpoint.

### Fields 
- `url::String`: the url of the API endpoint, excluding query parameters
- `query_params::Dict{String, String}`: parameters used in the request.
- `parser::AbstractContentParser`: a subtype of `AbstractContentParser` implementing `parse_content`.
- `headers::Dict{String,String}`: HTTP headers
- `symbol_key::String`: with what name will the symbol/symbols will be found
- `max_batch_size::Integer`: the maximum number of symbols allowed in a single request.
- `max_retries::Integer`: how many times to retry a failed request
- `rank_order::Integer`: if you have multiple `APIClients` capable of handling type `T`, the one wil the highest value will be used.

### Constructors
```julia
APIResource{T}(;
  url::String, 
  parser::AbstractContentParser,
  headers::Dict{String, String} = Dict(),
  query_params::Dict{String, String} = Dict(),
  symbol_key::String = max_batch_size > 1 ? "symbols" : "symbol",
  max_batch_size::String = 1,
  max_retries::Integer = 0,
  rank_order::Integer = 1,
)
```
"""
mutable struct APIResource{T<:AbstractStonxRecord}
  url::String
  query_params::Dict{String,String}
  parser::Parsers.AbstractContentParser
  headers::Dict{String,String}
  symbol_key::String
  max_batch_size::Integer
  max_retries::Integer
  rank_order::Integer
end
# constructor from kwargs
function APIResource{T}(;
  url,
  query_params=Dict(),
  parser=Parsers.JSONParser(()),
  headers=Dict(),
  symbol_key="",
  max_batch_size=1,
  max_retries=0,
  rank_order=1,
) where {T<:AbstractStonxRecord}
  symbol_key = isempty(symbol_key) && max_batch_size > 1 ? "symbols" : "symbol"
  return APIResource{T}(
    url, query_params, parser, headers, symbol_key, max_batch_size, max_retries, rank_order
  )
end
get_type_param(::APIResource{T}) where {T} = T

"""
A container for holding data required to make request to one or multiple APIs.
Just a collection of `APIResource`s.
"""
mutable struct APIClient <: AbstractDataClient
  url::String
  endpoints::Dict{String,APIResource}
  function APIClient(url, endpoints)
    return new(url, endpoints)
  end
end
get_supported_types(client::APIClient) = [get_type_param(v) for (k, v) in client.endpoints]

function get_resource(
  client::Union{APIClient,Nothing}, ::Type{T}
) where {T<:AbstractStonxRecord}
  if client !== nothing
    return first([r for (k, r) in client.endpoints if typeof(r) == APIResource{T}])
  else
    @chain begin
      build_clients_from_env()
      get_resource_from_clients(_, T)
    end
  end
end

"""
    build_clients_from_env() -> Union{Vector{APIClient}, DataClientError}

Utility function which will will try to create instances of `APIClient` from environment variables.
"""
function build_clients_from_env()::Union{Vector{APIClient},Exception}
  clients = APIClient[]
  function try_build_from_keys(keys::Vector{String}, clientBuilder::Function)
    for key in keys
      if haskey(ENV, key)
        !isempty(ENV[key]) && push!(clients, clientBuilder(ENV[key]))
        break
      end
    end
  end
  yahoo_keys = ["YAHOO_APIKEY", "YAHOO_TOKEN", "YAHOOFINANCE_APIKEY", "YAHOOFINANCE_TOKEN"]
  alphavantage_keys = ["ALPHAVANTAGE_APIKEY", "ALPHAVANTAGE_TOKEN"]
  try_build_from_keys(yahoo_keys, YahooClient)
  try_build_from_keys(alphavantage_keys, AlphavantageJSONClient)
  all_keys = k -> join(k, ", ")(vcat(yahoo_keys, alphavantage_keys))
  isempty(clients) && return DataClientError(
    "Could not build API client from environment variables. Please set one of the following: $all_keys",
  )
  return clients
end

"""
    get_resource_from_clients(clients::Vector{APIClient}, ::Type{T}) -> APIResource

Given a list of clients, returns the `APIResource` capable of handling `T`. 
If multiple resources are capable:
  - the one with the highest priority (`rank_order`) is returned.
  - if there is a tie based on `rank_order`, one will be chosen at random.
"""
function get_resource_from_clients(
  clients::Union{Vector{APIClient},Exception}, ::Type{T}
) where {T<:AbstractStonxRecord}
  typeof(clients) <: Exception && return clients
  capable_clients = [client for client in clients if T in get_supported_types(client)]
  isempty(capable_clients) &&
    return DataClientError("No client capable of handling type $T")
  length(capable_clients) == 1 && return get_resource(fist(capable_clients), T)
  #@debug "Found $(length(capable_clients)) capable clients for handling $T. Will chose them based on provided ranking"
  resources = [get_resource(client, T) for client in capable_clients]
  min_rank = minimum(map(r -> r.rank_order, resources))
  res = filter(r -> r.rank_order == min_rank, resources)
  length(res) == 1 && return first(res)
  #@debug "Found multiple resources with the same rank: $min_rank. WIll chose one at random"
  return res[rand(1:length(res))]
end

"""
    YahooClient(api_key::String) -> APIClient

Utility function for creating a client for accessing yahoofinance API. 
Contains the following `endpoints`: 
  - "info" => `APIResource{AssetInfo}`
  - "price" => `APIResource{AssetPrice}`
  - "exchange" => `APIResource{ExchangeRate}`
"""
function YahooClient(api_key::String)::APIClient
  url = "https://yfapi.net"
  headers = Dict("accept" => "application/json", "X-API-KEY" => api_key)
  price = APIResource{AssetPrice}(;
    url="$url/v8/finance/spark",
    query_params=Dict(
      "interval" => "{interval}", "range" => "{range}", "symbols" => "{symbols}"
    ),
    parser=Parsers.YahooPriceParser,
    headers=headers,
    max_batch_size=10,
    max_retries=1,
  )
  info = APIResource{AssetInfo}(;
    url="$url/v11/finance/quoteSummary/{symbol}",
    query_params=Dict("modules" => "assetProfile,quoteType,price"),
    parser=Parsers.YahooInfoParser,
    headers=headers,
    max_batch_size=1,
    max_retries=1,
  )
  exchange = APIResource{ExchangeRate}(;
    url="$url/v8/finance/spark",
    query_params=Dict(
      "interval" => "{interval}", "range" => "{range}", "symbols" => "{symbols}"
    ),
    parser=Parsers.YahooExchangeRateParser,
    headers=headers,
    max_batch_size=10,
    max_retries=1,
  )
  return APIClient(url, Dict("price" => price, "info" => info, "exchange" => exchange))
end

"""
    AlphavantageJSONClient(api_key::String) -> APIClient

Utility function for creating a client for accessing alphavantage API. 
Contains the following `endpoints`: 
  - "info" => `APIResource{AssetInfo}`
  - "price" => `APIResource{AssetPrice}`
  - "exchange" => `APIResource{ExchangeRate}`
"""
function AlphavantageJSONClient(api_key::String)::APIClient
  url = "https://www.alphavantage.co"
  headers = Dict("accept" => "application/json")
  price = APIResource{AssetPrice}(;
    url="$url/query",
    query_params=Dict(
      "function" => "TIME_SERIES_DAILY", "symbol" => "{symbol}", "apikey" => api_key
    ),
    parser=Parsers.AlphavantagePriceParser,
    headers=headers,
    max_retries=3,
    rank_order=2,
  )
  info = APIResource{AssetInfo}(;
    url="$url/query",
    query_params=Dict(
      "function" => "OVERVIEW", "symbol" => "{symbol}", "apikey" => api_key
    ),
    parser=Parsers.AlphavantageInfoParser,
    headers=headers,
    max_retries=3,
    rank_order=2,
  )
  exchange = APIResource{ExchangeRate}(;
    url="$url/query",
    query_params=Dict(
      "function" => "FX_DAILY",
      "from_symbol" => "{base}",
      "to_symbol" => "{target}",
      "apikey" => api_key,
    ),
    parser=Parsers.AlphavantageExchangeRateParser,
    headers=headers,
    max_retries=3,
    rank_order=2,
  )
  return APIClient(url, Dict("price" => price, "info" => info, "exchange" => exchange))
end

end
