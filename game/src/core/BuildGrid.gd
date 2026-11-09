# SPDX-License-Identifier: MIT
class_name BuildGrid
extends RefCounted
## A grade de construção (E8a, CON-01): uma peça por célula, num `Dictionary` por `Vector2i` (16 px por célula, GDD 8).
## Só dado e regra de forma: a validação de quem pode construir (receita, material, alcance, terreno, corpo no caminho)
## é do `BuildService`; aqui ficam a ocupação, o apoio, a porta e o save. Nada aqui conhece nó, sprite ou física: a
## apresentação e a navegação ouvem os sinais. `from_dict` nunca dispara evento de jogo (só estes sinais de vista).

## Uma peça entrou na célula (também ao restaurar um save).
signal piece_added(cell: Vector2i)
## A peça saiu da célula; `piece` é o que havia (já copiado).
signal piece_removed(cell: Vector2i, piece: Dictionary)
## A porta da célula abriu ou fechou.
signal door_changed(cell: Vector2i)

const FORMAT_VERSION := 1
## Célula além disto é dado ruim (o mapa tem 256, mas o save é de fora: o teto só evita número absurdo).
const MAX_CELL := 100000
const MAX_OWNER_LENGTH := 64

var catalog: PieceCatalog = PieceCatalog.with_defaults()
var rules: BuildRules = preload("res://data/balance/build_rules.tres")
## Confere o que não muda com o tempo (terreno e núcleo seguro): `(cell: Vector2i) -> String`, "" = serve. O `from_dict` o usa
## para descartar peça de save editado. Sem ele, vale tudo.
var fixed_check: Callable = Callable()

var _cells: Dictionary[Vector2i, Dictionary] = {}


func count() -> int:
	return _cells.size()


func cells() -> Array[Vector2i]:
	return _cells.keys()


func has_piece(cell: Vector2i) -> bool:
	return _cells.has(cell)


## Cópia da peça na célula (`{piece, rot, owner, open, id}`), ou `{}`.
func piece_at(cell: Vector2i) -> Dictionary:
	return (_cells[cell] as Dictionary).duplicate() if _cells.has(cell) else {}


func def_at(cell: Vector2i) -> PieceDef:
	return catalog.find(str((_cells[cell] as Dictionary)["piece"])) if _cells.has(cell) else null


func is_open(cell: Vector2i) -> bool:
	return _cells.has(cell) and bool((_cells[cell] as Dictionary)["open"])


## Quantas peças de `piece_id` existem.
func count_of(piece_id: String) -> int:
	var total := 0
	for cell: Vector2i in _cells:
		if (_cells[cell] as Dictionary)["piece"] == piece_id:
			total += 1
	return total


## A célula tem corpo sólido agora? (parede, porta fechada, Bancada)
func blocks(cell: Vector2i) -> bool:
	var def := def_at(cell)
	return def != null and def.blocks_body and not is_open(cell)


## Há peça de apoio (fundação) em volta de `cell` (até `support_radius`, sem contar a própria célula)?
func has_support(cell: Vector2i) -> bool:
	var radius := rules.support_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var other := cell + Vector2i(dx, dy)
			if other != cell and _gives_support(other):
				return true
	return false


## Células de peças que perderiam TODO o apoio se a peça de `cell` saísse.
func dependents_of(cell: Vector2i) -> Array[Vector2i]:
	var lost: Array[Vector2i] = []
	if not _gives_support(cell):
		return lost
	var radius := rules.support_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var other := cell + Vector2i(dx, dy)
			var def := def_at(other)
			if other != cell and def != null and def.needs_support and not _has_support_without(other, cell):
				lost.append(other)
	return lost


## Coloca a peça (sem validar quem pede: isso é do serviço). Falha se a célula está ocupada, a peça não existe ou o teto vale.
func add(cell: Vector2i, piece_id: String, rotation: int = 0, owner: String = "", entity_id: int = 0, open: bool = false) -> bool:
	var def := catalog.find(piece_id)
	if def == null or _cells.has(cell) or _cells.size() >= rules.max_pieces:
		return false
	if def.max_count > 0 and count_of(piece_id) >= def.max_count:
		return false
	_cells[cell] = {"piece": piece_id, "rot": posmod(rotation, 4), "owner": owner.substr(0, MAX_OWNER_LENGTH),
			"open": open and def.toggleable, "id": maxi(entity_id, 0)}
	piece_added.emit(cell)
	return true


## Tira a peça da célula e devolve o que havia (`{}` se nada).
func remove(cell: Vector2i) -> Dictionary:
	if not _cells.has(cell):
		return {}
	var piece: Dictionary = _cells[cell]
	_cells.erase(cell)
	piece_removed.emit(cell, piece)
	return piece


