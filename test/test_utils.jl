using Test

import Chain: @chain
import Stonx: UpdatableSymbol
import Dates

# function fake_stock_data(days=30, ref_date=Dates.today(), tickers=["AAPL", "IBM", "TSLA"])
#   dates = @chain begin [ref_date - Day(i) for i in reverse(0:days-1)] |> 
#     filter(x -> isweekday(x), _)
#   end
#   nrows = length(dates)
#   return @chain begin tickers
#    map(t -> DataFrame(
#     ticker=repeat([t], nrows),
#     date=dates,
#     price=[100 + (rand(-8:10) * 0.1) for i in 1:nrows]),
#     _) 
#    vcat(_...)
#   end
# end

isweekday(x) = !(Dates.issaturday(x) | Dates.issunday(x))

function last_sunday()
  td = Dates.today()
  p7d = [td - Dates.Day(i) for i in 1:7]
  return p7d[findfirst(Dates.issunday, p7d)]
end

function last_workday()
  td = Dates.today()
  @chain [td - Dates.Day(i) for i in 1:3] _[findfirst(isweekday ,_)]
end

function complex_tickers() 
  [
    UpdatableSymbol("AAPL", from = "2022-01-01"),
    UpdatableSymbol("MSFT", from = "2022-02-10"),
    UpdatableSymbol("TSLA", from = "2022-02-10"),
    UpdatableSymbol("IBM"),
    UpdatableSymbol("GOOG"),
    UpdatableSymbol("NFLX")
  ]
end
