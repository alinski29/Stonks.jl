using Dates
using JSON3
using Test

using Stonks: to_dataframe
using Stonks.Models: ExchangeRate, AssetInfo
using Stonks.Parsers: tryparse_js, js_to_dict, apply_filters, snake_case, JSONParser

include("test_utils.jl")

@testset "Parsing utility functions" begin
  content_ex = """{"from":"EUR", "to": "USD", "date": "2022-03-12", "close": "1.0915"}"""
  js_ex = JSON3.read(content_ex)

  @testset "Parse a flat js object into a data type with remaps" begin
    try_data = tryparse_js(ExchangeRate, js_ex)
    @test typeof(try_data) <: Exception
    ex = tryparse_js(
      ExchangeRate, js_ex; remaps=Dict(:base => :from, :target => :to, :rate => :close)
    )
    @test isa(ex, ExchangeRate)
    @test ex.base == js_ex[:from] &&
      ex.target == js_ex[:to] &&
      ex.date == Date(js_ex[:date])
  end

  @testset "Parse a flat js object into a data type with fields of wrong type" begin
    content = """{"symbol":"AAPL", "currency": "USD", "employees": "None"}"""
    data = tryparse_js(AssetInfo, JSON3.read(content))
    @test ismissing(data.employees)
  end

  @testset "Parse a flat js object into a data type with remaps and fixed values" begin
    content = """{"date": "2022-03-12", "close": "1.0915"}"""
    ex = tryparse_js(
      ExchangeRate,
      js_ex;
      remaps=Dict(:rate => :close),
      fixed=Dict(:base => "FOO", :target => "BAR"),
    )
    @test isa(ex, ExchangeRate)
    @test ex.base == "FOO" && ex.target == "BAR" && ex.date == Date(js_ex[:date])
  end

  @testset "Conert a JSON object to a dictionary" begin
    js_dict = js_to_dict(js_ex)
    @test isa(js_dict, Dict)
    @test isempty(setdiff(keys(js_dict), keys(js_ex)))
  end

  @testset "Conert a JSON nested object to a dict" begin
    content = """{
      "endDate": {
        "raw": 1640908800,
        "fmt": "2021-12-31"
      },
      "totalRevenue": {
        "raw": 3258000000,
        "fmt": "3.26B",
        "longFmt": "3,258,000,000"
      },
      "costOfRevenue": {
        "raw": -2680000000,
        "fmt": "-2.68B",
        "longFmt": "-2,680,000,000"
      }
    }"""
    js = JSON3.read(content)
    data = js_to_dict(js)
    @test isempty(setdiff(keys(data), keys(js)))
  end

  @testset "Apply date filters" begin
    prices = fake_price_data(7, Date("2022-03-12"))
    get_minmax(data) = @chain map(x -> x.date, data) (minimum(_), maximum(_))
    min, max = get_minmax(prices)
    p_filt = apply_filters(prices, "date"; from=min + Day(1), to=max - Day(1))
    p_min, p_max = get_minmax(p_filt)
    p_filt = apply_filters(prices, "date"; from=min + Day(1))
    p_min, p_max = get_minmax(p_filt)
    @test p_min == min + Day(1) && p_max == max
    p_filt = apply_filters(prices, "date"; to=max - Day(2))
    p_min, p_max = get_minmax(p_filt)
    @test p_min == min && p_max == max - Day(2)
    p_filt = apply_filters(prices, "date"; from=min + Day(3))
    p_min, p_max = get_minmax(p_filt)
    @test p_min == min + Day(3) && p_max == max
  end

  @testset "Converting camelCase to snake_case" begin
    snake_case("timeStamp")
    snake_case("askBestVolume")
    snake_case("askBest30MWPrice") 
  end
end
