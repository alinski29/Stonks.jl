using Chain
using CSV
using Dates
using DataFrames
using Test

using Stonx: SchemaValidationError, UpdatableSymbol, to_dataframe, last_workday
using Stonx.Datastores: FileDatastore, find_update_candidates, validate_schema, load, save, update
using Stonx.Models: AssetPrice, AssetInfo

include("test_utils.jl")

@testset "Datastore updates" begin
  dest = joinpath(@__DIR__, "data/test_stonx")
  symbols = ["AAPL", "MSFT"]
  
  reader_csv(path::String) = CSV.File(path) |> DataFrame
  writer_csv(df::AbstractDataFrame, path::String) = CSV.write(path, df)
  ds = FileDatastore{AssetPrice}(dest, "csv", ["symbol"], ["symbol"], "date", reader_csv, writer_csv)

  @testset "Update candidates, updates available" begin 
    df = fake_price_data(7,  last_workday() - Dates.Day(7), symbols) |> to_dataframe
    candidates = find_update_candidates(df, symbols; keys=ds.keys, time_column=ds.time_column)
    @test length(candidates) == length(symbols)
    @test isa(maximum(map(x -> x.from, candidates)), Date)
  end 

  @testset "Update candidates, updates available + new symbols" begin
    df = fake_price_data(7, last_workday() - Dates.Day(7), symbols) |> to_dataframe
    symbols_new = vcat(symbols, ["IBM", "GOOG"])
    candidates_new = find_update_candidates(df, symbols_new; keys=ds.keys, time_column=ds.time_column)
    @test length(candidates_new) == length(symbols_new)
    @test @chain filter(x -> ismissing(x.from), candidates_new) map(x -> x.ticker, _) == ["IBM", "GOOG"]
  end

  @testset "Update candidates, no updates available" begin
    df = fake_price_data(7, last_workday(), symbols) |> to_dataframe
    candidates = find_update_candidates(df, symbols; keys=ds.keys, time_column=ds.time_column)
    @test isempty(candidates)
  end

  @testset "Update candidates, updates from new tickers only" begin
    df = fake_price_data(7, today(), symbols) |> to_dataframe
    symbols_new = vcat(symbols, ["IBM", "GOOG"])
    candidates = find_update_candidates(df, symbols_new; keys=ds.keys, time_column=ds.time_column)
    @test length(candidates) == 2
    @test map(x -> x.ticker, candidates) == ["IBM", "GOOG"]
  end

  @testset "Initialize a datastore" begin
    ds = FileDatastore{AssetPrice}(dest, "csv", ["symbol"], [], "date", reader_csv, writer_csv)
    df = load(ds)
    @test nrow(df) == 0
    @test validate_schema(AssetPrice, df)
    rm(dest, recursive=true, force=true)
  end 

  # @testset "Update a datastore" begin
  #   # Not yet implemented, requires solution for mocking API calls
  #   prices = fake_price_data(7,  last_workday() - Dates.Day(7), symbols) |> to_dataframe
  #   save(ds, prices)
  #   symbols_new = vcat(symbols, ["IBM", "GOOG"])
  #   upd_symbols = [("AAPL", Date("2022-02-16")), ("MSFT", Date("2022-02-16")), ("IBM", Date("2022-02-18"))]
  #   new_df = @chain update(ds, upd_symbols) load(_)
  #   max_date = @chain new_df groupby(_, :symbol) combine(_, :date => minimum, :date => maximum, :symbol => length) 
  #   show(max_date)
  #   rm(dest, recursive=true, force=true)
  # end

end
