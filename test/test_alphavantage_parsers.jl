
using Test
import Dates: Date, Day

using Stonx, Stonx.Models, Stonx.Parsers

@testset "Test alphavantage parsers" begin

  price_content = open(f -> read(f, String), "test/data/alphavantage_prices.json")
  exchange_content = open(f -> read(f, String), "test/data/alphavantage_exchange.json")
  price_parser = Parsers.AlphavantagePriceParser
  info_parser = Parsers.AlphavantageInfoParser
  exchange_parser = Parsers.AlphavantageExchangeRateParser

  @testset "Test parsing succesfull alphavantage response from query?function=TIME_SERIES_DAILY" begin
    data = parse_content(price_parser, price_content)
    dates = map(x -> x.date, data)
    @test isa(data, Vector{AssetPrice})
    @test minimum(dates) == Date("2022-02-15")
    @test maximum(dates) == Date("2022-02-18")
  end

  @testset "Test parsing succesfull alphavantage response from query?function=TIME_SERIES_DAILY with from date param" begin
    data = parse_content(price_parser, price_content, from = Date("2022-02-16"))
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-02-16")
    @test maximum(dates) == Date("2022-02-18")
  end

  @testset "Test parsing succesfull alphavantage response from query?function=TIME_SERIES_DAILY with from and to date param" begin
    data = parse_content(price_parser, price_content, from = Date("2022-02-16"), to = Date("2022-02-17"))
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-02-16")
    @test maximum(dates) == Date("2022-02-17")
  end

  @testset "Test parsing when API key is missing or invalid" begin
    content = """{
      "Error Message": "the parameter apikey is invalid or missing. Please claim your free API key on (https://www.alphavantage.co/support/#api-key). It should take less than 20 seconds."
    }"""
    data = parse_content(price_parser, content)
    @test typeof(data) <: Exception
  end

  @testset "Test parsing succesfull alphavantage response from query?function=OVERVIEW" begin
    overview_content = open(f -> read(f, String), "test/data/alphavantage_overview.json")
    data = parse_content(info_parser, overview_content)
    @test length(data) == 1
    @test first(data).symbol == "IBM"
  end

  @testset "Test parsing successfull alphavantage exchange rate response" begin
    data = parse_content(exchange_parser, exchange_content)
    @test isa(data, Vector{ExchangeRate})
    @test length(data) == 5
  end

  @testset "Test parsing successfull alphavantage exchange rate response with from limit" begin
    data = parse_content(exchange_parser, exchange_content, from = Date("2022-02-18"))
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-02-18")
  end

  @testset "Test parsing successfull alphavantage exchange rate response with from and to limits" begin
    data = parse_content(exchange_parser, exchange_content, from = Date("2022-02-18"), to = Date("2022-02-21"))
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-02-18")
    @test maximum(dates) == Date("2022-02-21")
  end

end
