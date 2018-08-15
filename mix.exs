defmodule YAB.MixProject do
  use Mix.Project

  def project do
    [
      app: :yab,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

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
