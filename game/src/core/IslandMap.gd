# SPDX-License-Identifier: MIT
class_name IslandMap
extends RefCounted
## O mapa estático da ilha Lunata (`res://data/world/lunata.json`, gerado por `docs/design/mapa_export.py`):
## terreno por tile, início, marcos, posição dos nós de recurso, do cenário e dos nascimentos. Lógica pura,
## sem nó nem física: o jogo o LÊ, nunca o gera ao rodar, e ele NÃO vai ao save (só o estado dos nós).
## Dado externo: lido só com `JSON`, validado ao carregar; arquivo ruim vira mapa vazio (`is_valid()` falso).

const DEFAULT_PATH := "res://data/world/lunata.json"
const FORMAT := 1

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
var size: int = 0
var tile: int = 16
var seed_value: int = 0
var start_cell: Vector2i = Vector2i.ZERO
var landmarks: Dictionary = {}
var dens: Dictionary = {}
## Posições (em tiles) por tipo de nó: `{"tree": [Vector2i, ...], ...}`.
var nodes: Dictionary = {}
var scenery: Dictionary = {}
var spawns: Dictionary = {}
var loose_core_count: int = 0

var _terrain: PackedByteArray = PackedByteArray()
var _valid: bool = false


## Mapa padrão, lido uma vez por execução (o dado não muda). Os testes que querem o arquivo cru usam `from_file`.
static func default_map() -> IslandMap:
	if _default == null:
		_default = IslandMap.from_file(DEFAULT_PATH)
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
	if SafeRead.integer(data.get("format"), 0, 0, 1 << 20) != FORMAT:
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
	_terrain = cells
	size = side
	map_id = SafeRead.text(data.get("id"), "")
	revision = SafeRead.integer(data.get("revision"), 0, 0, 1 << 20)
	tile = SafeRead.integer(data.get("tile"), 16, 4, 64)
	seed_value = SafeRead.integer(data.get("seed"), 0, 0, 1 << 30)
	start_cell = _cell_of(data.get("start"), Vector2i(side >> 1, side >> 1))
	landmarks = _cells_dict(SafeRead.dict(data.get("landmarks")))
	dens = _cells_dict(SafeRead.dict(data.get("dens")))
	nodes = _cell_lists(SafeRead.dict(data.get("nodes")))
	scenery = _cell_lists(SafeRead.dict(data.get("scenery")))
	spawns = _cell_lists(SafeRead.dict(data.get("spawns")))
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
