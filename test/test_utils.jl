using Chain
using Dates
using Test

using Stonks:
  UpdatableSymbol,
  AssetPrice,
  ExchangeRate,
  is_weekday,
  last_sunday,
  last_workday,
  build_fx_pair


function fake_stock_data(days=30, ref_date=today(), symbols=["AAPL", "IBM", "TSLA"])
  dates = filter(x -> is_weekday(x), [ref_date - Day(i) for i in reverse(0:(days - 1))])
  n = length(dates)
  @chain symbols begin 
    map(s -> (symbol = repeat([s], n), date=dates, close=[100 + (rand(-8:10) * 0.1) for i in 1:n]), _)
    map(x -> [AssetPrice(; symbol = x.symbol[i], date = x.date[i], close = x.close[i]) for i in 1:n], _)
    vcat(_...)  
  end
end 


function fake_price_data(
  days=30, ref_date=today(), symbols=["AAPL", "IBM", "TSLA"]
)::Vector{AssetPrice}
  dates = @chain begin
    [ref_date - Day(i) for i in reverse(0:(days - 1))]
    filter(x -> is_weekday(x), _)
  end
  data = AssetPrice[]
  for symbol in symbols
    append!(
      data, map(d -> AssetPrice(; symbol=symbol, date=d, close=100 + rand() * 10), dates)
    )
  end
  return data
end

function fake_exchange_data(
  days=30, ref_date=today(), symbols=["EUR/USD", "USD/CAD", "USD/JPY"]
)::Vector{ExchangeRate}
  dates = @chain begin
    [ref_date - Day(i) for i in reverse(0:(days - 1))]
    filter(x -> is_weekday(x), _)
  end
  data = ExchangeRate[]
  for symbol in symbols
    base, target = build_fx_pair(symbol)
    append!(
      data,
      map(
        d -> ExchangeRate(; base=base, target=target, date=d, rate=1 + rand() * 10), dates
      ),
    )
  end
  return data
end

function test_info_data()
  return [
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
end

function test_price_data()
  return [
    AssetPrice(; symbol="MSFT", date=Date("2022-02-16"), close=299.5),
    AssetPrice(; symbol="MSFT", date=Date("2022-02-17"), close=290.73),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-17"), close=168.88),
    AssetPrice(; symbol="AAPL", date=Date("2022-02-18"), close=167.3),
  ]
end

get_test_data(path::String) = open(f -> read(f, String), joinpath(@__DIR__, path))

function complex_tickers()
  return [
    UpdatableSymbol("AAPL"; from="2022-01-01"),
    UpdatableSymbol("MSFT"; from="2022-02-10"),
    UpdatableSymbol("TSLA"; from="2022-02-10"),
    UpdatableSymbol("IBM"),
    UpdatableSymbol("GOOG"),
    UpdatableSymbol("NFLX"),
  ]
end
