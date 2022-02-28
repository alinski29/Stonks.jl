using Test

using Stonx: DataClientError
using Stonx.APIClients: APIClient, APIResource, YahooClient
using Stonx.APIClients:
  get_type_param,
  get_supported_types,
  get_resource,
  get_resource_from_clients,
  build_clients_from_env
using Stonx.Models: AbstractStonxRecord, AssetInfo, AssetPrice, ExchangeRate

@testset "Client building utilities" begin
  test_client = YahooClient("abc")
  function unset_env_vars()
    for (k, _) in ENV
      (endswith(k, "_TOKEN") || endswith(k, "_APIKEY")) && delete!(ENV, k)
    end
  end
  set_env_vars() = foreach(k -> ENV[k] = "secret", ["ALPHAVANTAGE_TOKEN", "YAHOO_TOKEN"])
  unset_env_vars()

  @testset "Get type parameter of API resource" begin
    T = get_type_param(test_client.endpoints["price"])
    @test T === AssetPrice
  end

  @testset "Get supported types" begin
    types = get_supported_types(test_client)
    @test types == [ExchangeRate, AssetPrice, AssetInfo]
  end

  @testset "Get resource from client of a certain type" begin
    resource = get_resource(test_client, AssetInfo)
    @test get_type_param(resource) === AssetInfo
  end

  @testset "Build clients from environmental vars, no env vars set" begin
    unset_env_vars()
    @test isa(build_clients_from_env(), DataClientError)
  end

  @testset "Build clients from environmental vars, 2 env vars set" begin
    set_env_vars()
    clients = build_clients_from_env()
    @test length(clients) == 2
    @test isa(clients, Vector{APIClient})
    unset_env_vars()
  end

  @testset "Get one resource from multiple clients" begin
    set_env_vars()
    clients = build_clients_from_env()
    resource = get_resource_from_clients(clients, AssetPrice)
    @test isa(resource, APIResource{AssetPrice})
    unset_env_vars()
  end

  @testset "Get resource with no configured clients" begin
    set_env_vars()
    clients = build_clients_from_env()
    struct MyCustomType <: AbstractStonxRecord
      value::String
    end
    resource = get_resource_from_clients(clients, MyCustomType)
    @test isa(resource, DataClientError)
  end
end
