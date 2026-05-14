defmodule Azar.Application do
  @moduledoc """
  Punto de entrada de la aplicación Azar.

  El Supervisor es el "jefe" que vigila al servidor.
  Si el servidor muere por algún error, el supervisor lo reinicia
  automáticamente. Esto es lo que hace a Elixir tolerante a fallos.

  Para iniciar toda la app:
    mix run --no-halt
  O en iex:
    iex -S mix
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Lista de procesos que el supervisor debe vigilar
    children = [
      # El servidor central — si falla, se reinicia solo
      Azar.Servidor
    ]

    # Estrategia :one_for_one = si un hijo muere, solo reinicia ese hijo
    # (no reinicia los demás)
    opts = [strategy: :one_for_one, name: Azar.Supervisor]

    IO.puts("🏢 Iniciando sistema Azar S.A...")

    Supervisor.start_link(children, opts)
  end
end
