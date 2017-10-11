use Mix.Config

unless File.exists?("config/host/auth_secret_test.exs") do
  Mix.raise("You need to configure your test environment.\r\n")
end

import_config("auth_secret_test.exs")

config :farmbot, data_path: "tmp/"

config :farmbot, :init, [
  Farmbot.Host.Bootstrap.Configurator
]

# Transports.
config :farmbot, :transport, []

# Configure Farmbot Behaviours.
config :farmbot, :behaviour,
  authorization: Farmbot.Test.Authorization,
  system_tasks: Farmbot.Test.SystemTasks

config :farmbot, Farmbot.Repo.A,
  adapter: Sqlite.Ecto2,
  database: "test_A.sqlite3",
  priv: "priv/repo",
  pool: Ecto.Adapters.SQL.Sandbox

config :farmbot, Farmbot.Repo.B,
  adapter: Sqlite.Ecto2,
  database: "test_B.sqlite3",
  priv: "priv/repo",
  pool: Ecto.Adapters.SQL.Sandbox

config :farmbot, ecto_repos: [Farmbot.Repo.A, Farmbot.Repo.B, Farmbot.System.ConfigStorage]