## Abre ou fecha a porta da célula. Falso se não há porta ou já está assim.
func set_open(cell: Vector2i, open: bool) -> bool:
	var def := def_at(cell)
	if def == null or not def.toggleable or is_open(cell) == open:
		return false
	(_cells[cell] as Dictionary)["open"] = open
	door_changed.emit(cell)
	return true


## Guarda o id da entidade registrada na autoridade (a Bancada), para o save levar o mesmo id.
func set_entity_id(cell: Vector2i, entity_id: int) -> void:
	if _cells.has(cell):
		(_cells[cell] as Dictionary)["id"] = maxi(entity_id, 0)


func to_dict() -> Dictionary:
	var keys := _cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var pieces: Array = []
	for cell: Vector2i in keys:
		var piece: Dictionary = _cells[cell]
		var entry := {"piece": piece["piece"], "x": cell.x, "y": cell.y, "rot": piece["rot"], "owner": piece["owner"]}
		if piece["open"]:
			entry["open"] = true
		if int(piece["id"]) > 0:
			entry["id"] = piece["id"]
		pieces.append(entry)
	return {"version": FORMAT_VERSION, "pieces": pieces}


## Restaura a grade no lugar da de agora. Dado de fora: o que não vale é descartado (entrada que não é dicionário, peça
## desconhecida, célula fora da faixa, repetida, em terreno ou núcleo que não servem, acima do teto, apoiada em nada); o
## resto é saneado. Peça que precisa de apoio entra depois das que não precisam, então a ordem do arquivo não importa.
## Nunca emite evento de jogo; devolve sempre true (só sanea).
func from_dict(data: Dictionary) -> bool:
	for cell: Vector2i in _cells.keys():
		remove(cell)
	var entries: Array = []
	var seen: Dictionary = {}
	for raw: Variant in SafeRead.list(data.get("pieces")):
		var entry := _read_entry(raw)
		if entry.is_empty() or seen.has(entry["cell"]):
			continue
		if fixed_check.is_valid() and str(fixed_check.call(entry["cell"])) != "":
			continue
		seen[entry["cell"]] = true
		entries.append(entry)
	for needs_support in [false, true]:
		for entry: Dictionary in entries:
			var def := catalog.find(str(entry["piece"]))
			if def.needs_support != needs_support or (needs_support and not has_support(entry["cell"])):
				continue
			add(entry["cell"], entry["piece"], entry["rot"], entry["owner"], entry["id"], entry["open"])
	return true


## Lista de peças no formato do save para as Bancadas gravadas antes da E8a (`world.workbenches`, `{id, x, y}` em pixels).
## A posição vira a célula que a contém. Entrada ruim é ignorada; o resto passa por `from_dict`, que valida de novo.
static func pieces_from_legacy_benches(list: Array, tile_px: float) -> Array:
	var pieces: Array = []
	for raw: Variant in list:
		var data := SafeRead.dict(raw)
		var x: Variant = data.get("x")
		var y: Variant = data.get("y")
		if not _is_number(x) or not _is_number(y) or not is_finite(float(x)) or not is_finite(float(y)):
			continue
		if absf(float(x)) > MAX_CELL * tile_px or absf(float(y)) > MAX_CELL * tile_px:
			continue
		pieces.append({"piece": "workbench", "x": floori(float(x) / tile_px), "y": floori(float(y) / tile_px),
				"id": data.get("id", 0)})
	return pieces


func _read_entry(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = raw
	var piece_id := SafeRead.text(data.get("piece"), "")
	if catalog.find(piece_id) == null:
		return {}
	var x := SafeRead.integer(data.get("x"), MAX_CELL + 1, -MAX_CELL, MAX_CELL)
	var y := SafeRead.integer(data.get("y"), MAX_CELL + 1, -MAX_CELL, MAX_CELL)
	if absi(x) > MAX_CELL or absi(y) > MAX_CELL:
		return {}  # coordenada ausente, que não é número inteiro ou fora da faixa: a entrada não vale
	return {"cell": Vector2i(x, y), "piece": piece_id, "rot": posmod(SafeRead.integer(data.get("rot"), 0, -1000, 1000), 4),
			"owner": SafeRead.text(data.get("owner"), "").substr(0, MAX_OWNER_LENGTH),
			"open": SafeRead.flag(data.get("open"), false),
			# Id fora da faixa vira 0 (o próximo livre): um id no teto empurraria o contador e o próximo load seria recusado.
			"id": SafeRead.integer(data.get("id"), 0, 0, SaveMigrations.MAX_ENTITY_ID - 1)}


func _gives_support(cell: Vector2i) -> bool:
	var def := def_at(cell)
	return def != null and def.gives_support


func _has_support_without(cell: Vector2i, ignored: Vector2i) -> bool:
	var radius := rules.support_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var other := cell + Vector2i(dx, dy)
			if other != cell and other != ignored and _gives_support(other):
				return true
	return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
