# SPDX-License-Identifier: MIT
class_name WildLayout
extends RefCounted
## Onde nascem os bandos selvagens (ADR-007, emenda de 07/11). Lógica pura e determinística: lê as vagas e as máscaras do
## mapa e sorteia, com a semente do mundo, o centro de cada bando e a posição de cada membro. Só a autoridade o usa
## (o cliente recebe os selvagens já postos). Fluxos: centro `["wild", semente, vaga, geração, "pos"]` (com `tries` no fim
## quando maior que 0), membro `["wild", semente, vaga, geração, "member", k]`.
##
## Regras: o centro cai num tile da região da vaga e do terreno da espécie; fica longe do início e de todo centro já posto
## (`max(min_group_spacing_any_tiles, espécie)` entre bandos da mesma espécie; só a global entre espécies diferentes); no
## respawn, também longe dos jogadores. Os membros ficam no raio de coesão, em tile da mesma região.

const NO_CELL := Vector2i(-1, -1)

var map: IslandMap
var rules: WorldRules
var world_seed: int = 0
## Espécies que o jogo conhece (as demais da tabela de vagas são ignoradas sem erro).
var species: Array[DinoBaseStats] = []


func _init(island: IslandMap, world_rules: WorldRules, seed_value: int, kinds: Array[DinoBaseStats]) -> void:
	map = island
	rules = world_rules
	world_seed = seed_value
	species = kinds


## Espécie da vaga pela chave (`spawn_key`); null se o jogo ainda não a tem (Dodo, Triceratops).
func species_of(slot: Dictionary) -> DinoBaseStats:
	for kind in species:
		if kind.spawn_key == slot["species"]:
			return kind
	return null


## Tamanho do bando: o do mapa, saturado nos limites da espécie (o `Resource` é o limite) e depois nos da própria vaga.
func size_of(slot: Dictionary) -> int:
	var kind := species_of(slot)
	if kind == null:
		return 0
	var limited := clampi(int(slot["size"]), kind.group_size_min, kind.group_size_max)
	return clampi(limited, int(slot["size_min"]), maxi(int(slot["size_min"]), int(slot["size_max"])))


## Um centro posto: `{"cell": Vector2i, "species": String, "spacing": float}`.
static func placed_center(cell: Vector2i, species_key: String, spacing: float) -> Dictionary:
	return {"cell": cell, "species": species_key, "spacing": spacing}


## Disposição inicial (geração 0): `{id da vaga: centro}` das vagas que acharam lugar, em ordem crescente do id (vaga nova
## entra no fim, então acrescentar não move as existentes). `fixed` são centros já postos (o do tutorial). Sortear em
## sequência pode travar uma vaga: ela fica de fora e o id vai em `empty` (o chamador avisa; nunca relaxa distância nem
## região). Nunca se refaz a disposição por causa dela: as vagas que já tinham lugar não se movem. (`pick_center` já varre a
## máscara inteira antes de desistir, então outra variante do fluxo não acharia lugar onde ele não existe.)
func layout(fixed: Array[Dictionary], empty: Array[String] = []) -> Dictionary:
	var placed: Array[Dictionary] = fixed.duplicate()
	var centers: Dictionary = {}
	for slot in map.spawn_slots:
		var kind := species_of(slot)
		if kind == null:
			continue
		var cell := pick_center(slot, 0, 0, placed, [], 0.0)
		if cell == NO_CELL:
			empty.append(slot["id"])
			continue
		centers[slot["id"]] = cell
		placed.append(placed_center(cell, kind.spawn_key, kind.min_group_spacing_tiles))
	return centers


