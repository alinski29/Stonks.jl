<div align="center">
   <img 
      src="https://i.kym-cdn.com/entries/icons/original/000/029/959/Screen_Shot_2019-06-05_at_1.26.32_PM.jpg" 
      alt="Stonks logo" 
      style="height: 150px; width:266px;"/>
  <br />
  <p>
    <h1>
      <b>
        Stonks.jl
      </b>
    </h1>
  </p>
  <p>
    <b> 📈 The layman's solution for retrieval and storage of financial data.</b>
  </p>
  <p>
  <a href="https://github.com/alinski29/Stonks.jl/actions/workflows/ci.yml/badge.svg?branch=main">
   <img
   src="https://github.com/alinski29/Stonks.jl/actions/workflows/ci.yml/badge.svg?branch=main"
   alt="CI status"
   />
  </a>
  <a href="https://codecov.io/gh/alinski29/Stonks.jl/branch/main/graph/badge.svg?token=FPIHWY0WD3">
   <img
   src=https://codecov.io/gh/alinski29/Stonks.jl/branch/main/graph/badge.svg?token=FPIHWY0WD3
   alt="Coverage status"
   />
  </a>
  <a href="https://github.com/alinski29/Stonks.jl/actions/workflows/documentation.yml/badge.svg?branch=main">
  <img
  src="https://github.com/alinski29/Stonks.jl/actions/workflows/documentation.yml/badge.svg?branch=main"
  alt="Documentation status"
  />
  </a>
  </p>  
  <p>
</div>

Stonks.jl is the Julia library that lets you access and store financial data from multiple APIs into a unified data model. It gives you the tools to generalize the data retrieval and storage from any API with a simple interface in a type-safe manner.

<details open>
  <summary><b>Table of contents</b></summary>

