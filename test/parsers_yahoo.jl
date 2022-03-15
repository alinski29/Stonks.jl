using Dates
using JSON3
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
  is_content = get_test_data("data/yahoo_income_statement.json")
  bs_content = get_test_data("data/yahoo_balance_sheet.json")
  eps_content = get_test_data("data/yahoo_earnings.json")
  price_parser = Parsers.YahooPriceParser
  exchange_parser = Parsers.YahooExchangeRateParser
  is_parser = Parsers.YahooIncomeStatementParser
  bs_parser = Parsers.YahooBalanceSheetParser
  eps_parser = Parsers.YahooEarningsParser

  @testset "Unpack quote summary response" begin
    content = """{
      "quoteSummary": {
        "result": null,
        "error": {
          "code": "Not Found",
          "description": "No fundamentals data found for any of the summaryTypes=incomeStatementHistory"
        }
      }
    }"""
    res = Parsers.unpack_quote_summary_response(JSON3.read(content))
    @test isa(res, APIResponseError)
    content = """{"foo": "bar"}"""
    res = Parsers.unpack_quote_summary_response(JSON3.read(content))
    @test isa(res, ContentParserError)
    content = """{
      "quoteSummary": {
        "result": [{"foo": "bar"}],
        "error": null
      }
    }"""
    res = Parsers.unpack_quote_summary_response(JSON3.read(content))
    @test isa(res, JSONContent)
  end

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
    @test isa(data, APIResponseError)
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

  @testset "Succesful income statement response" begin
    data = parse_content(is_parser, is_content; symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) == Date("2018-12-31")
    @test maximum(dates) == Date("2021-12-31")
    @test isa(data, Vector{IncomeStatement})
  end

  @testset "Succesful income statement response with from date filter" begin
    data = parse_content(is_parser, is_content; from=Date("2020-01-01"), symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= Date("2020-01-01")
  end

  @testset "Failed income statement response" begin
    content = """{
      "quoteSummary": {
        "result": null,
        "error": {
          "code": "Not Found",
          "description": "No fundamentals data found for any of the summaryTypes=incomeStatementHistory"
        }
      }
    }"""
    res = parse_content(is_parser, content)
    @test isa(res, APIResponseError)
  end

  @testset "Succesful balance sheet response" begin
    data = parse_content(bs_parser, bs_content; symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) == Date("2018-12-31")
    @test maximum(dates) == Date("2021-12-31")
    @test isa(data, Vector{BalanceSheet})
  end

  @testset "Succesful balance sheet response with from date filter" begin
    data = parse_content(bs_parser, bs_content; from=Date("2020-01-01"), symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= Date("2020-01-01")
  end
 
  @testset "Succesful earnings response" begin
    data = parse_content(eps_parser, eps_content; symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) == Date("2021-03-31")
    @test maximum(dates) == Date("2021-12-31")
    @test isa(data, Vector{Earnings})
  end

  @testset "Succesful earnings response with from date filter" begin
    data = parse_content(eps_parser, eps_content; from=Date("2021-06-01"), symbol="IBM")
    dates = map(x -> x.fiscalDate, data)
    @test minimum(dates) >= Date("2020-06-30")
  end

  @testset "Succesful earnings response with yearly frequency (no data)" begin
    data = parse_content(eps_parser, eps_content; frequency="yearly")
    @test isa(data, Vector{Earnings})
    @test length(data) == 0
  end
end
