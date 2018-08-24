use Mix.Config

import_config "../apps/*/config/config.exs"

config :logger, :console,
  level: :debug,
  format: "\n$time $metadata\n[$level] $message\n",
  metadata: [:module, :function]
