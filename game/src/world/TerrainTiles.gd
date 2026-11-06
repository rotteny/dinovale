# SPDX-License-Identifier: MIT
class_name TerrainTiles
extends RefCounted
## Monta o desenho do mapa estático para o `TileMapLayer`: o `TileSet` do terreno (a folha `terreno.png` com o
## `terreno.json`), as camadas de terreno em autotile de costa e o `TileSet` do cenário (árvore decorativa e
## formações, tiles grandes com colisão só nos pés). Só calcula; quem põe nas camadas é o `TerrainView`.
##
## Camadas por posto (rank): 0 água funda (base), 1 rasa, 2 praia, 3 Campina, 4 Mata-baixa, 5 Pedreira. A camada R
## leva um tile em todo tile do mapa de posto >= R, escolhido pela máscara de 8 bits dos vizinhos de posto >= R
## (N=1 NE=2 L=4 SE=8 S=16 SO=32 O=64 NO=128; diagonal só com as duas arestas), com o FORA transparente. Um tile
## de miolo (máscara 255) que fica sob outro miolo é pulado: ninguém o vê, e são dezenas de milhares de tiles.
## O resultado é guardado por execução (o dado não muda): o título e a partida pagam a conta uma vez só.

const ATLAS: Texture2D = preload("res://assets/sprites/cenario/terreno.png")
const SHEET_PATH := "res://assets/sprites/cenario/terreno.json"
const TILE := 16
const LAYER_COUNT := 6
const FULL_MASK := 255
## Alternativa do tile de água funda COM colisão (o anel de 2 tiles junto ao raso). A 0 não colide.
const RING_ALTERNATIVE := 1
## Terreno do `IslandMap` -> posto da camada.
const RANK_OF_TERRAIN: Array[int] = [0, 1, 2, 3, 4, 5, 0]
## Bytes por célula no formato `tile_map_data` (x, y, fonte, atlas x, atlas y, alternativa; 6 x 16 bits).
const CELL_BYTES := 12

static var _ground_set: TileSet = null
static var _scenery_set: TileSet = null
static var _lut: Array = []
static var _layers_cache: Array[PackedByteArray] = []
static var _layers_key: String = ""


## `TileSet` do terreno: uma fonte (a folha inteira, 16x25 tiles) e a camada de física do anel de água funda.
static func ground_tile_set() -> TileSet:
	if _ground_set != null:
		return _ground_set
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var texture: Texture2D = ATLAS
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	var columns := int(texture.get_width()) / TILE
	var rows := int(texture.get_height()) / TILE
	for row in rows:
		for column in columns:
			source.create_tile(Vector2i(column, row))
	tile_set.add_source(source, 0)  # a fonte entra antes: só assim o dado dos tiles ganha a camada de física
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for column in columns:  # a linha 0 são as variações cheias da água funda: ganham a versão com colisão
		var coords := Vector2i(column, 0)
		source.create_alternative_tile(coords, RING_ALTERNATIVE)
		var data := source.get_tile_data(coords, RING_ALTERNATIVE)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
	_ground_set = tile_set
	return tile_set


## `TileSet` do cenário: uma fonte por `SceneryDef` (o índice na lista de `rules` é o id da fonte), cada uma com
## UM tile do tamanho da imagem. A origem do tile é o PÉ do desenho (o centro da célula) e a colisão só ali.
static func scenery_tile_set(rules: WorldRules) -> TileSet:
	if _scenery_set != null:
		return _scenery_set
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	for index in rules.scenery.size():
		var def := rules.scenery[index]
		var size := def.texture.get_size()
		var source := TileSetAtlasSource.new()
		source.texture = def.texture
		source.texture_region_size = Vector2i(TILE, TILE)
		var span := Vector2i(ceili(size.x / TILE), ceili(size.y / TILE))
		source.create_tile(Vector2i.ZERO, span)
		tile_set.add_source(source, index)
		var data := source.get_tile_data(Vector2i.ZERO, 0)
		# O motor desenha a imagem centrada na célula, deslocada por `texture_origin` (para cima e para a
		# esquerda): com h/2 de origem a BASE da imagem cai no centro da célula, que é onde ficam os pés.
		data.texture_origin = Vector2(0.0, size.y * 0.5)
		if def.foot_size != Vector2.ZERO:
			var half := def.foot_size.x * 0.5
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-half, -def.foot_size.y), Vector2(half, -def.foot_size.y), Vector2(half, 0.0), Vector2(-half, 0.0)]))
	_scenery_set = tile_set
	return tile_set


## Bytes de `tile_map_data` das 6 camadas de terreno (índice = posto). Guardado por revisão do mapa.
static func ground_layers(map: IslandMap) -> Array[PackedByteArray]:
	var key := "%s:%d" % [map.map_id, map.revision]
	if _layers_key == key:
		return _layers_cache
	_layers_cache = _compute_layers(map)
	_layers_key = key
	return _layers_cache


## Bytes de `tile_map_data` do cenário, na ordem de `rules.scenery`.
static func scenery_layer(map: IslandMap, rules: WorldRules) -> PackedByteArray:
	var entries := PackedInt32Array()
	for index in rules.scenery.size():
		var cells: Array = map.scenery.get(rules.scenery[index].id, [])
		for cell: Vector2i in cells:
			entries.append_array([cell.x, cell.y, index, 0, 0, 0])
	return _pack(entries)


