module Stonks

include("utils.jl")
include("errors.jl")
include("Models.jl")
include("Parsers.jl")
include("APIClients.jl")
include("Requests.jl")
include("curl.jl")
include("conversions.jl")
include("Stores.jl")

using Stonks.Models
using Stonks.Parsers
using Stonks.APIClients
using Stonks.Stores

export AbstractStonksRecord,
  AssetInfo,
  AssetPrice,
  ExchangeRate,
  BalanceSheet,
  IncomeStatement,
  CashflowStatement,
  Earnings
export AlphavantageJSONClient, YahooClient
export get_price,
  get_info,
  get_exchange_rate,
  get_balance_sheet,
  get_income_statement,
  get_cashflow_statement,
  get_earnings,
  get_data
  to_dict,
  to_table
export FileStore, load, save, update

end
