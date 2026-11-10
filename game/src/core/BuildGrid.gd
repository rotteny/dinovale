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
## `from_dict` vai trocar a grade inteira (começou) e já trocou (terminou): quem ouve peça a peça pode juntar o trabalho em um lote
## só (a navegação refaz as grades de busca uma vez, não a cada uma das milhares de peças). Também são sinais de vista.
signal load_started
signal load_finished

const FORMAT_VERSION := 1
## Célula além disto é dado ruim (o mapa tem 256, mas o save é de fora: o teto só evita número absurdo).
const MAX_CELL := 100000
const MAX_OWNER_LENGTH := 64
## Teto do instante `ready_at` lido de um save (segundos de jogo, como `WorldSnapshot.MAX_TIME`).
const MAX_READY_AT := 1.0e12

var catalog: PieceCatalog = PieceCatalog.with_defaults()
var rules: BuildRules = preload("res://data/balance/build_rules.tres")
## Confere o que não muda com o tempo (terreno e núcleo seguro): `(cell: Vector2i) -> String`, "" = serve. O `from_dict` o usa
## para descartar peça de save editado. Sem ele, vale tudo.
var fixed_check: Callable = Callable()

## Itens de peça (a Bancada) que a MIGRAÇÃO de um save antigo não conseguiu pôr no grid (terreno, núcleo, célula ocupada, teto):
## item -> quantidade, refeito a cada `from_dict`. Quem carrega os devolve ao jogador, para nenhuma Bancada sumir.
var unplaced_items: Dictionary = {}
## Item devolvido -> id da peça (para conferir o teto de peças do tipo ao fim da carga).
var _unplaced_piece: Dictionary = {}

var _cells: Dictionary[Vector2i, Dictionary] = {}
## Conteúdo das peças que guardam coisas (Baú): um inventário por célula, criado com a peça e liberado com ela. É a fonte da
## verdade do conteúdo: o nó do mundo só aponta para ele, e o save o leva junto da peça. Fica fora da árvore (sem `_process`).
var _boxes: Dictionary[Vector2i, InventoryComponent] = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for box: InventoryComponent in _boxes.values():
			if is_instance_valid(box):
				box.free()
		_boxes.clear()


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


## Quantas peças de `piece_id` existem; com `owner_id`, só as postas por esse dono (o limite por jogador da Cama e do Saco).
func count_of(piece_id: String, owner_id: String = "") -> int:
	var total := 0
	for cell: Vector2i in _cells:
		var piece: Dictionary = _cells[cell]
		if piece["piece"] == piece_id and (owner_id == "" or piece["owner"] == owner_id):
			total += 1
	return total


## Instante do relógio do mundo em que a peça (a Cama) pode ser usada de novo; 0 = livre. Só o `RespawnPointService` o escreve.
func ready_at(cell: Vector2i) -> float:
	return float((_cells[cell] as Dictionary).get("ready_at", 0.0)) if _cells.has(cell) else 0.0


func set_ready_at(cell: Vector2i, instant: float) -> void:
	if _cells.has(cell):
		(_cells[cell] as Dictionary)["ready_at"] = maxf(instant, 0.0)


## A célula tem corpo sólido agora? (parede, porta fechada, Bancada)
func blocks(cell: Vector2i) -> bool:
	var def := def_at(cell)
	return def != null and def.blocks_body and not is_open(cell)


## O inventário da peça de `cell` (Baú), ou null se ela não guarda nada.
func container_at(cell: Vector2i) -> InventoryComponent:
	return _boxes.get(cell)


## Há parede (peça sólida agora) no caminho reto de `from` a `to` (pixels do mundo)? A célula de quem está em cada ponta
## não conta: quem está colado na parede continua do lado dela. A mordida do bravo passa por aqui: golpe não atravessa parede.
func segment_blocked(from: Vector2, to: Vector2) -> bool:
	var line := GridLine.cells(from, to, rules.tile_px)
	for index in range(1, line.size() - 1):
		if blocks(line[index]):
			return true
	return false


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
	if def.container_slots > 0:
		var box := InventoryComponent.new()
		box.capacity = def.container_slots
		box.iid_prefix = "c"
		_boxes[cell] = box
	piece_added.emit(cell)
	return true


## Tira a peça da célula e devolve o que havia (`{}` se nada).
func remove(cell: Vector2i) -> Dictionary:
	if not _cells.has(cell):
		return {}
	var piece: Dictionary = _cells[cell]
	_cells.erase(cell)
	piece_removed.emit(cell, piece)
	var box: InventoryComponent = _boxes.get(cell)
	if box != null:  # depois do sinal: quem ouvia ainda lê o conteúdo; o serviço já tirou o que devia largar
		_boxes.erase(cell)
		box.free()
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
		if float(piece.get("ready_at", 0.0)) > 0.0:
			entry["ready_at"] = piece["ready_at"]  # espera da Cama (instante do relógio do mundo, ADR-006; ausente = livre)
		var box: InventoryComponent = _boxes.get(cell)
		if box != null and not box.is_empty():
			entry["items"] = box.to_dict()
		pieces.append(entry)
	return {"version": FORMAT_VERSION, "pieces": pieces}


