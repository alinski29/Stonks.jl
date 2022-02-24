"""
Collection of data models used for content parsing
"""
module Models

using Base: @kwdef
using Dates

export AbstractStonxRecord, AssetInfo, AssetPrice, ExchangeRate, EconomicIndicator

abstract type AbstractStonxRecord end

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
  employees::Union{Int64,Missing} = missing
end

@kwdef struct AssetPrice <: AbstractStonxRecord
  symbol::String
  date::Date
  close::Float64
  open::Union{Float64,Missing} = missing
  high::Union{Float64,Missing} = missing
  low::Union{Float64,Missing} = missing
  close_adjusted::Union{Float64,Missing} = missing
  volume::Union{Int64,Missing} = missing
end

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
  value::Date
end

end
