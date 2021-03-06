defmodule Exiats.MixProject do
  use Mix.Project

  def project do
    [
      app: :exiats,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19.3"},
      {:earmark, "~> 1.3"},
      {:poison, "~> 4.0"},
      {:httpoison, "~> 1.5"},
      {:uuid, "~> 1.1"},
    ]
  end
end
