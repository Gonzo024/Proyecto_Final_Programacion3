defmodule Azar.Servicios.GestorSorteos do
  @moduledoc """
  Gestión completa de sorteos: crear, listar, eliminar,
  consultar clientes, ingresos y balance.
  Toda la información se persiste en archivos JSON.
  """
# IMPORTANTE ESTO ESTA GENERADO CON IA Y TENGO QUE SABER QUE ES LO QUE HACE Y ESTUDIARLO
  alias Azar.Modelos.Sorteo
  alias Azar.Utils.JsonHelper

  # Rutas de los archivos JSON (relativas al directorio raíz del proyecto)
  @archivo_sorteos "priv/data/sorteos.json"
  @archivo_premios "priv/data/premios.json"
  @archivo_billetes "priv/data/billetes.json"
  @archivo_clientes "priv/data/clientes.json"

  # ---------------------------------------------------------------------------
  # CREAR SORTEO
  # ---------------------------------------------------------------------------

  @doc """
  Crea un nuevo sorteo y lo guarda en sorteos.json.

  Genera un id único basado en timestamp.
  Retorna {:ok, sorteo} o {:error, motivo}

  Ejemplo:
    GestorSorteos.crear_sorteo("Lotería Mayo", "2026-05-20", 30000, 5, 100)
  """
  def crear_sorteo(nombre, fecha, valor_billete, fracciones, cantidad_billetes) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    # Generamos un id único usando el tiempo actual
    id = "sorteo_#{System.os_time(:millisecond)}"

    nuevo_sorteo = %{
      "id" => id,
      "nombre" => nombre,
      "fecha" => fecha,
      "valor_billete" => valor_billete,
      "fracciones" => fracciones,
      "cantidad_billetes" => cantidad_billetes,
      "realizado" => false,
      "numeros_ganadores" => []
    }

    case JsonHelper.escribir_archivo(@archivo_sorteos, [nuevo_sorteo | sorteos]) do
      :ok ->
        IO.puts("✅ Sorteo '#{nombre}' creado con id #{id}")
        {:ok, nuevo_sorteo}

      :error ->
        IO.puts("❌ Error al guardar el sorteo")
        {:error, "No se pudo guardar el sorteo"}
    end
  end

  # ---------------------------------------------------------------------------
  # LISTAR SORTEOS (ordenados por fecha)
  # ---------------------------------------------------------------------------

  @doc """
  Lista todos los sorteos ordenados por fecha.
  Muestra premios asociados si existen.
  Si ya se realizó, muestra números ganadores y ganadores por premio.
  """
  def listar_sorteos do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    if sorteos == [] do
      IO.puts("No hay sorteos registrados.")
    else
      sorteos
      # Ordenamos por fecha (string "YYYY-MM-DD" se puede comparar directamente)
      |> Enum.sort_by(fn s -> s["fecha"] end)
      |> Enum.each(fn sorteo ->
        IO.puts("\n─────────────────────────────────")
        IO.puts("📋 #{sorteo["nombre"]}  [#{sorteo["id"]}]")
        IO.puts("   Fecha: #{sorteo["fecha"]}")
        IO.puts("   Billete: $#{sorteo["valor_billete"]} | Fracciones: #{sorteo["fracciones"]} | Billetes: #{sorteo["cantidad_billetes"]}")

        # Premios de este sorteo
        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)

        if premios_sorteo == [] do
          IO.puts("   Sin premios registrados.")
        else
          IO.puts("   🏆 Premios:")
          Enum.each(premios_sorteo, fn p ->
            IO.puts("      - #{p["nombre"]}: $#{p["valor"]}")
          end)
        end

        # Si ya se realizó, mostramos ganadores
        if sorteo["realizado"] do
          IO.puts("   ✅ REALIZADO - Números ganadores: #{inspect(sorteo["numeros_ganadores"])}")
          Enum.each(premios_sorteo, fn p ->
            if p["ganadores"] != [] do
              IO.puts("      #{p["nombre"]} → ganadores: #{Enum.join(p["ganadores"], ", ")}")
            end
          end)
        else
          IO.puts("   ⏳ Pendiente")
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # ELIMINAR SORTEO
  # ---------------------------------------------------------------------------

  @doc """
  Elimina un sorteo SOLO si no tiene premios asociados.
  Retorna {:ok, mensaje} o {:error, motivo}
  """
  def eliminar_sorteo(id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    # Verificamos que el sorteo existe
    case Enum.find(sorteos, fn s -> s["id"] == id end) do
      nil ->
        {:error, "Sorteo con id '#{id}' no encontrado"}

      _sorteo ->
        # Verificamos que no tenga premios asociados
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

  @doc """
  Lista los clientes de un sorteo ordenados alfabéticamente,
  agrupados en: compradores de billete completo y compradores por fracción.
  """
  def consultar_clientes(sorteo_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    # Billetes activos (no devueltos) de este sorteo
    billetes_sorteo =
      billetes
      |> Enum.filter(fn b -> b["sorteo_id"] == sorteo_id and not b["devuelto"] end)

    if billetes_sorteo == [] do
      IO.puts("No hay clientes para este sorteo.")
    else
      # Función auxiliar: dado un cliente_id, retorna el nombre
      nombre_cliente = fn id ->
        case Enum.find(clientes, fn c -> c["id"] == id end) do
          nil -> "Desconocido (#{id})"
          c -> c["nombre"]
        end
      end

      # Separamos por tipo
      completos =
        billetes_sorteo
        |> Enum.filter(fn b -> b["tipo"] == "completo" end)
        |> Enum.map(fn b -> nombre_cliente.(b["cliente_id"]) end)
        |> Enum.uniq()
        |> Enum.sort()

      fracciones =
        billetes_sorteo
        |> Enum.filter(fn b -> b["tipo"] == "fraccion" end)
        |> Enum.map(fn b -> nombre_cliente.(b["cliente_id"]) end)
        |> Enum.uniq()
        |> Enum.sort()

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
  # CONSULTAR INGRESOS POR SORTEO
  # ---------------------------------------------------------------------------

  @doc """
  Muestra el total de dinero recolectado en un sorteo específico.
  """
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
  # CONSULTAR PREMIOS ENTREGADOS EN SORTEOS PASADOS
  # ---------------------------------------------------------------------------

  @doc """
  Para sorteos ya realizados, muestra:
  - Premios entregados y sus ganadores
  - Dinero recolectado
  - Ganancias o pérdidas
  """
  def consultar_premios_entregados do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    sorteos_pasados = Enum.filter(sorteos, fn s -> s["realizado"] end)

    if sorteos_pasados == [] do
      IO.puts("No hay sorteos realizados aún.")
    else
      Enum.each(sorteos_pasados, fn sorteo ->
        IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        IO.puts("📅 #{sorteo["nombre"]} (#{sorteo["fecha"]})")

        # Ingresos: suma de billetes vendidos no devueltos
        ingresos =
          billetes
          |> Enum.filter(fn b -> b["sorteo_id"] == sorteo["id"] and not b["devuelto"] end)
          |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

        IO.puts("   💰 Dinero recolectado: $#{ingresos}")

        # Premios de este sorteo
        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)
        total_premios = Enum.reduce(premios_sorteo, 0, fn p, acc -> acc + p["valor"] end)

        IO.puts("   🏆 Premios entregados:")
        Enum.each(premios_sorteo, fn premio ->
          # Nombre de los ganadores
          nombres_ganadores =
            premio["ganadores"]
            |> Enum.map(fn gid ->
              case Enum.find(clientes, fn c -> c["id"] == gid end) do
                nil -> gid
                c -> c["nombre"]
              end
            end)

          if nombres_ganadores == [] do
            IO.puts("      - #{premio["nombre"]}: $#{premio["valor"]} (sin ganador)")
          else
            # El valor se divide entre los ganadores (fracciones)
            valor_por_ganador = div(premio["valor"], length(nombres_ganadores))
            IO.puts("      - #{premio["nombre"]}: $#{premio["valor"]}")
            Enum.each(nombres_ganadores, fn n ->
              IO.puts("        👤 #{n} recibe $#{valor_por_ganador}")
            end)
          end
        end)

        # Cálculo de ganancia o pérdida
        diferencia = ingresos - total_premios
        resultado = if diferencia >= 0, do: "✅ Ganancia", else: "❌ Pérdida"
        IO.puts("   #{resultado}: $#{abs(diferencia)}")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # BALANCE DE TODOS LOS SORTEOS PASADOS
  # ---------------------------------------------------------------------------

  @doc """
  Muestra ganancias/pérdidas por cada sorteo realizado
  y el total acumulado de todos.
  """
  def consultar_balance do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    sorteos_pasados = Enum.filter(sorteos, fn s -> s["realizado"] end)

    if sorteos_pasados == [] do
      IO.puts("No hay sorteos realizados aún.")
    else
      IO.puts("\n📊 BALANCE GENERAL")
      IO.puts("════════════════════════════════════")

      total_acumulado =
        Enum.reduce(sorteos_pasados, 0, fn sorteo, acc_total ->
          ingresos =
            billetes
            |> Enum.filter(fn b -> b["sorteo_id"] == sorteo["id"] and not b["devuelto"] end)
            |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

          total_premios =
            premios
            |> Enum.filter(fn p -> p["sorteo_id"] == sorteo["id"] end)
            |> Enum.reduce(0, fn p, acc -> acc + p["valor"] end)

          diferencia = ingresos - total_premios
          simbolo = if diferencia >= 0, do: "✅", else: "❌"

          IO.puts("#{simbolo} #{sorteo["nombre"]}: $#{diferencia}")

          acc_total + diferencia
        end)

      IO.puts("────────────────────────────────────")
      simbolo_total = if total_acumulado >= 0, do: "✅ GANANCIA TOTAL", else: "❌ PÉRDIDA TOTAL"
      IO.puts("#{simbolo_total}: $#{abs(total_acumulado)}")
    end
  end

  # ---------------------------------------------------------------------------
  # REALIZAR SORTEO (asignar números ganadores aleatoriamente)
  # ---------------------------------------------------------------------------

  @doc """
  Realiza un sorteo pendiente: asigna números ganadores aleatorios
  a cada premio y marca el sorteo como realizado.
  Usado por el admin al actualizar la fecha del sistema.
  """
  def realizar_sorteo(sorteo_id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    case Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) do
      nil ->
        {:error, "Sorteo no encontrado"}

      sorteo when sorteo["realizado"] ->
        {:error, "El sorteo ya fue realizado"}

      sorteo ->
        cantidad = sorteo["cantidad_billetes"]
        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo_id end)

        # Generamos un número ganador único por premio
        {premios_actualizados, _usados} =
          Enum.map_reduce(premios_sorteo, [], fn premio, usados ->
            numero = numero_unico_aleatorio(cantidad, usados)
            premio_actualizado = Map.put(premio, "numero_ganador", numero)
            {premio_actualizado, [numero | usados]}
          end)

        # Actualizamos los premios en el JSON
        otros_premios = Enum.reject(premios, fn p -> p["sorteo_id"] == sorteo_id end)
        JsonHelper.escribir_archivo(@archivo_premios, otros_premios ++ premios_actualizados)

        # Marcamos el sorteo como realizado
        numeros = Enum.map(premios_actualizados, fn p -> p["numero_ganador"] end)

        sorteo_actualizado =
          sorteo
          |> Map.put("realizado", true)
          |> Map.put("numeros_ganadores", numeros)

        nuevos_sorteos = Enum.map(sorteos, fn s ->
          if s["id"] == sorteo_id, do: sorteo_actualizado, else: s
        end)

        JsonHelper.escribir_archivo(@archivo_sorteos, nuevos_sorteos)

        # Asignamos ganadores según quién compró esos números
        asignar_ganadores(sorteo_id, premios_actualizados)

        IO.puts("🎉 Sorteo '#{sorteo["nombre"]}' realizado. Ganadores: #{inspect(numeros)}")
        {:ok, numeros}
    end
  end

  # ---------------------------------------------------------------------------
  # FUNCIONES PRIVADAS
  # ---------------------------------------------------------------------------

  # Genera un número aleatorio entre 1 y max que no esté en la lista 'usados'
  defp numero_unico_aleatorio(max, usados) do
    numero = :rand.uniform(max)
    if numero in usados, do: numero_unico_aleatorio(max, usados), else: numero
  end

  # Busca quién compró cada número ganador y los registra como ganadores del premio
  defp asignar_ganadores(sorteo_id, premios_con_ganadores) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    premios_actuales = JsonHelper.leer_archivo(@archivo_premios)

    premios_finales =
      Enum.map(premios_actuales, fn premio ->
        if premio["sorteo_id"] == sorteo_id do
          # Buscamos quién tiene el número ganador (puede ser 1 o varios si es fraccionado)
          ganadores =
            billetes
            |> Enum.filter(fn b ->
              b["sorteo_id"] == sorteo_id and
              b["numero"] == premio["numero_ganador"] and
              not b["devuelto"]
            end)
            |> Enum.map(fn b -> b["cliente_id"] end)

          Map.put(premio, "ganadores", ganadores)
        else
          premio
        end
      end)

    JsonHelper.escribir_archivo(@archivo_premios, premios_finales)
  end
end
