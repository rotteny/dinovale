# SPDX-License-Identifier: MIT
class_name ResourceNodeView
extends Node2D
## Desenho do nó de recurso: o sprite do tipo (cheio ou esgotado), com os pés na origem do nó e a ordem de
## profundidade pelo Y do nó. Sem textura no tipo, cai num volume na cor dele. Só observa o nó; não decide nada.

@export var node: ResourceNode

var _sprite: Sprite2D = null


func _ready() -> void:
	if not node.is_node_ready():  # o componente do nó só existe depois do _ready dele
		await node.ready
	if node.def != null and node.def.texture != null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		add_child(_sprite)
	node.component.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _sprite == null:
		queue_redraw()
		return
	var texture := node.def.texture if node.is_available() or node.def.texture_depleted == null else node.def.texture_depleted
	_sprite.texture = texture
	var size := texture.get_size()
	_sprite.offset = Vector2(-size.x * 0.5, -size.y)  # pés (base, centro) na origem do nó


func _draw() -> void:
	if _sprite != null or node.def == null:
		return
	var full := node.is_available()
	var color := node.def.color if full else Color(node.def.color, 0.3)
	var size := 10.0 if full else 5.0
	draw_circle(Vector2(0, -size * 0.6), size, color)
	draw_arc(Vector2(0, -size * 0.6), size, 0.0, TAU, 16, Color(0, 0, 0, 0.6 if full else 0.2), 1.0)
