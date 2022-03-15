# Functions 

---
## Index
```@index
Pages = ["api_functions.md"]
```
---
## Client setup
The library comes with methods for creating `APIClient` instances with preconfigured data for these providers:
```@docs
YahooClient
AlphavantageJSONClient
```

You can omit the `client` parameter in all functions IF you set an environment variables:
- Alphavantage: `ALPHAVANTAGE_TOKEN` => will build an `APIClient` using `AlphavantageJSONClient` 
- Yahoo Finance: `YAHOOFINANCE_TOKEN` => will build an `APIClient` using `YahooClient`

---
## Retrieving data 
```@docs 
get_price
get_info
get_exchange_rate
get_balance_sheet
get_income_statement
get_cashflow_statement
get_earnings
get_data
```

---
## DataFrame conversion
```@docs
to_dataframe
```

---
## Persisting data
```@docs
load
save
update
```

---
## Content parsers
```@docs
Stonks.Parsers.parse_content
```