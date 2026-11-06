# SPDX-License-Identifier: MIT
class_name RespawnPicker
extends RefCounted
## Sorteio do ponto de respawn numa região (GDD 12.2). Lógica pura: quem chama diz o que é um ponto
## livre (`is_free`, colisão e nós de recurso) e onde estão os selvagens. O RNG é de quem chama,
## semeável (`SeededRng`, derivado do `world_id` (ainda não há seed de mundo própria) e do contador de respawns).


## `{position: Vector2, fallback: bool}`. Até `rules.max_attempts` sorteios uniformes entre os tiles
## da área; o primeiro que serve vence. Nenhum serviu (ou área sem tile): ponto reserva da região.
## `is_free: Callable(Vector2) -> bool`; `wild_positions` são as posições de dinos selvagens.
static func pick(region: RespawnRegion, rules: RespawnRules, rng: SeededRng,
		is_free: Callable, wild_positions: Array[Vector2]) -> Dictionary:
	var tile := float(rules.tile_size)
	var columns := int(floorf(region.area.size.x / tile))
	var rows := int(floorf(region.area.size.y / tile))
	if columns > 0 and rows > 0:
		for _attempt in rules.max_attempts:
			var cell := Vector2(rng.next_below(columns), rng.next_below(rows))
			var point := region.area.position + (cell + Vector2(0.5, 0.5)) * tile
			if _serves(point, rules, is_free, wild_positions):
				return {"position": point, "fallback": false}
	return {"position": region.fallback_point, "fallback": true}


static func _serves(point: Vector2, rules: RespawnRules, is_free: Callable, wild_positions: Array[Vector2]) -> bool:
	for wild in wild_positions:
		if point.distance_to(wild) < rules.min_distance_from_wild:
			return false
	return not is_free.is_valid() or bool(is_free.call(point))
