defmodule Wallet.MixProject do
  use Mix.Project

  def project do
    [
      app: :wallet,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Wallet, {}}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yab, in_umbrella: true},
      {:chain_node, in_umbrella: true}
    ]
  end
end
