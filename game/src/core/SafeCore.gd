# SPDX-License-Identifier: MIT
class_name SafeCore
extends RefCounted
## Núcleo seguro ÚNICO do mundo (E3a): a região de nascimento do jogador (`RespawnRules`) mais a margem
## `PredationRules.spawn_safe_margin_tiles`. Um dado, um teste: a presa não é elegível dentro dele, o caçador não nasce,
## não passeia nem entra nele, e a perseguição pára na borda. A margem precisa ser >= à percepção de todo caçador, para
## quem está de fora nunca perceber o jogador de dentro (o teste B6 trava isso).

var margin_px: float = 0.0
var _rects: Array[Rect2] = []


func _init(respawn: RespawnRules, margin_tiles: float, tile_px: float) -> void:
	margin_px = margin_tiles * tile_px
	for region in respawn.available_regions():
		_rects.append(region.area.grow(margin_px))


func contains(point: Vector2) -> bool:
	for rect in _rects:
		if rect.has_point(point):
			return true
	return false
