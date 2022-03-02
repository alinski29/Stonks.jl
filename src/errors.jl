export APIResponseError,
  APIRateExceeded, ContentParserError, DataClientError, RequestBuilderError

struct DataClientError <: Exception
  msg::String
end

struct ContentParserError <: Exception
  msg::String
end

struct APIResponseError <: Exception
  msg::String
end

struct RequestBuilderError <: Exception
  msg::String
end

struct APIRateExceeded <: Exception
  msg::String
end

struct SchemaValidationError <: Exception
  msg::String
end