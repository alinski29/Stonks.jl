using Chain
using DataFrames
using Test

using Stonks: SchemaValidationError, to_dataframe
using Stonks.Stores: FileStore, load, save
using Stonks.Stores:
  generate_partition_pairs,
  filter_files,
  list_nested_files,
  list_partition_nesting,
  validate_schema
using Stonks.Models: AssetPrice, AssetInfo

include("test_utils.jl")

@testset "Store functionality" begin
  symbols = ["AAPL", "MSFT"]
  dest = joinpath(@__DIR__, "data/test_stonks")
  prices = to_dataframe(test_price_data())
  info = to_dataframe(test_info_data())
  ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"])
  dsp = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"])

  @testset "Schema validation" begin
    @test validate_schema(AssetPrice, prices)
    @test isa(validate_schema(AssetInfo, prices), SchemaValidationError)
  end

  @testset "Store writes - valid schema with no partitions" begin
    save(ds, prices)
    @test readdir(dest) == ["data.csv"]
    @test filesize("$dest/data.csv") > 0
    rm(dest; recursive=true, force=true)
  end

  @testset "Store writes - valid schema with partitions" begin
    save(dsp, prices)
    @test readdir(dest) == map(s -> "symbol=$s", symbols)
    @test minimum(map(s -> filesize("$dest/symbol=$s/data.csv"), symbols)) > 0
    rm(dest; recursive=true, force=true)
  end

  @testset "Store writes - invalid schema" begin
    @test isa(save(dsp, info), SchemaValidationError)
  end

  @testset "Store kwargs constructors" begin 
    # ids which are not members of AssetPrice => throw error
    try_ds = try 
      FileStore{AssetPrice}(; path=dest, ids=["foo", "bar"])
    catch err
      err 
    end
    @test typeof(try_ds) === DomainError
    # partitions which are not members of AssetPrice => throw error
    try_ds = try 
      FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["foo", "bar"])
    catch err
      err 
    end
    @test typeof(try_ds) === DomainError
    # more than 2 ids should throw a DomainError
    try_ds = try 
      FileStore{AssetPrice}(; path=dest, ids=["symbol", "date", "close"])
    catch err
      err 
    end  
    @test typeof(try_ds) === DomainError
  end

  @testset "Default arguments" begin 
    ds = FileStore{AssetPrice}(; path=dest, ids=[:symbol])
    @test ds.time_column == "date"
    @test ds.format == "csv"
    @test ds.partitions == []
    ds = FileStore{AssetInfo}(; path=dest, ids=[:symbol])
    @test ismissing(ds.time_column)
  end

  @testset "Partition pairs" begin
    partitions = generate_partition_pairs(prices, dsp.partitions)
    @test length(partitions) == 2
    @test sort(map(x -> x.key, partitions)) == map(s -> "symbol=$s", symbols)
  end

  @testset "Store read" begin
    save(dsp, prices)
    data = load(dsp)
    @test readdir(dest) == map(s -> "symbol=$s", symbols)
    @test nrow(data) == nrow(prices)
    get_type_param(::Vector{S}) where {S} = S
    df_types = [(name=col, type=get_type_param(data[:, col])) for col in names(data)]
    @test map(x -> x.name, df_types) == [String(x) for x in fieldnames(AssetPrice)]
    @test validate_schema(AssetPrice, data) == true
    rm(dsp.path; recursive=true, force=true)
  end

  @testset "Initialize a datastore" begin
    isdir(dest) && rm(dest; recursive=true, force=true)
    ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"])
    df = load(ds)
    @test nrow(df) == 0
    @test validate_schema(AssetPrice, df)
    rm(dest; recursive=true, force=true)
  end

  @testset "Initialize a datastore with 1 partition" begin
    ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"])
    df = load(ds)
    @test nrow(df) == 0
    @test validate_schema(AssetPrice, df)
    @test readdir("$dest/symbol=__init__") == ["data.csv"]
    rm(dest; recursive=true, force=true)
  end

  @testset "Initialize a datastore with multiple partitions" begin
    ds = FileStore{AssetPrice}(;
      path=dest, ids=["symbol"], partitions=["symbol", "date"]
    )
    df = load(ds)
    @test nrow(df) == 0
    @test validate_schema(AssetPrice, df)
    @test list_partition_nesting(ds.path) == ds.partitions
    @test readdir("$dest/symbol=__init__/date=__init__") == ["data.csv"]
    rm(dest; recursive=true, force=true)
  end

  @testset "Filter files with a datastore with one partition" begin
    ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"])
    ref_date, symb = (last_workday(), ["AAPL", "MSFT", "IBM", "GOOG"])
    prices = to_dataframe(fake_price_data(7, ref_date, symb))
    save(ds, prices)
    all_files = list_nested_files(ds.path)
    p_files = filter_files(ds, Dict("symbol" => symbols[1:2]))
    @test length(p_files) < length(all_files)
    @test all(map(x -> !contains(x, "symbol=GOOG"), p_files))

    err = filter_files(ds, Dict("foo" => ["bar", "baz"]))
    @test typeof(err) <: Exception
    rm(dest; recursive=true, force=true)
  end

  @testset "Filter files with a datastore with multiple partitions" begin
    ds = FileStore{AssetPrice}(;
      path=dest, ids=["symbol"], partitions=["symbol", "date"]
    )
    ref_date, symb = (last_workday(), ["AAPL", "MSFT", "IBM", "GOOG"])
    prices = to_dataframe(fake_price_data(7, ref_date, symb))
    save(ds, prices)
    all_files = list_nested_files(ds.path)
    p_files = @chain begin
      map(i -> Dates.format(ref_date - Day(i), "Y-mm-dd"), 1:3)
      filter_files(ds, Dict("symbol" => symbols[1:2], "date" => _))
    end
    @test length(p_files) < length(all_files)
    @test all(map(x -> !contains(x, "symbol=GOOG"), p_files))

    symbols_new = vcat(symb[1:2], ["FOO", "BAR"])
    files_new = filter_files(ds, Dict("symbol" => symbols_new))
    @test length(files_new) < length(all_files) && length(files_new) > length(p_files)
    rm(dest; recursive=true, force=true)
  end

  @testset "Load a datastore using partition pruning" begin
    ds = FileStore{AssetPrice}(; path=dest, ids=["symbol"], partitions=["symbol"])
    ref_date, symb = (last_workday(), ["AAPL", "MSFT", "IBM", "GOOG"])
    prices = to_dataframe(fake_price_data(7, ref_date, symb))
    save(ds, prices)
    df = load(ds, Dict("symbol" => ["AAPL", "MSFT"]))
    @test sort(unique(df[:, :symbol])) == ["AAPL", "MSFT"]
    data = load(ds, Dict("foo" => ["BAR", "BAZ"]))
    #println(data)
    @test typeof(data) <: Exception
    rm(dest; recursive=true, force=true)
  end

  isdir(dest) && rm(dest; recursive=true, force=true)
end
