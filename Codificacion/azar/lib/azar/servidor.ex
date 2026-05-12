defmodule Azar.Servidor do

  def iniciar do
    spawn(fn -> loop([]) end)
  end

  defp loop(estado) do
    receive do
      {:crear_sorteo, nombre, fecha} ->
        nuevo = %{nombre: nombre, fecha: fecha}
        IO.puts("Sorteo recibido: #{nombre}")

        loop([nuevo | estado])

      {:listar, pid_cliente} ->
        send(pid_cliente, {:respuesta, estado})
        loop(estado)

      :salir ->
        IO.puts("Servidor apagado")

      _ ->
        IO.puts("Mensaje no reconocido")
        loop(estado)
    end
  end
end
