using Dates
using Test

using Stonks: to_table, to_dict
using Stonks.Models: AssetInfo, AssetPrice

include("test_utils.jl")

@testset "Conversions" begin

  prices = test_price_data()

  @testset "Vector{AssetPrice} to dict" begin
    dct = to_dict(prices)
    exp_names = [x for x in fieldnames(AssetPrice)]
    @test all(x -> x[1] in exp_names && x[2] == length(prices), [(k, length(vals)) for (k, vals) in dct])
  end
  
  @testset "Vector{AssetPrice} to table interface - named tuples" begin
    tbl = to_table(prices)
    exp_names = [x for x in fieldnames(AssetPrice)]
    @test all(col -> length(getfield(tbl, col)) == length(prices), exp_names)
  end

end
