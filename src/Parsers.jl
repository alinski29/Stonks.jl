module Parsers

import ..Models: FinancialData

export parse_content

abstract type Parser end
abstract type ContentParser <: Parser end

struct JSONParser{F} <: ContentParser
    func::F
end

struct CSVParser{F} <: ContentParser
    func::F
end

function parse_content end

parse_content(p::ContentParser, c::AbstractString; kwargs...)::Union{Vector{T}, Exception} where {T <: FinancialData} = p.func(c; kwargs...)

include("parsers/parser_yahoo.jl")
#include("parser_alphavantage.jl")

const YahooPriceParser = JSONParser(parse_yahoo_price)
const YahooInfoParser = JSONParser(parse_yahoo_info)

end