## Centro da vaga na geração `gen` (tentativa `tries`) ou `NO_CELL` se nenhum tile serve. `placed` = centros dos outros
## bandos; `players` = células dos jogadores com `player_clearance` tiles de folga (0 = sem exigir, o caso da disposição
## inicial, que em vez disso exige o raio livre do início).
func pick_center(slot: Dictionary, gen: int, tries: int, placed: Array[Dictionary], players: Array,
		player_clearance: float) -> Vector2i:
	var kind := species_of(slot)
	var region := map.region_cells(slot["region"])
	if kind == null or region.is_empty():
		return NO_CELL
	var parts: Array = ["wild", world_seed, slot["id"], gen, "pos"]
	if tries > 0:
		parts.append(tries)
	var rng := SeededRng.new()
	rng.seed_from(parts)
	for attempt in rules.group_spawn_attempts:
		var cell := _cell_from_index(region[rng.next_below(region.size())])
		if _center_fits(cell, kind, placed, players, player_clearance, gen == 0):
			return cell
	# Sorteio esgotado: varre a máscara toda a partir de um ponto sorteado (determinístico), para só dar "sem lugar" quando
	# realmente não há.
	var start := rng.next_below(region.size())
	for step in region.size():
		var cell := _cell_from_index(region[(start + step) % region.size()])
		if _center_fits(cell, kind, placed, players, player_clearance, gen == 0):
			return cell
	return NO_CELL


## Membros do bando: `{k: célula}`; o 0 é o centro, os demais ficam a até `cohesion_radius_tiles` dele, em tile da região e
## do terreno da espécie, sem dividir tile. Membro que não acha tile livre não nasce (o bando fica menor, nunca abaixo de 1).
func members_of(slot: Dictionary, gen: int, center: Vector2i) -> Dictionary:
	var kind := species_of(slot)
	var members: Dictionary = {}
	if kind == null:
		return members
	members[0] = center
	var used := {center: true}
	var radius := kind.cohesion_radius_tiles
	var reach := ceili(radius)
	for k in range(1, size_of(slot)):
		var rng := SeededRng.new()
		rng.seed_from(["wild", world_seed, slot["id"], gen, "member", k])
		for attempt in rules.group_member_attempts:
			var offset := Vector2i(rng.next_below(2 * reach + 1) - reach, rng.next_below(2 * reach + 1) - reach)
			var cell := center + offset
			if Vector2(offset).length() <= radius and not used.has(cell) and _tile_ok(slot, kind, cell):
				members[k] = cell
				used[cell] = true
				break
	return members


## O tile serve de centro desta vaga (região, terreno da espécie)? Valida a entrada de um save.
func center_is_valid(slot: Dictionary, cell: Vector2i) -> bool:
	var kind := species_of(slot)
	return kind != null and _tile_ok(slot, kind, cell)


func _tile_ok(slot: Dictionary, kind: DinoBaseStats, cell: Vector2i) -> bool:
	return map.region_has(slot["region"], cell) and kind.spawn_terrains.has(map.terrain_at(cell))


func _center_fits(cell: Vector2i, kind: DinoBaseStats, placed: Array[Dictionary], players: Array,
		player_clearance: float, away_from_start: bool) -> bool:
	if not _tile_ok_for_kind(cell, kind):
		return false
	if away_from_start and _too_close(cell, map.start_cell, rules.group_start_clearance_tiles):
		return false
	for other in placed:
		var needed := rules.min_group_spacing_any_tiles
		if other["species"] == kind.spawn_key:
			needed = maxf(needed, kind.min_group_spacing_tiles)
		if _too_close(cell, other["cell"], needed):
			return false
	for player_cell: Vector2i in players:
		if _too_close(cell, player_cell, player_clearance):
			return false
	return true


## O terreno do tile serve à espécie (a região já foi usada para escolher o candidato).
func _tile_ok_for_kind(cell: Vector2i, kind: DinoBaseStats) -> bool:
	return kind.spawn_terrains.has(map.terrain_at(cell))


func _too_close(a: Vector2i, b: Vector2i, minimum: float) -> bool:
	return Vector2(a - b).length_squared() < minimum * minimum


func _cell_from_index(index: int) -> Vector2i:
	return Vector2i(index % map.size, index / map.size)
