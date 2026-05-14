defmodule Azar.Modelos.Billete do
  @moduledoc """
  Representa la compra de un billete (completo o fracción) por un cliente.

  Campos:
    - id: identificador único de la compra
    - sorteo_id: a qué sorteo pertenece
    - cliente_id: quién compró
    - numero: el número de billete (del 1 a cantidad_billetes del sorteo)
    - tipo: :completo o :fraccion
    - fraccion_numero: si es fracción, qué fracción es (1, 2, 3...). Nil si es completo.
    - valor_pagado: cuánto pagó el cliente
    - fecha_compra: cuándo compró (string "YYYY-MM-DD")
    - devuelto: si devolvió la compra (true/false)
  """

  defstruct [
    :id,
    :sorteo_id,
    :cliente_id,
    :numero,
    :tipo,
    :fraccion_numero,
    :valor_pagado,
    :fecha_compra,
    devuelto: false
  ]
end
