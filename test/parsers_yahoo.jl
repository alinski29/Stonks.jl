using Dates
using Test
using Logging

using Stonks
using Stonks: JSONContent, APIResponseError, ContentParserError
using Stonks.Models
using Stonks.Parsers

include("test_utils.jl")

@testset "Yahoofinance parsers" begin
  price_content = get_test_data("data/yahoo_prices.json")
  overview_content = get_test_data("data/yahoo_overview.json")
  exchange_content = get_test_data("data/yahoo_exchange.json")
  price_parser = Parsers.YahooPriceParser
  exchange_parser = Parsers.YahooExchangeRateParser

  @testset "Succesful price response" begin
    data = parse_content(price_parser, price_content)
    @test isa(data, Vector{AssetPrice})
    # 5 datapoint for 4 tickers
    @test length(data) == 5 * 4
    dates = [x.date for x in data]
    @test minimum(dates) == Date("2022-02-09")
    @test maximum(dates) == Date("2022-02-15")
  end

  @testset "Successful price response with from date limit" begin
    from = Date("2022-02-11")
    data = parse_content(price_parser, price_content; from=from)
    @test isa(data, Vector{AssetPrice})
    # 3 datapoint for 4 tickers (filtered using from)
    @test length(data) == 3 * 4
    dates = [x.date for x in data]
    @test minimum(dates) == from
    @test maximum(dates) == Date("2022-02-15")
  end

  @testset "Succesful price response with from and to date limits" begin
    from, to = Date("2022-02-11"), Date("2022-02-14")
    data = parse_content(price_parser, price_content; from=from, to=to)
    @test isa(data, Vector{AssetPrice})
    # 3 datapoint for 4 tickers (filtered using from)
    @test length(data) == 2 * 4
    dates = [x.date for x in data]
    @test minimum(dates) == from
    @test maximum(dates) == to
  end

  @testset "Failed yahoo API response" begin
    content = """{
      "spark": {
        "result": null,
        "error": {
          "code": "Not Found",
          "description": "No data found for spark symbols"
        }
      }
    }"""
    data = parse_content(price_parser, content)
    @test isa(data, ContentParserError)
  end

  @testset "Succesful yahoofinance response on AssetInfo" begin
    parser = Parsers.YahooInfoParser
    data = parse_content(parser, overview_content)
    @test isa(data, Vector{AssetInfo})
    @test length(data) == 1
  end

  @testset "Succesful exchange rate response" begin
    data = parse_content(exchange_parser, exchange_content)
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-01-24")
    @test maximum(dates) == Date("2022-02-22")
    @test unique(map(x -> (x.base, x.target), data)) == [("USD", "CAD"), ("EUR", "USD")]
    @test isa(data, Vector{ExchangeRate})
    @test length(data) == 44
  end

  @testset "Succesful exchange rate response with from date filter" begin
    from = Date("2022-02-01")
    data = parse_content(exchange_parser, exchange_content; from=from)
    @test minimum(map(x -> x.date, data)) == from
  end

  @testset "Succesful exchange rate response with from and to date filters" begin
    from, to = Date("2022-02-01"), Date("2022-02-10")
    data = parse_content(exchange_parser, exchange_content; from=from, to=to)
    dates = map(x -> x.date, data)
    @test minimum(dates) == from
    @test maximum(dates) == to
  end
end
