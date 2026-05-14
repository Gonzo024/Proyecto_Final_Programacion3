defmodule Azar.Modelos.Premio do
  @moduledoc """
  Representa un premio asociado a un sorteo.

  Campos:
    - id: identificador único (string, ej: "premio_001")
    - sorteo_id: id del sorteo al que pertenece
    - nombre: nombre del premio (ej: "Primer Premio", "Segundo Premio")
    - valor: monto en pesos del premio (número)
    - numero_ganador: número de billete ganador (nil hasta que se realice el sorteo)
    - ganadores: lista de clientes que ganaron (puede ser 1 si billete completo,
                 o varios si compraron fracciones)
  """

  defstruct [
    :id,
    :sorteo_id,
    :nombre,
    :valor,
    numero_ganador: nil,
    ganadores: []
  ]
end
