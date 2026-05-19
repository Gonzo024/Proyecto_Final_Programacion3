defmodule Azar.Red do
  @moduledoc """
  Maneja la comunicación distribuida entre nodos de Elixir.

  El servidor corre en su propio nodo con nombre:
    iex --name servidor@127.0.0.1 --cookie azar_cookie -S mix

  Los clientes (admin y jugador) corren en nodos distintos:
    iex --name admin@127.0.0.1 --cookie azar_cookie -S mix
    iex --name jugador@127.0.0.1 --cookie azar_cookie -S mix

  La cookie es una clave compartida que permite a los nodos
  reconocerse y confiar entre sí. Sin la misma cookie, la
  conexión es rechazada.
  """

  # Nombre del nodo donde corre el servidor central
  # Cambiar la IP si el servidor está en otra máquina
  @nodo_servidor :"servidor@127.0.0.1"

  @doc """
  Conecta este nodo al nodo del servidor.
  Debe llamarse antes de hacer cualquier request.
  Retorna :ok o {:error, motivo}
  """
  def conectar do
    case Node.connect(@nodo_servidor) do
      true ->
        IO.puts("✅ Conectado al servidor en #{@nodo_servidor}")
        :ok

      false ->
        IO.puts("❌ No se pudo conectar a #{@nodo_servidor}")
        IO.puts("   Verifica que el servidor esté corriendo con:")
        IO.puts("   iex --name servidor@127.0.0.1 --cookie azar_cookie -S mix")
        {:error, "Conexión fallida"}

      :ignored ->
        # El nodo ya estaba conectado o es el mismo nodo
        :ok
    end
  end

  @doc """
  Verifica si hay conexión activa con el servidor.
  """
  def conectado? do
    @nodo_servidor in Node.list()
  end

  @doc """
  Retorna el nombre del nodo servidor para usarlo en GenServer.call
  """
  def nodo_servidor, do: @nodo_servidor

  @doc """
  Hace una llamada al GenServer remoto del servidor.
  Si no hay conexión, intenta reconectar primero.
  """
  def llamar(mensaje) do
    unless conectado?() do
      case conectar() do
        :ok -> :ok
        error -> throw(error)
      end
    end

    try do
      GenServer.call({:servidor_azar, @nodo_servidor}, mensaje, 10_000)
    catch
      :exit, {:noproc, _} ->
        {:error, "El servidor no está disponible. Intenta reconectar."}

      :exit, {:timeout, _} ->
        {:error, "El servidor tardó demasiado en responder."}
    end
  end
end
