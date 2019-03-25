# Exiats

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exiats` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exiats, "~> 0.1.0"}
  ]
end
```

## Required Config

```
config :exiats, :global_config,
  merchant_key: "{merchant_key}",
  processor_id:  "{processor_id}"
```

Both of these keys can be found in your IATS transaction centre account. 

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exiats](https://hexdocs.pm/exiats).
