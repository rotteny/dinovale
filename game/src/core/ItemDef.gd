# SPDX-License-Identifier: MIT
class_name ItemDef
extends RefCounted
## Definição mínima de um item: dado puro, sem cena nem sprite.

var id: String
var display_name: String
var max_stack: int
## Cor placeholder usada pela UI até existir arte.
var color: Color


func _init(p_id: String, p_name: String, p_max_stack: int, p_color: Color) -> void:
	id = p_id
	display_name = p_name
	max_stack = maxi(p_max_stack, 1)
	color = p_color
