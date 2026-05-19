defmodule Azar.Servicios.GestorSorteos do
  @moduledoc """
  Gestión completa de sorteos con persistencia JSON.

  CAMBIO CLAVE vs la versión anterior:
  Al crear un sorteo, ahora también levanta un proceso
  ServidorSorteo dedicado mediante el DynamicSupervisor.
  Ese proceso es el "servidor especializado por sorteo"
  que pide el profesor.
  """

  alias Azar.Utils.JsonHelper
  alias Azar.SupervisorSorteos

  @archivo_sorteos  "priv/data/sorteos.json"
  @archivo_premios  "priv/data/premios.json"
  @archivo_billetes "priv/data/billetes.json"
  @archivo_clientes "priv/data/clientes.json"

  # ---------------------------------------------------------------------------
  # CREAR SORTEO — también levanta el proceso especializado
  # ---------------------------------------------------------------------------

  def crear_sorteo(nombre, fecha, valor_billete, fracciones, cantidad_billetes) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    id = "sorteo_#{System.os_time(:millisecond)}"

    nuevo_sorteo = %{
      "id"                => id,
      "nombre"            => nombre,
      "fecha"             => fecha,
      "valor_billete"     => valor_billete,
      "fracciones"        => fracciones,
      "cantidad_billetes" => cantidad_billetes,
      "realizado"         => false,
      "numeros_ganadores" => []
    }

    case JsonHelper.escribir_archivo(@archivo_sorteos, [nuevo_sorteo | sorteos]) do
      :ok ->
        # 🔑 PUNTO CRÍTICO: levantamos el proceso dedicado para este sorteo
        SupervisorSorteos.iniciar_sorteo(id)
        IO.puts("✅ Sorteo '#{nombre}' creado [#{id}] — proceso especializado activo")
        {:ok, nuevo_sorteo}

      :error ->
        {:error, "No se pudo guardar el sorteo"}
    end
  end

  # ---------------------------------------------------------------------------
  # LISTAR SORTEOS
  # ---------------------------------------------------------------------------

  def listar_sorteos do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    if sorteos == [] do
      IO.puts("No hay sorteos registrados.")
    else
      sorteos
      |> Enum.sort_by(fn s -> s["fecha"] end)
      |> Enum.each(fn sorteo ->
        IO.puts("\n─────────────────────────────────")
        IO.puts("📋 #{sorteo["nombre"]}  [#{sorteo["id"]}]")
        IO.puts("   Fecha: #{sorteo["fecha"]}")
        IO.puts("   Billete: $#{sorteo["valor_billete"]} | Fracciones: #{sorteo["fracciones"]} | Billetes: #{sorteo["cantidad_billetes"]}")

        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)

        if premios_sorteo == [] do
          IO.puts("   Sin premios registrados.")
        else
          IO.puts("   🏆 Premios:")
          Enum.each(premios_sorteo, fn p ->
            IO.puts("      - #{p["nombre"]}: $#{p["valor"]}")
          end)
        end

        if sorteo["realizado"] do
          IO.puts("   ✅ REALIZADO - Números ganadores: #{inspect(sorteo["numeros_ganadores"])}")
          Enum.each(premios_sorteo, fn p ->
            if p["ganadores"] != [] do
              IO.puts("      #{p["nombre"]} → ganadores: #{Enum.join(p["ganadores"], ", ")}")
            end
          end)
        else
          # Mostramos si tiene proceso activo
          activo = Azar.ServidorSorteo.activo?(sorteo["id"])
          estado_proceso = if activo, do: "⚙️ proceso activo", else: "⚠️ sin proceso"
          IO.puts("   ⏳ Pendiente (#{estado_proceso})")
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # ELIMINAR SORTEO
  # ---------------------------------------------------------------------------

  def eliminar_sorteo(id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    case Enum.find(sorteos, fn s -> s["id"] == id end) do
      nil ->
        {:error, "Sorteo con id '#{id}' no encontrado"}

      _sorteo ->
        tiene_premios = Enum.any?(premios, fn p -> p["sorteo_id"] == id end)

        if tiene_premios do
          {:error, "No se puede eliminar: el sorteo tiene premios asociados"}
        else
          nuevos_sorteos = Enum.reject(sorteos, fn s -> s["id"] == id end)

          case JsonHelper.escribir_archivo(@archivo_sorteos, nuevos_sorteos) do
            :ok ->
              IO.puts("🗑️  Sorteo '#{id}' eliminado")
              {:ok, "Sorteo eliminado"}

            :error ->
              {:error, "Error al guardar los cambios"}
          end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # CONSULTAR CLIENTES DE UN SORTEO
  # ---------------------------------------------------------------------------

  def consultar_clientes(sorteo_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    billetes_sorteo =
      Enum.filter(billetes, fn b ->
        b["sorteo_id"] == sorteo_id and not b["devuelto"]
      end)

    if billetes_sorteo == [] do
      IO.puts("No hay clientes para este sorteo.")
    else
      nombre_cliente = fn id ->
        case Enum.find(clientes, fn c -> c["id"] == id end) do
          nil -> "Desconocido (#{id})"
          c -> c["nombre"]
        end
      end

      completos =
        billetes_sorteo
        |> Enum.filter(fn b -> b["tipo"] == "completo" end)
        |> Enum.map(fn b -> nombre_cliente.(b["cliente_id"]) end)
        |> Enum.uniq() |> Enum.sort()

      fracciones =
        billetes_sorteo
        |> Enum.filter(fn b -> b["tipo"] == "fraccion" end)
        |> Enum.map(fn b -> nombre_cliente.(b["cliente_id"]) end)
        |> Enum.uniq() |> Enum.sort()

      IO.puts("\n👥 Clientes del sorteo #{sorteo_id}")
      IO.puts("\n  Billete Completo:")
      if completos == [], do: IO.puts("    (ninguno)"),
        else: Enum.each(completos, fn n -> IO.puts("    - #{n}") end)
      IO.puts("\n  Por Fracción:")
      if fracciones == [], do: IO.puts("    (ninguno)"),
        else: Enum.each(fracciones, fn n -> IO.puts("    - #{n}") end)
    end
  end

  # ---------------------------------------------------------------------------
  # CONSULTAR INGRESOS
  # ---------------------------------------------------------------------------

  def consultar_ingresos(sorteo_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    total =
      billetes
      |> Enum.filter(fn b -> b["sorteo_id"] == sorteo_id and not b["devuelto"] end)
      |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

    IO.puts("💰 Ingresos del sorteo #{sorteo_id}: $#{total}")
    total
  end

  # ---------------------------------------------------------------------------
  # PREMIOS ENTREGADOS EN SORTEOS PASADOS
  # ---------------------------------------------------------------------------

  def consultar_premios_entregados do
    sorteos  = JsonHelper.leer_archivo(@archivo_sorteos)
    premios  = JsonHelper.leer_archivo(@archivo_premios)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    sorteos_pasados = Enum.filter(sorteos, fn s -> s["realizado"] end)

    if sorteos_pasados == [] do
      IO.puts("No hay sorteos realizados aún.")
    else
      Enum.each(sorteos_pasados, fn sorteo ->
        IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        IO.puts("📅 #{sorteo["nombre"]} (#{sorteo["fecha"]})")

        ingresos =
          billetes
          |> Enum.filter(fn b -> b["sorteo_id"] == sorteo["id"] and not b["devuelto"] end)
          |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

        IO.puts("   💰 Dinero recolectado: $#{ingresos}")

        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)
        total_premios = Enum.reduce(premios_sorteo, 0, fn p, acc -> acc + p["valor"] end)

        IO.puts("   🏆 Premios entregados:")
        Enum.each(premios_sorteo, fn premio ->
          nombres =
            premio["ganadores"]
            |> Enum.map(fn gid ->
              case Enum.find(clientes, fn c -> c["id"] == gid end) do
                nil -> gid
                c -> c["nombre"]
              end
            end)

          if nombres == [] do
            IO.puts("      - #{premio["nombre"]}: $#{premio["valor"]} (sin ganador)")
          else
            por_ganador = div(premio["valor"], length(nombres))
            IO.puts("      - #{premio["nombre"]}: $#{premio["valor"]}")
            Enum.each(nombres, fn n -> IO.puts("        👤 #{n} recibe $#{por_ganador}") end)
          end
        end)

        diferencia = ingresos - total_premios
        resultado = if diferencia >= 0, do: "✅ Ganancia", else: "❌ Pérdida"
        IO.puts("   #{resultado}: $#{abs(diferencia)}")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # BALANCE GENERAL
  # ---------------------------------------------------------------------------

  def consultar_balance do
    sorteos  = JsonHelper.leer_archivo(@archivo_sorteos)
    premios  = JsonHelper.leer_archivo(@archivo_premios)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    pasados = Enum.filter(sorteos, fn s -> s["realizado"] end)

    if pasados == [] do
      IO.puts("No hay sorteos realizados aún.")
    else
      IO.puts("\n📊 BALANCE GENERAL")
      IO.puts("════════════════════════════════════")

      total =
        Enum.reduce(pasados, 0, fn sorteo, acc ->
          ingresos =
            billetes
            |> Enum.filter(fn b -> b["sorteo_id"] == sorteo["id"] and not b["devuelto"] end)
            |> Enum.reduce(0, fn b, a -> a + b["valor_pagado"] end)

          total_premios =
            premios
            |> Enum.filter(fn p -> p["sorteo_id"] == sorteo["id"] end)
            |> Enum.reduce(0, fn p, a -> a + p["valor"] end)

          dif = ingresos - total_premios
          simbolo = if dif >= 0, do: "✅", else: "❌"
          IO.puts("#{simbolo} #{sorteo["nombre"]}: $#{dif}")
          acc + dif
        end)

      IO.puts("────────────────────────────────────")
      s = if total >= 0, do: "✅ GANANCIA TOTAL", else: "❌ PÉRDIDA TOTAL"
      IO.puts("#{s}: $#{abs(total)}")
    end
  end

  # ---------------------------------------------------------------------------
  # REALIZAR SORTEO — delega al proceso especializado si está activo
  # ---------------------------------------------------------------------------

  def realizar_sorteo(sorteo_id) do
    if Azar.ServidorSorteo.activo?(sorteo_id) do
      # Usamos el proceso dedicado del sorteo (arquitectura distribuida)
      Azar.ServidorSorteo.realizar(sorteo_id)
    else
      # Fallback: lógica directa si el proceso no está activo
      realizar_directo(sorteo_id)
    end
  end

  # ---------------------------------------------------------------------------
  # FUNCIONES PRIVADAS
  # ---------------------------------------------------------------------------

  defp realizar_directo(sorteo_id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    case Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) do
      nil -> {:error, "Sorteo no encontrado"}
      %{"realizado" => true} -> {:error, "El sorteo ya fue realizado"}
      sorteo ->
        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo_id end)

        {premios_actualizados, _} =
          Enum.map_reduce(premios_sorteo, [], fn p, usados ->
            num = numero_unico_aleatorio(sorteo["cantidad_billetes"], usados)
            {Map.put(p, "numero_ganador", num), [num | usados]}
          end)

        otros = Enum.reject(premios, fn p -> p["sorteo_id"] == sorteo_id end)
        JsonHelper.escribir_archivo(@archivo_premios, otros ++ premios_actualizados)

        numeros = Enum.map(premios_actualizados, & &1["numero_ganador"])
        sorteo_ok = sorteo |> Map.put("realizado", true) |> Map.put("numeros_ganadores", numeros)
        nuevos = Enum.map(sorteos, fn s -> if s["id"] == sorteo_id, do: sorteo_ok, else: s end)
        JsonHelper.escribir_archivo(@archivo_sorteos, nuevos)

        asignar_ganadores(sorteo_id, premios_actualizados)
        IO.puts("🎉 Sorteo '#{sorteo["nombre"]}' realizado. Ganadores: #{inspect(numeros)}")
        {:ok, numeros}
    end
  end

  defp numero_unico_aleatorio(max, usados) do
    n = :rand.uniform(max)
    if n in usados, do: numero_unico_aleatorio(max, usados), else: n
  end

  defp asignar_ganadores(sorteo_id, premios_actualizados) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    todos = JsonHelper.leer_archivo(@archivo_premios)

    finales =
      Enum.map(todos, fn p ->
        if p["sorteo_id"] == sorteo_id do
          ganadores =
            billetes
            |> Enum.filter(fn b ->
              b["sorteo_id"] == sorteo_id and
              b["numero"] == p["numero_ganador"] and
              not b["devuelto"]
            end)
            |> Enum.map(& &1["cliente_id"])
          Map.put(p, "ganadores", ganadores)
        else
          p
        end
      end)

    JsonHelper.escribir_archivo(@archivo_premios, finales)
    premios_actualizados
  end
end
