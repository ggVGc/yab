defmodule YAB.MixProject do
  use Mix.Project

  def project do
    [
      app: :yab,
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:triq, "~> 1.2.0"},
      {:gb_merkle_trees, git: "https://github.com/aeternity/gb_merkle_trees.git", tag: "v0.2.0"}
    ]
  end
end
