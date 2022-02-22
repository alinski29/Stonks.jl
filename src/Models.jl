"""
Modules defining data structues
"""

module Models

import Base: @kwdef
import Dates: Date

export FinancialData, AssetInfo, AssetPrice, ExchangeRate, EconomicIndicator

abstract type FinancialData end

@kwdef struct AssetInfo <: FinancialData
  symbol::String
  currency::String
  name::Union{String,Missing} = missing 
  type::Union{String,Missing} = missing
  exchange::Union{String,Missing} = missing
  country::Union{String,Missing} = missing
  industry::Union{String,Missing} = missing
  sector::Union{String,Missing} = missing
  timezone::Union{String,Missing} = missing
  employees::Union{Int64,Missing} = missing
end

@kwdef struct AssetPrice <: FinancialData
  symbol::String
  date::Date
  close::Float64
  open::Union{Float64,Missing} = missing
  high::Union{Float64,Missing} = missing
  low::Union{Float64,Missing} = missing
  close_adjusted::Union{Float64,Missing} = missing
  volume::Union{Float64,Missing} = missing
end

@kwdef struct ExchangeRate <: FinancialData
  from::String
  to::String
  date::Date
  rate::Float64
end

struct EconomicIndicator <: FinancialData
  symbol::String
  name::String
  date::Date
  value::Date
end

# abstract type Transaction end
#
# struct Deposit <: Transaction
#   date::Date
#   currency::String
#   amount::Float64
# end
#
# struct CurrencyExchange <: Transaction
#   date::Date
#   from::String
#   to::String
#   rate::Float64
# end
#
#
#
# struct Buy <: Transaction
#   date::Date
#   asset::String
#   shares::Int64
#   share_price::Float64
#   comission::Float64
#   currency::String
#   amount::Float64
#   function Buy(date::Date, asset::String, shares::Int64, share_price::Float64, comission::Float64 = 0.0, currency::String = "USD")
#     return new(date, asset, shares, share_price, comission, currency, shares * share_price)
#   end
# end
#
# struct Sell <: Transaction
#   date::Date
#   asset::String
#   shares::Int64
#   share_price::Float64
#   commission::Float64
#   amount::Float64
#   function Sell(date::Date, asset::String, shares::Int64, share_price::Float64, comission::Float64 = 0.0)
#     return new(date, asset, shares, share_price, comission, shares * share_price)
#   end
# end
#
#
# struct Portfolio
#   name::String
#   holdings::Array{Transaction}
# end
# #get_assets(p::Portfolio)::Array{FinancialAsset} = map(x -> x.asset, p.holdings)
# # function get_data(p::Portfolio)::DataFrame
#
# # end

end
