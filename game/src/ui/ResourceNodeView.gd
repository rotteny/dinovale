# SPDX-License-Identifier: MIT
class_name ResourceNodeView
extends Node2D
## Desenho provisório do nó de recurso até existir arte: um volume na cor do tipo, apagado e menor
## enquanto esgotado. Só observa o nó; não decide nada.

@export var node: ResourceNode


func _ready() -> void:
	if not node.is_node_ready():  # o componente do nó só existe depois do _ready dele
		await node.ready
	node.component.changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var def := node.def
	if def == null:
		return
	var full := node.is_available()
	var color := def.color if full else Color(def.color, 0.3)
	var size := 10.0 if full else 5.0
	draw_circle(Vector2(0, -size * 0.6), size, color)
	draw_arc(Vector2(0, -size * 0.6), size, 0.0, TAU, 16, Color(0, 0, 0, 0.6 if full else 0.2), 1.0)
