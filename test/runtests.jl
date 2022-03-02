using Test

@testset "Stonx" begin
  include("test_request.jl")
  include("test_apiclients.jl")
  include("test_yahoo_parsers.jl")
  include("test_alphavantage_parsers.jl")
  include("test_conversions.jl")
  include("test_write_utils.jl")
  include("test_datastore.jl")
  include("test_updates.jl")
end