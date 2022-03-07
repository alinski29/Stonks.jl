using Chain: @chain
using Dates: Day, today
using Test

using Stonx.APIClients
using Stonx.Requests
using Stonx: UpdatableSymbol, RequestBuilderError, split_tickers_in_batches, build_fx_pair,  construct_updatable_symbols
using Stonx.Models: AssetPrice

include("test_utils.jl")

@testset "Request utilities" begin
  test_client = APIClients.YahooClient("abc")

  @testset "Build FX pairs" begin
    @test build_fx_pair("EUR/USD") == ("EUR", "USD")
    @test isa(build_fx_pair("EUR&USD"), ArgumentError)
    @test isa(build_fx_pair("EURO/USD"), ArgumentError)
    @test isa(build_fx_pair("EUR/USD/CAD"), ArgumentError)
  end 

  @testset "Build UpdatableSymbol using an FX pair" begin
    @test first(construct_updatable_symbols("FOO/BAR")).fx_pair == ("FOO", "BAR")
    @test first(construct_updatable_symbols("FOOOO/BAR")).fx_pair |> ismissing
    @test last(construct_updatable_symbols(["EUR/USD", "USD/CAD"])).fx_pair == ("USD", "CAD")
  end

  @testset "Ticker batching when all dates are missing" begin
    tickers = @chain ["AAPL", "MSFT", "TSLA", "IBM"] map(t -> UpdatableSymbol(t), _)
    batches_max10 = split_tickers_in_batches(tickers, 10)
    batches_max2 = split_tickers_in_batches(tickers, 2)
    @test length(batches_max10) == 1
    @test length(batches_max2) == 2
  end

  # TODO - move it to test_utils.jl
  @testset "Complex ticker batching" begin
    tickers = complex_tickers()
    batches = split_tickers_in_batches(tickers, 2)
    groups = @chain batches map(batch -> map(t -> t.ticker, batch), _)
    @test length(batches) == 4
    @test groups == [["AAPL"], ["MSFT", "TSLA"], ["IBM", "GOOG"], ["NFLX"]]
  end

  # @testset "Ticker batching for exchange rates" begin
  #   tickers = construct_updatable_symbols(["EUR/USD", "USD/CAD", "FOO/BAR"])
  #   batches = split_tickers_in_batches(tickers, 2)
  #   println(batches)
  # end

  @testset "Request building using APIResource" begin
    tickers = complex_tickers()
    resource = test_client.endpoints["price"]
    resource.max_batch_size = 2
    request_params = Requests.prepare_requests(tickers, resource; interval="1d")
    @test length(request_params) == 4
    @test sum(map(r -> length(r.tickers), request_params)) == length(tickers)
  end

  # @testset "Test request building using APIClient" begin
  #   tickers = complex_tickers()
  #   request_params = Requests.prepare_requests(tickers, test_client, interval = "1d")
  #   println(request_params)
  #   #@test isa(request_params, Dict)
  #   #@test keys(request_params) == keys(test_client.endpoints)
  # end

  @testset "Resolution of url params" begin
    url = "https://example.com/{endpoint}/{symbol}?lang=en&symbol={symbol}"
    new_url = Requests.resolve_url_params(url; endpoint="quote", symbol="AAPL", foo="bar")
    @test new_url == "https://example.com/quote/AAPL?lang=en&symbol=AAPL"
  end

  @testset "Resolution of query parameters" begin
    query_params = Dict(
      "interval" => "{interval}",
      "range" => "{range}",
      "symbols" => "{symbols}",
      "content" => "json",
    )
    params_resolved = Requests.resolve_query_params(
      query_params; interval="1d", range="30d", symbols="AAPL,MSFT"
    )
    @test params_resolved["interval"] == "1d"
    @test params_resolved["symbols"] == "AAPL,MSFT"
    @test params_resolved["range"] == "30d"
    @test params_resolved["content"] == "json"
  end

  @testset "Resolution of all request parameters (url, query, others)" begin
    resource = test_client.endpoints["price"]
    tickers = complex_tickers()
    request_params = Requests.prepare_requests(tickers, resource; interval="1d")
    @test length(request_params) == 4
    @test first(request_params).params["interval"] == "1d"
  end

  @testset "Resolution of all request parameters (url, query, others) for yahoo exchange rates" begin
    resource = test_client.endpoints["exchange"]
    resource.max_batch_size = 2
    tickers = construct_updatable_symbols(["EUR/USD", "USD/CAD", "FOO/BAR"])
    batches = Requests.split_tickers_in_batches(tickers, resource.max_batch_size)
    request_params = map(b -> Requests.resolve_request_parameters(b, resource; interval="1d"), batches)
    @test length(request_params) == 2
    @test first(request_params).params["symbols"] == "EURUSD=X,USDCAD=X"
  end

  @testset "Resolution of all request parameters (url, query, others) for alphavantage exchange rates" begin
    client = APIClients.AlphavantageJSONClient("abc")
    resource = client.endpoints["exchange"]
    tickers = construct_updatable_symbols(["EUR/USD", "USD/CAD", "FOO/BAR"])
    batches = Requests.split_tickers_in_batches(tickers, resource.max_batch_size)
    request_params = map(b -> Requests.resolve_request_parameters(b, resource; interval="1d"), batches)
    @test length(request_params) == 3
    @test first(request_params).params["from_symbol"] == "EUR"
    @test first(request_params).params["to_symbol"] == "USD"
  end

  @testset "Resolution of request parameters for alphavantage json client" begin
    client = APIClients.AlphavantageJSONClient("abc")
    resource = client.endpoints["price"]
    tickers = @chain ["AAPL", "MSFT"] map(t -> UpdatableSymbol(t), _)
    request_params = Requests.prepare_requests(tickers, resource)
    @test first(request_params).params["symbol"] == "AAPL"
  end

  @testset "Resolution of request parameters for exchange rate" begin
    query_params = Dict(
      "function" => "FX_DAILY", "from_symbol" => "{base}", "to_symbol" => "{target}"
    )
    params_resolved = Requests.resolve_query_params(query_params; base="EUR", target="USD")
    @test params_resolved["from_symbol"] == "EUR"
    @test params_resolved["to_symbol"] == "USD"
  end

  @testset "Validation of request parameters" begin
    resource = test_client.endpoints["price"]
    resource.query_params = Dict(
      "symbols" => "{symbols}", "from_symbol" => "{base}", "foo" => "{target}"
    )
    tickers = @chain ["AAPL", "MSFT"] map(t -> UpdatableSymbol(t), _)
    rp = Requests.resolve_request_parameters(tickers, resource; base="USD")
    @test isa(rp, RequestBuilderError)
  end

  @testset "Optimistic request resolution - success" begin
    params = Requests.RequestParams(; 
      url = "http://example.com",
      tickers = map(UpdatableSymbol, ["AAPL", "MSFT"])
    )
    ok_values = [
      (
        params = params,
        value=[
          AssetPrice(; symbol="MSFT", date=Date("2022-02-16"), close=299.5),
          AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=299.92)
        ],
        err=nothing
      ),
      (
        params = params,
        value=[AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=290.73)],
        err=nothing,
      ),
      (
        params = params,
        value=nothing, 
        err=ErrorException("Somwething went wrong")
      )
    ]
    responses = Channel(3)
    foreach(v -> push!(responses, v), ok_values)
    close(responses)
    res = Requests.optimistic_request_resolution(AssetPrice, responses)
    @test isa(res, Vector{AssetPrice})
  end

  @testset "Optimistic request resolution - failure" begin
    params = Requests.RequestParams(; 
      url = "http://example.com",
      tickers = map(UpdatableSymbol, ["AAPL", "MSFT"])
    )
    values = [
      (params = params, value=nothing, err = ErrorException("Something went wrong")),
      (params = params, value=nothing, err = ErrorException("Another issue")),
    ]
    responses = Channel(2)
    foreach(v -> push!(responses, v), values)
    close(responses)
    res = Requests.optimistic_request_resolution(AssetPrice, responses)
    @test isa(res, ErrorException)
  end

  @testset "Conversion of date to range expression" begin
    today = Dates.today()
    conv_fn = Requests.convert_date_to_range_expr
    @test conv_fn(today) == "1d"
    @test conv_fn(today - Dates.Day(2)) == "5d"
    @test conv_fn(today - Dates.Day(7)) == "1mo"
    @test conv_fn(today - Dates.Day(28)) == "1mo"
    @test conv_fn(today - Dates.Day(30)) == "3mo"
    @test conv_fn(today - Dates.Day(89)) == "6mo"
    @test conv_fn(today - Dates.Day(179)) == "6mo"
    @test conv_fn(today - Dates.Day(180)) == "1y"
    @test conv_fn(today - Dates.Day(364)) == "1y"
    @test conv_fn(today - Dates.Day(365)) == "5y"
    @test conv_fn(today - Dates.Day(5000)) == "5y"
  end
end
