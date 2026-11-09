# SPDX-License-Identifier: MIT
class_name BuildPiece
extends Node2D
## Uma peça construída no mundo (E8a): fundação, parede ou porta. Posição no centro da célula e, se a peça é sólida, um
## corpo estático que bloqueia o passo (a porta aberta o desliga). Sem regra de construção (é da `BuildGrid` e do
## `BuildService`) e sem desenho (o `BuildPieceView` desenha). A Bancada continua sendo o `Workbench`.

## A porta abriu ou fechou (a vista troca o quadro).
signal open_changed(open: bool)

## Camada de colisão do terreno e do jogador (a máscara dos dinos e do jogador inclui a 1).
const BODY_LAYER := 1

var piece_id: String = ""
var rotation_steps: int = 0
var is_open: bool = false

var _shape: CollisionShape2D = null


## Monta a peça: `tile_px` é o lado do corpo (célula inteira: parede e porta fecham o vão).
func setup(def: PieceDef, steps: int, open: bool, tile_px: float) -> void:
	piece_id = def.id
	rotation_steps = posmod(steps, 4)
	if def.blocks_body:
		var body := StaticBody2D.new()
		body.collision_layer = BODY_LAYER
		body.collision_mask = 0
		_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tile_px, tile_px)
		_shape.shape = rect
		body.add_child(_shape)
		add_child(body)
	set_open(open)


## Abre ou fecha: aberta, a peça deixa de ter colisão.
func set_open(open: bool) -> void:
	is_open = open
	if _shape != null:
		_shape.set_deferred("disabled", open)
	open_changed.emit(open)
