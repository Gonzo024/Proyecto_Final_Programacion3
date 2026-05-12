defmodule Azar.Servicios.GestorSorteos do
  alias Azar.Modelos.Sorteo
  alias Azar.Utils.JsonHelper

  @archivo "sorteos.json"

  def crear_sorteo(nombre, fecha, valor, fracciones, cantidad) do
    sorteo = %Sorteo{
      nombre: nombre,
      fecha: fecha,
      valor_billete: valor,
      fracciones: fracciones,
      cantidad_billetes: cantidad
    }

    IO.puts("Sorteo creado:")
    IO.inspect(sorteo)

    sorteo
  end

  def listar_sorteos do
     sorteos = JsonHelper.leer_archivo(@archivo)

    if sorteos == [] do
      IO.puts("No hay sorteos")
    else
      Enum.each(sorteos, fn s ->
        IO.puts("Nombre: #{s["nombre"]} | Fecha: #{s["fecha"]}")
      end)
    end
  end
end
