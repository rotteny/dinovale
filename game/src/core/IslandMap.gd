# SPDX-License-Identifier: MIT
class_name IslandMap
extends RefCounted
## O mapa estático da ilha Lunata (`res://data/world/lunata.json`, gerado por `docs/design/mapa_export.py`):
## terreno por tile, início, marcos, posição dos nós de recurso e do cenário e as vagas de bando selvagem (ADR-007,
## emenda de 07/11: o mapa diz ONDE cada espécie pode nascer, não o ponto). Lógica pura,
## sem nó nem física: o jogo o LÊ, nunca o gera ao rodar, e ele NÃO vai ao save (só o estado dos nós).
## Dado externo: lido só com `JSON`, validado ao carregar; arquivo ruim vira mapa vazio (`is_valid()` falso).

const DEFAULT_PATH := "res://data/world/lunata.json"
const FORMAT := 2
## Tetos do que se lê do arquivo (dado de fora não é confiável).
const MAX_RUNS := 100000
const MAX_SLOTS := 1024
const MAX_SLOT_ID_LENGTH := 32
const MAX_GROUP_SIZE := 16

## Índices do terreno (a mesma ordem do `terreno.json`; 6 é a água funda do anel com colisão).
const DEEP := 0
const SHALLOW := 1
const BEACH := 2
const GRASSLAND := 3
const WOODLAND := 4
const QUARRY := 5
const DEEP_RING := 6
const TERRAIN_COUNT := 7

static var _default: IslandMap = null

var map_id: String = ""
var revision: int = 0
## Hash do conteúdo do mapa (gravado pelo exportador, ADR-007): é o que o save guarda em `world.map_revision`.
var content_hash: String = ""
var size: int = 0
var tile: int = 16
var seed_value: int = 0
var start_cell: Vector2i = Vector2i.ZERO
var landmarks: Dictionary = {}
var dens: Dictionary = {}
## Posições (em tiles) por tipo de nó: `{"tree": [Vector2i, ...], ...}`.
var nodes: Dictionary = {}
var scenery: Dictionary = {}
## Ids estáveis (ADR-007), alinhados índice a índice com `nodes[tipo]`: `{"tipo": [String]}`.
var node_ids: Dictionary = {}
## Vagas de bando, em ordem crescente do número do id: `{id, species, region, size, size_min, size_max}`. A posição não está
## no mapa: a autoridade a sorteia (`WildLayout`). Vaga de região desconhecida é descartada na carga.
var spawn_slots: Array[Dictionary] = []
## Regiões de nascimento: `{id: {"terrains": Array[int], "cells": PackedInt32Array, "mask": PackedByteArray}}`.
## `cells` guarda `y * size + x` na ordem das runs do arquivo; `mask` tem 1 nos tiles da região (tile fora do `terrains` é recusado).
var spawn_regions: Dictionary = {}
var loose_core_count: int = 0
## Por que a última carga recusou o arquivo ("" = nenhuma recusa). `default_map` o escreve no log.
var load_error: String = ""

var _terrain: PackedByteArray = PackedByteArray()
var _valid: bool = false


## Mapa padrão, lido uma vez por execução (o dado não muda). Os testes que querem o arquivo cru usam `from_file`.
static func default_map() -> IslandMap:
	if _default == null:
		_default = IslandMap.from_file(DEFAULT_PATH)
		if not _default.is_valid():  # o jogo não anda sem o mapa: erro claro no log (formato velho, arquivo ruim)
			var reason := _default.load_error if _default.load_error != "" else "arquivo ausente ou inválido"
			push_error("IslandMap: %s recusado (%s)" % [DEFAULT_PATH, reason])
	return _default


static func from_file(path: String) -> IslandMap:
	var map := IslandMap.new()
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()  # `parse` (e não `parse_string`) para o arquivo ruim não sujar o log
	if text != "" and json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
		map.load_dict(json.data)
	return map


