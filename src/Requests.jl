"""
Collection of utilities for creating, validating and sending HTTP requests
"""
module Requests

using Base: @kwdef
using Chain: @chain
using Dates: Date, Day, today, days, unix2datetime
using HTTP: HTTP
using JSON3: JSON3
using Logging: @debug, @warn

using Stonks: UpdatableSymbol, Either, Success, Failure, RequestBuilderError
using Stonks: split_tickers_in_batches, get_minimum_dates
using Stonks.APIClients: APIResource, APIClient
using Stonks.Models: AbstractStonksRecord, AssetInfo, AssetPrice, ExchangeRate
using Stonks.Parsers: AbstractContentParser, parse_content

@kwdef struct RequestParams
  url::String
  tickers::Vector{UpdatableSymbol}
  headers::Dict{String,String} = Dict()
  params::Dict{String,String} = Dict()
  query::String = ""
  from::Union{Date,Missing} = missing
  to::Union{Date,Missing} = missing
end

"""
    prepare_requests(tickers, resource; kwargs...)

  Decides how many requests should be created based upon `resource.max_batch_size`. 
  After this step, for each request, the parameters with {param} are replaced by the value of the keyword argumets with the same name.
"""
function prepare_requests(
  tickers::Vector{UpdatableSymbol}, resource::APIResource; kwargs...
)::Union{Vector{RequestParams},Exception}
  requests = @chain begin
    tickers
    split_tickers_in_batches(_, resource.max_batch_size)
    map(t -> resolve_request_parameters(t, resource; kwargs...), _)
  end
  valid_requests = @chain requests filter(r -> isa(r, RequestParams), _)
  isempty(valid_requests) && return first(requests)
  length(valid_requests) != length(requests) &&
    return first(filter(r -> isa(r, RequestBuilderError), requests))
  #@debug "Prepared $(length(valid_requests)) requests for $(resource.url)), params -> $(map(r -> r.params, valid_requests))"
  return valid_requests
end

#"""
#    prepare_requests(tickers, provider; kwargs...)
#
#Prepares request for all all the API endpoints. It will run `prepare_requests(tickers, resource)` for each key of `provider.endpoints`. 
#"""
# function prepare_requests(tickers::Vector{UpdatableSymbol}, provider::APIClient; kwargs...)::Union{Dict{String,Vector{RequestParams}}, Exception}
#   requests = Dict(k => prepare_requests(tickers, resource; kwargs...) for (k, resource) in provider.endpoints)
#   # Requests: Dict{String, Vector{RequestParams}}
#   valid_requests = Dict()
#   for (k, reqs) in requests
#     if all([r -> isa(r, RequestParams) for r in reqs]) 
#        valid_requests[k] = reqs
#     end
#   end
#   #valid_requests = Dict(k => reqs for (k, reqs) in requests if all(map(r -> isa(r, RequestParams), reqs)))
#   println(valid_requests)
#   if isempty(valid_requests)
#     @warn "No valid requests"
#   end
#   first_failure = first([ first(reqs) for (k, reqs) in requests if any(map(r -> isa(r, RequestBuilderError), reqs))])
#   isempty(valid_requests) && return first_failure
#   diff = setdiff(keys(requests), keys(valid_requests))
#   if !isempty(diff)
#     @warn("The following resources have errors and were removed: $(join(diff, ','))")
#   end
#   _req_per_endpoint = [k => length(v) for (k, v) in valid_requests]
#   _total_req = sum([v for (k, v) in _req_per_endpoint])
#   @debug "Prepared a total of $(_total_req) requests: $(_req_per_endpoint)"
#   return requests
# end

function materialize_request(rp::RequestParams, parser::AbstractContentParser; kwargs...)
  @chain begin
    rp
    send_request
    extract_content
    deserialize_content(_, parser; kwargs...)
  end
end

"""
  resolve_request_parameters(tickers, resource; kwargs...)

Replaces all template values from `resource.headers` and `resouurce.params` with the concrete values passed as keyword arguments.
Puts all the resolved fields  into a RequestParams struct.
"""
function resolve_request_parameters(
  tickers::Vector{UpdatableSymbol}, resource::APIResource; kwargs...
)::Union{RequestParams,Exception}
  symbol_value = join(map(x -> x.ticker, tickers), ",")
  args = Dict(kwargs)
  from, to = get_minimum_dates(
    tickers; from=get(args, :from, missing), to=get(args, :to, missing)
  )
  kwargs_to_add = Dict()
  kwargs_to_add[:from] = from
  kwargs_to_add[:to] = to
  if haskey(resource.query_params, resource.symbol_key) || contains(resource.url, resource.symbol_key)
    kwargs_to_add[Symbol(resource.symbol_key)] = symbol_value
  end
  if length(tickers) == 1
    ticker = first(tickers)
    if !ismissing(ticker.fx_pair) && !haskey(resource.query_params, resource.symbol_key)
      base, target = ticker.fx_pair
      kwargs_to_add[:base] = base 
      kwargs_to_add[:target] = target
    end
  end
  kwargs_new = @chain merge(args, kwargs_to_add) filter(kw -> kw[1] !== :symbol_key, _)
  url_part = resolve_url_params(resource.url; symbol_key=symbol_value, kwargs_new...)
  query_params = resolve_query_params(resource.query_params, resource.url; kwargs_new...)
  validation = validate_parameter_substitution(url_part, query_params)
  isa(validation, RequestBuilderError) && return validation
  return RequestParams(;
    url=url_part,
    params=query_params,
    tickers=tickers,
    headers=resource.headers,
    query=join(["$k=$v" for (k, v) in query_params], "&"),
    from=from,
    to=to,
  )
