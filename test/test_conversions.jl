using Test

using Stonx
using Dates
using DataFrames

include("test_utils.jl")

@testset "Testing conversions" begin

  info = [
    AssetInfo("AAPL", "USD", "Apple Inc.", "EQUITY", "NMS", "United States", "Consumer Electronics", "Technology", "America/New_York", 100000),
    AssetInfo("MSFT", "USD", "Microsoft Corporation", "EQUITY", missing, "United States", "Software—Infrastructure", "Technology", "America/New_York", 181000),
  ]

  prices = [
    AssetPrice("MSFT", Date("2022-02-16"), 299.5, missing, missing, missing, missing, missing),
    AssetPrice("MSFT", Date("2022-02-17"), 290.73, missing, missing, missing, missing, missing),
    AssetPrice("AAPL", Date("2022-02-17"), 168.88, missing, missing, missing, missing, missing),
    AssetPrice("AAPL", Date("2022-02-18"), 167.3, missing, missing, missing, missing, missing),
  ]

  @testset "Test to dataframe conversion of AssetInfo" begin
    df = to_dataframe(info)
    model_types = [(String(name), T) for (name, T) in zip(fieldnames(AssetInfo), AssetInfo.types)]
    df_types = [(name, eltype(x)) for (name, x) in zip(names(df), eachcol(df))]
    @test length(info) == nrow(df)
    @test model_types == df_types
  end

  @testset "Test to dataframe conversion of AssetPrice" begin
    df = to_dataframe(prices)
    model_types = [(String(name), T) for (name, T) in zip(fieldnames(AssetPrice), AssetPrice.types)]
    df_types = [(name, eltype(x)) for (name, x) in zip(names(df), eachcol(df))]
    @test length(prices) == nrow(df)
    @test model_types == df_types
  end
  
end
