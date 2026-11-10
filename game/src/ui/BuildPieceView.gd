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

## Peças da base (E12) sem arte pronta: desenhadas por código, em formas simples de 16 px, até o ART-09 do `YATORA`.
const DRAWN: Array[String] = ["campfire", "sleeping_bag", "bed"]
const STONE_COLOR := Color(0.55, 0.55, 0.6)
const LOG_COLOR := Color(0.4, 0.26, 0.14)
const FLAME_COLOR := Color(1.0, 0.62, 0.15)
const FLAME_CORE := Color(1.0, 0.9, 0.4)
const FRAME_COLOR := Color(0.5, 0.34, 0.18)
const BLANKET_COLOR := Color(0.72, 0.38, 0.36)
const BAG_COLOR := Color(0.45, 0.5, 0.7)
const PILLOW_COLOR := Color(0.93, 0.92, 0.88)

var piece: BuildPiece = null

var _sprite := Sprite2D.new()
var _time: float = 0.0


func _ready() -> void:
	add_child(_sprite)
	set_process(piece != null and piece.piece_id == "campfire")
	_sprite.rotation = float(piece.rotation_steps) * PI * 0.5
	piece.open_changed.connect(_show)
	_show(piece.is_open)


## Textura da peça `piece_id` (aberta ou fechada), ou null se não tem desenho. O ghost usa a mesma.
static func texture_for(piece_id: String, open: bool = false) -> Texture2D:
	return TEXTURES.get(piece_id + "_open" if open else piece_id)


func _show(open: bool) -> void:
	_sprite.texture = texture_for(piece.piece_id, open)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta  # só a Fogueira: a chama oscila
	queue_redraw()


func _draw() -> void:
	if piece == null or not DRAWN.has(piece.piece_id):
		return
	match piece.piece_id:
		"campfire":
			_draw_campfire()
		"sleeping_bag":
			draw_rect(Rect2(-4.0, -7.0, 8.0, 14.0), BAG_COLOR)
			draw_rect(Rect2(-3.0, -6.0, 6.0, 3.0), PILLOW_COLOR)
		"bed":
			draw_rect(Rect2(-7.0, -8.0, 14.0, 16.0), FRAME_COLOR)
			draw_rect(Rect2(-6.0, -4.0, 12.0, 11.0), BLANKET_COLOR)
			draw_rect(Rect2(-5.0, -7.0, 10.0, 3.0), PILLOW_COLOR)


func _draw_campfire() -> void:
	for step in 6:
		var angle := float(step) * TAU / 6.0
		draw_circle(Vector2(cos(angle), sin(angle)) * 6.0, 1.6, STONE_COLOR)
	draw_line(Vector2(-4.0, 3.0), Vector2(4.0, -1.0), LOG_COLOR, 2.0)
	draw_line(Vector2(-4.0, -1.0), Vector2(4.0, 3.0), LOG_COLOR, 2.0)
	var lift := 1.0 + sin(_time * 9.0) * 0.8
	draw_colored_polygon(PackedVector2Array([Vector2(-3.0, 1.0), Vector2(0.0, -6.0 - lift), Vector2(3.0, 1.0)]), FLAME_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(-1.5, 1.0), Vector2(0.0, -3.0 - lift * 0.5), Vector2(1.5, 1.0)]), FLAME_CORE)
