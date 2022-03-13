"""
Collection of data models used for content parsing
"""
module Models

using Base: @kwdef
using Dates

export AbstractStonksRecord, AssetInfo, AssetPrice, ExchangeRate, IncomeStatement

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
  employees::Union{Int,Missing}=missing,
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
  employees::Union{Int,Missing} = missing
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

"""
Stores a datapoint containing income statement information. 
Follows normalized fields mapped to GAAP and IFRS taxonomies of the SEC.

### Constructors 
```julia
IncomeStatement(;
  symbol::String,
  frequency::String,
  fiscalDate::Date,
  totalRevenue::Int64,
  costOfRevenue::Int64,
  grossProfit::Int64,
  operatingIncome::Int64,
  sellingGeneralAndAdministrative::Union{Int64,Missing} = missing,
  researchAndDevelopment::Union{Int64,Missing} = missing,
  depreciation::Union{Int64,Missing} = missing,
  depreciationAndAmortization::Union{Int64,Missing} = missing,
  incomeBeforeTax::Union{Int64,Missing} = missing,
  incomeTaxExpense::Union{Int64,Missing} = missing,
  interestAndDebtExpense::Union{Int64,Missing} = missing,
  comprehensiveIncomeNetOfTax::Union{Int64,Missing} = missing,
  ebit::Union{Int64,Missing} = missing,
  ebitda::Union{Int64,Missing} = missing,
  netIncome::Int64,
  netIncomeApplicableToCommonShares::Union{Int64,Missing} = missing,
)
```
"""
@kwdef struct IncomeStatement <: AbstractStonksRecord
  symbol::String
  frequency::String
  fiscalDate::Date
  totalRevenue::Int64
  costOfRevenue::Int64
  grossProfit::Int64
  operatingIncome::Int64
  sellingGeneralAndAdministrative::Union{Int64,Missing} = missing
  researchAndDevelopment::Union{Int64,Missing} = missing
  depreciation::Union{Int64,Missing} = missing # Depreciation, Total 
  depreciationAndAmortization::Union{Int64,Missing} = missing
  incomeBeforeTax::Union{Int64,Missing} = missing
  incomeTaxExpense::Union{Int64,Missing} = missing
  interestAndDebtExpense::Union{Int64,Missing} = missing
  comprehensiveIncomeNetOfTax::Union{Int64,Missing} = missing
  ebit::Union{Int64,Missing} = missing
  ebitda::Union{Int64,Missing} = missing
  netIncome::Int64
  netIncomeApplicableToCommonShares::Union{Int64,Missing} = missing
end

# @kwdef struct EconomicIndicator <: AbstractStonksRecord
#   symbol::String
#   name::String
#   date::Date
#   value::Number
# end

end
