# Basic usage

---
## Installation
```julia
using Pkg
Pkg.add("Stonks")
```
If for some reason, the package is not available within the Julia Pkg ecosystem, you can install it from Github
```julia
using Pkg
Pkg.dev("https://github.com/alinski29/Stonks.jl")
```

Throughout the rest of the tutorial we will assume that you have installed the Stonks.jl package and
have already typed `using Stonks` which loads the package.

---
## Client setup 
For retrieving data from the web, you'll need an instance of [`Stonks.APIClient`](@ref), which holds all relevant information for requesting the data. There are currently two data providers supported:
- [Yahoo Finance](https://www.yahoofinanceapi.com)
- [Alphavantage](https://www.alphavantage.co)

For any provider, you need to sign up on the website and obtain a token. 
Then, you can load a client using one of the following functions.
```julia
client = YahooClient("<my_token>")
# or client = AlphavantageJSONClient("<my_token>")
```

---
### Client resolution fron ENV variables
You can omit the `client` parameter in all functions IF you set one of the environment variables:
- For Alphavantage: `ALPHAVANTAGE_TOKEN` => will build an `APIClient` using [`AlphavantageJSONClient`](@ref)
- For Yahoo Finance: `YAHOOFINANCE_TOKEN` => will build an `APIClient` using [`YahooClient`](@ref)
In your terminal, type:
```bash
export ALPHAVANTAGE_TOKEN='MY_TOKEN'
echo $ALPHAVANTAGE_TOKEN
MY_TOKEN
```
```julia
julia> ENV["ALPHAVANTAGE_TOKEN"]
"MY_TOKEN"
```

---
## Get price time series
```julia
using Dates

# Create a  client
client = YahooClient("<api_key>") # or AlphavantageJSONClient(<api_key>)
julia> ref_date = Date("2022-02-18") # just for reproducible results, you can omit it
2022-02-18

# 'to' can be ommited, defaults to current day.
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
## Get asset information
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
## Get exchange rates
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
## DataFrames integration
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
## Persisting data
Using a [`FileStore`](@ref), you can easily persist and incrementaly update data having at least one identifier and one time dimension.
Default file format is CSV, but you can plug in any format you wish. See [example for custom file formats](advanced_usage.html#create-api-resources-for-your-custom-models).
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
