# Welcome

---
Welcome to Stonks.jl documentation.
The resource aims to give you all the information needed about this package. Weather you need just the basics in order to get started, or have more advanced use cases for which you meed to extend the functionality, you should find your answers here.

---
## About
Stonks.jl is the Julia library that lets you access and store financial data from multiple APIs into a unified data model. It gives you the tools to generalize the data retrieval and storage from any API with a simple API in a type-safe manner.

---
## Motivation
You want to analyze some financial data to optimize your portfolio, test some strategies, whatever.
Quality historical data is hard to find for free. You might find the data you need, but scattered across several API providers, each with its own formats, parameters, rate limits, etc. You need to write lots of code and do a lot of validation in order to get the data you want.

Stonks.jl solves this problem by trying to find the best sources for financial data, parse them and return them into a type-safe form.
It is highly extensible, allowing you to define any API resource and your own data types. 

The next problem I encountered was that I wanted a reliable way to store data locally and update it from time to time with new data. 
That problem is solved by [`FileStore`](@ref), which can work with any file format. Supports data partitioning, writes are atomic, schema validation on read and write. Incrementally update everything in your "local database" with [just one function](api_functions.html#Stonks.Stores.update).

---
## Features
- Designed to work with several APIs in an agnostic way, where several APIs are capable of returning the same data.
- Comes with a pre-defined data model (types), but you're free to [design your own types](advanced_usage.html#Create-API-resources-for-your-custom-models).
- Store and update data locally with ease using the [`FileStore`](basic_usage.html#persisting-data), which can work with [any file format](advanced_usage.html#Plug-in-any-data-format). Supports data partitioning, writes are atomic, schema validation on read and write. Incrementally update everything in your datastore with just one function.
- [Tables.j; integration](basic_usage.html#Tablesjl-integration)
- Batching of multiple stock tickers if the API resource allows it, thus minimizing the number of requests.
- Asynchronous request processing. Multiple requests will processed asynchronously and multi-threaded, thus minimizing the network wait time.
- Silent by design. The main exposed functions for fetching and saving data don't throw an error, making your program crash. Instead, it will return the error with a descriptive message of what went wrong. 

---

## Manual
```@contents
Pages = ["index.md", "basic_usage.md", "advanced_usage.md", "api_types.md", "api_functions.md", "contributing.md"]
Depth = 2
```

---