## Aplica o dicionário do arquivo. Recusa (mapa fica inválido e vazio) formato errado, linhas fora do tamanho
## ou caractere de terreno desconhecido: nunca carga parcial.
func load_dict(data: Dictionary) -> bool:
	_valid = false
	load_error = ""
	var format := SafeRead.integer(data.get("format"), 0, 0, 1 << 20)
	if format != FORMAT:
		load_error = "mapa em formato %d, o jogo lê o formato %d: regere com docs/design/mapa_export.py" % [format, FORMAT]
		return false
	var side := SafeRead.integer(data.get("size"), 0, 0, 4096)
	var rows := SafeRead.list(data.get("rows"))
	if side < 16 or rows.size() != side:
		return false
	var cells := PackedByteArray()
	cells.resize(side * side)
	for y in side:
		var row := SafeRead.text(rows[y], "")
		if row.length() != side:
			return false
		var bytes := row.to_ascii_buffer()
		for x in side:
			var code: int = bytes[x] - 48
			if code < 0 or code >= TERRAIN_COUNT:
				return false
			cells[y * side + x] = code
	size = side  # `in_bounds` lê o tamanho
	var node_points := _read_points(SafeRead.dict(data.get("nodes")), SafeRead.dict(data.get("node_ids")), "n")
	var regions := _read_regions(SafeRead.dict(data.get("spawn_regions")), side, cells)
	var slots := _read_slots(SafeRead.list(data.get("spawn_slots")), regions)
	if not _ids_are_unique([node_points[1]]) or _slot_ids_repeat(SafeRead.list(data.get("spawn_slots"))):
		size = 0
		return false  # id vazio ou repetido: o save apontaria para dois lugares (ADR-007)
	_terrain = cells
	map_id = SafeRead.text(data.get("id"), "")
	revision = SafeRead.integer(data.get("revision"), 0, 0, 1 << 20)
	tile = SafeRead.integer(data.get("tile"), 16, 4, 64)
	seed_value = SafeRead.integer(data.get("seed"), 0, 0, 1 << 30)
	start_cell = _cell_of(data.get("start"), Vector2i(side >> 1, side >> 1))
	landmarks = _cells_dict(SafeRead.dict(data.get("landmarks")))
	dens = _cells_dict(SafeRead.dict(data.get("dens")))
	content_hash = SafeRead.text(data.get("content_hash"), "")
	nodes = node_points[0]
	node_ids = node_points[1]
	scenery = _cell_lists(SafeRead.dict(data.get("scenery")))
	spawn_regions = regions
	spawn_slots = slots
	loose_core_count = SafeRead.integer(SafeRead.dict(data.get("loose_stone_respawn")).get("core_count"), 0, 0, 1000)
	_valid = true
	return true


func is_valid() -> bool:
	return _valid


## Terreno do tile (`DEEP` fora do mapa: o que está além da borda é mar).
func terrain_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return DEEP
	return _terrain[cell.y * size + cell.x]


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / tile), floori(point.y / tile))


## Centro do tile, em pixels do mundo (onde os pés de quem nasce ali ficam).
func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile


## Anda-se nele: terra, praia e água rasa (sem lentidão). A água funda bloqueia.
func is_walkable(cell: Vector2i) -> bool:
	var terrain := terrain_at(cell)
	return terrain >= SHALLOW and terrain <= QUARRY


func is_walkable_at(point: Vector2) -> bool:
	return is_walkable(cell_of(point))


## Terra firme (praia inclusa): onde se constrói, nasce nó e nasce dino. Água rasa não.
func is_land(cell: Vector2i) -> bool:
	var terrain := terrain_at(cell)
	return terrain >= BEACH and terrain <= QUARRY


## Tile da água funda com colisão (anel de 2 tiles junto ao raso).
func has_ring_collision(cell: Vector2i) -> bool:
	return terrain_at(cell) == DEEP_RING


## Ponto de nascimento do jogador, em pixels.
func start_point() -> Vector2:
	return center_of(start_cell)


## Ponto seguro para quem estava fora da ilha (posição de um save antigo): o início.
func safe_point() -> Vector2:
	return start_point()


## Mapa inteiro em pixels (o limite da câmera é este retângulo, em `map_bounds.tres`).
func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size, size) * tile)


