# SPDX-License-Identifier: MIT
class_name DinoOrderRules
extends Resource
## Números das ordens do dino domado, só dados. Valores em `res://data/balance/dino_order_rules.tres`.
## Quem usa: `DinoStateMachine`. A conta do Seguir é pura (`follow_direction`), testável sem física.

## Lado do tile do mapa, em pixels.
@export_range(4, 64) var tile_size: int = 16
## Seguir: o dino vai até o dono quando está a mais que isto, em tiles (GDD 6.11: "fica a 3 tiles").
@export_range(1.0, 12.0) var follow_distance_tiles: float = 3.0
## Seguir: depois de andar, para ao chegar a esta distância (histerese: não treme na borda dos 3).
@export_range(0.5, 12.0) var arrive_distance_tiles: float = 2.5
## Seguir: multiplicador da velocidade de andar (jogador a 70 px/s, dino a 40: 1,8 dá 72 e alcança o dono andando) [proposta].
@export_range(1.75, 4.0) var follow_speed_multiplier: float = 1.8


func follow_px() -> float:
	return follow_distance_tiles * tile_size


func arrive_px() -> float:
	return minf(arrive_distance_tiles, follow_distance_tiles) * tile_size


## Direção (comprimento 1, ou zero) para seguir o dono. `moving` diz se já estava andando: parado só
## sai quando passa de `follow_px`; andando só para ao chegar em `arrive_px`.
func follow_direction(from: Vector2, owner_at: Vector2, moving: bool) -> Vector2:
	var offset := owner_at - from
	var distance := offset.length()
	var limit := arrive_px() if moving else follow_px()
	if distance <= limit or distance == 0.0:
		return Vector2.ZERO
	return offset / distance
