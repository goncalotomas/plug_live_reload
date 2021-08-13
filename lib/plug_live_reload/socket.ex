defmodule PlugLiveReload.Socket do
  @moduledoc """
  Cowboy socket handler that sends websocket events. This websocket is what
  the `PlugLiveReload` plug's injected Javascript subscribes to in order
  to know when to reload.

  ## Usage

  Add the `PlugLiveReload.Socket` to your Cowboy child spec.

      children = [
        {Plug.Cowboy, scheme: :http, plug: MyApp.Router, options: [
          port: 4040,
          dispatch:  [
            {:_,
              [
                {"/plug_live_reload/socket", PlugLiveReload.Socket, []},
                {:_, Plug.Cowboy.Handler, {MyApp.Router, []}}
              ]
            }
          ]
        ]}
      ]

  This adds a new `:cowboy_websocket` handler for one route, `/plug_live_reload/socket`.
  All other routes will continue to be handled as usual by your plug router.

  ## Configuration

  TODO

  """

  require Logger

  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(request, state \\ %{}) do
    {:cowboy_websocket, request, state}
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    {:ok, _} = Application.ensure_all_started(:plug_live_reload)

    if Process.whereis(:phoenix_live_reload_file_monitor) do
      FileSystem.subscribe(:phoenix_live_reload_file_monitor)
      {:ok, state}
    else
      Logger.warn("live reload backend not running")
      {:stop, state}
    end
  end

  @impl :cowboy_websocket
  def websocket_handle(_inframe, state) do
    {:ok, state}
  end

  @impl :cowboy_websocket
  def websocket_info({:file_event, _pid, {path, _event}}, state) do
    patterns = Map.get(state, :patterns, [])

    if matches_any_pattern?(path, patterns) do
      asset_type = remove_leading_dot(Path.extname(path))
      Logger.debug("Live reload: #{Path.relative_to_cwd(path)}")
      {:reply, {:text, asset_type}, state}
    else
      {:ok, state}
    end
  end

  defp matches_any_pattern?(path, patterns) do
    path = to_string(path)

    Enum.any?(patterns, fn pattern ->
      String.match?(path, pattern) and !String.match?(path, ~r{(^|/)_build/})
    end)
  end

  defp remove_leading_dot("." <> rest), do: rest
  defp remove_leading_dot(rest), do: rest
end
