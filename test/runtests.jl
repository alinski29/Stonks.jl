using Test

@testset "Stonks" begin
  include("requests.jl")
  include("apiclients.jl")
  include("parsers_utils.jl")
  include("parsers_yahoo.jl")
  include("parsers_alphavantage.jl")
  include("conversions.jl")
  include("stores_atomic_write.jl")
  include("stores.jl")
  include("stores_updates.jl")
  include("grouping_utils.jl")
end