# SPDX-License-Identifier: MIT
class_name Workbench
extends Node2D
## Bancada colocada no mundo (E7a): entidade simples com id da autoridade, posição no centro do tile e um corpo que
## bloqueia o passo. Sem lógica de fabricação (ela é da `WorldAuthority`) e sem desenho (o `WorkbenchView` desenha).
## Migra para o `BuildGrid` na E8a.

## Lado do corpo de colisão, em pixels (um pouco menor que o tile, para não prender a quem passa rente).
const BODY_SIZE := Vector2(14.0, 10.0)


func _init() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
