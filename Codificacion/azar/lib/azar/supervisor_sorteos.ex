defmodule Azar.SupervisorSorteos do
  @moduledoc """
  DynamicSupervisor: crea y vigila un proceso ServidorSorteo
  por cada sorteo existente.

  A diferencia de un Supervisor normal (que tiene hijos fijos),
  el DynamicSupervisor puede levantar y bajar hijos en tiempo
  de ejecución — perfecto para sorteos que se crean dinámicamente.

  Árbol de procesos resultante:
    Azar.Supervisor (raíz)
    ├── Azar.RegistroSorteos       (Registry: sorteo_id → PID)
    ├── Azar.SupervisorSorteos     (DynamicSupervisor)
    │   ├── ServidorSorteo "sorteo_001"   ← proceso exclusivo
    │   ├── ServidorSorteo "sorteo_002"   ← proceso exclusivo
    │   └── ServidorSorteo "sorteo_003"   ← proceso exclusivo
    └── Azar.Servidor              (GenServer central)
  """

  use DynamicSupervisor

  # ---------------------------------------------------------------------------
  # INICIO
  # ---------------------------------------------------------------------------

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # :one_for_one: si un ServidorSorteo muere, solo ese se reinicia
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # ---------------------------------------------------------------------------
  # API PÚBLICA
  # ---------------------------------------------------------------------------

  @doc """
  Levanta un proceso ServidorSorteo para el sorteo dado.
  Se llama desde GestorSorteos.crear_sorteo/5 automáticamente.
  """
  def iniciar_sorteo(sorteo_id) do
    spec = {Azar.ServidorSorteo, sorteo_id}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        IO.puts("⚙️  Proceso para sorteo '#{sorteo_id}' iniciado [PID: #{inspect(pid)}]")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        IO.puts("⚠️  El sorteo '#{sorteo_id}' ya tiene proceso activo")
        {:ok, pid}

      error ->
        IO.puts("❌ No se pudo iniciar proceso para '#{sorteo_id}': #{inspect(error)}")
        error
    end
  end

  @doc """
  Lista los IDs de los sorteos que tienen proceso activo ahora mismo.
  """
  def sorteos_activos do
    Registry.select(Azar.RegistroSorteos, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Al arrancar la app, carga un proceso para cada sorteo pendiente
  que ya exista en el JSON (para no perder el estado entre reinicios).
  """
  def cargar_sorteos_existentes do
    sorteos = Azar.Utils.JsonHelper.leer_archivo("priv/data/sorteos.json")

    pendientes = Enum.reject(sorteos, fn s -> s["realizado"] end)

    Enum.each(pendientes, fn s -> iniciar_sorteo(s["id"]) end)

    IO.puts("✅ #{length(pendientes)} sorteo(s) cargados con proceso activo")
  end
end
