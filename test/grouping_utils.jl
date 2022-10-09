using Dates
using Test

using Stonks
using Stonks.Models: AssetInfo, AssetPrice

include("test_utils.jl")

@testset "Grouping functions" begin

  prices = [
    AssetPrice(; symbol="MSFT", date=Date("2022-02-16"), close=200.00),
    AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=210.00),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-17"), close=160.00),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-18"), close=155.00),
  ]

  @testset "Correctly group data in" begin
    groups = Stonks.groupby(prices, [:symbol])
    @test length(groups) == 2
    @test sort([k.symbol for (k, v) in groups]) == sort(unique(map(x -> x.symbol, prices)))
    @test [length(v) for (k, v) in groups] == [2, 2]
  end

  @testset "Correctly apply reducing functions to grouped data" begin 
    groups = Stonks.groupby(prices, [:symbol])
    reducers = [
      :date => maximum => :date_max, 
      :date => minimum => :date_min,
      :close => minimum => :close_min,
      :close => maximum => :close_max,
    ]
    
    res = Stonks.aggregate(groups, reducers)
    @test sort(res) ==  [
      (symbol = "AAPL", date_max = Date("2022-02-18"), date_min = Date("2022-02-17"), close_min = 155.00, close_max = 160.00),
      (symbol = "MSFT", date_max = Date("2022-02-17"), date_min = Date("2022-02-16"), close_min = 200.00, close_max = 210.00)
    ]
    
  end 

  @testset "Empty array should return nothing" begin 
    grouped = Stonks.groupby(AssetPrice[], [:symbol]) 
    res = Stonks.aggregate(grouped, [:date => maximum => :date_max])
    @test grouped === nothing
    @test res === nothing
  end



end