using DataFrames
using Dates
using Test

using Stonks: to_dataframe
using Stonks.Models: AssetInfo, AssetPrice

include("test_utils.jl")

@testset "Conversions" begin

  prices = test_price_data()
  info = test_info_data()

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
