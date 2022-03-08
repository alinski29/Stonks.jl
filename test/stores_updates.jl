using Dates
using DataFrames
using Test

using Stonks: SchemaValidationError, UpdatableSymbol, to_dataframe, last_workday
using Stonks.Stores: FileStore, load, save, update
using Stonks.Stores:
  find_update_candidates,
  list_partition_nesting,
  list_nested_files,
  validate_schema,
  symbols_from_df
using Stonks.Models: AssetPrice, AssetInfo, ExchangeRate

include("test_utils.jl")

@testset "Store updates" begin
  dest = joinpath(@__DIR__, "data/test_stonx")
  symbols = ["AAPL", "MSFT"]

  ds = FileStore{AssetPrice}(;
    path=dest, ids=[:symbol], partitions=[:symbol], time_column="date"
  )

  @testset "Generate Symbol types from datastore ids" begin
    ref_date = last_workday() - Day(7)
    prices = to_dataframe(fake_price_data(7, ref_date, symbols))
    upd_smb = symbols_from_df(prices, ds.ids; time_column=ds.time_column)
    @test upd_smb == map(x -> (x, ref_date + Day(1), last_workday()), symbols)
  end

  @testset "Update candidates, updates available" begin
    df = to_dataframe(fake_price_data(7, last_workday() - Dates.Day(7), symbols))
    candidates = find_update_candidates(df, symbols; ids=ds.ids, time_column=ds.time_column)
    @test length(candidates) == length(symbols)
    @test isa(maximum(map(x -> x.from, candidates)), Date)
  end

  @testset "Update candidates, updates available + new symbols" begin
    df = to_dataframe(fake_price_data(7, last_workday() - Dates.Day(7), symbols))
    symbols_new = vcat(symbols, ["IBM", "GOOG"])
    candidates_new = find_update_candidates(
      df, symbols_new; ids=ds.ids, time_column=ds.time_column
    )
    @test length(candidates_new) == length(symbols_new)
    @test @chain filter(x -> ismissing(x.from), candidates_new) map(x -> x.ticker, _) ==
      ["IBM", "GOOG"]
  end

  @testset "Update candidates, no updates available" begin
    df = to_dataframe(fake_price_data(7, last_workday(), symbols))
    candidates = find_update_candidates(df, symbols; ids=ds.ids, time_column=ds.time_column)
    @test isempty(candidates)
  end

  @testset "Update candidates, updates from new tickers only" begin
    df = to_dataframe(fake_price_data(7, today(), symbols))
    symbols_new = vcat(symbols, ["IBM", "GOOG"])
    candidates = find_update_candidates(
      df, symbols_new; ids=ds.ids, time_column=ds.time_column
    )
    @test length(candidates) == 2
    @test map(x -> x.ticker, candidates) == ["IBM", "GOOG"]
  end

  @testset "Update candidates exchange_rate, updates available" begin
    symbols = ["EUR/USD", "USD/CAD"]
    df = to_dataframe(fake_exchange_data(7, last_workday() - Dates.Day(7), symbols))
    candidates = find_update_candidates(
      df, symbols; ids=["base", "target"], time_column=ds.time_column
    )
    @test length(candidates) == length(symbols)
    @test isa(maximum(map(x -> x.from, candidates)), Date)
    @test all(map(c -> !isnothing(c.fx_pair), candidates))
  end

  @testset "Update candidates exchange_rate, updates available + new_symbols" begin
    symbols = ["EUR/USD", "USD/CAD"]
    df = to_dataframe(fake_exchange_data(7, last_workday() - Dates.Day(7), symbols))
    symbols_new = vcat(symbols, ["USD/JPY"])
    candidates = find_update_candidates(
      df, symbols_new; ids=["base", "target"], time_column="date"
    )
    @test length(candidates) == length(symbols_new)
    @test @chain filter(x -> ismissing(x.from), candidates) map(x -> x.ticker, _) ==
      ["USDJPY=X"]
    @test all(map(c -> !isnothing(c.fx_pair), candidates))
  end

  @testset "Update candidates exchange_rate, updates from new symbols only" begin
    symbols = ["EUR/USD", "USD/CAD"]
    df = to_dataframe(fake_exchange_data(7, last_workday() - Dates.Day(7), symbols))
    symbols_new = ["USD/JPY", "EUR/CZK"]
    candidates = find_update_candidates(
      df, symbols_new; ids=["base", "target"], time_column="date"
    )
    @test length(candidates) == length(symbols_new)
    @test @chain filter(x -> ismissing(x.from), candidates) map(x -> x.ticker, _) ==
      ["USDJPY=X", "EURCZK=X"]
  end

  @testset "Update candidates exchange_rate, no updates available" begin
    symbols = ["EUR/USD", "USD/CAD"]
    df = to_dataframe(fake_exchange_data(7, today(), symbols))
    candidates = find_update_candidates(
      df, symbols; ids=["base", "target"], time_column="date"
    )
    @test isempty(candidates)
  end
end
