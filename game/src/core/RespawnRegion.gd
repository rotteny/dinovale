# SPDX-License-Identifier: MIT
class_name RespawnRegion
extends Resource
## Uma região onde o jogador pode renascer (GDD 12.2). Só dados: o sorteio do ponto é do
## `RespawnPicker`. Mata-baixa, Pedreira e as demais entram como novos recursos na lista de
## `RespawnRules`, sem mexer em código nem na tela de morte.

## Id estável em string (vai para o save e para o pedido de respawn).
@export var id: String = ""
@export var display_name: String = ""
## Área sorteável, em pixels do mundo. O sorteio escolhe um tile inteiro dentro dela.
@export var area: Rect2 = Rect2()
## Ponto usado quando nenhum sorteio serve; precisa ser livre e longe de qualquer toca.
@export var fallback_point: Vector2 = Vector2.ZERO
