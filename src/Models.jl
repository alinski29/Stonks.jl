"""
Collection of data models used for content parsing
"""
module Models

using Base: @kwdef
using Dates

export AbstractStonxRecord, AssetInfo, AssetPrice, ExchangeRate, EconomicIndicator

"""
Abstract type inteded to be subtyped by an data model
"""
abstract type AbstractStonxRecord end

"""
General information about a quoted symbol / ticker.

### Constructors
* All optional [kwarg]s have `missing` default values.
AssetInfo(;\n
  symbol::String, currency::String,\n
  [name::String], [type::String], [exchange::String], [country::String],\n
  [industry::String], [sector::String],[timezone::String], [employees::Integer]\n
)
"""
@kwdef struct AssetInfo <: AbstractStonxRecord
  symbol::String
  currency::String
  name::Union{String,Missing} = missing
  type::Union{String,Missing} = missing
  exchange::Union{String,Missing} = missing
  country::Union{String,Missing} = missing
  industry::Union{String,Missing} = missing
  sector::Union{String,Missing} = missing
  timezone::Union{String,Missing} = missing
  employees::Union{Integer,Missing} = missing
end

"""
Container for holding a time series datapoint with price data. Lowest frequency is daily.

### Constructors
* All optional [kwarg]s have `missing` default values.
AssetPrice(;
  symbol::String, date::Date, close::Float64,\n
  [open::Float64], [high::Float64], [low::Float64], [close_adjusted::Float64],\n 
  [volume::Float64]\n
)
"""
@kwdef struct AssetPrice <: AbstractStonxRecord
  symbol::String
  date::Date
  close::Float64
  open::Union{Float64,Missing} = missing
  high::Union{Float64,Missing} = missing
  low::Union{Float64,Missing} = missing
  close_adjusted::Union{Float64,Missing} = missing
  volume::Union{Integer,Missing} = missing
end

"""
Container for holding an exchange rate datapoint. Lowest frequency is daily.

### Constructors
ExchangeRate(; base::String, target::String, date::Date, rate::Float64)
"""
@kwdef struct ExchangeRate <: AbstractStonxRecord
  base::String
  target::String
  date::Date
  rate::Float64
end

@kwdef struct EconomicIndicator <: AbstractStonxRecord
  symbol::String
  name::String
  date::Date
  value::Number
end

end
