# SPDX-License-Identifier: MIT
class_name BuildPieceView
extends Node2D
## Desenho de uma peça construída (E8a): o sprite placeholder de 16x16 no centro da célula, girado pela rotação; a porta
## troca de quadro ao abrir. Só apresentação: ouve `BuildPiece.open_changed`.

const TEXTURES: Dictionary[String, Texture2D] = {
	"foundation": preload("res://assets/sprites/pecas/foundation.png"),
	"wall": preload("res://assets/sprites/pecas/wall.png"),
	"door": preload("res://assets/sprites/pecas/door_closed.png"),
	"chest": preload("res://assets/sprites/pecas/chest.png"),
	"door_open": preload("res://assets/sprites/pecas/door_open.png"),
}

var piece: BuildPiece = null

var _sprite := Sprite2D.new()


func _ready() -> void:
	add_child(_sprite)
	_sprite.rotation = float(piece.rotation_steps) * PI * 0.5
	piece.open_changed.connect(_show)
	_show(piece.is_open)


## Textura da peça `piece_id` (aberta ou fechada), ou null se não tem desenho. O ghost usa a mesma.
static func texture_for(piece_id: String, open: bool = false) -> Texture2D:
	return TEXTURES.get(piece_id + "_open" if open else piece_id)


func _show(open: bool) -> void:
	_sprite.texture = texture_for(piece.piece_id, open)
