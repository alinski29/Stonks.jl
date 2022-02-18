import Pipe: @pipe

import Stonx: UpdatableSymbol
import ..APIClients: APIClient, APIResource, get_resource
import ..Models: FinancialData, AssetPrice, AssetInfo
import ..Parsers: ContentParser
import ..Requests: optimistic_request_resolution, prepare_requests, materialize_request

"""
Interaces:

# general function that is called by other functions
- get_data(tickers::Vector{UpdatableSymbol}, resource::APIResource{T}) -> Vector{T}
  

### PRICES => [AssetPrice]
- get_time_series(client, symbol, from, to, interval)
- get_time_series(client, symbols, from, to, interval)
- get_time_series(client, [(symbol1, date_start), (symbol2, date_start)], from, to, interval)
- get_time_series(client, [(symbol1, date_start, date_end), (symbol2, date_start, date_end)], from, to, interval)

### COMPANY OVERVIEW => [AssetInfo]
- get_info(client, symbol)  
- get_info(client, symbols)  


### get_all_data(client, symbol) => Dict{String, FinancialData}
"""

function get_time_series(client::APIClient, symbol::AbstractString, model::Type{T} = AssetPrice
                         ;interval = "1d", from = Dates.today() - Dates.Day(7), to = missing, kwargs...) where {T <: FinancialData}
  resource = get_resource(client, model)
  get_data(resource, [UpdatableSymbol(symbol)], interval=interval, from=from, to=to, kwargs...)
end

function get_time_series(client::APIClient, symbols::Vector{String}, model::Type{T} = AssetPrice
                         ;interval = "1d", from = Dates.today() - Dates.Day(7), to = missing, kwargs...) where {T <: FinancialData}
  resource = get_resource(client, model)
  tickers = map(x -> UpdatableSymbol(x, from=from, to=to), symbols)
  get_data(resource, tickers, interval=interval, from=from, to=to, kwargs...)
end

function get_time_series(client::APIClient, symbols::Vector{Tuple{String, Date}}, model::Type{T} = AssetPrice
                         ;interval = "1d", to = missing, kwargs...) where {T <: FinancialData}
  resource = get_resource(client, model)
  tickers = map(x -> UpdatableSymbol(x[1], from=x[2], to=to), symbols)
  get_data(resource, tickers, interval=interval, to=to, kwargs...)
end

function get_time_series(client::APIClient, symbols::Vector{Tuple{String, Date, Date}}, model::Type{T} = AssetPrice
                         ;interval = "1d", kwargs...) where {T <: FinancialData}
  resource = get_resource(client, model)
  tickers = map(x -> UpdatableSymbol(x[1], from=x[2], to=x[3]), symbols)
  get_data(resource, tickers, interval=interval, kwargs...)
end

function get_info(client::APIClient, symbol::AbstractString, model::Type{T} = AssetInfo) where {T <: FinancialData}
  resource = get_resource(client, model)
  get_data(resource, [UpdatableSymbol(symbol)])
end

function get_info(client::APIClient, symbols::Vector{String}, model::Type{T} = AssetInfo) where {T <: FinancialData}
  resource = get_resource(client, model)
  get_data(resource, map(UpdatableSymbol, symbols))
end

function get_data(resource::APIResource, tickers::Vector{UpdatableSymbol}; kwargs...)::Union{Vector{FinancialData}, Exception}
    requests = prepare_requests(tickers, resource; kwargs...) 
    responses = Channel(length(requests))
    @sync begin 
      for rp in requests
        @Threads.spawn begin
        res = materialize_request(rp, resource.parser; from=rp.from)
        push!(responses, (params = rp, err = res.err, value = res.value))
      end
      end
    end
    close(responses)
    optimistic_request_resolution(responses)
end

function get_data(client::APIClient, tickers::Vector{UpdatableSymbol})::Dict{String, Union{Vector{FinancialData}, Exception}}
  responses = Channel(length(client.endpoints))
  @sync begin 
    for (k, resource) in client.endpoints
      @Threads.spawn begin
        resp = get_data(resource, tickers)
        push!(responses, (endpoint=k, value=resp))
      end
    end
  end
  close(responses)
  collect_results(responses)
end

function collect_results(c::Channel)
  result = Dict()
  for item in c
    has_value = isa(item.value, Vector{FinancialData})
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