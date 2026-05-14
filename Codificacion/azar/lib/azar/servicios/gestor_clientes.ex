defmodule Azar.Servicios.GestorClientes do
  @moduledoc """
  Gestión completa de clientes/jugadores:
  registro, login, compras, devoluciones, historial,
  premios obtenidos, balance personal y notificaciones.
  """

  alias Azar.Utils.JsonHelper

  @archivo_clientes "priv/data/clientes.json"
  @archivo_sorteos "priv/data/sorteos.json"
  @archivo_billetes "priv/data/billetes.json"
  @archivo_premios "priv/data/premios.json"

  # ---------------------------------------------------------------------------
  # REGISTRO DE USUARIO
  # ---------------------------------------------------------------------------

  @doc """
  Registra un nuevo jugador en el sistema.
  Verifica que el documento no esté ya registrado.
  Retorna {:ok, cliente} o {:error, motivo}
  """
  def registrar(nombre, documento, password, tarjeta) do
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    # Verificamos que el documento no exista ya
    ya_existe = Enum.any?(clientes, fn c -> c["documento"] == documento end)

    if ya_existe do
      {:error, "Ya existe un usuario con el documento #{documento}"}
    else
      id = "cliente_#{System.os_time(:millisecond)}"

      nuevo_cliente = %{
        "id" => id,
        "nombre" => nombre,
        "documento" => documento,
        "password" => password,
        "tarjeta" => tarjeta,
        "notificaciones" => []
      }

      case JsonHelper.escribir_archivo(@archivo_clientes, [nuevo_cliente | clientes]) do
        :ok ->
          IO.puts("✅ Cliente '#{nombre}' registrado con id #{id}")
          {:ok, nuevo_cliente}

        :error ->
          {:error, "No se pudo guardar el cliente"}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # LOGIN
  # ---------------------------------------------------------------------------

  @doc """
  Verifica documento y contraseña.
  Retorna {:ok, cliente} o {:error, motivo}
  """
  def login(documento, password) do
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    case Enum.find(clientes, fn c -> c["documento"] == documento end) do
      nil ->
        {:error, "Usuario no encontrado"}

      cliente ->
        if cliente["password"] == password do
          IO.puts("✅ Login exitoso: #{cliente["nombre"]}")
          {:ok, cliente}
        else
          {:error, "Contraseña incorrecta"}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # SORTEOS DISPONIBLES (solo los que aún no se han jugado)
  # ---------------------------------------------------------------------------

  @doc """
  Retorna la lista de sorteos que aún no han sido realizados.
  """
  def sorteos_disponibles do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    disponibles =
      sorteos
      |> Enum.filter(fn s -> not s["realizado"] end)
      |> Enum.sort_by(fn s -> s["fecha"] end)

    if disponibles == [] do
      IO.puts("No hay sorteos disponibles en este momento.")
    else
      IO.puts("\n🎰 Sorteos disponibles:")

      Enum.each(disponibles, fn s ->
        valor_fraccion = div(s["valor_billete"], s["fracciones"])
        IO.puts("  [#{s["id"]}] #{s["nombre"]} — Fecha: #{s["fecha"]}")
        IO.puts("    Billete completo: $#{s["valor_billete"]} | Fracción: $#{valor_fraccion}")
        IO.puts("    Billetes disponibles: #{s["cantidad_billetes"]}")
      end)
    end

    disponibles
  end

  # ---------------------------------------------------------------------------
  # NÚMEROS DISPONIBLES EN UN SORTEO
  # ---------------------------------------------------------------------------

  @doc """
  Muestra qué números y fracciones están disponibles para comprar
  en un sorteo específico.
  """
  def numeros_disponibles(sorteo_id) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)

    case Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) do
      nil ->
        {:error, "Sorteo no encontrado"}

      %{"realizado" => true} ->
        {:error, "El sorteo ya fue realizado"}

      sorteo ->
        total = sorteo["cantidad_billetes"]
        fracciones = sorteo["fracciones"]

        # Billetes activos (no devueltos) de este sorteo
        billetes_vendidos =
          Enum.filter(billetes, fn b ->
            b["sorteo_id"] == sorteo_id and not b["devuelto"]
          end)

        # Números con billete completo vendido
        numeros_completos =
          billetes_vendidos
          |> Enum.filter(fn b -> b["tipo"] == "completo" end)
          |> Enum.map(fn b -> b["numero"] end)
          |> MapSet.new()

        IO.puts("\n📋 Disponibilidad para sorteo: #{sorteo["nombre"]}")

        # Revisamos cada número del 1 al total
        Enum.each(1..total, fn num ->
          if num in numeros_completos do
            IO.puts("  ##{num} — COMPLETO (vendido)")
          else
            # Vemos qué fracciones están tomadas
            fracs_tomadas =
              billetes_vendidos
              |> Enum.filter(fn b -> b["numero"] == num and b["tipo"] == "fraccion" end)
              |> Enum.map(fn b -> b["fraccion_numero"] end)

            fracs_libres =
              Enum.reject(1..fracciones |> Enum.to_list(), fn f -> f in fracs_tomadas end)

            if fracs_libres == [] do
              IO.puts("  ##{num} — COMPLETO (todas las fracciones vendidas)")
            else
              IO.puts("  ##{num} — Fracciones libres: #{Enum.join(fracs_libres, ", ")}")
            end
          end
        end)

        {:ok, %{sorteo: sorteo, billetes_vendidos: billetes_vendidos}}
    end
  end

  # ---------------------------------------------------------------------------
  # COMPRAR BILLETE
  # ---------------------------------------------------------------------------

  @doc """
  Registra la compra de un billete completo o una fracción.

  tipo puede ser "completo" o "fraccion".
  Si es fracción, fraccion_numero indica cuál (1, 2, 3...).
  Retorna {:ok, billete} o {:error, motivo}
  """
  def comprar_billete(cliente_id, sorteo_id, numero, tipo, fraccion_numero \\ nil) do
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    with {:ok, sorteo} <- encontrar_sorteo_activo(sorteos, sorteo_id),
         :ok <- validar_numero(numero, sorteo["cantidad_billetes"]),
         :ok <-
           validar_disponibilidad(
             billetes,
             sorteo_id,
             numero,
             tipo,
             fraccion_numero,
             sorteo["fracciones"]
           ),
         {:ok, _} <- encontrar_cliente(clientes, cliente_id) do
      valor = calcular_valor(sorteo, tipo)
      id = "billete_#{System.os_time(:millisecond)}"
      fecha = Date.utc_today() |> Date.to_string()

      nuevo_billete = %{
        "id" => id,
        "sorteo_id" => sorteo_id,
        "cliente_id" => cliente_id,
        "numero" => numero,
        "tipo" => tipo,
        "fraccion_numero" => fraccion_numero,
        "valor_pagado" => valor,
        "fecha_compra" => fecha,
        "devuelto" => false
      }

      case JsonHelper.escribir_archivo(@archivo_billetes, [nuevo_billete | billetes]) do
        :ok ->
          IO.puts("✅ Compra exitosa: billete ##{numero} (#{tipo}) — $#{valor}")
          {:ok, nuevo_billete}

        :error ->
          {:error, "No se pudo guardar la compra"}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # HISTORIAL DE COMPRAS
  # ---------------------------------------------------------------------------

  @doc """
  Muestra todas las compras del cliente con el total gastado.
  """
  def historial_compras(cliente_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    mis_compras =
      billetes
      |> Enum.filter(fn b -> b["cliente_id"] == cliente_id end)
      |> Enum.sort_by(fn b -> b["fecha_compra"] end)

    if mis_compras == [] do
      IO.puts("No tienes compras registradas.")
    else
      IO.puts("\n🧾 Historial de compras:")

      Enum.each(mis_compras, fn b ->
        sorteo = Enum.find(sorteos, fn s -> s["id"] == b["sorteo_id"] end)
        nombre_sorteo = if sorteo, do: sorteo["nombre"], else: b["sorteo_id"]
        devuelto = if b["devuelto"], do: " [DEVUELTO]", else: ""

        IO.puts(
          "  #{b["fecha_compra"]} | #{nombre_sorteo} | ##{b["numero"]} (#{b["tipo"]}) | $#{b["valor_pagado"]}#{devuelto}"
        )
      end)

      total =
        mis_compras
        |> Enum.reject(fn b -> b["devuelto"] end)
        |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

      IO.puts("  ─────────────────────────────")
      IO.puts("  💰 Total gastado: $#{total}")
    end

    mis_compras
  end

  # ---------------------------------------------------------------------------
  # DEVOLVER COMPRA
  # ---------------------------------------------------------------------------

  @doc """
  Devuelve una compra SOLO si el sorteo aún no se ha realizado.
  Retorna {:ok, mensaje} o {:error, motivo}
  """
  def devolver_compra(billete_id, cliente_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    case Enum.find(billetes, fn b -> b["id"] == billete_id end) do
      nil ->
        {:error, "Billete no encontrado"}

      %{"cliente_id" => id_del_billete} when id_del_billete != cliente_id ->
        {:error, "Este billete no pertenece a tu cuenta"}

      %{"devuelto" => true} ->
        {:error, "Este billete ya fue devuelto"}

      billete ->
        sorteo = Enum.find(sorteos, fn s -> s["id"] == billete["sorteo_id"] end)

        if sorteo["realizado"] do
          {:error, "No se puede devolver: el sorteo ya fue realizado"}
        else
          # Marcamos el billete como devuelto
          billetes_actualizados =
            Enum.map(billetes, fn b ->
              if b["id"] == billete_id, do: Map.put(b, "devuelto", true), else: b
            end)

          case JsonHelper.escribir_archivo(@archivo_billetes, billetes_actualizados) do
            :ok ->
              IO.puts(
                "✅ Billete ##{billete["numero"]} devuelto. Se reembolsarán $#{billete["valor_pagado"]}"
              )

              {:ok, "Billete devuelto correctamente"}

            :error ->
              {:error, "Error al guardar los cambios"}
          end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # PREMIOS OBTENIDOS
  # ---------------------------------------------------------------------------

  @doc """
  Muestra los premios que ha ganado el cliente en sorteos pasados.
  """
  def premios_obtenidos(cliente_id) do
    premios = JsonHelper.leer_archivo(@archivo_premios)
    sorteos = JsonHelper.leer_archivo(@archivo_sorteos)

    mis_premios =
      Enum.filter(premios, fn p -> cliente_id in p["ganadores"] end)

    if mis_premios == [] do
      IO.puts("Aún no has ganado premios.")
    else
      IO.puts("\n🏆 Premios obtenidos:")

      Enum.each(mis_premios, fn p ->
        sorteo = Enum.find(sorteos, fn s -> s["id"] == p["sorteo_id"] end)
        nombre_sorteo = if sorteo, do: sorteo["nombre"], else: p["sorteo_id"]
        # Si hay varios ganadores, el valor se divide
        valor_recibido = div(p["valor"], length(p["ganadores"]))
        IO.puts("  🎉 #{p["nombre"]} en '#{nombre_sorteo}' — Recibiste: $#{valor_recibido}")
      end)
    end

    mis_premios
  end

  # ---------------------------------------------------------------------------
  # BALANCE PERSONAL
  # ---------------------------------------------------------------------------

  @doc """
  Calcula la diferencia entre lo gastado y los premios obtenidos.
  """
  def balance_personal(cliente_id) do
    billetes = JsonHelper.leer_archivo(@archivo_billetes)
    premios = JsonHelper.leer_archivo(@archivo_premios)

    total_gastado =
      billetes
      |> Enum.filter(fn b -> b["cliente_id"] == cliente_id and not b["devuelto"] end)
      |> Enum.reduce(0, fn b, acc -> acc + b["valor_pagado"] end)

    total_ganado =
      premios
      |> Enum.filter(fn p -> cliente_id in p["ganadores"] end)
      |> Enum.reduce(0, fn p, acc ->
        acc + div(p["valor"], length(p["ganadores"]))
      end)

    diferencia = total_ganado - total_gastado
    resultado = if diferencia >= 0, do: "✅ Ganancia", else: "❌ Pérdida"

    IO.puts("\n💼 Balance personal:")
    IO.puts("   Total gastado:  $#{total_gastado}")
    IO.puts("   Total ganado:   $#{total_ganado}")
    IO.puts("   #{resultado}: $#{abs(diferencia)}")

    %{gastado: total_gastado, ganado: total_ganado, diferencia: diferencia}
  end

  # ---------------------------------------------------------------------------
  # VER NOTIFICACIONES
  # ---------------------------------------------------------------------------

  @doc """
  Muestra las notificaciones que el servidor envió al jugador.
  """
  def ver_notificaciones(cliente_id) do
    clientes = JsonHelper.leer_archivo(@archivo_clientes)

    case Enum.find(clientes, fn c -> c["id"] == cliente_id end) do
      nil ->
        {:error, "Cliente no encontrado"}

      cliente ->
        notifs = cliente["notificaciones"]

        if notifs == [] do
          IO.puts("No tienes notificaciones.")
        else
          IO.puts("\n🔔 Notificaciones:")
          Enum.each(notifs, fn n -> IO.puts("  • #{n}") end)
        end

        {:ok, notifs}
    end
  end

  # ---------------------------------------------------------------------------
  # FUNCIONES PRIVADAS — validaciones internas
  # ---------------------------------------------------------------------------

  defp encontrar_sorteo_activo(sorteos, sorteo_id) do
    case Enum.find(sorteos, fn s -> s["id"] == sorteo_id end) do
      nil ->
        {:error, "Sorteo no encontrado"}

      %{"realizado" => true} ->
        {:error, "El sorteo ya fue realizado"}

      sorteo ->
        {:ok, sorteo}
    end
  end

  defp encontrar_cliente(clientes, cliente_id) do
    case Enum.find(clientes, fn c -> c["id"] == cliente_id end) do
      nil -> {:error, "Cliente no encontrado"}
      cliente -> {:ok, cliente}
    end
  end

  defp validar_numero(numero, total) do
    if numero >= 1 and numero <= total do
      :ok
    else
      {:error, "Número #{numero} fuera de rango (1-#{total})"}
    end
  end

  defp validar_disponibilidad(
         billetes,
         sorteo_id,
         numero,
         tipo,
         fraccion_numero,
         total_fracciones
       ) do
    activos =
      Enum.filter(billetes, fn b ->
        b["sorteo_id"] == sorteo_id and b["numero"] == numero and not b["devuelto"]
      end)

    cond do
      # Si alguien ya tiene el billete completo, nadie puede comprarlo
      Enum.any?(activos, fn b -> b["tipo"] == "completo" end) ->
        {:error, "El billete ##{numero} ya está vendido completo"}

      # Si quieren comprar completo pero ya hay fracciones vendidas
      tipo == "completo" and activos != [] ->
        {:error, "El billete ##{numero} ya tiene fracciones vendidas"}

      # Si quieren fracción pero esa fracción ya está tomada
      tipo == "fraccion" and
          Enum.any?(activos, fn b -> b["fraccion_numero"] == fraccion_numero end) ->
        {:error, "La fracción #{fraccion_numero} del billete ##{numero} ya está vendida"}

      # Fracción fuera de rango
      tipo == "fraccion" and
          (fraccion_numero < 1 or fraccion_numero > total_fracciones) ->
        {:error, "Fracción #{fraccion_numero} inválida (1-#{total_fracciones})"}

      true ->
        :ok
    end
  end

  defp calcular_valor(sorteo, tipo) do
    if tipo == "completo" do
      sorteo["valor_billete"]
    else
      div(sorteo["valor_billete"], sorteo["fracciones"])
    end
  end
end
