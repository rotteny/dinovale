# SPDX-License-Identifier: MIT
class_name DinoHome
extends RefCounted
## A toca de UM dino em tempo de jogo: o centro em pixels e as regras (já com as chaves do `ServerRules`). Não vai ao save:
## a toca vem do `den` da vaga do mapa. A máquina de estados o consulta para a ronda, a volta e a âncora.

var center: Vector2
var rules: HomeRules
var tile_px: float


func _init(den_center: Vector2, home_rules: HomeRules, tile_size: float) -> void:
	center = den_center
	rules = home_rules
	tile_px = tile_size


func patrol_px() -> float:
	return rules.patrol_tiles * tile_px


func anchor_px() -> float:
	return rules.anchor_tiles * tile_px


func in_patrol(point: Vector2) -> bool:
	return center.distance_squared_to(point) <= patrol_px() * patrol_px()


func in_anchor(point: Vector2) -> bool:
	return center.distance_squared_to(point) <= anchor_px() * anchor_px()


## Distância do ponto à toca, em tiles.
func tiles_from(point: Vector2) -> float:
	return center.distance_to(point) / tile_px


## O passo de `from` até `to` é permitido ao dino distante? Dentro da ronda, ou fora dela só se aproxima da toca.
func step_allowed(from: Vector2, to: Vector2) -> bool:
	return in_patrol(to) or center.distance_squared_to(to) < center.distance_squared_to(from)
