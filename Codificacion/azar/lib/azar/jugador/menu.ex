defmodule Azar.Jugador.Menu do
  @moduledoc """
  Interfaz de consola para los jugadores de Azar S.A.
  Permite registrarse, iniciar sesión y participar en sorteos.

  Para iniciar:
    Azar.Jugador.Menu.iniciar()
  """

  alias Azar.Servidor

  # ---------------------------------------------------------------------------
  # PUNTO DE ENTRADA
  # ---------------------------------------------------------------------------

  def iniciar do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║        AZAR S.A. — JUGADOR           ║
    ╚══════════════════════════════════════╝
    """)
    menu_acceso()
  end

  # ---------------------------------------------------------------------------
  # MENÚ DE ACCESO (antes de iniciar sesión)
  # ---------------------------------------------------------------------------

  defp menu_acceso do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │            ACCESO               │
    ├─────────────────────────────────┤
    │  1. Iniciar sesión              │
    │  2. Registrarse                 │
    │  0. Salir                       │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> iniciar_sesion()
      "2" -> registrarse()
      "0" -> IO.puts("👋 Hasta luego.")
      _   -> opcion_invalida() ; menu_acceso()
    end
  end

  # ---------------------------------------------------------------------------
  # REGISTRO
  # ---------------------------------------------------------------------------

  defp registrarse do
    IO.puts("\n── Registro de nuevo jugador ─────")
    nombre    = leer_campo("Nombre completo")
    documento = leer_campo("Número de documento")
    password  = leer_campo("Contraseña")

    IO.puts("\n── Datos de tarjeta (simulados) ──")
    numero_tarjeta = leer_campo("Número de tarjeta (16 dígitos)")
    vencimiento    = leer_campo("Vencimiento (MM/YY)")
    cvv            = leer_campo("CVV")

    tarjeta = %{
      "numero"      => numero_tarjeta,
      "vencimiento" => vencimiento,
      "cvv"         => cvv
    }

    case Servidor.registrar_cliente(nombre, documento, password, tarjeta) do
      {:ok, cliente} ->
        IO.puts("✅ Registro exitoso. Bienvenido, #{cliente["nombre"]}!")
        # Entramos directo al menú principal con la sesión activa
        menu_principal(cliente)

      {:error, motivo} ->
        IO.puts("❌ Error: #{motivo}")
        menu_acceso()
    end
  end

  # ---------------------------------------------------------------------------
  # INICIO DE SESIÓN
  # ---------------------------------------------------------------------------

  defp iniciar_sesion do
    IO.puts("\n── Iniciar Sesión ────────────────")
    documento = leer_campo("Documento")
    password  = leer_campo("Contraseña")

    case Servidor.login_cliente(documento, password) do
      {:ok, cliente} ->
        IO.puts("✅ Bienvenido, #{cliente["nombre"]}!")
        menu_principal(cliente)

      {:error, motivo} ->
        IO.puts("❌ Error: #{motivo}")
        menu_acceso()
    end
  end

  # ---------------------------------------------------------------------------
  # MENÚ PRINCIPAL (con sesión activa)
  # cliente es el mapa con los datos del jugador logueado
  # ---------------------------------------------------------------------------

  defp menu_principal(cliente) do
    IO.puts("""
    \n┌─────────────────────────────────┐
    │   Sesión: #{String.pad_trailing(cliente["nombre"], 23)}│
    ├─────────────────────────────────┤
    │  1. Ver sorteos disponibles     │
    │  2. Ver números disponibles     │
    │  3. Comprar billete             │
    │  4. Mi historial de compras     │
    │  5. Devolver una compra         │
    │  6. Mis premios                 │
    │  7. Mi balance personal         │
    │  8. Ver notificaciones          │
    │  0. Cerrar sesión               │
    └─────────────────────────────────┘
    """)

    case leer_opcion() do
      "1" -> ver_sorteos(cliente)
      "2" -> ver_numeros(cliente)
      "3" -> comprar(cliente)
      "4" -> historial(cliente)
      "5" -> devolver(cliente)
      "6" -> mis_premios(cliente)
      "7" -> mi_balance(cliente)
      "8" -> notificaciones(cliente)
      "0" -> IO.puts("👋 Sesión cerrada.") ; menu_acceso()
      _   -> opcion_invalida() ; menu_principal(cliente)
    end
  end

  # ---------------------------------------------------------------------------
  # ACCIONES DEL JUGADOR
  # ---------------------------------------------------------------------------

  defp ver_sorteos(cliente) do
    IO.puts("\n── Sorteos Disponibles ───────────")
    Servidor.sorteos_disponibles()
    menu_principal(cliente)
  end

  defp ver_numeros(cliente) do
    IO.puts("\n── Números Disponibles ───────────")
    Servidor.sorteos_disponibles()
    sorteo_id = leer_campo("\nID del sorteo")
    Servidor.numeros_disponibles(sorteo_id)
    menu_principal(cliente)
  end

  defp comprar(cliente) do
    IO.puts("\n── Comprar Billete ───────────────")
    Servidor.sorteos_disponibles()
    sorteo_id = leer_campo("\nID del sorteo")

    # Mostramos números disponibles antes de pedir el número
    Servidor.numeros_disponibles(sorteo_id)

    numero = leer_entero("\nNúmero de billete a comprar")

    IO.puts("\nTipo de compra:")
    IO.puts("  1. Billete completo")
    IO.puts("  2. Fracción")

    case leer_opcion() do
      "1" ->
        case Servidor.comprar_billete(cliente["id"], sorteo_id, numero, "completo") do
          {:ok, _}        -> IO.puts("✅ Billete completo comprado.")
          {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
        end

      "2" ->
        fraccion = leer_entero("Número de fracción")
        case Servidor.comprar_billete(cliente["id"], sorteo_id, numero, "fraccion", fraccion) do
          {:ok, _}        -> IO.puts("✅ Fracción comprada.")
          {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
        end

      _ -> opcion_invalida()
    end

    menu_principal(cliente)
  end

  defp historial(cliente) do
    IO.puts("\n── Historial de Compras ──────────")
    Servidor.historial_compras(cliente["id"])
    menu_principal(cliente)
  end

  defp devolver(cliente) do
    IO.puts("\n── Devolver Compra ───────────────")
    # Mostramos el historial para que el jugador vea los ids
    Servidor.historial_compras(cliente["id"])
    billete_id = leer_campo("\nID del billete a devolver")

    case Servidor.devolver_compra(billete_id, cliente["id"]) do
      {:ok, _}        -> IO.puts("✅ Compra devuelta correctamente.")
      {:error, motivo} -> IO.puts("❌ Error: #{motivo}")
    end

    menu_principal(cliente)
  end

  defp mis_premios(cliente) do
    IO.puts("\n── Mis Premios ───────────────────")
    Servidor.premios_cliente(cliente["id"])
    menu_principal(cliente)
  end

  defp mi_balance(cliente) do
    IO.puts("\n── Mi Balance Personal ───────────")
    Servidor.balance_cliente(cliente["id"])
    menu_principal(cliente)
  end

  defp notificaciones(cliente) do
    IO.puts("\n── Mis Notificaciones ────────────")
    Servidor.ver_notificaciones(cliente["id"])
    menu_principal(cliente)
  end

  # ---------------------------------------------------------------------------
  # HELPERS
  # ---------------------------------------------------------------------------

  defp leer_campo(etiqueta) do
    IO.write("#{etiqueta}: ")
    IO.gets("") |> String.trim()
  end

  defp leer_entero(etiqueta) do
    valor = leer_campo(etiqueta)
    case Integer.parse(valor) do
      {n, _} -> n
      :error ->
        IO.puts("⚠️  Ingresa un número válido.")
        leer_entero(etiqueta)
    end
  end

  defp leer_opcion do
    IO.write("Elige una opción: ")
    IO.gets("") |> String.trim()
  end

  defp opcion_invalida do
    IO.puts("⚠️  Opción no válida. Intenta de nuevo.")
  end
end
