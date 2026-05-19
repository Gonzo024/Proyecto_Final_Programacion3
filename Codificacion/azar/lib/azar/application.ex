defmodule Azar.Application do
  @moduledoc """
  Punto de entrada de la aplicación Azar S.A.

  Levanta el árbol de supervisión completo en orden:
  1. Registry primero (los demás lo necesitan para registrarse)
  2. DynamicSupervisor de sorteos
  3. Servidor central GenServer

  Luego carga los procesos de sorteos existentes en el JSON.

  COMANDOS PARA CORRER EL SISTEMA DISTRIBUIDO:

  Terminal 1 — SERVIDOR:
    iex --name servidor@127.0.0.1 --cookie azar_cookie -S mix

  Terminal 2 — ADMIN:
    iex --name admin@127.0.0.1 --cookie azar_cookie -S mix
    iex> Azar.Red.conectar()
    iex> Azar.Admin.Menu.iniciar()

  Terminal 3 — JUGADOR:
    iex --name jugador1@127.0.0.1 --cookie azar_cookie -S mix
    iex> Azar.Red.conectar()
    iex> Azar.Jugador.Menu.iniciar()
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Registry: directorio que mapea sorteo_id → PID del proceso
      #    Debe arrancar PRIMERO porque ServidorSorteo lo necesita al iniciarse
      {Registry, keys: :unique, name: Azar.RegistroSorteos},

      # 2. DynamicSupervisor: gestiona los procesos especializados por sorteo
      Azar.SupervisorSorteos,

      # 3. Servidor central: recibe todas las requests de los clientes
      Azar.Servidor
    ]

    opts = [strategy: :one_for_one, name: Azar.Supervisor]

    IO.puts("""
    ╔══════════════════════════════════════════╗
    ║       AZAR S.A. — Iniciando sistema...   ║
    ╚══════════════════════════════════════════╝
    """)

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Una vez levantado todo, cargamos los sorteos existentes
        Azar.SupervisorSorteos.cargar_sorteos_existentes()
        {:ok, pid}

      error ->
        error
    end
  end
end
