defmodule Azar.Main do
  @moduledoc """
  Punto de entrada del sistema completo.
  Permite elegir si entras como administrador o como jugador.

  Cómo usar en iex:
    iex -S mix
    iex> Azar.Main.iniciar()
  """

  def iniciar do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║         BIENVENIDO A AZAR S.A.       ║
    ║      Sistema de Gestión de Sorteos   ║
    ╚══════════════════════════════════════╝

      1. Soy Administrador
      2. Soy Jugador
      0. Salir
    """)

    IO.write("¿Quién eres? ")
    opcion = IO.gets("") |> String.trim()

    case opcion do
      "1" -> Azar.Admin.Menu.iniciar()
      "2" -> Azar.Jugador.Menu.iniciar()
      "0" -> IO.puts("👋 Hasta luego.")
      _   ->
        IO.puts("⚠️  Opción no válida.")
        iniciar()
    end
  end
end
