
using Dates
using Test

using Stonks
using Stonks: JSONContent, APIResponseError, ContentParserError
using Stonks.Models
using Stonks.Parsers

include("test_utils.jl")

@testset "Alphavantage parsers" begin
  price_content = get_test_data("data/alphavantage_prices.json")
  exchange_content = get_test_data("data/alphavantage_exchange.json")
  is_content = get_test_data("data/alphavantage_income_statement.json")
  bs_content = get_test_data("data/alphavantage_balance_sheet.json")
  eps_content = get_test_data("data/alphavantage_earnings.json")
  price_parser = Parsers.AlphavantagePriceParser
  info_parser = Parsers.AlphavantageInfoParser
  exchange_parser = Parsers.AlphavantageExchangeRateParser
  is_parser = Parsers.AlphavantageIncomeStatementParser
  bs_parser = Parsers.AlphavantageBalanceSheetParser
  eps_parser = Parsers.AlphavantageEarningsParser

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

  @testset "Successful income statement response" begin
    data = parse_content(is_parser, is_content)
    dates = map(x -> x.fiscalDate, data)
    @test isa(data, Vector{Models.IncomeStatement})
    @test length(data) == 25
    @test first(data).symbol == "IBM"
  end

  @testset "Successful income statement response with yearly frequency" begin
    data = parse_content(is_parser, is_content; frequency="yearly")
    @test length(data) == 5
  end

  @testset "Successful income statement response with quarterly frequency" begin
    data = parse_content(is_parser, is_content; frequency="quarterly")
    @test length(data) == 20
  end

  @testset "Successful income statement response with date filters" begin
    date_min, date_max = Date("2020-01-01"), Date("2020-12-31")
    data = parse_content(is_parser, is_content; from=date_min, to=date_max)
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= date_min && maximum(dates) <= date_max
  end

  @testset "Empty income statement response" begin
    res = parse_content(is_parser, "{}")
    @test isa(res, ContentParserError)
  end

  @testset "Successful balance sheet response" begin
    data = parse_content(bs_parser, bs_content)
    dates = map(x -> x.fiscalDate, data)
    @test isa(data, Vector{Models.BalanceSheet})
    @test length(data) == 25
    @test first(data).symbol == "IBM"
  end

  @testset "Successful balance sheet response with quarterly frequency" begin
    data = parse_content(bs_parser, bs_content; frequency="quarterly")
    @test length(data) == 20
  end

  @testset "Successful balance sheet response with date filters" begin
    date_min, date_max = Date("2020-01-01"), Date("2020-12-31")
    data = parse_content(bs_parser, bs_content; from=date_min, to=date_max)
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= date_min && maximum(dates) <= date_max
  end

  @testset "Empty balance sheet response" begin
    res = parse_content(bs_parser, "{}")
    @test isa(res, ContentParserError)
  end

  @testset "Successful earnings response" begin
    data = parse_content(eps_parser, eps_content)
    dates = map(x -> x.fiscalDate, data)
    @test isa(data, Vector{Models.Earnings})
    @test length(data) == 15
    @test first(data).symbol == "IBM"
  end

  @testset "Successful earnings response with quarterly frequency" begin
    data = parse_content(eps_parser, eps_content; frequency="quarterly")
    @test length(data) == 12
    @test unique(map(x -> x.frequency, data)) == ["quarterly"]
  end

  @testset "Successful earnings response with date filters" begin
    date_min, date_max = Date("2020-01-01"), Date("2020-12-31")
    data = parse_content(eps_parser, eps_content; from=date_min, to=date_max)
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= date_min && maximum(dates) <= date_max
  end

end
