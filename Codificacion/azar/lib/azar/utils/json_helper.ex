defmodule Azar.Utils.JsonHelper do
  @moduledoc """
  Helper para manejar operaciones con archivos JSON
  """

  def leer_archivo(ruta) do
    case File.read(ruta) do
      {:ok, contenido} ->
        case Jason.decode(contenido) do
          {:ok, datos} -> datos
          {:error, _} -> []
        end
      {:error, _} ->
        []
    end
  end

  def escribir_archivo(ruta, datos) do
    with {:ok, json} <- Jason.encode(datos),
         :ok <- File.write(ruta, json) do
      :ok
    else
      _ -> :error
    end
  end
end