## A `version` do bloco é a que este código entende? (ausente vale: bloco montado pela migração da Bancada antiga.)
static func version_ok(data: Dictionary) -> bool:
	return SafeRead.format_version(data, FORMAT_VERSION) != 0


## Restaura a grade no lugar da de agora. Dado de fora: o que não vale é descartado (entrada que não é dicionário, peça
## desconhecida, célula fora da faixa, repetida, em terreno ou núcleo que não servem, acima do teto, apoiada em nada); o
## resto é saneado. Peça que precisa de apoio entra depois das que não precisam, então a ordem do arquivo não importa.
## Nunca emite evento de jogo. Devolve false (e NADA muda) só quando a `version` do bloco é inválida ou maior que a conhecida;
## fora isso devolve true (só sanea). Quem carrega confere `version_ok` antes de tocar no resto do save.
func from_dict(data: Dictionary) -> bool:
	if not version_ok(data):
		return false  # versão de outro formato: nada é aplicado (a grade de agora fica como está)
	load_started.emit()
	for cell: Vector2i in _cells.keys():
		remove(cell)
	unplaced_items = {}
	_unplaced_piece = {}
	var legacy := SafeRead.flag(data.get("legacy_benches"), false)
	var entries: Array = []
	var seen: Dictionary = {}
	for raw: Variant in SafeRead.list(data.get("pieces")):
		var entry := _read_entry(raw)
		if entry.is_empty():
			continue
		if seen.has(entry["cell"]) or (fixed_check.is_valid() and str(fixed_check.call(entry["cell"])) != ""):
			_note_unplaced(entry, legacy)
			continue
		seen[entry["cell"]] = true
		entries.append(entry)
	var owned: Dictionary = {}  # "peça|dono" -> quantas já entraram (o limite por jogador também vale na carga)
	for needs_support in [false, true]:
		for entry: Dictionary in entries:
			var def := catalog.find(str(entry["piece"]))
			if def.needs_support != needs_support or (needs_support and not has_support(entry["cell"])):
				continue
			var owner_key := "%s|%s" % [def.id, entry["owner"]]
			if def.max_per_owner > 0 and int(owned.get(owner_key, 0)) >= def.max_per_owner:
				_note_unplaced(entry, legacy)  # excedente do dono: fica de fora, o da frente do arquivo vale (determinístico)
				continue
			if add(entry["cell"], entry["piece"], entry["rot"], entry["owner"], entry["id"], entry["open"]):
				owned[owner_key] = int(owned.get(owner_key, 0)) + 1
				set_ready_at(entry["cell"], entry["ready_at"])
				_load_contents(entry["cell"], entry["items"])
			else:
				_note_unplaced(entry, legacy)
	_cap_unplaced()
	load_finished.emit()
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
			"open": SafeRead.flag(data.get("open"), false), "items": SafeRead.dict(data.get("items")),
			"ready_at": SafeRead.number(data.get("ready_at"), 0.0, 0.0, MAX_READY_AT),  # campo novo: save antigo = livre
			# Id fora da faixa vira 0 (o próximo livre): um id no teto empurraria o contador e o próximo load seria recusado.
			"id": SafeRead.integer(data.get("id"), 0, 0, SaveMigrations.MAX_ENTITY_ID - 1)}


## Peça de item (Bancada) que a migração não pôde pôr: conta para ser devolvida. O teto de peças do tipo é conferido no fim da
## carga (`_cap_unplaced`), quando já se sabe quantas ficaram postas.
func _note_unplaced(entry: Dictionary, legacy: bool) -> void:
	var def := catalog.find(str(entry["piece"]))
	if not legacy or def == null or def.item_id == "":
		return
	unplaced_items[def.item_id] = int(unplaced_items.get(def.item_id, 0)) + 1
	_unplaced_piece[def.item_id] = def.id


## Um save não rende mais Bancadas do que o mundo comporta: postas + devolvidas <= `max_count` do tipo.
func _cap_unplaced() -> void:
	for item_id: String in unplaced_items.keys():
		var def := catalog.find(str(_unplaced_piece.get(item_id, "")))
		if def == null or def.max_count <= 0:
			continue
		var kept := mini(int(unplaced_items[item_id]), maxi(def.max_count - count_of(def.id), 0))
		if kept > 0:
			unplaced_items[item_id] = kept
		else:
			unplaced_items.erase(item_id)


## O conteúdo gravado vai para o inventário da peça. Dado de fora: o que o inventário recusa (formato ruim, item que não
## cabe) deixa o Baú vazio, e a peça fica; nunca aborta a carga da grade.
func _load_contents(cell: Vector2i, items: Dictionary) -> void:
	var box: InventoryComponent = _boxes.get(cell)
	if box != null and not items.is_empty():
		box.from_dict(items)


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
