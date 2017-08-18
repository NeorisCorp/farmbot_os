defmodule Farmbot.Bootstrap.Supervisor do
  @moduledoc """
  Starts services that require Authorization.
  this includes things like
  * HTTP
  * Realtime transports (MQTT, Websockets, etc)

  It is expected that there is authorization credentials in the application's
  environment by this point. This can be configured via a `Farmbot.Init` module.

  For example:

  # config.exs
      use Mix.Config

      config :farmbot, :init, [
        Farmbot.Configurator
      ]

      config :farmbot, :behaviour,
        authorization: Farmbot.Configurator

  # farmbot_configurator.ex

      defmodule Farmbot.Configurator do
        @moduledoc false
        @behaviour Farmbot.System.Init
        @behaviour Farmbot.Bootstrap.Authorization

        # Callback for Farmbot.System.Init.
        # This can return {:ok, pid} if it should be a supervisor.
        def start_link(_args, _opts) do
          creds = [
            email: "some_user@some_server.org",
            password: "some_secret_password_dont_actually_store_in_plain_text",
            server:   "https://my.farmbot.io"
          ]
          Application.put_env(:farmbot, :behaviour, creds)
          :ignore
        end

        # Callback for Farmbot.Bootstrap.Authorization.
        # Should return `{:ok, token}` where `token` is a binary jwt, or
        # {:error, reason} reason can be anything, but a binary is easiest to
        # Parse.
        def authorize(email, password, server) do
          # some intense http stuff or whatever.
          {:ok, token}
        end
      end

  This will cause the `creds` to be stored in the application's environment.
  This moduld then will try to use the configured module to `authorize`.

  If either of these things error, the bot try to factory reset
  """

  use Supervisor
  alias Farmbot.Bootstrap.Authorization, as: Auth
  require Logger

  error_msg = """
  Please configure an authorization module!
  for example:
      config: :farmbot, :behaviour, [
        authorization: Farmbot.Bootstrap.Authorization
      ]
  """
  @auth_task Application.get_env(:farmbot, :behaviour)[:authorization] || Mix.raise(error_msg)

  @doc "Start Bootstrap services."
  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    Logger.info "Beginning Authorization."
    # try to find the creds.
    case get_creds() do
      # do the actual supervisor init if we have creds. This may still fail.
      {email, pass, server} -> actual_init(args, email, pass, server)
      # This will cause a factory reset.
      {:error, reason}      -> {:error, reason}
    end
  end

  @typedoc "Authorization credentials."
  @type auth :: {Auth.email, Auth.password, Auth.server}

  @spec get_creds() :: auth | {:error, term}
  defp get_creds do
    try do
      # Get out authorization data out of the environment.
      # for host environment this will be configured at compile time.
      # for target environment it will be configured by `configurator`.
      email  = Application.get_env(:farmbot, :authorization)[:email   ] || raise Auth.Error, "No email provided."
      pass   = Application.get_env(:farmbot, :authorization)[:password] || raise Auth.Error, "No password provided."
      server = Application.get_env(:farmbot, :authorization)[:server  ] || raise Auth.Error, "No server provided."
      {email, pass, server}
    rescue
      # If there was an auth error, just take the message.
      # it makes the factory reset reason look nicer.
      e in Auth.Error -> {:error, e.message}
      # any other error, reraise it and let application.start/2 catch it.
      # the error will be formatted from there.
      e -> reraise e, System.stacktrace()
    end
  end

  defp actual_init(args, email, pass, server) do
    # get a token
    case @auth_task.authorize(email, pass, server) do
      {:ok, token} ->
        children = [
          supervisor(Farmbot.BotState.Supervisor,    [token, [name: Farmbot.BotState.Supervisor  ]])

          # supervisor(Farmbot.HTTP.Supervisor,      [token, [name: Farmbot.HTTP.Supervisor]]),
          # supervisor(Farmbot.Transport.Supervisor, [token, [name: Farmbot.Transport.Supervisor]])
        ]
        opts = [strategy: :one_for_all]
        supervise(children, opts)
      # I don't actually _have_ to factory reset here. It would get detected ad
      # an application start fail and we would factory_reset from there,
      # the error message is just way more useful here.
      {:error, reason} -> Farmbot.System.factory_reset(reason)
    end
  end
end