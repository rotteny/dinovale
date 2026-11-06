# SPDX-License-Identifier: MIT
class_name WorldRules
extends Resource
## Regras do mundo da ilha, só dados (`res://data/world/world_rules.tres`): que nó e que cenário cada tipo do
## mapa usa, o que a v0.2 instancia e os níveis por bioma. O mapa em si (`IslandMap`) só diz ONDE.

## Tipo do mapa (`tree`, `bush_baga`...) -> definição do nó de recurso.
@export var node_defs: Dictionary[String, ResourceNodeDef] = {}
## Cenário do mapa (`tree_decor`, `formation_a`...) por id.
@export var scenery: Array[SceneryDef] = []
## Nós que o mapa traz e a v0.2 NÃO instancia (o filão de ferro é do M4: GDD 5.9c e `mapa-ilha.md` 8).
@export var disabled_node_kinds: Array[String] = ["iron_seam"]
## Pedra avulsa do núcleo volta mais cedo (300 s) que a da trilha (600 s; GDD 5.9b).
@export_range(1.0, 3600.0) var loose_core_respawn_seconds: float = 300.0
## Raio do núcleo em volta do início, em tiles (`mapa-ilha.md` 5): a pedra avulsa de dentro dele volta em 300 s.
@export_range(1.0, 64.0) var core_radius_tiles: float = 16.0
## Faixa de nível dos dinos nascidos em cada bioma (índice do terreno do `IslandMap` -> mínimo e máximo).
@export var level_bands: Dictionary[int, Vector2i] = {}
## Teto de dinos selvagens que o jogo coloca no mundo nesta etapa (só há uma espécie; os 360 vêm com as espécies).
@export_range(0, 400) var wild_population_max: int = 108


func scenery_by_id(scenery_id: String) -> SceneryDef:
	for entry in scenery:
		if entry.id == scenery_id:
			return entry
	return null


func node_def_of(kind: String) -> ResourceNodeDef:
	if disabled_node_kinds.has(kind):
		return null
	return node_defs.get(kind)


func level_band_of(terrain: int) -> Vector2i:
	return level_bands.get(terrain, Vector2i(1, 10))
