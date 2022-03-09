"""
Collection of data models used for content parsing
"""
module Models

using Base: @kwdef
using Dates

export AbstractStonksRecord, AssetInfo, AssetPrice, ExchangeRate

"""
Abstract type inteded to be subtyped by an data model.

All subtypes are constructed from keyword args and optional values default to `missing`.
"""
abstract type AbstractStonksRecord end

"""
Stores general information about a quoted symbol / ticker.

### Constructors
```julia
AssetInfo(;
  symbol::String,
  currency::String,
  name::Union{String,Missing}=missing,
  type::Union{String,Missing}=missing,
  exchange::Union{String,Missing}=missing,
  country::Union{String,Missing}=missing,
  industry::Union{String,Missing}=missing,
  sector::Union{String,Missing}=missing,
  timezone::Union{String,Missing}=missing,
  employees::Union{Integer,Missing}=missing,
)
```
"""
@kwdef struct AssetInfo <: AbstractStonksRecord
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
Stores a time series datapoint with price information. Lowest frequency is daily.

### Constructors
```julia 
AssetPrice(
  symbol::String,
  date::Date,
  close::Float64,
  open::Union{Float64,Missing} = missing,
  high::Union{Float64,Missing} = missing,
  low::Union{Float64,Missing} = missing,
  close_adjusted::Union{Float64,Missing} = missing,
  volume::Union{Integer,Missing} = missing,
)
end
```
"""
@kwdef struct AssetPrice <: AbstractStonksRecord
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
Stores an exchange rate datapoint. Lowest frequency is daily.

### Constructors
```julia
ExchangeRate(;
  base::String,
  target::String,
  date::Date,
  rate::Float64,
)
```
"""
@kwdef struct ExchangeRate <: AbstractStonksRecord
  base::String
  target::String
  date::Date
  rate::Float64
end

# @kwdef struct EconomicIndicator <: AbstractStonksRecord
#   symbol::String
#   name::String
#   date::Date
#   value::Number
# end

end
