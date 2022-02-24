using DataFrames: nrow
using Dates
using Test

using Stonx: to_dataframe
using Stonx.Models: AssetInfo, AssetPrice

@testset "Conversions" begin
  info = [
    AssetInfo(;
      symbol="AAPL",
      currency="USD",
      name="Apple Inc.",
      type="EQUITY",
      exchange="NMS",
      country="United States",
      industry="Consumer Electronics",
      sector="Technology",
      timezone="America/New_York",
      employees=100000,
    ),
    AssetInfo(;
      symbol="MSFT",
      currency="USD",
      name="Microsoft Corporation",
      type="EQUITY",
      country="United States",
      industry="Software—Infrastructure",
      sector="Technology",
      timezone="America/New_York",
      employees=181000,
    ),
  ]

  prices = [
    AssetPrice(; symbol="MSFT", date=Date("2022-02-16"), close=299.5),
    AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=290.73),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-17"), close=168.88),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-18"), close=167.3),
  ]

  @testset "Vector{AssetInfo} to DataFrame" begin
    df = to_dataframe(info)
    model_types = [
      (String(name), T) for (name, T) in zip(fieldnames(AssetInfo), AssetInfo.types)
    ]
    df_types = [(name, eltype(x)) for (name, x) in zip(names(df), eachcol(df))]
    @test length(info) == nrow(df)
    @test model_types == df_types
  end

  @testset "Vector{AssetPrice} to DataFrame" begin
    df = to_dataframe(prices)
    model_types = [
      (String(name), T) for (name, T) in zip(fieldnames(AssetPrice), AssetPrice.types)
    ]
    df_types = [(name, eltype(x)) for (name, x) in zip(names(df), eachcol(df))]
    @test length(prices) == nrow(df)
    @test model_types == df_types
  end
end
