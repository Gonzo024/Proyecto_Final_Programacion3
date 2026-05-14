defmodule Azar.Modelos.Cliente do
  @moduledoc """
  Representa un jugador registrado en el sistema.

  Campos:
    - id: identificador único (string, ej: "cliente_001")
    - nombre: nombre completo
    - documento: número de cédula o documento de identidad
    - password: contraseña (en un sistema real iría hasheada)
    - tarjeta: datos simulados de tarjeta de crédito (mapa con número, vencimiento, cvv)
    - notificaciones: lista de mensajes enviados por el servidor
  """

  defstruct [
    :id,
    :nombre,
    :documento,
    :password,
    :tarjeta,
    notificaciones: []
  ]
end
