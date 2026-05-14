defmodule Azar.Admin.Menu do
  @moduledoc """
  Interfaz de consola para el administrador de Azar S.A.
  Permite gestionar sorteos y premios mediante un menú interactivo.

  Para iniciar:
    Azar.Admin.Menu.iniciar()
  """

  alias Azar.Servidor

  # ---------------------------------------------------------------------------
  # PUNTO DE ENTRADA
  # ---------------------------------------------------------------------------

  def iniciar do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║       AZAR S.A. — ADMINISTRADOR      ║
    ╚══════════════════════════════════════╝
    """)
    menu_principal()
  end

  # ---------------------------------------------------------------------------
  # MENÚ PRINCIPAL
  # ---------------------------------------------------------------------------

  defp menu_principal do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │         MENÚ PRINCIPAL          │
    ├─────────────────────────────────┤
    │  1. Gestión de Sorteos          │
    │  2. Gestión de Premios          │
    │  3. Reportes y Consultas        │
    │  4. Actualizar fecha del sistema│
    │  0. Salir                       │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> menu_sorteos()
      "2" -> menu_premios()
      "3" -> menu_reportes()
      "4" -> actualizar_fecha()
      "0" -> IO.puts("👋 Hasta luego.")
      _   -> opcion_invalida() ; menu_principal()
    end
  end

  # ---------------------------------------------------------------------------
  # MENÚ SORTEOS
  # ---------------------------------------------------------------------------

  defp menu_sorteos do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │         GESTIÓN SORTEOS         │
    ├─────────────────────────────────┤
    │  1. Crear sorteo                │
    │  2. Listar sorteos              │
    │  3. Eliminar sorteo             │
    │  4. Consultar clientes          │
    │  5. Consultar ingresos          │
    │  0. Volver                      │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> crear_sorteo()    ; menu_sorteos()
      "2" -> listar_sorteos()  ; menu_sorteos()
      "3" -> eliminar_sorteo() ; menu_sorteos()
      "4" -> consultar_clientes_sorteo() ; menu_sorteos()
      "5" -> consultar_ingresos()        ; menu_sorteos()
      "0" -> menu_principal()
      _   -> opcion_invalida() ; menu_sorteos()
    end
  end

  # ---------------------------------------------------------------------------
  # MENÚ PREMIOS
  # ---------------------------------------------------------------------------

  defp menu_premios do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │         GESTIÓN PREMIOS         │
    ├─────────────────────────────────┤
    │  1. Crear premio                │
    │  2. Listar premios              │
    │  3. Eliminar premio             │
    │  0. Volver                      │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> crear_premio()    ; menu_premios()
      "2" -> listar_premios()  ; menu_premios()
      "3" -> eliminar_premio() ; menu_premios()
      "0" -> menu_principal()
      _   -> opcion_invalida() ; menu_premios()
    end
  end

  # ---------------------------------------------------------------------------
  # MENÚ REPORTES
  # ---------------------------------------------------------------------------

  defp menu_reportes do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │       REPORTES Y CONSULTAS      │
    ├─────────────────────────────────┤
    │  1. Premios entregados          │
    │  2. Balance general             │
    │  0. Volver                      │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> Servidor.consultar_premios_entregados() ; menu_reportes()
      "2" -> Servidor.consultar_balance()            ; menu_reportes()
      "0" -> menu_principal()
      _   -> opcion_invalida() ; menu_reportes()
    end
  end

  # ---------------------------------------------------------------------------
  # ACCIONES DE SORTEOS
  # ---------------------------------------------------------------------------

  defp crear_sorteo do
    IO.puts("\n── Crear Sorteo ──────────────────")
    nombre    = leer_campo("Nombre del sorteo")
    fecha     = leer_campo("Fecha (YYYY-MM-DD)")
    valor     = leer_entero("Valor del billete completo ($)")
    fracciones = leer_entero("Cantidad de fracciones por billete")
    cantidad  = leer_entero("Cantidad de billetes")

    case Servidor.crear_sorteo(nombre, fecha, valor, fracciones, cantidad) do
      {:ok, _}        -> IO.puts("✅ Sorteo creado correctamente.")
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end
  end

  defp listar_sorteos do
    IO.puts("\n── Listado de Sorteos ────────────")
    Servidor.listar_sorteos()
  end

  defp eliminar_sorteo do
    IO.puts("\n── Eliminar Sorteo ───────────────")
    # Primero listamos para que el admin vea los ids
    Servidor.listar_sorteos()
    id = leer_campo("\nID del sorteo a eliminar")

    case Servidor.eliminar_sorteo(id) do
      {:ok, _}        -> IO.puts("✅ Sorteo eliminado.")
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end
  end

  defp consultar_clientes_sorteo do
    IO.puts("\n── Clientes por Sorteo ───────────")
    Servidor.listar_sorteos()
    sorteo_id = leer_campo("\nID del sorteo")
    Servidor.consultar_clientes_sorteo(sorteo_id)
  end

  defp consultar_ingresos do
    IO.puts("\n── Ingresos por Sorteo ───────────")
    Servidor.listar_sorteos()
    sorteo_id = leer_campo("\nID del sorteo")
    Servidor.consultar_ingresos(sorteo_id)
  end

  # ---------------------------------------------------------------------------
  # ACCIONES DE PREMIOS
  # ---------------------------------------------------------------------------

  defp crear_premio do
    IO.puts("\n── Crear Premio ──────────────────")
    Servidor.listar_sorteos()
    sorteo_id = leer_campo("\nID del sorteo")
    nombre    = leer_campo("Nombre del premio (ej: Primer Premio)")
    valor     = leer_entero("Valor del premio ($)")

    case Servidor.crear_premio(sorteo_id, nombre, valor) do
      {:ok, _}        -> IO.puts("✅ Premio creado correctamente.")
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end
  end

  defp listar_premios do
    IO.puts("\n── Listado de Premios ────────────")
    Servidor.listar_premios()
  end

  defp eliminar_premio do
    IO.puts("\n── Eliminar Premio ───────────────")
    Servidor.listar_premios()
    premio_id = leer_campo("\nID del premio a eliminar")

    case Servidor.eliminar_premio(premio_id) do
      {:ok, _}        -> IO.puts("✅ Premio eliminado.")
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end
  end

  # ---------------------------------------------------------------------------
  # ACTUALIZAR FECHA DEL SISTEMA
  # ---------------------------------------------------------------------------

  defp actualizar_fecha do
    IO.puts("\n── Actualizar Fecha del Sistema ──")
    IO.puts("Esto ejecutará todos los sorteos pendientes hasta la fecha indicada.")
    fecha = leer_campo("Nueva fecha del sistema (YYYY-MM-DD)")

    case Servidor.actualizar_fecha(fecha) do
      {:ok, []}        -> IO.puts("No había sorteos pendientes.")
      {:ok, resultados} ->
        IO.puts("✅ Sorteos ejecutados:")
        Enum.each(resultados, fn {nombre, res} ->
          IO.puts("  • #{nombre}: #{inspect(res)}")
        end)
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end

    menu_principal()
  end

  # ---------------------------------------------------------------------------
  # HELPERS — lectura de datos desde consola
  # ---------------------------------------------------------------------------

  # Lee una línea del teclado y quita espacios al inicio/fin
  defp leer_campo(etiqueta) do
    IO.write("#{etiqueta}: ")
    IO.gets("") |> String.trim()
  end

  # Lee un entero; si el usuario escribe algo inválido, vuelve a pedir
  defp leer_entero(etiqueta) do
    valor = leer_campo(etiqueta)
    case Integer.parse(valor) do
      {n, _} -> n
      :error ->
        IO.puts("⚠️  Ingresa un número válido.")
        leer_entero(etiqueta)
    end
  end

  # Lee la opción del menú
  defp leer_opcion do
    IO.write("Elige una opción: ")
    IO.gets("") |> String.trim()
  end

  defp opcion_invalida do
    IO.puts("⚠️  Opción no válida. Intenta de nuevo.")
  end
end
