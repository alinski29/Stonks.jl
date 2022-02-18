module APIClients

import Dates: Date
import ..Models: FinancialData, AssetPrice, AssetInfo
import ..Parsers

export APIClient, APIResource

abstract type DataClient end
abstract type AbstractAPIClient <: DataClient end

mutable struct APIResource{T <: FinancialData}
  url::String
  query_params::Dict{String, String}
  parser::Parsers.ContentParser
  headers::Dict{String, String}
  symbol_key::String
  max_batch_size::Integer
  max_retries::Integer
end
# constructor from kwargs
function APIResource{T}(;url = "", query_params = Dict(),
  parser = JSONParser(), headers=Dict(), symbol_key = "",
  max_batch_size=1, max_retries = 0) where {T <: FinancialData} 
  symbol_key = isempty(symbol_key) && max_batch_size > 1 ? "symbols" : "symbol"
  APIResource{T}(url, query_params, parser, headers, symbol_key, max_batch_size, max_retries)
end
get_type_param(x::APIResource{T}) where {T} = T

mutable struct APIClient <: DataClient
  url::String
  endpoints::Dict{String, APIResource}
  function APIClient(url, endpoints)
    new(url, endpoints)
  end
end
get_supported_types(client::APIClient) = [get_type_param(v) for (k, v) in client.endpoints]

function get_resource(client::APIClient, model::Type{T}) where {T <: FinancialData}
  first([r for (k, r) in client.endpoints if typeof(r) == APIResource{model}])
end

function YahooClient(api_key::String)::APIClient
  url = "https://yfapi.net"
  headers = Dict("accept" => "application/json", "X-API-KEY" => api_key)
  price = APIResource{AssetPrice}(
    url = "$url/v8/finance/spark",
    query_params = Dict("interval" => "{interval}", "range" => "{range}", "symbols" => "{symbols}"),
    parser = Parsers.YahooPriceParser,
    headers = headers,
    max_batch_size = 10,
    max_retries = 3
  )
  info = APIResource{AssetInfo}(
    url = "$url/v11/finance/quoteSummary/{symbol}",
    query_params = Dict("modules" => "assetProfile,quoteType,price"),
    parser = Parsers.YahooInfoParser,
    headers = headers,
    max_batch_size = 1,
    max_retries = 3
  )
  return APIClient(url, Dict(
    "price" => price,
    "info" => info,
    ))
end

end