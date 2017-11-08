defmodule Farmbot.BotState.Transport.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    :farmbot
    |> Application.get_env(:transport)
    |> Enum.map(&worker(&1, []))
    |> supervise(strategy: :one_for_one)
  end
end