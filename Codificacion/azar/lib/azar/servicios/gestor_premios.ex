defmodule Azar.Servicios.GestorPremios do
  @moduledoc """
  Gestión completa de premios: crear, listar, eliminar.
  Un premio siempre pertenece a un sorteo.
  """

  alias Azar.Utils.JsonHelper

  @archivo_premios "priv/data/premios.json"
  @archivo_sorteos "priv/data/sorteos.json"
  @archivo_billetes "priv/data/billetes.json"

  # ---------------------------------------------------------------------------
  # CREAR PREMIO
  # ---------------------------------------------------------------------------

  @doc """
  Crea un premio para un sorteo existente.
  Retorna {:ok, premio} o {:error, motivo}
  """
  def crear_premio(sorteo_id, nombre, valor) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    # Verificamos que el sorteo existe
    case Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) do
      nil ->
        {:error, "El sorteo '#{sorteo_id}' no existe"}

      %{"realizado" => true} ->
        {:error, "No se pueden agregar premios a un sorteo ya realizado"}

      _sorteo ->
        id = "premio_#{System.os_time(:millisecond)}"

        nuevo_premio = %{
          "id" => id,
          "sorteo_id" => sorteo_id,
          "nombre" => nombre,
          "valor" => valor,
          "numero_ganador" => nil,
          "ganadores" => []
        }

        case JsonHelper.escribir_archivo(@archivo_premios, [nuevo_premio | premios]) do
          :ok ->
            IO.puts("✅ Premio '#{nombre}' creado para sorteo #{sorteo_id}")
            {:ok, nuevo_premio}

          :error ->
            {:error, "No se pudo guardar el premio"}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # LISTAR PREMIOS (ordenados por fecha del sorteo, agrupados por sorteo)
  # ---------------------------------------------------------------------------

  @doc """
  Lista todos los premios agrupados por sorteo,
  ordenados por fecha del sorteo.
  """
  def listar_premios do
    premios = JsonHelper.leer_archivo(@archivo_premios)
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    if premios == [] do
      IO.puts("No hay premios registrados.")
    else
      # Ordenamos los sorteos por fecha y agrupamos los premios bajo cada uno
      sorteos
      |> Enum.sort_by(fn s -> s["fecha"] end)
      |> Enum.each(fn sorteo ->
        premios_sorteo = Enum.filter(premios, fn p -> p["sorteo_id"] == sorteo["id"] end)

        if premios_sorteo != [] do
          IO.puts("\n📅 #{sorteo["nombre"]} (#{sorteo["fecha"]})")

          Enum.each(premios_sorteo, fn p ->
            IO.puts("   🏆 #{p["nombre"]}: $#{p["valor"]}  [#{p["id"]}]")
          end)
        end
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # ELIMINAR PREMIO
  # ---------------------------------------------------------------------------

  @doc """
  Elimina un premio SOLO si el sorteo no tiene clientes (billetes vendidos).
  Retorna {:ok, mensaje} o {:error, motivo}
  """
  def eliminar_premio(premio_id) do
    premios = JsonHelper.leer_archivo(@archivo_premios)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    case Enum.find(premios, fn p -> p["id"] == premio_id end) do
      nil ->
        {:error, "Premio '#{premio_id}' no encontrado"}

      premio ->
        # Verificamos que el sorteo no tenga billetes vendidos
        tiene_clientes =
          Enum.any?(billetes, fn b ->
            b["sorteo_id"] == premio["sorteo_id"] and not b["devuelto"]
          end)

        if tiene_clientes do
          {:error, "No se puede eliminar: el sorteo ya tiene clientes con billetes comprados"}
        else
          nuevos_premios = Enum.reject(premios, fn p -> p["id"] == premio_id end)

          case JsonHelper.escribir_archivo(@archivo_premios, nuevos_premios) do
            :ok ->
              IO.puts("🗑️  Premio '#{premio_id}' eliminado")
              {:ok, "Premio eliminado"}

            :error ->
              {:error, "Error al guardar los cambios"}
          end
        end
    end
  end
end
