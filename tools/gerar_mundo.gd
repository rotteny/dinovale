# SPDX-License-Identifier: MIT
extends SceneTree
## Gera o mapa da Main a partir do pacote Ninja Adventure (CC0): o TileSet
## `game/src/world/world_tiles.tres` e a cena `game/src/world/Terrain.tscn`
## (grama, caminho, miudezas, árvores com colisão no tronco, folhagem nas bordas,
## casa e baú decorativos). É determinístico: rodar de novo produz o mesmo mapa.
## Coordenadas e recortes vêm de `assets/third_party/ninja-adventure/MAPA.md`.
##
## Uso, da raiz do repositório:
##   godot --headless --path game --script ../tools/gerar_mundo.gd
## Depois: godot --headless --path game --import

const NINJA := "res://assets/third_party/ninja-adventure/"
const TILES_PATH := "res://src/world/world_tiles.tres"
const TERRAIN_PATH := "res://src/world/Terrain.tscn"
const SIZE := Vector2i(40, 23)
const SRC_FLOOR := 0
const SRC_NATURE := 1

const GRASS := Vector2i(0, 12)
const GRASS_VARIANTS: Array[Vector2i] = [Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12),
		Vector2i(2, 11), Vector2i(3, 11)]
const TUFTS: Array[Vector2i] = [Vector2i(3, 10), Vector2i(4, 10), Vector2i(5, 10), Vector2i(7, 10)]
const FLOWERS: Array[Vector2i] = [Vector2i(0, 11), Vector2i(1, 11), Vector2i(3, 11), Vector2i(6, 11)]
const ROCKS: Array[Vector2i] = [Vector2i(17, 13), Vector2i(18, 13), Vector2i(19, 13)]
const BUSHES: Array[Vector2i] = [Vector2i(1, 10), Vector2i(2, 10)]
const TREE := Vector2i(3, 18)
const FOLIAGE := Vector2i(4, 2)
const TREE_CELLS: Array[Vector2i] = [Vector2i(5, 4), Vector2i(14, 2), Vector2i(8, 13), Vector2i(30, 12),
		Vector2i(34, 6), Vector2i(17, 6)]
const TREE_SHIFT := Vector2(-16, -16)
const FOLIAGE_SHIFT := Vector2(-24, -16)
const HOUSE_BASE := Vector2(424.0, 101.0)
const CHEST_BASE := Vector2(470.0, 102.0)

var _occupied := {}
var _path := {}


func _init() -> void:
	var tileset := _make_tileset()
	ResourceSaver.save(tileset, TILES_PATH)
	tileset = load(TILES_PATH)
	_save_terrain(tileset)
	print("mundo gerado: ", TILES_PATH, " e ", TERRAIN_PATH)
	quit()


func _hash(x: int, y: int) -> int:
	return int(absf(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453)) % 100


func _make_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer()
	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = load(NINJA + "tilesets/tileset_floor.png")
	floor_source.texture_region_size = Vector2i(16, 16)
	var floor_tiles: Array[Vector2i] = [GRASS, Vector2i(1, 8)]
	floor_tiles.append_array(GRASS_VARIANTS)
	for column in 4:
		for row in 4:
			floor_tiles.append(Vector2i(column, 7 + row))
	floor_tiles.append_array([Vector2i(5, 8), Vector2i(6, 8), Vector2i(5, 9), Vector2i(6, 9)])
	for coords in floor_tiles:
		if not floor_source.has_tile(coords):
			floor_source.create_tile(coords)
	tileset.add_source(floor_source, SRC_FLOOR)

	var nature := TileSetAtlasSource.new()
	nature.texture = load(NINJA + "tilesets/tileset_nature.png")
	nature.texture_region_size = Vector2i(16, 16)
	for coords in TUFTS + FLOWERS + ROCKS + BUSHES:
		if not nature.has_tile(coords):
			nature.create_tile(coords)
	nature.create_tile(TREE, Vector2i(3, 3))
	nature.create_tile(FOLIAGE, Vector2i(4, 3))
	tileset.add_source(nature, SRC_NATURE)
	# Tiles de várias células são desenhados centrados na célula âncora; o deslocamento
	# alinha o canto superior esquerdo da arte com o da célula.
	var trunk := nature.get_tile_data(TREE, 0)
	trunk.texture_origin = Vector2i(TREE_SHIFT)
	nature.get_tile_data(FOLIAGE, 0).texture_origin = Vector2i(FOLIAGE_SHIFT)
	# Colisão só no tronco (48x48: tronco em x 19..29, y 34..44 da arte), relativa
	# ao centro da célula âncora.
	trunk.add_collision_polygon(0)
	trunk.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(11, 26), Vector2(21, 26), Vector2(21, 36), Vector2(11, 36)]))
	# Ordem de profundidade pela base do tronco.
	trunk.y_sort_origin = 36
	return tileset


func _layer(layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	return layer


func _save_terrain(tileset: TileSet) -> void:
	var root := Node2D.new()
	root.name = "Terrain"
	root.y_sort_enabled = true
	var ground := _layer("Ground", tileset)
	ground.z_index = -10
	var decor := _layer("Decor", tileset)
	decor.z_index = -9
	var trees := _layer("Trees", tileset)
	trees.y_sort_enabled = true
	var foliage := _layer("Foliage", tileset)
	foliage.z_index = 5
	for node: Node in [ground, decor, trees, foliage]:
		root.add_child(node)
	_build_path()
	_fill_ground(ground)
	_place_foliage(foliage)
	_place_trees(trees)
	_place_decor(decor)
	_place_house(root)
	_place_chest(root)
	_own_all(root, root)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, TERRAIN_PATH)


