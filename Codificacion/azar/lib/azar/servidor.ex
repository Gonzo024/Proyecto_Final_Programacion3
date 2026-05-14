defmodule Azar.Servidor do
  @moduledoc """
  Servidor central de Azar S.A.

  Funciona como GenServer: vive en memoria, recibe solicitudes
  de los clientes (admin y jugadores), las redirige a los
  gestores especializados y registra cada acción en bitácora.

  Para iniciar:
    Azar.Servidor.start_link([])

  Para llamarlo desde otro módulo:
    Azar.Servidor.crear_sorteo("Lotería", "2026-06-01", 30000, 5, 100)
  """

  use GenServer

  alias Azar.Servicios.GestorSorteos
  alias Azar.Servicios.GestorPremios
  alias Azar.Servicios.GestorClientes
  alias Azar.Utils.Bitacora

  # ---------------------------------------------------------------------------
  # API PÚBLICA — funciones que llaman los clientes (admin / jugador)
  # Estas funciones son las que usas desde fuera del servidor.
  # Internamente mandan un mensaje al proceso GenServer.
  # ---------------------------------------------------------------------------

  def start_link(_opts) do
    # Registra el proceso con el nombre :servidor_azar para encontrarlo fácil
    GenServer.start_link(__MODULE__, %{}, name: :servidor_azar)
  end

  # ── SORTEOS ──────────────────────────────────────────────────────────────────

  def crear_sorteo(nombre, fecha, valor, fracciones, cantidad) do
    GenServer.call(:servidor_azar, {:crear_sorteo, nombre, fecha, valor, fracciones, cantidad})
  end

  def listar_sorteos do
    GenServer.call(:servidor_azar, :listar_sorteos)
  end

  def eliminar_sorteo(id) do
    GenServer.call(:servidor_azar, {:eliminar_sorteo, id})
  end

  def consultar_clientes_sorteo(sorteo_id) do
    GenServer.call(:servidor_azar, {:consultar_clientes, sorteo_id})
  end

  def consultar_ingresos(sorteo_id) do
    GenServer.call(:servidor_azar, {:consultar_ingresos, sorteo_id})
  end

  def consultar_premios_entregados do
    GenServer.call(:servidor_azar, :consultar_premios_entregados)
  end

  def consultar_balance do
    GenServer.call(:servidor_azar, :consultar_balance)
  end

  def actualizar_fecha(fecha_nueva) do
    GenServer.call(:servidor_azar, {:actualizar_fecha, fecha_nueva})
  end

  # ── PREMIOS ───────────────────────────────────────────────────────────────────

  def crear_premio(sorteo_id, nombre, valor) do
    GenServer.call(:servidor_azar, {:crear_premio, sorteo_id, nombre, valor})
  end

  def listar_premios do
    GenServer.call(:servidor_azar, :listar_premios)
  end

  def eliminar_premio(premio_id) do
    GenServer.call(:servidor_azar, {:eliminar_premio, premio_id})
  end

  # ── CLIENTES / JUGADORES ──────────────────────────────────────────────────────

  def registrar_cliente(nombre, documento, password, tarjeta) do
    GenServer.call(:servidor_azar, {:registrar_cliente, nombre, documento, password, tarjeta})
  end

  def login_cliente(documento, password) do
    GenServer.call(:servidor_azar, {:login_cliente, documento, password})
  end

  def sorteos_disponibles do
    GenServer.call(:servidor_azar, :sorteos_disponibles)
  end

  def numeros_disponibles(sorteo_id) do
    GenServer.call(:servidor_azar, {:numeros_disponibles, sorteo_id})
  end

  def comprar_billete(cliente_id, sorteo_id, numero, tipo, fraccion_numero \\ nil) do
    GenServer.call(:servidor_azar, {:comprar_billete, cliente_id, sorteo_id, numero, tipo, fraccion_numero})
  end

  def historial_compras(cliente_id) do
    GenServer.call(:servidor_azar, {:historial_compras, cliente_id})
  end

  def devolver_compra(billete_id, cliente_id) do
    GenServer.call(:servidor_azar, {:devolver_compra, billete_id, cliente_id})
  end

  def premios_cliente(cliente_id) do
    GenServer.call(:servidor_azar, {:premios_cliente, cliente_id})
  end

  def balance_cliente(cliente_id) do
    GenServer.call(:servidor_azar, {:balance_cliente, cliente_id})
  end

  def ver_notificaciones(cliente_id) do
    GenServer.call(:servidor_azar, {:ver_notificaciones, cliente_id})
  end

  # ---------------------------------------------------------------------------
  # CALLBACKS DE GENSERVER — aquí es donde el servidor PROCESA los mensajes
  # No los llamas directamente; GenServer los invoca internamente.
  # ---------------------------------------------------------------------------

  @impl true
  def init(estado_inicial) do
    IO.puts("🚀 Servidor Azar S.A. iniciado correctamente")
    {:ok, estado_inicial}
  end

  # ── HANDLE_CALL — mensajes que esperan respuesta ──────────────────────────

  @impl true
  def handle_call({:crear_sorteo, nombre, fecha, valor, fracciones, cantidad}, _from, estado) do
    resultado = GestorSorteos.crear_sorteo(nombre, fecha, valor, fracciones, cantidad)
    Bitacora.registrar("CREAR_SORTEO nombre=#{nombre}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call(:listar_sorteos, _from, estado) do
    resultado = GestorSorteos.listar_sorteos()
    Bitacora.registrar("LISTAR_SORTEOS", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:eliminar_sorteo, id}, _from, estado) do
    resultado = GestorSorteos.eliminar_sorteo(id)
    Bitacora.registrar("ELIMINAR_SORTEO id=#{id}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:consultar_clientes, sorteo_id}, _from, estado) do
    resultado = GestorSorteos.consultar_clientes(sorteo_id)
    Bitacora.registrar("CONSULTAR_CLIENTES sorteo=#{sorteo_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:consultar_ingresos, sorteo_id}, _from, estado) do
    resultado = GestorSorteos.consultar_ingresos(sorteo_id)
    Bitacora.registrar("CONSULTAR_INGRESOS sorteo=#{sorteo_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call(:consultar_premios_entregados, _from, estado) do
    resultado = GestorSorteos.consultar_premios_entregados()
    Bitacora.registrar("CONSULTAR_PREMIOS_ENTREGADOS", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call(:consultar_balance, _from, estado) do
    resultado = GestorSorteos.consultar_balance()
    Bitacora.registrar("CONSULTAR_BALANCE", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:actualizar_fecha, fecha_nueva}, _from, estado) do
    # Ejecuta todos los sorteos pendientes cuya fecha <= fecha_nueva
    resultado = ejecutar_sorteos_pendientes(fecha_nueva)
    Bitacora.registrar("ACTUALIZAR_FECHA fecha=#{fecha_nueva}", :ok)
    {:reply, resultado, estado}
  end

  # ── PREMIOS ───────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:crear_premio, sorteo_id, nombre, valor}, _from, estado) do
    resultado = GestorPremios.crear_premio(sorteo_id, nombre, valor)
    Bitacora.registrar("CREAR_PREMIO sorteo=#{sorteo_id} nombre=#{nombre}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call(:listar_premios, _from, estado) do
    resultado = GestorPremios.listar_premios()
    Bitacora.registrar("LISTAR_PREMIOS", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:eliminar_premio, premio_id}, _from, estado) do
    resultado = GestorPremios.eliminar_premio(premio_id)
    Bitacora.registrar("ELIMINAR_PREMIO id=#{premio_id}", resultado)
    {:reply, resultado, estado}
  end

  # ── CLIENTES ──────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:registrar_cliente, nombre, documento, password, tarjeta}, _from, estado) do
    resultado = GestorClientes.registrar(nombre, documento, password, tarjeta)
    Bitacora.registrar("REGISTRAR_CLIENTE doc=#{documento}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:login_cliente, documento, password}, _from, estado) do
    resultado = GestorClientes.login(documento, password)
    Bitacora.registrar("LOGIN_CLIENTE doc=#{documento}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call(:sorteos_disponibles, _from, estado) do
    resultado = GestorClientes.sorteos_disponibles()
    Bitacora.registrar("SORTEOS_DISPONIBLES", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:numeros_disponibles, sorteo_id}, _from, estado) do
    resultado = GestorClientes.numeros_disponibles(sorteo_id)
    Bitacora.registrar("NUMEROS_DISPONIBLES sorteo=#{sorteo_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:comprar_billete, cliente_id, sorteo_id, numero, tipo, fraccion_numero}, _from, estado) do
    resultado = GestorClientes.comprar_billete(cliente_id, sorteo_id, numero, tipo, fraccion_numero)
    Bitacora.registrar("COMPRAR_BILLETE cliente=#{cliente_id} sorteo=#{sorteo_id} num=#{numero}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:historial_compras, cliente_id}, _from, estado) do
    resultado = GestorClientes.historial_compras(cliente_id)
    Bitacora.registrar("HISTORIAL_COMPRAS cliente=#{cliente_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:devolver_compra, billete_id, cliente_id}, _from, estado) do
    resultado = GestorClientes.devolver_compra(billete_id, cliente_id)
    Bitacora.registrar("DEVOLVER_COMPRA billete=#{billete_id} cliente=#{cliente_id}", resultado)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:premios_cliente, cliente_id}, _from, estado) do
    resultado = GestorClientes.premios_obtenidos(cliente_id)
    Bitacora.registrar("PREMIOS_CLIENTE cliente=#{cliente_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:balance_cliente, cliente_id}, _from, estado) do
    resultado = GestorClientes.balance_personal(cliente_id)
    Bitacora.registrar("BALANCE_CLIENTE cliente=#{cliente_id}", :ok)
    {:reply, resultado, estado}
  end

  @impl true
  def handle_call({:ver_notificaciones, cliente_id}, _from, estado) do
    resultado = GestorClientes.ver_notificaciones(cliente_id)
    Bitacora.registrar("VER_NOTIFICACIONES cliente=#{cliente_id}", :ok)
    {:reply, resultado, estado}
  end

  # Captura cualquier mensaje desconocido sin que el servidor explote
  @impl true
  def handle_call(mensaje_desconocido, _from, estado) do
    IO.puts("⚠️  Mensaje no reconocido: #{inspect(mensaje_desconocido)}")
    Bitacora.registrar("MENSAJE_DESCONOCIDO #{inspect(mensaje_desconocido)}", :negado)
    {:reply, {:error, "Mensaje no reconocido"}, estado}
  end

  # ---------------------------------------------------------------------------
  # LÓGICA INTERNA — actualizar fecha y ejecutar sorteos pendientes
  # ---------------------------------------------------------------------------

  defp ejecutar_sorteos_pendientes(fecha_nueva) do
    sorteos = Azar.Utils.JsonHelper.leer_archivo("priv/data/sorteos.json")

    # Filtramos sorteos que aún no se realizaron y cuya fecha ya pasó
    pendientes =
      sorteos
      |> Enum.filter(fn s ->
        not s["realizado"] and s["fecha"] <= fecha_nueva
      end)

    if pendientes == [] do
      IO.puts("No hay sorteos pendientes hasta #{fecha_nueva}")
      {:ok, []}
    else
      resultados =
        Enum.map(pendientes, fn sorteo ->
          IO.puts("🎰 Ejecutando sorteo: #{sorteo["nombre"]} (#{sorteo["fecha"]})")
          resultado = GestorSorteos.realizar_sorteo(sorteo["id"])

          # Notificamos a los jugadores ganadores
          case resultado do
            {:ok, _numeros} -> notificar_ganadores(sorteo["id"])
            _ -> :ok
          end

          {sorteo["nombre"], resultado}
        end)

      {:ok, resultados}
    end
  end

  # Envía notificaciones a los clientes que ganaron en un sorteo
  defp notificar_ganadores(sorteo_id) do
    premios   = Azar.Utils.JsonHelper.leer_archivo("priv/data/premios.json")
    clientes  = Azar.Utils.JsonHelper.leer_archivo("priv/data/clientes.json")
    sorteos   = Azar.Utils.JsonHelper.leer_archivo("priv/data/sorteos.json")

    sorteo = Enum.find(sorteos, fn s -> s["id"] == sorteo_id end)

    premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo_id end)

    clientes_actualizados =
      Enum.map(clientes, fn cliente ->
        # Buscamos si este cliente ganó algún premio
        notifs_nuevas =
          premios_sorteo
          |> Enum.filter(fn p -> cliente["id"] in p["ganadores"] end)
          |> Enum.map(fn p ->
            "🎉 Ganaste #{p["nombre"]} en '#{sorteo["nombre"]}' con el número #{p["numero_ganador"]}. Premio: $#{p["valor"]}"
          end)

        if notifs_nuevas == [] do
          cliente
        else
          Map.update(cliente, "notificaciones", notifs_nuevas, fn existing ->
            existing ++ notifs_nuevas
          end)
        end
      end)

    Azar.Utils.JsonHelper.escribir_archivo("priv/data/clientes.json", clientes_actualizados)
    IO.puts("📨 Notificaciones enviadas a los ganadores del sorteo #{sorteo_id}")
  end
end
