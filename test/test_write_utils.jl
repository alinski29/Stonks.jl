using CSV
using DataFrames
using Test

using Stonx.Datastores: WriteOperation, WriteTransaction
using Stonx.Datastores: backup, cleanup, commit, execute, rollback, write, write_tmp
using Stonx.Datastores: list_partition_nesting

include("test_utils.jl")

@testset "Datastore writes" begin
  symbols = ["AAPL", "IBM"]
  data = fake_stock_data(7, last_workday(), symbols)
  dest = joinpath(@__DIR__, "data/test_stonx")
  tr = @chain symbols begin 
    map(s -> WriteOperation(filter(:symbol => ==(s), data), "csv", "symbol=$s"), _) 
    WriteTransaction(_, "csv", dest)
  end
  writer_csv(df::AbstractDataFrame, path::String) = CSV.write(path, df)
  get_type_param(::Vector{S}) where {S} = S

  @testset "Write using a WriteOperation" begin
    path = joinpath(@__DIR__, "data/test_stonx")
    @chain begin
      WriteOperation(data, "csv")
      write(_, path, writer_csv)
    end
    @test isfile("$path/data.csv")
    @test filesize("$path/data.csv") > 0
    rm(path; recursive=true, force=true)
  end

  @testset "Write transaction individual functions" begin
    write_tmp(tr, writer_csv)
    @test sort(readdir("$dest/.tmp")) == ["symbol=AAPL", "symbol=IBM"]
    @test filesize("$dest/.tmp/symbol=IBM") > 0
    @test filesize("$dest/.tmp/symbol=AAPL") > 0

    commit(tr)
    dirs = @chain readdir(dest) filter(x -> !startswith(x, "."), _) sort
    @test list_partition_nesting(dest) == ["symbol"]
    @test dirs == ["symbol=AAPL", "symbol=IBM"]
    @test filesize("$dest/symbol=IBM") > 0
    @test filesize("$dest/symbol=AAPL") > 0

    has_backup, bkps = backup(tr)
    @test sort(readdir("$dest/.bkp")) == ["symbol=AAPL", "symbol=IBM"]
    @test sort(readdir("$dest/.bkp")) == ["symbol=AAPL", "symbol=IBM"]

    foreach(x -> rm("$dest/symbol=$x"; recursive=true, force=true), ["AAPL", "IBM"])
    rollback(bkps)
    dirs = @chain readdir(dest) filter(x -> !startswith(x, "."), _) sort
    @test dirs == ["symbol=AAPL", "symbol=IBM"]

    cleanup(tr)
    @test isdir("$dest/.tmp") == false
    @test isdir("$dest/.bkp") == false

    rm(dest; recursive=true, force=true)
  end

  @testset "Write transaction execute method" begin
    status, err = execute(tr, writer_csv)
    @test isnothing(err)
    @test isdir(dest)
    @test isdir("$dest/.bkp") == false
    @test isdir("$dest/.tmp") == false
    rm(dest; recursive=true, force=true)
  end
end
