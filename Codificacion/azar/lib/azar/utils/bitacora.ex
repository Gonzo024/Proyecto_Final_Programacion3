defmodule Azar.Utils.Bitacora do
  @moduledoc """
  Registra todas las solicitudes del sistema.

  Cada entrada tiene:
    - Fecha y hora exacta
    - La solicitud realizada
    - El resultado (ok o negado)

  Se muestra en pantalla Y se guarda en priv/data/bitacora.log
  """

  @archivo_log "priv/data/bitacora.log"

  @doc """
  Registra una entrada en la bitácora.

  Ejemplos:
    Bitacora.registrar("CREAR_SORTEO nombre=Navidad", {:ok, sorteo})
    Bitacora.registrar("LOGIN_CLIENTE doc=123", {:error, "pass incorrecta"})
  """
  def registrar(solicitud, resultado) do
    # Fecha y hora actual formateada
    ahora = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")

    # Determinamos si fue ok o negado
    estado = case resultado do
      {:ok, _}    -> "OK"
      :ok         -> "OK"
      {:error, _} -> "NEGADO"
      _           -> "OK"
    end

    # Línea de log
    linea = "[#{ahora}] #{solicitud} → #{estado}\n"

    # Mostramos en pantalla
    IO.write(linea)

    # Guardamos en el archivo (modo append para no borrar entradas anteriores)
    File.write(@archivo_log, linea, [:append])
  end
end
