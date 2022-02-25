"""
Collection of logic for how response data is parsed into concrete data types.
"""
module Parsers

using Stonx.Models: AbstractStonxRecord

export parse_content

abstract type AbstractParser end
abstract type AbstractContentParser <: AbstractParser end

"""
A wrapper type for a function implementing `parse_content` interface for JSON content.
"""
struct JSONParser{F} <: AbstractContentParser
  func::F
end

"""
A wrapper type for a function implementing `parse_content` interface for CSV content.
"""
struct CSVParser{F} <: AbstractContentParser
  func::F
end

function parse_content end

"""
    parse_content(p::AbstractContentParser, c::AbstractString; kwargs...) -> Vector{T<:AbstractStonxRecord} 

Interface for parsing raw data into a data model. 
All main functions responsible for getting data from APIs will call `parse_content` with a concrete subtype of `AbstractContentParser`.

### Example - Create a custom type and parser
```julia
using Dates, JSON3, Stonx

# Assume we have the following raw data
julia> content
{
  "name": "Inflation - US Consumer Prices",
  "interval": "annual",
  "unit": "percent",
  "data": [
    {"date": "2020-01-01", "value": "1.2335"},
    {"date": "2019-01-01", "value": "1.8122"}
  ]
}

# Create your custom type
struct MacroIndicator <: AbstractStonxRecord
  name::String
  date::Date
  value::Number
end

# Define a function with the same signature as parse_content.
function parse_inflation_data(content::AbstractString; kwargs...)
  js = JSON3.read(content)
  return map(x -> 
    MacroIndicator("Inflation", tryparse(Date, x[:date]), tryparse(Float64, x[:value])),
  js["data"])
end

# Wrap it around a concrete subtype of AbstractContentParser
my_parser = Stonx.Parsers.JSONParser(parse_inflation_data)
julia> parse_content(my_parser, content)
2-element Vector{MacroIndicator}:
 MacroIndicator("Inflation", Date("2020-01-01"), 1.2335)
 MacroIndicator("Inflation", Date("2019-01-01"), 1.8122)
```
"""
parse_content(p::AbstractContentParser, c::AbstractString; kwargs...) = p.func(c; kwargs...)

include("parsers/parser_yahoo.jl")
include("parsers/parser_alphavantage.jl")

YahooPriceParser = JSONParser(parse_yahoo_price)
YahooInfoParser = JSONParser(parse_yahoo_info)
YahooExchangeRateParser = JSONParser(parse_yahoo_exchange_rate)

AlphavantagePriceParser = JSONParser(parse_alphavantage_price)
AlphavantageInfoParser = JSONParser(parse_alphavantage_info)
AlphavantageExchangeRateParser = JSONParser(parse_alphavantage_exchange_rate)

end