func _own_all(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			_own_all(child, owner_node)


func _build_path() -> void:
	for x in range(0, 27):
		for y in [17, 18]:
			_path[Vector2i(x, y)] = true
	for x in [25, 26]:
		for y in range(6, 19):
			_path[Vector2i(x, y)] = true


func _dirt_tile(cell: Vector2i) -> Vector2i:
	var n := _path.has(cell + Vector2i(0, -1))
	var s := _path.has(cell + Vector2i(0, 1))
	var w := _path.has(cell + Vector2i(-1, 0))
	var e := _path.has(cell + Vector2i(1, 0))
	if not w and not e:
		if n and s:
			return Vector2i(3, 8)
		if s:
			return Vector2i(3, 7)
		if n:
			return Vector2i(3, 9)
		return Vector2i(3, 10)
	if not n and not s:
		if w and e:
			return Vector2i(1, 10)
		return Vector2i(0, 10) if e else Vector2i(2, 10)
	if n and s and w and e:
		if not _path.has(cell + Vector2i(1, 1)):
			return Vector2i(5, 8)
		if not _path.has(cell + Vector2i(-1, 1)):
			return Vector2i(6, 8)
		if not _path.has(cell + Vector2i(1, -1)):
			return Vector2i(5, 9)
		if not _path.has(cell + Vector2i(-1, -1)):
			return Vector2i(6, 9)
		return Vector2i(1, 8)
	var column := 1
	if not w:
		column = 0
	elif not e:
		column = 2
	var row := 1
	if not n:
		row = 0
	elif not s:
		row = 2
	return Vector2i(column, 7 + row)


func _fill_ground(ground: TileMapLayer) -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var coords := GRASS
			var h := _hash(x, y)
			if h < 14:
				coords = GRASS_VARIANTS[h % GRASS_VARIANTS.size()]
			if _path.has(cell):
				coords = _dirt_tile(cell)
			ground.set_cell(cell, SRC_FLOOR, coords)


func _free_block(origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			if _occupied.has(origin + Vector2i(x, y)):
				return false
	return true


func _occupy(origin: Vector2i, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			_occupied[origin + Vector2i(x, y)] = true


func _try_foliage(layer: TileMapLayer, origin: Vector2i) -> void:
	if _free_block(origin, Vector2i(4, 3)):
		layer.set_cell(origin, SRC_NATURE, FOLIAGE)
		_occupy(origin, Vector2i(4, 3))


func _place_foliage(layer: TileMapLayer) -> void:
	# Casa e baú reservam seu espaço antes das bordas.
	_occupy(Vector2i(24, 1), Vector2i(5, 6))
	_occupy(Vector2i(28, 5), Vector2i(2, 2))
	var row := -1
	while row < SIZE.y:
		_try_foliage(layer, Vector2i(-2 if (row / 3) % 2 == 0 else -3, row))
		_try_foliage(layer, Vector2i(38 if (row / 3) % 2 == 0 else 37, row))
		row += 3
	for x in range(2, 37, 4):
		_try_foliage(layer, Vector2i(x, -1))
		_try_foliage(layer, Vector2i(x, 21))


func _place_trees(layer: TileMapLayer) -> void:
	for cell in TREE_CELLS:
		if _free_block(cell, Vector2i(3, 3)):
			layer.set_cell(cell, SRC_NATURE, TREE)
			_occupy(cell, Vector2i(3, 3))


func _place_decor(layer: TileMapLayer) -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			if _occupied.has(cell) or _path.has(cell) or _path.has(cell + Vector2i(0, 1)):
				continue
			var roll := _hash(x * 3 + 1, y * 7 + 2)
			if roll >= 16:
				continue
			var pick := _hash(x + 5, y + 9)
			var coords: Vector2i
			if roll < 6:
				coords = TUFTS[pick % TUFTS.size()]
			elif roll < 11:
				coords = FLOWERS[pick % FLOWERS.size()]
			elif roll < 14:
				coords = ROCKS[pick % ROCKS.size()]
			else:
				coords = BUSHES[pick % BUSHES.size()]
			layer.set_cell(cell, SRC_NATURE, coords)


func _sprite(texture_path: String, region: Rect2, sprite_offset: Vector2, sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = load(texture_path)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.offset = sprite_offset
	return sprite


func _place_house(root: Node2D) -> void:
	var house := Node2D.new()
	house.name = "House"
	house.position = HOUSE_BASE
	var texture := NINJA + "tilesets/tileset_house.png"
	house.add_child(_sprite(texture, Rect2(400, 112, 64, 48), Vector2(-32, -81), "Roof"))
	house.add_child(_sprite(texture, Rect2(400, 191, 64, 33), Vector2(-32, -33), "Front"))
	# Só a base da parede bloqueia: o telhado é visual.
	var body := StaticBody2D.new()
	body.name = "Walls"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 18)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	body.add_child(shape)
	house.add_child(body)
	root.add_child(house)


func _place_chest(root: Node2D) -> void:
	var chest := _sprite(NINJA + "items/chest_small.png", Rect2(0, 0, 16, 16), Vector2(-8, -16), "Chest")
	chest.position = CHEST_BASE
	root.add_child(chest)
