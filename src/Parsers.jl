"""
Collection of logic for how response data is parsed into concrete data types.
"""
module Parsers

using Stonx.Models: AbstractStonxRecord

export parse_content

abstract type AbstractParser end
abstract type AbstractContentParser <: AbstractParser end

struct JSONParser{F} <: AbstractContentParser
  func::F
end

struct CSVParser{F} <: AbstractContentParser
  func::F
end

function parse_content end

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
