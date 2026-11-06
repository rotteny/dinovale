# SPDX-License-Identifier: MIT
class_name TerrainView
extends Node2D
## Desenha o mapa estático: 6 camadas de terreno (água funda, rasa, praia e os três biomas, em autotile de
## costa) e a camada de cenário em tiles grandes (árvore decorativa e formações), com ordem de profundidade
## pelo Y. Só apresentação e física dos tiles: o que está longe da câmera o `TileMapLayer` já não desenha
## (quadrantes), e a colisão fica só no anel de 2 tiles de água funda e nos pés do cenário.
## Não há borda a desenhar além do mapa: a câmera para no limite e há 12 tiles de mar dentro dele.

@export var rules: WorldRules = preload("res://data/world/world_rules.tres")

var map: IslandMap
var ground_layers: Array[TileMapLayer] = []
var scenery_layer: TileMapLayer


func _ready() -> void:
	if map == null:
		map = IslandMap.default_map()
	build()


## Monta as camadas (uma vez). Mapa inválido não monta nada.
func build() -> void:
	if not ground_layers.is_empty() or map == null or not map.is_valid():
		return
	var ground_set := TerrainTiles.ground_tile_set()
	var data := TerrainTiles.ground_layers(map)
	for rank in TerrainTiles.LAYER_COUNT:
		var layer := TileMapLayer.new()
		layer.name = "Ground%d" % rank
		layer.z_index = -10
		layer.tile_set = ground_set
		layer.physics_quadrant_size = 16
		layer.tile_map_data = data[rank]
		add_child(layer)
		ground_layers.append(layer)
	scenery_layer = TileMapLayer.new()
	scenery_layer.name = "Scenery"
	scenery_layer.y_sort_enabled = true
	scenery_layer.tile_set = TerrainTiles.scenery_tile_set(rules)
	scenery_layer.physics_quadrant_size = 16
	scenery_layer.tile_map_data = TerrainTiles.scenery_layer(map, rules)
	add_child(scenery_layer)
