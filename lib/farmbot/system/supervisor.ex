defmodule Farmbot.System.Supervisor do
  @moduledoc """
  Supervises Platform specific stuff for Farmbot to operate
  """
  use Supervisor
  import Farmbot.System.Init

  @doc false
  def start_link() do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    before_init_children = [
      worker(Farmbot.System.Init.FSCheckup, [[], []]),
      supervisor(Farmbot.System.Init.Ecto, [[], []]),
      supervisor(Farmbot.System.ConfigStorage, []),
      worker(Farmbot.System.ConfigStorage.Dispatcher, []),
      worker(Farmbot.System.GPIO.Leds, []),
      supervisor(Farmbot.System.Camera.Supervisor, [])
    ]

    init_mods =
      Application.get_env(:farmbot, :init)
      |> Enum.map(fn child -> fb_init(child, [[], [name: child]]) end)

    after_init_children = [
      supervisor(Farmbot.System.Updates, []),
      worker(Farmbot.System.GPIO, []),
      worker(Farmbot.EasterEggs, [])
    ]

    supervise(before_init_children ++ init_mods ++ after_init_children, strategy: :one_for_all)
  end
end
