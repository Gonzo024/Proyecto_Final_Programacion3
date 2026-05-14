defmodule Azar.Modelos.Sorteo do
  @moduledoc """
  Representa un sorteo de la empresa Azar S.A.

  Campos:
    - id: identificador único (string, ej: "sorteo_001")
    - nombre: nombre del sorteo (ej: "Lotería de Navidad")
    - fecha: fecha en que se realiza (string "YYYY-MM-DD")
    - valor_billete: precio del billete completo (número)
    - fracciones: cuántas fracciones tiene cada billete (número)
    - cantidad_billetes: cuántos billetes existen (número)
    - realizado: si ya se jugó (true/false)
    - numeros_ganadores: lista de números ganadores (asignados al realizarse)
  """

  defstruct [
    :id,
    :nombre,
    :fecha,
    :valor_billete,
    :fracciones,
    :cantidad_billetes,
    realizado: false,
    numeros_ganadores: []
  ]
end
