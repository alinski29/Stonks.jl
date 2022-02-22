# Stonx.jl
## A layman's solutiion to retrieval and storage of financial data.

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
using Stonx: Stonx, APIClients

client = APIClients.YahooClient(apiKey)

# daily data since 2022-01-01
julia> today = Dates.today()
2022-02-18
julia> get_time_series(client, "AAPL", from = today - Dates.Day(1))
1-element Vector{Stonx.Models.FinancialData}
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> from = today - Dates.Day(2)
2022-02-16
julia> prices = get_time_series(client, ["AAPL", "MSFT"], from = from)
Stonx.Models.AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing)
Stonx.Models.AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing
Stonx.Models.AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing
Stonx.Models.AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing
Stonx.Models.AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing
Stonx.Models.AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)

julia> prices = get_time_series(client, [("AAPL", Date("2022-02-17")), ("MSFT", Date("2022-02-18"))])
3-element Vector{Stonx.Models.FinancialData}:
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("MSFT", Date("2022-02-18"), 287.93, missing, missing, missing, missing, missing)

julia> prices = get_time_series(client, [("AAPL", Date("2022-02-15"), Date("2022-02-16")), ("MSFT", Date("2022-02-14"), Date("2022-02-15"))])
5-element Vector{Stonx.Models.FinancialData}:
 Stonx.Models.AssetPrice("MSFT", Date("2022-02-14"), 295.0, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("MSFT", Date("2022-02-15"), 300.47, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-15"), 172.79, missing, missing, missing, missing, missing)
 Stonx.Models.AssetPrice("AAPL", Date("2022-02-16"), 172.55, missing, missing, missing, missing, missing)
```

| Parameter | Description                                                                                                                                                                                                      | Type                                                                               | Required |
|-----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|----------|
| client    | Positional. Can be ommited if the correct environment varaible for getting the API key is set.                                                                                                                   | APIClient                                                                          | False    |
| symbols   | Positional. Examples:<br>1) "AAPL" <br>2) ["AAPL", "MSFT", "IBM"]; <br>3) [("AAPL", "2022-02-01"), ("MSFT", "2022-01-15")]; <br>4) [("AAPL", "2022-02-01", "2022-02-20"), ("MSFT", "2022-01-15", "2022-02-01")]; | String /<br> Vector{String} /<br> Vector{String, Date} /<br> Vector{String, Date, Date} | True     |
| from      | Keyword. Inception date. Either a Date type, or a String formatted as "YYYY-mm-dd". Use this if you want to query all symbols since <br>the same date.                                                           | Union{Date, String}                                                                | False    |
| to        | Keyword. End date. Either a Date type, or a String formatted as "YYYY-mm-dd". Use this if you want to query all symbols until <br>the same date.                                                                 | Union{Date, String}                                                                | False    |

### ** Asset information **
```julia
julia> get_info(client, "AAPL")
1-element Vector{Stonx.Models.FinancialData}:
 Stonx.Models.AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)

julia> get_info(client, ["AAPL", "MSFT"])
2-element Vector{Stonx.Models.FinancialData}:
 Stonx.Models.AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000)
 Stonx.Models.AssetInfo("MSFT", "USD", "Microsoft Corporation", "EQUITY", "NMS", "United States", "Software—Infrastructure", "Technology", "America/New_York", 181000)
```
