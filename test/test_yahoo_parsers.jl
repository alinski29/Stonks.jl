using Test
import Dates: Date, Day
import Pipe: @pipe

using Stonx, Stonx.Models, Stonx.Parsers

@testset "Test yahoo parsers" begin

  price_content = open(f -> read(f, String), "test/data/yahoo_prices.json")
  overview_content = open(f -> read(f, String), "test/data/yahoo_overview.json")
  price_parser = Parsers.YahooPriceParser

  @testset "Test parsing succesfull yahoofinance response from /v8/finance/spark" begin
    data = parse_content(price_parser, price_content)
    @test isa(data, Vector{T} where T <: FinancialData)
    # 5 datapoint for 4 tickers
    @test length(data) == 5 * 4 
    dates = [x.date for x in data]
    @test minimum(dates) == Date("2022-02-09")
    @test maximum(dates) == Date("2022-02-15")
  end

  @testset "Test parsing succesfull yahoofinance response from /v8/finance/spark with date limit" begin
    data = parse_content(price_parser, price_content, from=Date("2022-02-11"))
    @test isa(data, Vector{T} where T <: FinancialData)
    # 3 datapoint for 4 tickers (filtered using from)
    @test length(data) == 3 * 4 
    dates = [x.date for x in data]
    @test minimum(dates) == Date("2022-02-11")
    @test maximum(dates) == Date("2022-02-15")
  end

  @testset "Test parsing failed API response" begin
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
    @test isa(data, Exception)
  end

  @testset "Test parsing succesfull yahoofinance response on AssetInfo" begin
    parser = Parsers.YahooInfoParser
    data = parse_content(parser, overview_content)
    @test isa(data, Vector{AssetInfo})
    @test length(data) == 1
  end



end
