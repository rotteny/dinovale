# SPDX-License-Identifier: MIT
class_name WorkbenchField
extends Node2D
## As Bancadas do mundo (E7a): colocar (validado), achar a mais próxima, salvar e restaurar. Cada uma é um `Workbench`
## registrado na autoridade. Colocar é `WorldAuthority.request_place`; aqui só se decide se o ponto serve. Como o
## `GroundItemField`, a lista vai ao save como `to_list`/`restore_list` e nunca dispara evento de jogo.

## Uma Bancada entrou ou saiu do mundo (a navegação marca o tile dela).
signal bench_placed(bench: Workbench)
signal bench_removed(bench: Workbench)

const MAX_COORD := 1.0e6
## Motivos de ponto recusado (os textos estão em `GameMessages.REASONS`).
const REASON_TERRAIN := "bad_terrain"
const REASON_OCCUPIED := "occupied"
const REASON_SAFE_CORE := "safe_core"
const REASON_LIMIT := "place_limit"

@export var rules: CraftRules = preload("res://data/balance/craft_rules.tres")
var authority: WorldAuthority = null
## Mapa (terreno andável). Sem mapa não há terreno a conferir.
var map: IslandMap = null
## Ocupação do chão (jogador e dinos): a Bancada não nasce sobre quem está no tile.
var occupancy: TileOccupancy = null
## Núcleo seguro do mundo: nada de Bancada dentro dele. Null = sem núcleo.
var safe_core: SafeCore = null
## Nós de recurso: a Bancada não nasce sobre um.
var resources: ResourceField = null
var tile_px: float = 16.0

var _benches: Array[Workbench] = []


func count() -> int:
	return _benches.size()


func benches() -> Array[Workbench]:
	return _benches.duplicate()


## O centro do tile que contém `point`.
func snap(point: Vector2) -> Vector2:
	return (Vector2(floori(point.x / tile_px), floori(point.y / tile_px)) + Vector2(0.5, 0.5)) * tile_px


## Por que o ponto não serve ("" = serve): limite de peças, núcleo seguro, terreno, outra Bancada, recurso ou corpo no tile.
func problem_at(point: Vector2) -> String:
	var center := snap(point)
	if _benches.size() >= rules.max_workbenches:
		return REASON_LIMIT
	var fixed := fixed_problem(center)
	if fixed != "":
		return fixed
	if bench_at(center) != null or _resource_at(center):
		return REASON_OCCUPIED
	if occupancy != null and not occupancy.is_cell_free(Vector2i(floori(center.x / tile_px), floori(center.y / tile_px)), tile_px):
		return REASON_OCCUPIED
	return ""


## O que não muda com o tempo: núcleo seguro e terreno ("" = serve). É o que um save carregado também confere.
func fixed_problem(point: Vector2) -> String:
	var center := snap(point)
	if safe_core != null and safe_core.contains(center):
		return REASON_SAFE_CORE
	if map != null and map.is_valid() and not (map.is_land(map.cell_of(center)) and map.is_walkable_at(center)):
		return REASON_TERRAIN
	return ""


## A Bancada que ocupa o tile de `point`, ou null.
func bench_at(point: Vector2) -> Workbench:
	var center := snap(point)
	for bench in _benches:
		if bench.position.is_equal_approx(center):
			return bench
	return null


## A Bancada mais próxima de `origin` dentro de `reach` pixels, ou null.
func nearest_within(origin: Vector2, reach: float) -> Workbench:
	var best: Workbench = null
	var best_distance := reach
	for bench in _benches:
		var distance := origin.distance_to(bench.global_position)
		if distance <= best_distance:
			best = bench
			best_distance = distance
	return best


## Cria a Bancada no tile de `point` (já validado por `problem_at`). `entity_id` 0 = o próximo livre.
func place(point: Vector2, entity_id: int = 0) -> Workbench:
	var bench := Workbench.new()
	bench.position = snap(point)
	add_child(bench)
	_benches.append(bench)
	var view := WorkbenchView.new()
	bench.add_child(view)
	bench_placed.emit(bench)
	if authority != null and authority.register(bench, maxi(entity_id, 0)) == 0:
		authority.register(bench)
	return bench


## Tira a Bancada do mundo (e do registro).
func remove(bench: Workbench) -> void:
	if not _benches.has(bench):
		return
	_benches.erase(bench)
	bench_removed.emit(bench)
	if authority != null:
		authority.unregister(authority.id_of(bench))
	bench.queue_free()


## Para o save: id da entidade e posição.
func to_list() -> Array:
	var list: Array = []
	for bench in _benches:
		list.append({"id": authority.id_of(bench) if authority != null else 0, "x": bench.position.x, "y": bench.position.y})
	return list


## Restaura a lista salva no lugar das Bancadas de agora. Dado de fora: entrada ruim, número fora da faixa, tile repetido e
## excesso são descartados; save sem a lista (anterior à E7a) deixa o mundo sem Bancada. Nunca emite evento de jogo.
func restore_list(list: Array) -> void:
	for bench in _benches.duplicate():
		remove(bench)
	for entry: Variant in list:
		if _benches.size() >= rules.max_workbenches:
			break
		var data := SafeRead.dict(entry)
		if not _is_number(data.get("x")) or not _is_number(data.get("y")):
			continue  # coordenada ausente ou que não é número: a entrada não vale
		var point := Vector2(SafeRead.number(data.get("x"), 0.0, -MAX_COORD, MAX_COORD),
				SafeRead.number(data.get("y"), 0.0, -MAX_COORD, MAX_COORD))
		if bench_at(point) == null and fixed_problem(point) == "":  # save editado: terreno ou núcleo seguro que não servem
			# Id fora da faixa vira 0 (o próximo livre): um id no teto empurraria o contador e o próximo load seria recusado.
			place(point, SafeRead.integer(data.get("id"), 0, 0, SaveMigrations.MAX_ENTITY_ID - 1))


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _resource_at(center: Vector2) -> bool:
	if resources == null:
		return false
	for node in resources.nodes():
		if snap(node.global_position).is_equal_approx(center):
			return true
	return false