## Terra firme mais próxima de `point` em até `max_radius` tiles (em anéis crescentes); `fallback` se nada.
func nearest_walkable_point(point: Vector2, max_radius: int, fallback: Vector2) -> Vector2:
	var origin := cell_of(point)
	if is_walkable(origin):
		return point
	for radius in range(1, max_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius and is_walkable(origin + Vector2i(dx, dy)):
					return center_of(origin + Vector2i(dx, dy))
	return fallback


## Quantos tiles de cada terreno (para testes e para o relatório).
func count_by_terrain() -> Array[int]:
	var counts: Array[int] = []
	counts.resize(TERRAIN_COUNT)
	counts.fill(0)
	for code in _terrain:
		counts[code] += 1
	return counts


## `{"tipo": [Vector2i]}`: lista de pares `[x, y]` com os pares inválidos ou fora do mapa descartados.
func _cell_lists(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in raw:
		var cells: Array[Vector2i] = []
		for pair: Variant in SafeRead.list(raw[key]):
			var cell := _cell_of(pair, Vector2i(-1, -1))
			if in_bounds(cell):
				cells.append(cell)
		result[str(key)] = cells
	return result


## Como `_cell_lists`, mais o id de cada ponto mantido (`[células, ids]`). Sem lista de ids (mapa de teste), ou com
## tamanho diferente da lista de pontos, os ids saem `<prefixo><tipo>:<posição na lista>`: o arquivo real traz todos.
func _read_points(raw: Dictionary, raw_ids: Dictionary, prefix: String) -> Array:
	var all_cells: Dictionary = {}
	var all_ids: Dictionary = {}
	for key: Variant in raw:
		var pairs := SafeRead.list(raw[key])
		var saved_ids := SafeRead.list(raw_ids.get(key))
		var has_ids := saved_ids.size() == pairs.size()
		var cells: Array[Vector2i] = []
		var ids: Array[String] = []
		for i in pairs.size():
			var cell := _cell_of(pairs[i], Vector2i(-1, -1))
			if in_bounds(cell):
				cells.append(cell)
				ids.append(SafeRead.text(saved_ids[i], "") if has_ids else "%s%s:%d" % [prefix, key, i])
		all_cells[str(key)] = cells
		all_ids[str(key)] = ids
	return [all_cells, all_ids]


## Nenhum id vazio e nenhum repetido (`[{tipo: [ids]}, ...]`).
func _ids_are_unique(groups: Array) -> bool:
	var seen: Dictionary = {}
	for group: Dictionary in groups:
		for kind: Variant in group:
			for id: String in group[kind]:
				if id == "" or seen.has(id):
					return false
				seen[id] = true
	return true


## Região de nascimento `region_id` (vazia se não existe).
func region_cells(region_id: String) -> PackedInt32Array:
	return (spawn_regions.get(region_id, {}) as Dictionary).get("cells", PackedInt32Array())


## O tile pertence à região (máscara)?
func region_has(region_id: String, cell: Vector2i) -> bool:
	if not in_bounds(cell) or not spawn_regions.has(region_id):
		return false
	return (spawn_regions[region_id]["mask"] as PackedByteArray)[cell.y * size + cell.x] == 1


## Regiões do arquivo, com o terreno de cada tile conferido: `runs` = `[y, x0, x1]` (x1 inclusivo). Run mal formada ou fora do
## mapa é descartada; tile de terreno que a região não declara também (nunca entra tile fora do bioma).
func _read_regions(raw: Dictionary, side: int, terrain_bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in raw:
		var entry := SafeRead.dict(raw[key])
		var terrains: Array[int] = []
		for code: Variant in SafeRead.list(entry.get("terrains")):
			terrains.append(SafeRead.integer(code, -1, -1, TERRAIN_COUNT))
		var allowed := PackedByteArray()
		allowed.resize(TERRAIN_COUNT)
		for code in terrains:
			if code >= 0 and code < TERRAIN_COUNT:
				allowed[code] = 1
		var mask := PackedByteArray()
		mask.resize(side * side)
		var cells := PackedInt32Array()
		for run: Variant in SafeRead.list(entry.get("runs")).slice(0, MAX_RUNS):
			var triple := SafeRead.list(run)
			if triple.size() != 3:
				continue
			var y := SafeRead.integer(triple[0], -1, 0, side - 1)
			var x0 := SafeRead.integer(triple[1], -1, 0, side - 1)
			var x1 := SafeRead.integer(triple[2], -1, 0, side - 1)
			if y < 0 or x0 < 0 or x1 < x0:
				continue
			for x in range(x0, x1 + 1):
				var index := y * side + x
				if allowed[terrain_bytes[index]] == 1 and mask[index] == 0:
					mask[index] = 1
					cells.append(index)
		result[str(key)] = {"terrains": terrains, "cells": cells, "mask": mask}
	return result


## Vagas do arquivo em ordem crescente do número do id; sem id, sem espécie, de região desconhecida ou com id repetido, caem.
func _read_slots(raw: Array, regions: Dictionary) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var seen := {}
	for item: Variant in raw.slice(0, MAX_SLOTS):
		var entry := SafeRead.dict(item)
		var id := SafeRead.text(entry.get("id"), "")
		var species := SafeRead.text(entry.get("species"), "")
		var region := SafeRead.text(entry.get("region"), "")
		if id == "" or id.length() > MAX_SLOT_ID_LENGTH or species == "" or not regions.has(region) or seen.has(id):
			continue
		seen[id] = true
		var amount := SafeRead.integer(entry.get("size"), 1, 1, MAX_GROUP_SIZE)
		slots.append({"id": id, "species": species, "region": region, "size": amount,
				"size_min": SafeRead.integer(entry.get("size_min"), 1, 1, MAX_GROUP_SIZE),
				"size_max": SafeRead.integer(entry.get("size_max"), MAX_GROUP_SIZE, 1, MAX_GROUP_SIZE)})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := slot_number(a["id"])
		var right := slot_number(b["id"])
		return left < right if left != right else str(a["id"]) < str(b["id"]))
	return slots


## Id de vaga repetido ou vazio no arquivo (o save apontaria para duas vagas).
func _slot_ids_repeat(raw: Array) -> bool:
	var seen := {}
	for item: Variant in raw:
		var id := SafeRead.text(SafeRead.dict(item).get("id"), "")
		if id == "" or seen.has(id):
			return true
		seen[id] = true
	return false


## Número do id da vaga (`g12` -> 12); sem número, vai para o fim.
static func slot_number(id: String) -> int:
	var digits := id.trim_prefix("g")
	return digits.to_int() if digits.is_valid_int() else 1 << 30


func _cells_dict(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in raw:
		var cell := _cell_of(raw[key], Vector2i(-1, -1))
		if in_bounds(cell):
			result[str(key)] = cell
	return result


func _cell_of(pair: Variant, fallback: Vector2i) -> Vector2i:
	var list := SafeRead.list(pair)
	if list.size() != 2:
		return fallback
	return Vector2i(SafeRead.integer(list[0], -1, -1, 1 << 20), SafeRead.integer(list[1], -1, -1, 1 << 20))