---
- [Features](#features)
- [Basic Usage](#basic-usage)
  - [Get price time series](#get-price-time-series)
  - [Get asset information](#get-asset-information)
  - [Get exchange rates](#get-exchange-rates)
  - [DataFrames integration](#dataframes-integration)
  - [Persisting data](#persisting-data)
- [Advanced usage](#advanced-usage)
  - [Plug in any data format](#plug-in-any-data-format)
  - [Create API resources for your custom models](#create-api-resources-for-your-custom-models)
  - [Create your client from combining API resources](#create-your-client-from-combining-api-resources)
- [Contributing](#contributing)
- [License](#license)
---

</details>

## **Features**

- Designed to work with several APIs in an agnostic way, where several APIs are capable of returning the same data.
- Comes with a pre-defined data model (types), but you're free to [design your own types](#create-api-resources-for-your-custom-models).
- Store and update data locally with ease using the [`FileStore`](#persisting-data), which can work with [any file format](#plug-in-any-data-format). Supports data partitioning, writes are atomic, schema validation on read and write. Incrementally update everything in your datastore with just one function.
- Batching of multiple stock tickers if the API resource allows it, thus minimizing the number of requests.
- Asynchronous request processing. Multiple requests will processed asynchronously and multi-threaded, thus minimizing the network wait time.
- Silent by design. The main exposed functions for fetching and saving data don't throw an error, making your program crash. Instead, it will return the error with an explanative message of what went wrong. 
---

## **Basic Usage**

### **Get price time series**

```julia
using Dates
using Stonks

# Create a  client
client = YahooClient("<api_key>") # or AlphavantageJSONClient(<api_key>)
julia> ref_date = Date("2022-02-18")
2022-02-18

# to can be ommited, defaults to current day.
julia> get_price("AAPL", client; from=ref_date-Day(1), to=ref_date)
2-element Vector{AssetPrice}:
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, 169.82, 170.5413, 166.19, missing, 82772674)
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, 171.03, 171.91, 168.47, missing, 69589344)
 # you can omit the client if you have the correct environment variables set
julia> length(ENV["ALPHAVANTAGE_TOKEN"]) # ENV["YAHOOFINANCE_TOKEN"] works as well
16
julia> prices = get_price(["AAPL", "MSFT"]; from=ref_date-Day(2), to=ref_date) 
6-element Vector{AssetPrice}:
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, 169.82, 170.5413, 166.19, missing, 82772674)
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, 171.03, 171.91, 168.47, missing, 69589344)
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, 171.85, 173.34, 170.05, missing, 61177398)
 AssetPrice("MSFT", Date("2022-02-18"), 287.93, 293.05, 293.86, 286.305, missing, 34264008)
 AssetPrice("MSFT", Date("2022-02-17"), 290.73, 296.36, 296.8, 290.0, missing, 32461580)
 AssetPrice("MSFT", Date("2022-02-16"), 299.5, 298.365, 300.87, 293.68, missing, 29982121)
# you can query each symbol with different time intervals
julia> prices = get_price([
  ("AAPL", Date("2022-02-15"), Date("2022-02-16")),
  ("MSFT", Date("2022-02-14"), Date("2022-02-15")),
])
4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-15"), 300.47, 300.008, 300.8, 297.02, missing, 27379488)
 AssetPrice("MSFT", Date("2022-02-14"), 295.0, 293.77, 296.76, 291.35, missing, 36359487)
 AssetPrice("AAPL", Date("2022-02-16"), 172.55, 171.85, 173.34, 170.05, missing, 61177398)
 AssetPrice("AAPL", Date("2022-02-15"), 172.79, 170.97, 172.95, 170.25, missing, 64286320)
```
---

### **Get asset information**
```julia
julia> get_info("AAPL")
1-element Vector{AssetInfo}:
 AssetInfo("AAPL", "USD", "Apple Inc", "Common Stock", "NASDAQ", "USA", "Electronic Computers", "Technology", missing, missing)

julia> get_info(["AAPL", "MSFT"])
2-element Vector{AssetInfo}:
 AssetInfo("MSFT", "USD", "Microsoft Corporation", "Common Stock", "NASDAQ", "USA", "Services-Prepackaged Software", "Technology", missing, missing)
 AssetInfo("AAPL", "USD", "Apple Inc", "Common Stock", "NASDAQ", "USA", "Electronic Computers", "Technology", missing, missing)
```
---

### **Get exchange rates**
```julia
# Same API as get_price. the symbol needs to be a currency pair like $base/$quote,
# each consisting of exactly 3 characters.
julia> ref_date = Date("2022-02-18")
julia> get_exchange_rate("EUR/USD", from=ref_date-Day(1), to=ref_date)
3-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-18"), 1.13203)
 ExchangeRate("EUR", "USD", Date("2022-02-17"), 1.13592)
julia> get_exchange_rate(["EUR/USD", "USD/CAD"], from=ref_date-Day(1), to=ref_date)
# 4-element Vector{ExchangeRate}:
 ExchangeRate("EUR", "USD", Date("2022-02-18"), 1.13203)
 ExchangeRate("EUR", "USD", Date("2022-02-17"), 1.13592)
 ExchangeRate("USD", "CAD", Date("2022-02-18"), 1.2748)
 ExchangeRate("USD", "CAD", Date("2022-02-17"), 1.2707)
# Also works with []Tuple{String, Date} or []Tuple{String, Date, Date}
julia>get_exchange_rate([
  ("EUR/USD", Date("2022-02-15"), Date("2022-02-16")),
  ("USD/CAD", Date("2022-02-14"), Date("2022-02-15")),
])
4-element Vector{ExchangeRate}:
...
```
---

### **DataFrames integration**
The types of the `DataFrame` will match the types of any type model, `T<:AbstractStonksRecord`.
Currently only tested with flat data types.
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
---

### **Persisting data**
Using a `FileStore`, you can easily persist and incrementally update data having at least one identifier and one time dimension.
Default file format is CSV, but you can plug in any format you wish. See [example for custom file formats](#create-api-resources-for-your-custom-models).
```julia
using Chain, Dates, DataFrames
using Stonks

dest = joinpath(@__DIR__, "data/prices")
ds = FileStore{AssetPrice}(; path=dest, ids=[:symbol], partitions=[:symbol], time_column="date")
d_end = Date("2022-03-06")
2022-03-06

symbols = ["AAPL", "MSFT"]
data = get_price(symbols; from=d_end-Day(7), to=d_end-Day(5))

save(ds, data)
println(readdir(dest))
["symbol=AAPL", "symbol=MSFT"] #data stored in partitions
df = load(ds)
show(df[1:2, :]) # types are persisted
2×8 DataFrame
 Row │ symbol  date        close    open      high      low       close_adjusted  volume   
     │ String  Date        Float64  Float64?  Float64?  Float64?  Float64?        Integer? 
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ AAPL    2022-03-01   163.2    164.695    166.6     161.97         missing  83474425
   2 │ AAPL    2022-02-28   165.12   163.06     165.42    162.43         missing  95056629

show_stats(ds) = @chain load(ds) begin  
  groupby(_, :symbol) 
  combine(_, :date => maximum, :date => minimum, :symbol => length => :nrows)
 show
end

show_stats(ds)
2×4 DataFrame
 Row │ symbol  date_maximum  date_minimum  nrows 
     │ String  Date          Date          Int64 
─────┼───────────────────────────────────────────
   1 │ AAPL    2022-03-01    2022-02-28        2
   2 │ MSFT    2022-03-01    2022-02-28        2

# to is optional, defaults to latest workday. here, we need it for reproductible results.
update(ds; to=d_end)
show_stats(ds) 
# d_end (2022-03-06) is a Sunday, so the latest available data is from a Friday (2022-03-04).
2×4 DataFrame
 Row │ symbol  date_maximum  date_minimum  nrows 
     │ String  Date          Date          Int64 
─────┼───────────────────────────────────────────
   1 │ AAPL    2022-03-04    2022-02-28        6
   2 │ MSFT    2022-03-04    2022-02-28        6

d_start = d_end - Day(7)
# we add 2 new stocks to our store.
update(ds, [("IBM", d_start, d_end), ("AMD", d_start, d_end)], to=d_end)
show_stats(ds)
4×4 DataFrame
 Row │ symbol  date_maximum  date_minimum  nrows 
     │ String  Date          Date          Int64 
─────┼───────────────────────────────────────────
   1 │ AAPL    2022-03-04    2022-02-28        5
   2 │ AMD     2022-03-04    2022-02-28        5
   3 │ IBM     2022-03-04    2022-02-28        5
   4 │ MSFT    2022-03-04    2022-02-28        5
# update(ds, ["IBM", "AMD"]) - will include data since earliest available
# update(ds, vcat(symbols, ["IBM", "AMD"])) - will also update the existing symbols, 
#  if there is new data
```

## **Advanced usage**
---

### **Plug in any data format**
<details hide>
  <summary>Show</summary>

```julia
using Arrow, Dates, DataFrames
using Stonks

function write_arrow(df::AbstractDataFrame, path::String)
  open(path, "w") do io
    Arrow.write(io, df)
  end
end
read_arrow(path::String) = DataFrame(Arrow.Table(path))

ds = FileStore{AssetPrice}(;
  path=joinpath(@__DIR__, "data/arrow"),
  ids=[:symbol],
  format="arrow",
  time_column="date",
  reader=read_arrow,
  writer=write_arrow,
)

data = [
  AssetPrice(; symbol="MSFT", date=Date("2022-02-16"), close=299.5),
  AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=290.73),
  AssetPrice(; symbol="AAPL", date=Date("2022-02-17"), close=168.88),
  AssetPrice(; symbol="AAPL", date=Date("2022-02-18"), close=167.3),
]

save(ds, data)
readdir(ds.path)
1-element Vector{String}:
 "data.arrow"

df = load(ds)
show(df)
4×8 DataFrame
 Row │ symbol  date        close    open      high      low       close_adjusted  volume   
     │ String  Date        Float64  Float64?  Float64?  Float64?  Float64?        Integer? 
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ MSFT    2022-02-16   299.5    missing   missing   missing         missing   missing 
   2 │ MSFT    2022-02-17   290.73   missing   missing   missing         missing   missing 
   3 │ AAPL    2022-02-17   168.88   missing   missing   missing         missing   missing 
   4 │ AAPL    2022-02-18   167.3    missing   missing   missing         missing   missing 
```
</details>

### **Create API resources for your custom models**
<details hide>
  <summary>Show</summary>

 Assume we'll receive the following content from an API.
 Source: https://www.alphavantage.co/query?function=INFLATION&apikey=demo
```json
 {
  "name": "Inflation - US Consumer Prices",
  "interval": "annual",
  "unit": "percent",
  "data": [
    {"date": "2020-01-01", "value": "1.2335"},
    {"date": "2019-01-01", "value": "1.8122"}
  ]
}
```
```julia
using Chain, Dates, JSON3
using Stonks: Stonks, APIResource, JSONParser

# Create your custom type
struct MacroIndicator <: AbstractStonksRecord
  name::String
  date::Date
  value::Number
end

# Define a function with the same signature as `parse_conent`
# parse_content(content::AbstractString; kwargs...) -> Vector{<:AbstractStonksRecord}
function parse_inflation_data(content::AbstractString; kwargs...)
  js = JSON3.read(content)
  from, to = get(kwargs, :from, missing), get(kwargs, :to, missing)
  return @chain js["data"] begin 
    map(x -> MacroIndicator(
      "US Consumer Prices", tryparse(Date, x[:date]), tryparse(Float64, x[:value])), _,
    )
    isa(from, Date) ? filter(row -> row.date >= from, _) : _
    isa(to, Date) ? filter(row -> row.date <= to, _) : _
  end
end

# Define an API resource, wrap your function around a subtype of AbstractContentParser.
# subtypes(Stonks.Parsers.AbstractContentParser)
# [Stonks.Parsers.JSONParser, Stonks.Parsers.CSVParser]
my_resource = APIResource{MacroIndicator}(;
  url="https://www.alphavantage.co/query",
  headers=Dict("accept" => "application/json"),prices
  query_params=Dict("function" => "INFLATION", "apikey" => "demo"),
  parser=Stonks.JSONParser(parse_inflation_data),
)

data = get_data(my_resource; from=Date("2019-01-01"))
foreach(println, data)
MacroIndicator("US Consumer Prices", Date("2020-01-01"), 1.23358439630637)
MacroIndicator("US Consumer Prices", Date("2019-01-01"), 1.81221007526015)

# convert it to a dataframe - types are preserved.
to_dataframe(data)
2×3 DataFrame
 Row │ name       date        value   
     │ String     Date        Number  
─────┼────────────────────────────────
   1 │ US Consumer Prices  2020-01-01  1.23358
   2 │ US Consumer Prices  2019-01-01  1.81221
```
</details>

### **Create your client from combining API resources**
<details hide>
  <summary>Show</summary>

```julia 
using Stonks: Stonks, APIClient

yc = YahooClient("<my_secret_key>")
ac = AlphavantageJSONClient("<my_secret_key>")

my_client = Stonks.APIClient(Dict(
  "price" => ac.resources["price"],
  "info" => yc.resources["info"],
  "exchange" => yc.resources["exchange"], 
  # ... + your own custom resources
))
Stonks.APIClients.get_supported_types(my_client)
3-element Vector{DataType}:
 ExchangeRate
 AssetPrice
 AssetInfo
```
</details>

---

## **Contributing**
The project uses [git-flow workflow](https://danielkummer.github.io/git-flow-cheatsheet/). <br/>
If you want to add a new feature, open a branch feature/$feature-name and make a PR to develop branch. <br/>
Reporting issues in Github issues is highly appreciated.

## **License**
---
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT) - see the [`LICENSE`](https://github.com/alinski29/Stonks.jl/blob/main/LICENSE) file for details.

<p>⭐ If you enjoy this project please consider starring the 📈 <b>Stonks.jl</b> GitHub repo.</p>
