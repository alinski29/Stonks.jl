module Stonx

include("utils.jl")
include("errors.jl")
include("Models.jl")
include("Parsers.jl")
include("APIClients.jl")
include("Requests.jl")
include("curl.jl")
include("conversions.jl")
include("Datastores.jl")

using Stonx.Models 
using Stonx.Parsers
using Stonx.APIClients

export AbstractStonxRecord, AssetInfo, AssetPrice, ExchangeRate
export AbstractContentParser, JSONParser, parse_content
export YahooClient, AlphavantageJSONClient
export get_time_series, get_info, get_exchange_rate 
export to_dataframe

end
