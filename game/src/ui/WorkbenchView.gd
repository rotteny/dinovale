# SPDX-License-Identifier: MIT
class_name WorkbenchView
extends Node2D
## Desenho da Bancada: o sprite placeholder de 16x16 no centro do tile. Só apresentação.

const TEXTURE: Texture2D = preload("res://assets/sprites/pecas/workbench.png")


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	add_child(sprite)