## Tile (coluna e linha na folha) do posto `rank` com a máscara `mask`; (-1, -1) se a folha não tem.
static func tile_for(rank: int, mask: int) -> Vector2i:
	_load_lut()
	if rank < 1 or rank >= _lut.size():
		return Vector2i(-1, -1)
	var packed: int = (_lut[rank] as PackedInt32Array)[mask]
	return Vector2i(-1, -1) if packed < 0 else Vector2i(packed & 0xFF, packed >> 8)


## Máscara de 8 bits do tile `index` do mapa preenchido (com borda de 1) para o posto `rank`.
static func mask_of(ranks: PackedByteArray, index: int, row_stride: int, rank: int) -> int:
	var north := ranks[index - row_stride] >= rank
	var east := ranks[index + 1] >= rank
	var south := ranks[index + row_stride] >= rank
	var west := ranks[index - 1] >= rank
	var mask := (1 if north else 0) | (4 if east else 0) | (16 if south else 0) | (64 if west else 0)
	if north and east and ranks[index - row_stride + 1] >= rank:
		mask |= 2
	if east and south and ranks[index + row_stride + 1] >= rank:
		mask |= 8
	if south and west and ranks[index + row_stride - 1] >= rank:
		mask |= 32
	if west and north and ranks[index - row_stride - 1] >= rank:
		mask |= 128
	return mask


static func _compute_layers(map: IslandMap) -> Array[PackedByteArray]:
	_load_lut()
	var side := map.size
	var stride := side + 2
	var ranks := PackedByteArray()
	ranks.resize(stride * stride)  # a borda de 1 tile é mar (posto 0)
	for y in side:
		for x in side:
			ranks[(y + 1) * stride + x + 1] = RANK_OF_TERRAIN[map.terrain_at(Vector2i(x, y))]
	var covered := PackedByteArray()
	covered.resize(stride * stride)
	var result: Array[PackedByteArray] = []
	result.resize(LAYER_COUNT)
	for rank in range(LAYER_COUNT - 1, -1, -1):  # de cima para baixo: o miolo de cima esconde o de baixo
		var entries := PackedInt32Array()
		var lut: PackedInt32Array = _lut[rank] if rank >= 1 else PackedInt32Array()
		var newly_covered := PackedInt32Array()
		for y in side:
			for x in side:
				var index := (y + 1) * stride + x + 1
				var own := ranks[index]
				if own < rank:
					continue
				var mask := mask_of(ranks, index, stride, rank) if rank >= 1 else FULL_MASK
				if covered[index] == 0:
					var variant := _variant(x, y)
					var alternative := 0
					var atlas_x := variant
					var atlas_y := rank
					if mask != FULL_MASK:
						var packed := lut[mask]
						atlas_x = packed & 0xFF
						atlas_y = packed >> 8
					elif rank == 0 and map.has_ring_collision(Vector2i(x, y)):
						alternative = RING_ALTERNATIVE
					entries.append_array([x, y, 0, atlas_x, atlas_y, alternative])
				if mask == FULL_MASK and own >= rank:
					newly_covered.append(index)
		for index in newly_covered:
			covered[index] = 1
		result[rank] = _pack(entries)
	return result


## Variação cheia da célula: 9 em cada 10 lisas (colunas 0 a 7), as outras com detalhe (8 a 15); fixa por tile.
static func _variant(x: int, y: int) -> int:
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
	var plain := (h >> 4) % 8
	return plain + 8 if h % 10 == 0 else plain


static func _load_lut() -> void:
	if not _lut.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_PATH))
	var sets := SafeRead.dict(SafeRead.dict(parsed).get("conjuntos"))
	var names := SafeRead.list(SafeRead.dict(parsed).get("terrenos"))
	_lut.resize(LAYER_COUNT)
	_lut[0] = PackedInt32Array()
	for rank in range(1, LAYER_COUNT):
		var table := PackedInt32Array()
		table.resize(256)
		table.fill(-1)
		var entry := SafeRead.dict(sets.get(SafeRead.text(names[rank], "")))
		var by_mask := SafeRead.dict(entry.get("mascara_para_tile"))
		for key: Variant in by_mask:
			var pair := SafeRead.list(by_mask[key])
			var mask := int(str(key))
			if pair.size() == 2 and mask >= 0 and mask < 256:
				table[mask] = SafeRead.integer(pair[0], 0, 0, 255) | (SafeRead.integer(pair[1], 0, 0, 255) << 8)
		_lut[rank] = table


static func _pack(entries: PackedInt32Array) -> PackedByteArray:
	var count := entries.size() / 6
	var data := PackedByteArray()
	data.resize(2 + count * CELL_BYTES)
	data.encode_u16(0, 0)  # versão do formato de `tile_map_data`
	var offset := 2
	for i in count:
		var base := i * 6
		data.encode_s16(offset, entries[base])
		data.encode_s16(offset + 2, entries[base + 1])
		data.encode_u16(offset + 4, entries[base + 2])
		data.encode_u16(offset + 6, entries[base + 3])
		data.encode_u16(offset + 8, entries[base + 4])
		data.encode_u16(offset + 10, entries[base + 5])
		offset += CELL_BYTES
	return data
