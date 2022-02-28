# Stonx.jl
## A layman's solutiion to retrieval and storage of financial data.

[![Build status](https://github.com/alinski29/Stonx.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alinski29/Stonx.jl/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/alinski29/Stonx.jl/branch/main/graph/badge.svg?token=FPIHWY0WD3)](https://codecov.io/gh/alinski29/Stonx.jl)

Stonx.jl is designed with the goal of making access to financial data easier by standardizing the retrieval from various APIs into a unified data model. On top of that, it provides methods for storing the data locally in various format and gives you the tools to incrementally update it.
If you are not satisfited with the defaults, the APIs can be easily extended, as well as the data model.

<details open>
  <summary><b>Table of contents</b></summary>

---
- [Features](#features)
- [Usage](#usage)
- [Examples](#examples)
---

</details>

### **Features**

- Comes with an out-of-the box data model, configured API clients (currently yahoofinance and alphavantage) and functions for parsing the content into the default data model. 
- Extensible data model. Not satisfied with the default data model? You are free to define your own models and the functions for parsing the content.
- Batching of multiple stock tickers if the API endpoint allows it, thus minimizing the number of requests
- Local storage of data. Use the `Datastore` module to store the data you query in multiple file formats (csv, json, arrow, parquet). You can also define a partitioning column to make reading and writing more efficient. Writes to the datastore are atomic. The library exposes method to update all data for financial symbols in your datastore.
- Asynchronous requests. In case there are multiple requests, they will be processed asynchronously, thus minimizing the network wait time.
- Silent by design. The main exposed functions for fetching and saving data will never throw an error / exception, making your program crash. Instead, it will return the error with an explanative message of what went wrong. 


### **Usage**

### **Price time series**

```julia
using Dates
using Stonx

# Create a  client
client = YahooClient("<api_key>")
# daily data since 2022-01-01
julia> today = Dates.today()
2022-02-18

julia> get_time_series("AAPL", client; from = today - Dates.Day(1))
1-element Vector{AssetPrice}
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> length(ENV["YAHOOFINANCE_TOKEN"]) # you can omit the client if you have certain environment variables set
40

julia> from = today - Dates.Day(2)
2022-02-16
julia> prices = get_time_series(["AAPL", "MSFT"]; from = from) # client is resolved from ENV variable
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing

julia> prices = get_time_series([("AAPL", Date("2022-02-15"), Date("2022-02-16")), ("MSFT", Date("2022-02-14"), Date("2022-02-15"))])
5-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-14"), 295.0, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-15"), 300.47, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-15"), 172.79, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing)
```

### **Asset information**
```julia
julia> get_info("AAPL")
1-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)

julia> get_info(["AAPL", "MSFT"])
2-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)
 AssetInfo("MSFT", "USD", "Microsoft Corporation", "EQUITY", "NMS", "United States", "Software—Infrastructure", "Technology", "America/New_York", 181000)
```

### **Exchange rates**
```julia
julia> get_exchange_rate(base = "EUR", target = "USD" from = Date("2022-02-14"), to = Date("2022-02-16"))
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-14"), 1.1365)
 ExchangeRate("EUR", "USD", Date("2022-02-15"), 1.1306)
 ExchangeRate("EUR", "USD", Date("2022-02-16"), 1.1357)
```

### DataFrames integration
The types of the `DataFrame` will match the types of the model `T <: AbstractStonxRecord`.
```julia
julia> data
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-23"), 280.27, 290.18, 291.7, 280.1, missing, 37811167)
 AssetPrice("AAPL", Date("2022-02-23"), 160.07, 165.54, 166.15, 159.75, missing, 90009247)
julia> data |> to_dataframe
4x8 DataFrame
 Row │ symbol  date        close    open      high      low       close_adjusted  volume   
     │ String  Date        Float64  Float64?  Float64?  Float64?  Float64?        Int64?   
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ MSFT    2022-02-23   280.27    290.18    291.7     280.1          missing  37811167
   3 │ AAPL    2022-02-23   160.07    165.54    166.15    159.75         missing  90009247
```