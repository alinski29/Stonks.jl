using Chain: @chain
using Dates
using JSON3: JSON3
using Logging: @warn

using Stonks: JSONContent, APIResponseError, ContentParserError
using Stonks.Models: AssetPrice, AssetInfo, ExchangeRate, IncomeStatement, BalanceSheet

function parse_alphavantage_price(
  content::AbstractString; kwargs...
)::Union{Vector{AssetPrice},Exception}
  maybe_js = validate_alphavantage_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  key_data, key_meta = "Time Series (Daily)", "Meta Data"
  if !haskey(js, key_data)
    return ContentParserError("Did not find expected key: '$key_data'")
  end
  series = collect(js[key_data])
  if isempty(series)
    @warn("Response is valid, but contains no datapoints")
    return AssetPrice[]
  end
  len_original = length(series)
  ticker = js[key_meta]["2. Symbol"]
  key_price = "4. close"
  if (!haskey(first(values(js[key_data])), key_price))
    return ContentParserError("Did not find expected key: '$key_price'")
  end
  args = Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  series = @chain series begin
    isa(from, Date) ? filter(k -> Date(String(k[1])) >= from, _) : _
    isa(to, Date) ? filter(k -> Date(String(k[1])) <= to, _) : _
  end
  if isempty(series)
    @warn(
      "No datapoints between '$from' and '$to' after filtering. Original length: $len_original"
    )
    return AssetPrice[]
  end
  return [
    AssetPrice(;
      symbol=ticker,
      date=tryparse(Date, String(k)),
      close=tryparse(Float64, v["4. close"]),
      open=tryparse(Float64, v["1. open"]),
      high=tryparse(Float64, v["2. high"]),
      low=tryparse(Float64, v["3. low"]),
      volume=tryparse(Int64, v["5. volume"]),
    ) for (k, v) in series
  ]
end

function parse_alphavantage_info(
  content::AbstractString; kwargs...
)::Union{Vector{AssetInfo},Exception}
  maybe_js = validate_alphavantage_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  !haskey(js, "Symbol") && return ContentParserError("Key not found: 'Symbol'")
  !haskey(js, "Currency") && return ContentParserError("Key not found: 'Currency'")
  return [
    AssetInfo(;
      symbol=js["Symbol"],
      currency=js["Currency"],
      name=get(js, "Name", missing),
      type=get(js, "AssetType", missing),
      exchange=get(js, "Exchange", missing),
      country=get(js, "Country", missing),
      industry=titlecase(get(js, "Industry", missing)),
      sector=titlecase(get(js, "Sector", missing)),
    ),
  ]
end

function parse_alphavantage_exchange_rate(
  content::AbstractString; kwargs...
)::Union{Vector{ExchangeRate},Exception}
  maybe_js = validate_alphavantage_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  key_data, key_meta = "Time Series FX (Daily)", "Meta Data"
  if !haskey(js, key_data)
    return ContentParserError("Did not find expected key: '$key_data'")
  end
  series = collect(js[key_data])
  if isempty(series)
    @warn("Response is valid, but contains no datapoints")
    return ExchangeRate[]
  end
  original_len = length(series)
  args = Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  series = @chain series begin
    isa(from, Date) ? filter(k -> Date(String(k[1])) >= from, _) : _
    isa(to, Date) ? filter(k -> Date(String(k[1])) <= to, _) : _
  end
  if isempty(series)
    @warn "No datapoints between '$from' and '$to' after filtering. Original length = $original_len"
    return ExchangeRate[]
  end
  from_symbol, to_symbol = @chain js[key_meta] _["2. From Symbol"], _["3. To Symbol"]
  return [
    ExchangeRate(;
      base=from_symbol,
      target=to_symbol,
      date=tryparse(Date, String(k)),
      rate=tryparse(Float64, v["4. close"]),
    ) for (k, v) in series
  ]
end

function parse_alphavantage_financial_statement(
  ::Type{T}, content::AbstractString;
  symbol::Union{String,Missing},
  frequency::Union{String,Missing},
  from::Union{Date,Missing},
  to::Union{Date,Missing},
  remaps::Union{AbstractDict,Missing},
)::Union{Vector{T}, Exception} where {T<:AbstractStonksRecord}
  maybe_js = validate_alphavantage_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  smb = ismissing(symbol) ? get(js, :symbol, missing) : symbol
  keys_default = [:annualReports, :quarterlyReports]
  keys_exp = (
    if ismissing(frequency)
      keys_default
    elseif frequency in ["annual", "annualy", "year", "yearly"]
      [:annualReports]
    elseif frequency in ["quarter", "quarterly"]
      [:quarterlyReports]
    else 
      keys_default
    end
  )
  key_check = setdiff(keys_exp, keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  data = T[]
  for key in keys_exp
    js_vals = js[key]
    freq = key == :annualReports ? "yearly" : "quarterly"
    items = map(x -> begin 
      dval = js_to_dict(x)
      tryparse_js(
        T, dval; 
        fixed=Dict(:symbol => smb, :frequency => freq),
        remaps=remaps,
      ) 
    end, js_vals)
    append!(data, items)
  end
  original_len, latest_date = length(data), maximum(map(x -> x.fiscalDate, data))
  res = apply_filters(data, "fiscalDate"; from=from, to=to)
  if isempty(res) 
    @warn """No datapoints between '$from' and '$to' after filtering.
             Original length: $original_len. Latest date: $latest_date"""
    return T[]
  end
  return res
end

function parse_alphavantage_income_statement(
  content::AbstractString; kwargs...
)::Union{Vector{IncomeStatement},Exception}
  remaps = Dict(:fiscalDate => :fiscalDateEnding, :currency => :reportedCurrency)
  maybe_res = parse_alphavantage_financial_statement(
    IncomeStatement, content; 
    symbol=get(kwargs, :symbol, missing),
    frequency=get(kwargs, :frequency, missing),
    from=get(kwargs, :from, missing),
    to=get(kwargs, :to, missing),
    remaps=remaps,
  )
  typeof(maybe_res) <: Exception && return maybe_res
  return maybe_res
end

function parse_alphavantage_balance_sheet(
  content::AbstractString; kwargs...
)::Union{Vector{BalanceSheet},Exception}
  remaps = Dict(
    :fiscalDate => :fiscalDateEnding,
    :currency => :reportedCurrency,
    :cashAndCashEquivalents => :cashAndCashEquivalentsAtCarryingValue,
  )
  maybe_res = parse_alphavantage_financial_statement(
    BalanceSheet, content; 
    symbol=get(kwargs, :symbol, missing),
    frequency=get(kwargs, :frequency, missing),
    from=get(kwargs, :from, missing),
    to=get(kwargs, :to, missing),
    remaps=remaps,
  )
  typeof(maybe_res) <: Exception && return maybe_res
  return maybe_res
end


function validate_alphavantage_response(
  content::AbstractString
)::Union{JSONContent,Exception}
  maybe_js = JSON3.read(content)
  maybe_js === nothing && return ContentParserError("Content could not be parsed as JSON")
  js = maybe_js
  error_idx = findfirst(x -> contains(lowercase(x), "error"), [String(k) for k in keys(js)])
  error_in_response = error_idx !== nothing
  if error_in_response
    error_msg = [String(v) for (k, v) in js][error_idx]
    return APIResponseError(error_msg)
  end
  return js
end
