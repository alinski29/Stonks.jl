using Test

@testset "Stonx" begin
  include("test_request.jl")
  include("test_yahoo_parsers.jl")
  include("test_alphavantage_parsers.jl")
  include("test_conversions.jl")
end