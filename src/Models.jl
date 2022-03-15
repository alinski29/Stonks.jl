"""
Collection of data models used for content parsing
"""
module Models

using Base: @kwdef
using Dates

export AbstractStonksRecord,
  AssetInfo,
  AssetPrice,
  ExchangeRate,
  IncomeStatement,
  BalanceSheet,
  CashflowStatement,
  Earnings

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
  date::Date,
  currency::Union{String,Missing} = missing,
  total_revenue::Int64,
  cost_of_revenue::Int64,
  gross_profit::Int64,
  operating_income::Int64,
  selling_general_and_administrative::Union{Int64,Missing} = missing,
  research_and_development::Union{Int64,Missing} = missing,
  depreciation::Union{Int64,Missing} = missing, # Depreciation, Total 
  depreciation_and_amortization::Union{Int64,Missing} = missing,
  income_before_tax::Union{Int64,Missing} = missing,
  income_tax_expense::Union{Int64,Missing} = missing,
  interest_expense::Union{Int64,Missing} = missing,
  interest_and_debt_expense::Union{Int64,Missing} = missing,
  ebit::Union{Int64,Missing} = missing,
  ebitda::Union{Int64,Missing} = missing,
  net_income::Int64,
  net_income_common_shares::Union{Int64,Missing} = missing,
)
```
"""
@kwdef struct IncomeStatement <: AbstractStonksRecord
  symbol::String
  frequency::String
  date::Date
  currency::Union{String,Missing} = missing
  total_revenue::Int64
  cost_of_revenue::Int64
  gross_profit::Int64
  operating_income::Int64
  selling_general_and_administrative::Union{Int64,Missing} = missing
  research_and_development::Union{Int64,Missing} = missing
  depreciation::Union{Int64,Missing} = missing # Depreciation, Total 
  depreciation_and_amortization::Union{Int64,Missing} = missing
  income_before_tax::Union{Int64,Missing} = missing
  income_tax_expense::Union{Int64,Missing} = missing
  interest_expense::Union{Int64,Missing} = missing
  interest_and_debt_expense::Union{Int64,Missing} = missing
  #comprehensive_income_net_of_tax::Union{Int64,Missing} = missing
  ebit::Union{Int64,Missing} = missing
  ebitda::Union{Int64,Missing} = missing
  net_income::Int64
  net_income_common_shares::Union{Int64,Missing} = missing
end

"""
Stores a datapoint containing balance sheet information. 
Follows normalized fields mapped to GAAP and IFRS taxonomies of the SEC.

### Constructors
```julia
BalanceSheet(;
  symbol::String,
  frequency::String,
  date::Date,
  currency::Union{String,Missing} = missing,
  total_assets::Int64,
  total_liabilities::Int64,
  total_shareholder_equity::Int64,
  cash_and_equivalents::Union{Int64,Missing} = missing,
  current_net_receivables::Union{Int64,Missing} = missing,
  inventory::Union{Int64,Missing} = missing,
  short_term_investments::Union{Int64,Missing} = missing,
  other_current_assets::Union{Int64,Missing} = missing,
  total_current_assets::Union{Int64,Missing} = missing,
  property_plant_equipment::Union{Int64,Missing} = missing,
  goodwill::Union{Int64,Missing} = missing,
  long_term_investments::Union{Int64,Missing} = missing,
  intangible_assets::Union{Int64,Missing} = missing,
  total_noncurrent_assets::Union{Int64,Missing} = missing,
  current_accounts_payable::Union{Int64,Missing} = missing,
  deferred_revenue::Union{Int64,Missing} = missing,
  short_term_debt::Union{Int64,Missing} = missing,
  other_current_liabilities::Union{Int64,Missing} = missing,
  total_current_liabilities::Union{Int64,Missing} = missing,
  current_debt::Union{Int64,Missing} = missing,
  current_long_term_debt::Union{Int64,Missing} = missing,
  long_term_debt::Union{Int64,Missing} = missing,
  long_term_debt_noncurrent::Union{Int64,Missing} = missing,
  capital_lease_obligations::Union{Int64,Missing} = missing,
  other_noncurrent_liabilities::Union{Int64,Missing} = missing,
  total_noncurrent_liabilities::Union{Int64,Missing} = missing,
  treasury_stock::Union{Int64,Missing} = missing,
  retained_earnings::Union{Int64,Missing} = missing,
  common_stock::Union{Int64,Missing} = missing,
  common_stock_shares_outstanding::Union{Int64,Missing} = missing,
)
```
"""
@kwdef struct BalanceSheet <: AbstractStonksRecord
  symbol::String
  frequency::String
  date::Date
  currency::Union{String,Missing} = missing
  total_assets::Int64
  total_liabilities::Int64
  total_shareholder_equity::Int64
  cash_and_equivalents::Union{Int64,Missing} = missing
  current_net_receivables::Union{Int64,Missing} = missing
  inventory::Union{Int64,Missing} = missing
  short_term_investments::Union{Int64,Missing} = missing
  other_current_assets::Union{Int64,Missing} = missing
  total_current_assets::Union{Int64,Missing} = missing
  property_plant_equipment::Union{Int64,Missing} = missing
  goodwill::Union{Int64,Missing} = missing
  long_term_investments::Union{Int64,Missing} = missing
  intangible_assets::Union{Int64,Missing} = missing
  total_noncurrent_assets::Union{Int64,Missing} = missing
  current_accounts_payable::Union{Int64,Missing} = missing
  deferred_revenue::Union{Int64,Missing} = missing
  short_term_debt::Union{Int64,Missing} = missing
  other_current_liabilities::Union{Int64,Missing} = missing
  total_current_liabilities::Union{Int64,Missing} = missing
  current_debt::Union{Int64,Missing} = missing
  current_long_term_debt::Union{Int64,Missing} = missing
  long_term_debt::Union{Int64,Missing} = missing
  long_term_debt_noncurrent::Union{Int64,Missing} = missing
  capital_lease_obligations::Union{Int64,Missing} = missing
  other_noncurrent_liabilities::Union{Int64,Missing} = missing
  total_noncurrent_liabilities::Union{Int64,Missing} = missing
  treasury_stock::Union{Int64,Missing} = missing
  retained_earnings::Union{Int64,Missing} = missing
  common_stock::Union{Int64,Missing} = missing
  common_stock_shares_outstanding::Union{Int64,Missing} = missing
end

"""
Stores a datapoint containing cashflow statement information.

### Constructors
```julia
CashflowStatement(;
  symbol::String,
  frequency::String,
  date::String,
  currency::String,
  operating_cashflow::Union{Int64,Missing} = missing,
  cashflow_investment::Union{Int64,Missing} = missing,
  cashflow_financing::Union{Int64,Missing} = missing,
  change_operating_liabilities::Union{Int64,Missing} = missing,
  change_receivables::Union{Int64,Missing} = missing,
  change_inventory::Union{Int64,Missing} = missing,
  change_cash_and_equivalents::Union{Int64,Missing} = missing,
  depreciation_and_amortization::Union{Int64,Missing} = missing,
  capital_expenditures::Union{Int64,Missing} = missing,
  dividend_payout::Union{Int64,Missing} = missing,
  stock_repurchase::Union{Int64,Missing} = missing,
  net_income::Union{Int64,Missing} = missing,
)
```
"""
@kwdef struct CashflowStatement <: AbstractStonksRecord
  symbol::String
  frequency::String
  date::Date
  currency::String
  operating_cashflow::Union{Int64,Missing} = missing
  cashflow_investment::Union{Int64,Missing} = missing
  cashflow_financing::Union{Int64,Missing} = missing
  change_operating_liabilities::Union{Int64,Missing} = missing
  change_receivables::Union{Int64,Missing} = missing
  change_inventory::Union{Int64,Missing} = missing
  change_cash_and_equivalents::Union{Int64,Missing} = missing
  depreciation_and_amortization::Union{Int64,Missing} = missing
  capital_expenditures::Union{Int64,Missing} = missing
  dividend_payout::Union{Int64,Missing} = missing
  stock_repurchase::Union{Int64,Missing} = missing
  net_income::Union{Int64,Missing} = missing
end

"""
Stores a datapoint containing earnings (per share) information.
### Constructors
```julia
Earnings(;
  symbol::String,
  frequency::String,
  date::Date,
  currency::Union{String,Missing} = missing,
  actual::Float16,
  estimate::Union{Float16,Missing} = missing,
)
```
"""
@kwdef struct Earnings <: AbstractStonksRecord
  symbol::String
  frequency::String
  date::Date
  currency::Union{String,Missing} = missing
  actual::Float16
  estimate::Union{Float16,Missing} = missing
end

# @kwdef struct EconomicIndicator <: AbstractStonksRecord
#   symbol::String
#   name::String
#   date::Date
#   value::Number
# end

end
