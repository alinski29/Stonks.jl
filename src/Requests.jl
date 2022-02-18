"""
Collection of utilities for working with Requests data
"""
module Requests

import Stonx: Either, Success, Failure, JSONContent, UpdatableSymbol, split_tickers_in_batches
import ..APIClients: APIResource, APIClient
import ..Models: FinancialData, AssetPrice
import ..Parsers: ContentParser, parse_content

import JSON3, HTTP
import Logging: @info, @debug, @warn
import Pipe: @pipe

using Dates

struct RequestParams
  url::String
  tickers::Vector{UpdatableSymbol}
  headers::Dict{String, String}
  params::Dict{String, String}
  query::String
  from::Union{Date, Missing}
  to::Union{Date, Missing}
end

function RequestParams(; url, tickers, headers = Dict(), params = Dict(), query = "", from = missing, to = missing)
  RequestParams(url, tickers, headers, params, query, from, to)
end

"""
Prepares requests for a specific APIResource (endppoint). 
Returns a Vector{RequestParams}.
"""
function prepare_requests(tickers::Vector{UpdatableSymbol}, resource::APIResource; kwargs...) :: Vector{RequestParams}
  requests = @pipe tickers |>
    split_tickers_in_batches(_, resource.max_batch_size) |>
    map(t -> resolve_request_parameters(t, resource; kwargs... ), _)
  @info "Prepared $(length(requests)) requests for $(resource.url)), params -> $(map(r -> r.params, requests))"
  requests
end

"""
Prepares request for all all the API endpoints. 
Returns a Dict{String, Array{RequestParams}}, where each key is the name of an APIResource (endpoint).
"""
function prepare_requests(tickers::Vector{UpdatableSymbol}, provider::APIClient; kwargs...) :: Dict{String, Vector{RequestParams}}
  requests = Dict(k => prepare_requests(tickers, resource; kwargs...) for (k, resource) in provider.endpoints)
  _req_per_endpoint = [k => length(v) for (k, v) in requests]
  _total_req = sum([v for (k, v) in _req_per_endpoint])
  @info "Prepared a total of $(_total_req) requests: $(_req_per_endpoint)"
  return requests
end

function materialize_request(rp:: RequestParams, parser::ContentParser; kwargs...)#::Either{Vector{FinancialData}, Exception}
  @pipe send_request(rp) |> # Either{HTTP.Response, Exception}
    extract_content(_) |> # Either{String, Exception} 
    deserialize_content(_, parser; kwargs...) # Either{Array{FinancialData}, Exception}
end

function resolve_request_parameters(tickers::Vector{UpdatableSymbol}, resource::APIResource; kwargs...) :: RequestParams
  symbol_value =  join(map(x -> x.ticker, tickers), ",")
  dates_from = @pipe tickers |> map(x -> x.from, _) |> skipmissing 
  dates_to = @pipe tickers |> map(x -> x.to, _) |> skipmissing 
  args = Dict(kwargs)
  from = isempty(dates_from) ? get(args, :from, missing) : minimum(dates_from)
  to = isempty(dates_to) ? get(args, :to, missing) : minimum(dates_to)
  kwargs_new = @pipe merge(args, Dict(
    Symbol(resource.symbol_key) => symbol_value,
    :from => from,
    :to => to
  )) |> filter(kw -> kw[1] !== :symbol_key ,_)
  url_part = resolve_url_params(resource.url; symbol_key=symbol_value, kwargs_new...)
  query_params = resolve_query_params(resource.query_params, resource.url; kwargs_new...)
  return RequestParams(
    url=url_part,
    params=query_params, 
    tickers=tickers, 
    headers=resource.headers,
    query= join(["$k=$v" for (k, v) in query_params], "&"),
    from=from,
    to=to
  )
end

function send_request(req:: RequestParams, retries::Int=3) :: Either{HTTP.Response, Exception}
  try 
    resp = HTTP.request("GET", req.url, headers=req.headers, query=req.query, require_ssl_verification=false, retry=retries>0, retries=3)
    if resp.status != 200 
      return HTTP.StatusError(resp.status, "GET", req.url, resp)
    end
    return resp
  catch err
    return err
  end
