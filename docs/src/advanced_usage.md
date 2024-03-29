# Advanced usage

---
## Plug in any data format
The [`FileStore`](@ref) uses CSV as the default format for reading and writing data.
If you wish more performance, you are free to use it with any format you like. 
You just need to provide functions for reading and writing data with your format. 
Here's an example using the [Arrow](https://github.com/apache/arrow-julia) file format.

```julia
using Arrow, Dates, Tables
using Stonks
using Stonks.Stores: apply_schema

function write_arrow(data::Vector{T}, path::String) where {T<:AbstractStonksRecord}
  open(path, "w") do io
    Arrow.write(io, to_table(data))
  end
end

function read_arrow(path::String, ::Type{T}) where {T<:AbstractStonksRecord}
  apply_schema(collect(Tables.rows(Arrow.Table(path))), T)
end

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
# 1-element Vector{String}:
 "data.arrow"

load(ds)
# 4-element Vector{AssetPrice}:
 AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing)
 AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing)
 AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing)
```
---
## Create API resources for your custom models
Assume we'll receive the following content from an API.
Source: [https://www.alphavantage.co/query?function=INFLATION&apikey=demo](https://www.alphavantage.co/query?function=INFLATION&apikey=demo)
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
  headers=Dict("accept" => "application/json"),
  query_params=Dict("function" => "INFLATION", "apikey" => "demo"),
  parser=Stonks.JSONParser(parse_inflation_data),
)

data = get_data(my_resource; from=Date("2019-01-01"))
foreach(println, data)
MacroIndicator("US Consumer Prices", Date("2020-01-01"), 1.23358439630637)
MacroIndicator("US Consumer Prices", Date("2019-01-01"), 1.81221007526015)
```

---
## Create your client from combining API resources
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
# 3-element Vector{DataType}:
 ExchangeRate
 AssetPrice
 AssetInfo
```