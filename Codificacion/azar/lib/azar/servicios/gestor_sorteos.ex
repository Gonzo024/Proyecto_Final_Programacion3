defmodule Azar.Servicios.GestorSorteos do
  alias Azar.Modelos.Sorteo

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
end
