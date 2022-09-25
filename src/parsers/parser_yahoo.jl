using Chain: @chain
using Dates
using JSON3: JSON3

using Stonks: JSONContent, APIResponseError, ContentParserError
using Stonks.Models: 
  AssetPrice,
  AssetInfo, 
  ExchangeRate, 
  IncomeStatement, 
  BalanceSheet, 
  CashflowStatement, 
  Earnings

function parse_yahoo_info(
  content::AbstractString; kwargs...
)::Union{Vector{AssetInfo},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_quote_summary_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  key_check = setdiff([:quoteType, :price], keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  res = (
    assetProfile=get(js, "assetProfile", Dict()),
    quoteType=get(js, "quoteType", Dict()),
    price=get(js, "price", Dict()),
  )
  return [
    AssetInfo(;
      symbol=res.quoteType["symbol"],
      currency=res.price["currency"],
      name=get(res.quoteType, "longName", missing),
      type=get(res.quoteType, "quoteType", missing),
      exchange=get(res.quoteType, "exchange", missing),
      country=get(res.assetProfile, "country", missing),
      industry=get(res.assetProfile, "industry", missing),
      sector=get(res.assetProfile, "sector", missing),
      timezone=get(res.quoteType, "timeZoneFullName", missing),
      employees=get(res.assetProfile, "fullTimeEmployees", missing),
    ),
  ]
end

function parse_yahoo_price(
  content::AbstractString; kwargs...
)::Union{Vector{AssetPrice},Exception}
  maybe_js = validate_yahoo_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  args = Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  prices = @chain js begin
    [parse_price_record(v) for (k, v) in _]
    filter(x -> isa(x, Vector{AssetPrice}), _)
  end
  if isempty(prices)
    return ContentParserError("Couldn't constrct Vector{AssetPrice} from the json object")
  end
  return @chain prices begin
    isa(from, Date) ? map(price -> filter(row -> row.date >= from, price), _) : _
    isa(to, Date) ? map(price -> filter(row -> row.date <= to, price), _) : _
    vcat(_...)
    unique
  end
end

function parse_yahoo_exchange_rate(
  content::AbstractString; kwargs...
)::Union{Vector{ExchangeRate},Exception}
  maybe_js = validate_yahoo_response(content)
  typeof(maybe_js) <: Exception && return maybe_js
  js, args = maybe_js, Dict(kwargs)
  from, to = get(args, :from, missing), get(args, :to, missing)
  rates = @chain js begin
    [parse_exchange_record(v) for (k, v) in _]
    filter(x -> isa(x, Vector{ExchangeRate}), _)
  end
  if isempty(rates)
    return ContentParserError("Couldn't constrct Vector{ExchangeRate} from the json object")
  end
  return @chain rates begin
    isa(from, Date) ? map(xrate -> filter(row -> row.date >= from, xrate), _) : _
    isa(to, Date) ? map(xrate -> filter(row -> row.date <= to, xrate), _) : _
    vcat(_...)
    unique
  end
end

function parse_yahoo_income_statement(
  content::AbstractString; kwargs...
)::Union{Vector{IncomeStatement},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_quote_summary_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  from, to = [get(kwargs, arg, missing) for arg in [:from, :to]]
  frequency = get(kwargs, :frequency, missing)
  symbol = get(kwargs, :symbol, missing)
  keys_default = [:incomeStatementHistory, :incomeStatementHistoryQuarterly]
  currency = extract_currency(js)
  keys_exp = (
    if ismissing(frequency)
      keys_default
    elseif frequency in ["annual", "annualy", "year", "yearly"]
      [:incomeStatementHistory]
    elseif frequency in ["quarter", "quarterly"]
      [:incomeStatementHistoryQuarterly]
    else
      keys_default
    end
  )
  key_check = setdiff(keys_exp, keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  for key in keys_exp
    if !haskey(js[key], :incomeStatementHistory)
      return ContentParserError("Missing keys js[$key][:incomeStatementHistory]")
    end
  end
  remaps = Dict(
    :selling_general_and_administrative => :selling_general_administrative,
    :research_and_development => :research_development,
    :net_income_common_shares => :net_income_applicable_to_common_shares,
  )
  data = IncomeStatement[]
  for key in keys_exp
    js_vals = js[key][:incomeStatementHistory]
    dvals = map(x -> begin
      dval = js_to_dict(x; to_snake_case=true)
      dval[:date] = Date(unix2datetime(dval[:end_date]))
      dval[:interest_expense] = abs(get(dval, :interest_expense, missing))
      if !ismissing(currency) 
        dval[:currency] = currency
      end
      dval
    end, js_vals)
    freq = key == :incomeStatementHistory ? "yearly" : "quarterly"
    is = map(
      obj -> tryparse_js(
        IncomeStatement, obj;
        fixed=Dict(:symbol => symbol, :frequency => freq),
        remaps=remaps,
      ),
      dvals,
    )
    append!(data, is)
  end
  original_len, latest_date = length(data), maximum(map(x -> x.date, data))
  res = apply_filters(data, "date"; from=from, to=to)
  if isempty(res)
    @warn """No datapoints between '$from' and '$to' after filtering.
             Original length: $original_len. Latest date: $latest_date"""
    return IncomeStatement[]
  end
  return res
end

function parse_yahoo_balance_sheet(
  content::AbstractString; kwargs...
)::Union{Vector{BalanceSheet},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_quote_summary_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  from, to = [get(kwargs, arg, missing) for arg in [:from, :to]]
  frequency = get(kwargs, :frequency, missing)
  symbol = get(kwargs, :symbol, missing)
  keys_default = [:balanceSheetHistory, :balanceSheetHistoryQuarterly]
  currency = extract_currency(js)
  keys_exp = (
    if ismissing(frequency)
      keys_default
    elseif frequency in ["annual", "annualy", "year", "yearly"]
      [:balanceSheetHistory]
    elseif frequency in ["quarter", "quarterly"]
      [:balanceSheetHistoryQuarterly]
    else
      keys_default
    end
  )
  key_check = setdiff(keys_exp, keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  for key in keys_exp
    if !haskey(js[key], :balanceSheetStatements)
      return ContentParserError("Missing keys js[$key][:balanceSheetStatements]")
    end
  end
  remaps = Dict(
    :cash_and_equivalents => :cash,
    :current_net_receivables => :net_receivables,
    :current_accounts_payable => :accounts_payable,
    :other_current_liabilities => :other_current_liab,
    :total_liabilities => :total_liab,
    :total_shareholder_equity => :total_stockholder_equity,
  )
  data = BalanceSheet[]
  for key in keys_exp
    js_vals = js[key][:balanceSheetStatements]
    dvals = map(
      x -> begin
        dval = js_to_dict(x; to_snake_case=true)
        ks = [
          :intangible_assets,
          :goodwill,
          :treasury_stock,
          :other_stockholder_equity,
          :long_term_debt,
          :long_term_debt_noncurrent,
        ]
        for k in ks
          if haskey(dval, k)
            dval[k] = !isa(dval[k], Int64) ? tryparse(Int64, dval[k]) : dval[k]
          else 
            dval[k] = missing
          end
        end
        dval[:date] = Date(unix2datetime(dval[:end_date]))
        dval[:currency] = currency
        dval[:intangible_assets] = dval[:intangible_assets] + dval[:goodwill]
        dval[:treasury_stock] =
          abs(dval[:treasury_stock]) - abs(dval[:other_stockholder_equity])
        dval[:long_term_debt_noncurrent] = dval[:long_term_debt]
        delete!(dval, :long_term_debt)
        [delete!(dval, k) for (k, v) in dval if ismissing(v)]
        dval
      end,
      js_vals,
    )
    freq = key == :balanceSheetHistory ? "yearly" : "quarterly"
    bs = map(
      obj -> tryparse_js(
        BalanceSheet,obj;
        fixed=Dict(:symbol => symbol, :frequency => freq),
        remaps=remaps,
      ),
      dvals,
    )
    append!(data, bs)
  end
  original_len, latest_date = length(data), maximum(map(x -> x.date, data))
  res = apply_filters(data, "date"; from=from, to=to)
  if isempty(res)
    @warn """No datapoints between '$from' and '$to' after filtering.
             Original length: $original_len. Latest date: $latest_date"""
    return BalanceSheet[]
  end
  return res
end

function parse_yahoo_cashflow_statement(
  content::AbstractString; kwargs...
)::Union{Vector{CashflowStatement},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_quote_summary_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  from, to = [get(kwargs, arg, missing) for arg in [:from, :to]]
  frequency = get(kwargs, :frequency, missing)
  symbol = get(kwargs, :symbol, missing)
  keys_default = [:cashflowStatementHistory, :cashflowStatementHistoryQuarterly]
  currency = extract_currency(js)
  keys_exp = (
    if ismissing(frequency)
      keys_default
    elseif frequency in ["annual", "annualy", "year", "yearly"]
      [first(keys_default)]
    elseif frequency in ["quarter", "quarterly"]
      [last(keys_default)]
    else
      keys_default
    end
  )
  key_check = setdiff(keys_exp, keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  for key in keys_exp
    if !haskey(js[key], :cashflowStatements)
      return ContentParserError("Missing keys js[$key][:cashflowStatements]")
    end
  end
  remaps = Dict(
    :operating_cashflow => :total_cash_from_operating_activities,
    :change_operating_liabilities => :change_to_liabilities,
    :depreciation_and_amortization => :depreciation,
    :change_receivables => :change_to_account_receivables,
    :change_inventory => :change_to_inventory,
    :cashflow_investment => :total_cashflows_from_investing_activities,
    :cashflow_financing => :total_cash_from_financing_activities,
    :dividend_payout => :dividends_paid,
    :stock_repurchase => :repurchase_of_stock,
  )
  data = CashflowStatement[]
  for key in keys_exp
    js_vals = js[key][:cashflowStatements]
    dvals = map(x -> begin
      dval = js_to_dict(x; to_snake_case=true)
      ks = [
        :change_in_cash,
        :effect_of_exchange_rate,
        :capital_expenditures,
        :change_to_account_receivables,
        :change_to_inventory, 
        :dividends_paid
      ]
      for k in ks
        if haskey(dval, k)
          dval[k] = !isa(dval[k], Int64) ? tryparse(Int64, dval[k]) : dval[k]
        else 
          dval[k] = missing
        end
      end
      dval[:date] = Date(unix2datetime(dval[:end_date]))
      dval[:currency] = currency
      dval[:change_cash_and_equivalents] = dval[ks[1]] - dval[ks[2]]
      inv_sign = [:capital_expenditures, :change_to_account_receivables,
                  :change_to_inventory, :dividends_paid]
      [dval[k] = -dval[k] for k in inv_sign]
      dval
    end, js_vals)
    freq = key == first(keys_default) ? "yearly" : "quarterly"
    items = map(
      obj -> tryparse_js(
        CashflowStatement, obj;
        fixed=Dict(:symbol => symbol, :frequency => freq),
        remaps=remaps,
      ),
    dvals,
    )
    append!(data, items)
  end
  original_len, latest_date = length(data), maximum(map(x -> x.date, data))
  res = apply_filters(data, "date"; from=from, to=to)
  if isempty(res)
    @warn """No datapoints between '$from' and '$to' after filtering.
             Original length: $original_len. Latest date: $latest_date"""
    return CashflowStatement[]
  end
  return res
end

function parse_yahoo_earnings(
  content::AbstractString; kwargs...
)::Union{Vector{Earnings},Exception}
  maybe_js = @chain begin
    content
    validate_yahoo_response
    unpack_quote_summary_response
  end
  typeof(maybe_js) <: Exception && return maybe_js
  js = maybe_js
  from, to = [get(kwargs, arg, missing) for arg in [:from, :to]]
  frequency = get(kwargs, :frequency, missing)
  if !ismissing(frequency) && frequency in ["yearly", "annualy", "year", "annual"]
    @warn "'$frequency' frequency not available for this resource, only 'quarterly'."
    return Earnings[]
  end
  symbol = get(kwargs, :symbol, missing)
  keys_exp = [:earningsHistory]
  currency = extract_currency(js)
  key_check = setdiff(keys_exp, keys(js))
  if !isempty(key_check)
    return ContentParserError("Missing keys: $(join(key_check, ","))")
  end
  for key in keys_exp
    if !haskey(js[key], :history)
      return ContentParserError("Missing keys js[$key][:history]")
    end
  end
  remaps = Dict(
    :actual => :eps_actual,
    :estimate => :eps_estimate,
  )
  data = Earnings[]
  for key in keys_exp
    js_vals = js[key][:history]
    dvals = filter(j -> !ismissing(j) ,map(x -> begin
        dval = js_to_dict(x; to_snake_case=true)
        dval[:date] = !ismissing(dval[:quarter]) ? Date(unix2datetime(dval[:quarter])) : missing
        dval[:currency] = currency
        ismissing(dval[:date]) ? missing : dval
      end, js_vals))
    if !isempty(dvals)
      items = [tryparse_js(Earnings, obj; fixed=Dict(:symbol => symbol, :frequency => "quarterly"), remaps = remaps) for obj in dvals]  
      append!(data, items)
    end 
  end
  original_len, latest_date = length(data), maximum(map(x -> x.date, data))
  res = apply_filters(data, "date"; from=from, to=to)
  if isempty(res)
    @warn """No datapoints between '$from' and '$to' after filtering.
             Original length: $original_len. Latest date: $latest_date"""
    return Earnings[]
  end
  return res
end

function extract_currency(js::JSONContent)
  if haskey(js, :price)
    return (haskey(js[:price], :currency) ? js[:price][:currency] : missing)
  else
    return missing
  end
end

function parse_price_record(js_value::JSONContent)::Union{Vector{AssetPrice},Nothing}
  _keys = [String(k) for k in keys(js_value)]
  if !isempty(setdiff(["symbol", "timestamp", "close"], _keys))
    return nothing
  end
  isempty(js_value["timestamp"]) && return nothing
  nrows = length(js_value["timestamp"])
  ticker = js_value["symbol"]
  return [
    AssetPrice(;
      symbol=ticker,
      date=Date(unix2datetime(js_value["timestamp"][i])),
      close=Float64(js_value["close"][i]),
    ) for i in 1:nrows
  ]
end

function parse_exchange_record(js_value::JSONContent)::Union{Vector{ExchangeRate},Nothing}
  _keys = [String(k) for k in keys(js_value)]
  if !isempty(setdiff(["symbol", "timestamp", "close"], _keys))
    return nothing
  end
  isempty(js_value["timestamp"]) && return nothing
  nrows = length(js_value["timestamp"])
  base, target = @chain js_value begin
    replace(_["symbol"], "=X" => "")
    (_[1:3], _[4:length(_)])
  end
  return [
    ExchangeRate(;
      base=base,
      target=target,
      date=Date(unix2datetime(js_value["timestamp"][i])),
      rate=Float64(js_value["close"][i]),
    ) for i in 1:nrows
  ]
end

function validate_yahoo_response(content::AbstractString)::Union{JSONContent,Exception}
  maybe_js = JSON3.read(content)
  maybe_js === nothing && return error("Content could not be parsed as JSON")
  js_keys = keys(maybe_js)
  js = length(js_keys) == 1 ? maybe_js[first(js_keys)] : maybe_js
  error_idx = findfirst(x -> contains(lowercase(x), "error"), [String(k) for k in keys(js)])
  error_in_response = error_idx !== nothing ? isa(js["error"], JSON3.Object) : false
  if error_in_response
    error_msg = "Response contains an error"
    if haskey(js, :error)
      if isa(js[:error], JSON3.Object)
        error_msg = js[:error][first(keys(js[:error]))]
      elseif isa(js[:error], String)
        error_msg = js[:error]
      end
    end
    return APIResponseError(error_msg)
  end
  # In case the response has only 1 key, return the original response, not the one inside the key
  return maybe_js
end

function unpack_quote_summary_response(js::Union{JSON3.Object,Exception})
  !isa(js, JSON3.Object) && return js
  !in("quoteSummary", keys(js)) &&
    return ContentParserError("expected key 'quoteSummary' not found in API response")
  js["quoteSummary"]["error"] !== nothing &&
    return APIResponseError("API response contains error")
  res = js["quoteSummary"]["result"]
  return length(res) == 1 ? first(res) : res
end
