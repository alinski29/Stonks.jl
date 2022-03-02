using CSV
using DataFrames
using Test

using Stonx: SchemaValidationError, to_dataframe
using Stonx.Datastores: FileDatastore, generate_partition_pairs, validate_schema, load, save
using Stonx.Models: AssetPrice, AssetInfo

include("test_utils.jl")

@testset "Datastore functionality" begin
  symbols = ["AAPL", "MSFT"]
  dest = joinpath(@__DIR__, "data/test_stonx")

  prices = test_price_data() |> to_dataframe
  info = test_info_data() |> to_dataframe

  reader_csv(path::String) = CSV.File(path) |> DataFrame
  writer_csv(df::AbstractDataFrame, path::String) = CSV.write(path, df)
  get_type_param(::Vector{S}) where {S} = S
  ds = FileDatastore{AssetPrice}(dest, "csv", ["symbol"],  [], "date", reader_csv, writer_csv)
  dsp = FileDatastore{AssetPrice}(dest, "csv", ["symbol"], ["symbol"], "date", reader_csv, writer_csv)

  @testset "Schema validation" begin 
    @test validate_schema(AssetPrice, prices)
    @test isa(validate_schema(AssetInfo, prices), SchemaValidationError)
  end

  @testset "Datastore writes - valid schema with no partitions" begin
    save(ds, prices)
    @test readdir(dest) == ["data.csv"]
    @test filesize("$dest/data.csv") > 0
    rm(dest, recursive=true, force=true)
  end
  
  @testset "Datastore writes - valid schema with partitions" begin
    save(dsp, prices)
    @test readdir(dest) == map(s -> "symbol=$s", symbols)
    @test minimum(map(s -> filesize("$dest/symbol=$s/data.csv"), symbols)) > 0
    rm(dest, recursive=true, force=true)
  end

  @testset "Datastore writes - invalid schema" begin
    @test isa(save(dsp, info), SchemaValidationError)
  end 

  @testset "Partition pairs" begin 
    partitions = generate_partition_pairs(prices, dsp.partitions)
    @test length(partitions) == 2 
    @test sort(map(x -> x.key, partitions)) == map(s -> "symbol=$s", symbols)
  end

  @testset "Datastore read" begin
    save(dsp, prices)
    data = load(dsp)
    @test readdir(dest) == map(s -> "symbol=$s", symbols)
    @test nrow(data) == nrow(prices)
    df_types = [(name=col, type=get_type_param(data[:, col])) for col in names(data)]
    @test map(x -> x.name, df_types) == [String(x) for x in fieldnames(AssetPrice)]
    @test validate_schema(AssetPrice, data) == true
    rm(dsp.path, recursive=true, force=true)
  end

end