end

function validate_parameter_substitution(url::String, query_params::Dict{String,String})
  pattern = r"(?<=\{).+?(?=\})"
  url_params_unsolved = match(pattern, url)
  if url_params_unsolved !== nothing
    return RequestBuilderError(
      "Couldn't substitute url parameter at $(url_params_unsolved.match)"
    )
  end
  query_params_unsolved = @chain begin
    [match(pattern, v) for (k, v) in query_params]
    filter(!isnothing, _)
    !isempty(_) ? map(m -> m.match, _) : []
  end
  if !isempty(query_params_unsolved)
    qp = join(query_params_unsolved, ", ")
    return RequestBuilderError("Couldn't substitute query parameters: '$qp'")
  end
end

function send_request(
  req::RequestParams, retries::Integer=3
)::Either{HTTP.Response,Exception}
  try
    resp = HTTP.request(
      "GET", req.url; headers=req.headers, query=req.query, retries=retries
    )
    if resp.status != 200
      return HTTP.StatusError(resp.status, resp)
    end
    return Success(resp)
  catch err
    return Failure(HTTP.Response, err)
  end
end

function extract_content(
  r::Either{HTTP.Response,Exception}
)::Either{String,Exception}
  !isa(r.value, HTTP.Response) && return r.err
  try
    content = String(r.value.body)
    # @TODO: Add checks on content length
    return Success(content)
  catch err
    return Failure(typeof(err), err)
  end
end

function deserialize_content(
  c::Either{String,Exception}, parser::AbstractContentParser; kwargs...
)
  !isa(c.value, String) && return c.err
  content = c.value
  try
    return Success(parse_content(parser, content; kwargs...))
  catch err
    return Failure(typeof(err), err)
  end
end

function resolve_query_params(
  params::Dict{String,String}, url::AbstractString=""; kwargs...
)::Dict{String,String}
  pattern = r"(?<=\{).+?(?=\})"
  keys_to_resolve = [k for (k, v) in params if match(pattern, v) !== nothing]
  isempty(keys_to_resolve) && return params
  params_new = Dict()
  # insert values that don't need to be resolved
  [params_new[k] = v for (k, v) in params if match(pattern, v) === nothing]
  args = Dict(kwargs)
  for key in keys_to_resolve
    mutated_value = params[key]
    for m in eachmatch(pattern, params[key])
      kwarg_key = replace(m.match, r"[{}]" => "") # {param} => param
      kwarg_value = get(args, Symbol(kwarg_key), missing)
      if !ismissing(kwarg_value)
        new_value = replace_params_with_kwargs(
          kwarg_value, pattern; Dict(Symbol(kwarg_key) => kwarg_value)...
        )
        mutated_value = replace(mutated_value, "{$kwarg_key}" => new_value)
      end
    end
    params_new[key] = mutated_value
  end
  args = Dict(kwargs)
  specific_params = resolve_specific_query_params(
    url; from=get(args, :from, missing), to=get(args, :to, missing)
  )
  return merge(params_new, specific_params)
end

function resolve_url_params(url::AbstractString; kwargs...)
  return replace_params_with_kwargs(url, r"(?<=\{).+?(?=\})"; kwargs...)
end

function resolve_specific_query_params(url::AbstractString; from=missing, to=missing)
  specific_params = Dict()
  default_date = Date(unix2datetime(0)) # or Dates.today() - Dates.Day(28) ?
  if contains(url, "alphavantage")
    dt_from = isa(from, Date) ? from : default_date
    specific_params["outputsize"] = dt_from > today() - Day(99) ? "compact" : "full"
  end
  if contains(url, "yfapi")
    max_date = isa(from, Date) ? from : default_date
    specific_params["range"] = convert_date_to_range_expr(max_date)
  end
  return specific_params
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
  return new_s
end

function convert_date_to_range_expr(end_date::Date)
  days_delta = days(today() - end_date)
  in(days_delta, 0:1) && return "1d"
  in(days_delta, 2:5) && return "5d"
  in(days_delta, 6:28) && return "1mo"
  in(days_delta, 29:88) && return "3mo"
  in(days_delta, 89:179) && return "6mo"
  in(days_delta, 180:364) && return "1y"
  in(days_delta, 365:1820) && return "5y"
  return "5y"
end

"""
What to do when there are multiple requests, some succesfull, but some failed. 
  - optimistic approach => if at least one request succedes, return a Vector{AbstractStonksRecord},
    but print warnings for all requests which failed
"""
function optimistic_request_resolution(
  ::Type{T}, c::Channel
)::Union{Vector{T},Exception} where {T<:AbstractStonksRecord}
  result = T[]
  failures = Exception[]
  for response in c
    if response.err !== nothing
      @warn "Request to: $(response.params.url) failed. Error: $(typeof(response.err))"
      push!(failures, response.err)
    else
      append!(result, response.value)
    end
  end
  if !isempty(result)
    return result
  end
  return first(failures)
end

end