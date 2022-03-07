
using Dates
using Test

using Stonx
using Stonx.Models
using Stonx.Parsers

include("test_utils.jl")

@testset "Alphavantage parsers" begin
  price_content = get_test_data("data/alphavantage_prices.json")
  exchange_content = get_test_data("data/alphavantage_exchange.json")
  price_parser = Parsers.AlphavantagePriceParser
  info_parser = Parsers.AlphavantageInfoParser
  exchange_parser = Parsers.AlphavantageExchangeRateParser

  @testset "Succesful price response" begin
    data = parse_content(price_parser, price_content)
    dates = map(x -> x.date, data)
    @test isa(data, Vector{AssetPrice})
    @test minimum(dates) == Date("2022-02-15")
    @test maximum(dates) == Date("2022-02-18")
  end

  @testset "Succesful price response with from date limit" begin
    from = Date("2022-02-16")
    data = parse_content(price_parser, price_content; from=from)
    dates = map(x -> x.date, data)
    @test minimum(dates) == from
    @test maximum(dates) == Date("2022-02-18")
  end

  @testset "Succesful price response with from and to date limits" begin
    data = parse_content(
      price_parser, price_content; from=Date("2022-02-16"), to=Date("2022-02-17")
    )
    dates = map(x -> x.date, data)
    @test minimum(dates) == Date("2022-02-16")
    @test maximum(dates) == Date("2022-02-17")
  end

  @testset "Error response when API key is missing or invalid" begin
    content = """{
      "Error Message": "the parameter apikey is invalid or missing.
       Please claim your free API key on (https://www.alphavantage.co/support/#api-key).
       It should take less than 20 seconds."
    }""" |> c-> replace(c, "\n" => "")
    data = parse_content(price_parser, content)
    @test isa(data, APIResponseError)
  end

  @testset "Succesful overview (info) response" begin
    overview_content = get_test_data("data/alphavantage_overview.json")
    data = parse_content(info_parser, overview_content)
    @test length(data) == 1
    @test first(data).symbol == "IBM"
  end

  @testset "Successful exchange rate response" begin
    data = parse_content(exchange_parser, exchange_content)
    @test unique(map(x -> (x.base, x.target), data)) == [("EUR", "USD")]
    @test isa(data, Vector{ExchangeRate})
    @test length(data) == 5
  end

  @testset "Successful exchange rate response with from limit" begin
    from = Date("2022-02-18")
    data = parse_content(exchange_parser, exchange_content; from=from)
    @test minimum(map(x -> x.date, data)) == from
  end

  @testset "Successful exchange rate response with from and to limits" begin
    from, to = Date("2022-02-18"), Date("2022-02-21")
    data = parse_content(exchange_parser, exchange_content; from=from, to=to)
    dates = map(x -> x.date, data)
    @test minimum(dates) == from
    @test maximum(dates) == to
  end
end
