# SPDX-License-Identifier: MIT
class_name BuildField
extends Node2D
## Põe o que a `BuildGrid` guarda no mundo (E8a): um `BuildPiece` (corpo e vista) por fundação, parede e porta, e um
## `Workbench` (entidade registrada na autoridade) por Bancada, e um `Chest` (também
## registrado) por Baú. Só reage aos sinais da grade; quem decide é o
## `BuildService`. A Bancada migrou para o grid: este campo ocupa o lugar do antigo `WorkbenchField`, e o save dela agora
## é o da grade (o `Workbench` volta ao mesmo id porque a grade o guarda).

## Uma Bancada entrou ou saiu do mundo (o cursor e os testes ouvem).
signal bench_placed(bench: Workbench)
signal bench_removed(bench: Workbench)

var authority: WorldAuthority = null
var grid: BuildGrid = null
var tile_px: float = 16.0

var _nodes: Dictionary[Vector2i, Node2D] = {}


## Liga ao grid e cria o que já houver nele.
func attach(source: BuildGrid, tile: float) -> void:
	grid = source
	tile_px = tile
	grid.piece_added.connect(_on_added)
	grid.piece_removed.connect(_on_removed)
	grid.door_changed.connect(_on_door_changed)
	for cell in grid.cells():
		_on_added(cell)


func benches() -> Array[Workbench]:
	var list: Array[Workbench] = []
	for node in _nodes.values():
		if node is Workbench:
			list.append(node)
	return list


func count_benches() -> int:
	return benches().size()


## A Bancada na célula, ou null.
func bench_in(cell: Vector2i) -> Workbench:
	return _nodes.get(cell) as Workbench


## A Bancada mais próxima de `origin` dentro de `reach` pixels, ou null.
func nearest_workbench(origin: Vector2, reach: float) -> Workbench:
	var best: Workbench = null
	var best_distance := reach
	for bench in benches():
		var distance := origin.distance_to(bench.global_position)
		if distance <= best_distance:
			best = bench
			best_distance = distance
	return best


func _on_added(cell: Vector2i) -> void:
	var def := grid.def_at(cell)
	if def == null or _nodes.has(cell):
		return
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * tile_px
	if def.item_id == Items.WORKBENCH:
		var bench := Workbench.new()
		bench.position = center
		add_child(bench)
		_nodes[cell] = bench
		bench.add_child(WorkbenchView.new())
		bench_placed.emit(bench)
		if authority != null:
			var saved_id := int(grid.piece_at(cell).get("id", 0))
			var entity_id := authority.register(bench, saved_id)
			if entity_id == 0:
				entity_id = authority.register(bench)
			grid.set_entity_id(cell, entity_id)
		return
	var piece: BuildPiece = Chest.new() if def.container_slots > 0 else BuildPiece.new()
	piece.position = center
	piece.setup(def, int(grid.piece_at(cell).get("rot", 0)), grid.is_open(cell), tile_px)
	add_child(piece)
	_nodes[cell] = piece
	var view := BuildPieceView.new()
	view.piece = piece
	piece.add_child(view)
	var chest := piece as Chest
	if chest != null:
		chest.attach_box(grid.container_at(cell))
		_register_chest(cell, chest)


## O Baú entra no registro da autoridade (o id vem da grade, para o save levar o mesmo; id tomado = o próximo livre).
func _register_chest(cell: Vector2i, chest: Chest) -> void:
	if authority == null:
		return
	var entity_id := authority.register(chest, int(grid.piece_at(cell).get("id", 0)))
	if entity_id == 0:
		entity_id = authority.register(chest)
	grid.set_entity_id(cell, entity_id)


func _on_removed(cell: Vector2i, _piece: Dictionary) -> void:
	var node: Node2D = _nodes.get(cell)
	if node == null:
		return
	_nodes.erase(cell)
	var chest := node as Chest
	if chest != null and authority != null:
		authority.unregister(authority.id_of(chest))
	var bench := node as Workbench
	if bench != null:
		bench_removed.emit(bench)
		if authority != null:
			authority.unregister(authority.id_of(bench))
	node.queue_free()


func _on_door_changed(cell: Vector2i) -> void:
	var piece := _nodes.get(cell) as BuildPiece
	if piece != null:
		piece.set_open(grid.is_open(cell))
