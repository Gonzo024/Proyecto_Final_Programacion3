defmodule Azar.ServidorSorteo do
  @moduledoc """
  GenServer dedicado exclusivamente a UN sorteo.

  Cada sorteo tiene su propio proceso aislado registrado en
  Azar.RegistroSorteos. Si el proceso del "Sorteo A" falla,
  los demás sorteos siguen corriendo sin interrupciones.

  El DynamicSupervisor lo levanta automáticamente cuando
  el administrador crea un sorteo nuevo.

  Para encontrar el proceso de un sorteo específico:
    {:via, Registry, {Azar.RegistroSorteos, "sorteo_001"}}
  """

  use GenServer

  alias Azar.Utils.JsonHelper

  @archivo_sorteos  "priv/data/sorteos.json"
  @archivo_premios  "priv/data/premios.json"
  @archivo_billetes "priv/data/billetes.json"

  # ---------------------------------------------------------------------------
  # INICIO
  # ---------------------------------------------------------------------------

  def start_link(sorteo_id) do
    GenServer.start_link(
      __MODULE__,
      sorteo_id,
      # via Registry: registra el proceso con el id del sorteo como nombre
      # Esto permite encontrarlo después con via(sorteo_id) sin guardar el PID
      name: via(sorteo_id)
    )
  end

  # ---------------------------------------------------------------------------
  # API PÚBLICA DEL SERVIDOR DE SORTEO
  # ---------------------------------------------------------------------------

  @doc "Retorna los datos actuales del sorteo"
  def estado(sorteo_id), do: GenServer.call(via(sorteo_id), :estado)

  @doc "Realiza el sorteo: asigna números ganadores aleatorios a cada premio"
  def realizar(sorteo_id), do: GenServer.call(via(sorteo_id), :realizar)

  @doc "Retorna los números y fracciones disponibles para comprar"
  def numeros_disponibles(sorteo_id), do: GenServer.call(via(sorteo_id), :numeros_disponibles)

  @doc "Verifica si el proceso de este sorteo está activo"
  def activo?(sorteo_id) do
    case Registry.lookup(Azar.RegistroSorteos, sorteo_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  # ---------------------------------------------------------------------------
  # CALLBACKS GENSERVER
  # ---------------------------------------------------------------------------

  @impl true
  def init(sorteo_id) do
    # Cargamos el sorteo desde JSON al arrancar el proceso
    sorteo = cargar_sorteo(sorteo_id)
    IO.puts("⚙️  Servidor del sorteo '#{sorteo["nombre"]}' activo [PID: #{inspect(self())}]")
    {:ok, sorteo}
  end

  @impl true
  def handle_call(:estado, _from, sorteo) do
    {:reply, sorteo, sorteo}
  end

  @impl true
  def handle_call(:realizar, _from, sorteo) do
    if sorteo["realizado"] do
      {:reply, {:error, "El sorteo ya fue realizado"}, sorteo}
    else
      premios = JsonHelper.leer_archivo(@archivo_premios)
      premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)

      # Asignamos un número ganador único a cada premio
      {premios_actualizados, _usados} =
        Enum.map_reduce(premios_sorteo, [], fn premio, usados ->
          numero = numero_unico(sorteo["cantidad_billetes"], usados)
          {Map.put(premio, "numero_ganador", numero), [numero | usados]}
        end)

      # Guardamos premios actualizados
      otros = Enum.reject(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)
      JsonHelper.escribir_archivo(@archivo_premios, otros ++ premios_actualizados)

      # Actualizamos el sorteo como realizado en JSON
      numeros = Enum.map(premios_actualizados, & &1["numero_ganador"])
      sorteo_ok = sorteo |> Map.put("realizado", true) |> Map.put("numeros_ganadores", numeros)

      todos = JsonHelper.leer_archivo(@archivo_sorteos)
      JsonHelper.escribir_archivo(
        @archivo_sorteos,
        Enum.map(todos, fn s -> if s["id"] == sorteo["id"], do: sorteo_ok, else: s end)
      )

      # Asignamos ganadores buscando quién compró esos números
      asignar_ganadores(sorteo["id"], premios_actualizados)

      IO.puts("🎉 Sorteo '#{sorteo["nombre"]}' realizado. Ganadores: #{inspect(numeros)}")
      # Actualizamos el estado interno del proceso
      {:reply, {:ok, numeros}, sorteo_ok}
    end
  end

  @impl true
  def handle_call(:numeros_disponibles, _from, sorteo) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    vendidos =
      Enum.filter(billetes, fn b ->
        b["sorteo_id"] == sorteo["id"] and not b["devuelto"]
      end)

    info =
      Enum.map(1..sorteo["cantidad_billetes"], fn num ->
        compras = Enum.filter(vendidos, fn b -> b["numero"] == num end)
        %{numero: num, compras: compras}
      end)

    {:reply, {:ok, info}, sorteo}
  end

  # ---------------------------------------------------------------------------
  # FUNCIONES PRIVADAS
  # ---------------------------------------------------------------------------

  # Nombre via Registry — permite encontrar el proceso por id del sorteo
  defp via(sorteo_id) do
    {:via, Registry, {Azar.RegistroSorteos, sorteo_id}}
  end

  # Carga el sorteo desde el JSON
  defp cargar_sorteo(sorteo_id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) ||
      %{"id" => sorteo_id, "nombre" => "Desconocido", "realizado" => false, "cantidad_billetes" => 0}
  end

  # Número aleatorio que no esté ya usado
  defp numero_unico(max, usados) do
    n = :rand.uniform(max)
    if n in usados, do: numero_unico(max, usados), else: n
  end

  # Busca quién compró cada número ganador y los registra en el premio
  defp asignar_ganadores(sorteo_id, premios_con_numeros) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    todos_premios = JsonHelper.leer_archivo(@archivo_premios)

    actualizados =
      Enum.map(todos_premios, fn p ->
        if p["sorteo_id"] == sorteo_id do
          ganadores =
            billetes
            |> Enum.filter(fn b ->
              b["sorteo_id"] == sorteo_id and
              b["numero"] == p["numero_ganador"] and
              not b["devuelto"]
            end)
            |> Enum.map(fn b -> b["cliente_id"] end)

          Map.put(p, "ganadores", ganadores)
        else
          p
        end
      end)

    JsonHelper.escribir_archivo(@archivo_premios, actualizados)
    premios_con_numeros
  end
end
