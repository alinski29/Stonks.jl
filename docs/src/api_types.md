# Types

---
## Index
```@index
Pages = ["api_types.md"]
```

---
## Data Models
Defines the types into which data will be deserialized.
```@docs
AbstractStonksRecord
AssetInfo
AssetPrice
ExchangeRate
IncomeStatement
BalanceSheet
```
---
## API Clients
Stores information required to make requests HTTP APIs.
```@docs
Stonks.APIClients.AbstractDataClient
Stonks.APIClients.APIResource
Stonks.APIClients.APIClient
```

---
## Content Parsers
Parsers transform the content received from n HTTP request into a `Vector{<:AbstractStonxRecord}`
```@docs
Stonks.Parsers.AbstractContentParser
Stonks.Parsers.JSONParser
Stonks.Parsers.CSVParser
```

---
## Stores
Responsible for persisting and retrieving data: `Vector{<:AbstractStonxRecord}`.
```@docs
Stonks.Stores.AbstractStore
FileStore
```