end

function extract_content(r::Either{HTTP.Response, Exception})::Either{AbstractString, Exception}
  !isa(r.value, HTTP.Response) && return r.err
  try
    content = String(r.value.body)
    # @TODO: Add checks on content length
    return Success(content)
  catch err
    return Failure(typeof(err), err)
  end
end

function deserialize_content(c::Either{AbstractString, Exception}, parser::ContentParser; kwargs...)#::Either{Vector{FinancialData}, Exception}
  !isa(c.value, String) && return c.err
  content = c.value
  try
    return Success(parse_content(parser, content; kwargs...))
  catch err 
    return Failure(typeof(err), err)
  end
end

function resolve_query_params(params::Dict{String, String}, url::AbstractString=""; kwargs...)::Dict{String, String} 
  pattern = r"(?<=\{).+?(?=\})"
  keys_to_resolve = [k for (k, v) in params if match(pattern, v) !== nothing]
  isempty(keys_to_resolve) && return params
  params_new = Dict()
  # insert values that don't need to be resolved
  [params_new[k] = v for (k, v) in params if match(pattern, v) === nothing]
  for key in keys_to_resolve
    kwargs_to_resolve = filter(kw -> String(kw[1]) == key, kwargs)
    if !isempty(kwargs_to_resolve)
      params_new[key] = replace_params_with_kwargs(params[key], pattern; kwargs_to_resolve...)
    end
  end
  args = Dict(kwargs)
  specific_params = resolve_specific_query_params(
    url, 
    from=get(args, :from, missing), 
    to=get(args, :to, missing)
  )
  merge(params_new, specific_params)
end

# TODO: Throw exception if the string still has unresolved parameters
function resolve_url_params(url::AbstractString; kwargs...)
  replace_params_with_kwargs(url, r"(?<=\{).+?(?=\})"; kwargs...)
end

function resolve_specific_query_params(url::AbstractString; from=missing, to=missing)
  specific_params = Dict()
  if contains(url, "alphavantage") && length(tickers) > 1
    specific_params["outputsize"] = isa(first(tickers).from, Date) ? "compact" : "full"
  end
  if contains(url, "yfapi")
    default_dete = Date(unix2datetime(0)) #Dates.today() - Dates.Day(28)
    max_date = isa(from, Date) ? from :  default_dete
    specific_params["range"] = convert_date_to_range_expr(max_date)
  end
  specific_params
end

function replace_params_with_kwargs(s::AbstractString, pattern::Regex; kwargs...)
  new_s = s
  for (k, v) in kwargs
    for m in eachmatch(pattern, s)
      if m.match == String(k)
        new_s = replace(new_s, "{$(m.match)}" => v)
      end
    end
  end
  new_s
end

function convert_date_to_range_expr(end_date::Date)
  days_delta = Dates.days(Dates.today() - end_date)
  in(days_delta, 0:1) && return "1d"
  in(days_delta, 2:5) && return "5d"
  in(days_delta, 6:28) && return "1mo"
  in(days_delta, 29:88) && return "3mo"
  in(days_delta, 89:179) && return "6mo"
  in(days_delta, 180:364) && return "1y"
  in(days_delta, 365:1820) && return "5y"
  "5y"
end

# TODO: Test this
function optimistic_request_resolution(c::Channel)::Union{Vector{FinancialData}, Exception}
    # responses:: Vector{Either{Vector{FinancialData}, Exception}}
    # what to do when one reqest fails, but others succeed? 
    # optimistic approach => if at least one request succedes, return a Vector{FinancialData}, but print warnings for all requests which failed
    # pesimistic approach => if one request fails, return an Exception
    result = Vector{FinancialData}()
    failures = Vector{Exception}()
    for response in c 
      if response.err !== nothing
        @warn "Request to: $(response.params.url) failed. Error: $(typeof(response.err))"
        #append!(failures, response.err)
        push!(failures, response.err)
      else
        #push!(result, response.value)
        append!(result, response.value)
      end
    end
    if !isempty(result)
      return result
    end
    return first(failures)
end
end