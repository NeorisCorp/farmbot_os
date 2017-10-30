defmodule Farmbot.CeleryScript.AST do
  @moduledoc """
  Handy functions for turning various data types into Farbot Celery Script
  Ast nodes.
  """

  alias Farmbot.CeleryScript.Error

  @typedoc """
  CeleryScript args.
  """
  @type args :: map

  @typedoc """
  Type for CeleryScript Ast's.
  """
  @type t :: %__MODULE__{
          args: args,
          body: [t, ...],
          kind: String.t(),
          comment: String.t() | nil
        }

  @enforce_keys [:args, :body, :kind]
  defstruct kind: nil,
            args: %{},
            body: [],
            comment: nil

  @doc """
  Parses json and traverses the tree and turns everything can
  possibly be parsed.
  """
  @spec parse(map | [map, ...]) :: t
  def parse(map_or_json_map)

  def parse(%{"kind" => kind, "args" => args} = thing) do
    body = thing["body"] || []
    comment = thing["comment"]
    %__MODULE__{kind: kind, args: parse_args(args), body: parse(body), comment: comment}
  end

  def parse(%{__struct__: _} = thing) do
    thing |> Map.from_struct() |> parse
  end

  def parse(%{kind: kind, args: args} = thing) do
    body = thing[:body] || []
    comment = thing[:comment]
    %__MODULE__{kind: kind, body: parse(body), args: parse_args(args), comment: comment}
  end

  # You can give a list of nodes.
  def parse(body) when is_list(body) do
    Enum.reduce(body, [], fn blah, acc ->
      acc ++ [parse(blah)]
    end)
  end

  # TODO: This is a pretty heavy memory leak, what should happen is
  # The corpus should create a bunch of atom, and then this should be
  # Strint.to_existing_atom
  @spec parse_args(map) :: map
  def parse_args(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      if is_map(val) do
        # if it is a map, it could be another node so parse it too.
        real_val = parse(val)
        Map.put(acc, String.to_atom(key), real_val)
      else
        Map.put(acc, String.to_atom(key), val)
      end
    end)
  end
end