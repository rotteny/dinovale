# SPDX-License-Identifier: MIT
class_name CorpseView
extends Node2D
## Desenho do corpo do jogador no chão (`corpo.png`: corpo com a trouxa de itens e um brilho de 2 quadros) e, com o mouse
## por cima, quantos itens guarda. Só observa o `PlayerCorpse`; não decide nada.

const HOVER_RADIUS := 14.0
const FONT_SIZE := 8
const LABEL_WIDTH := 90.0

@export var corpse: PlayerCorpse

var _label: Label = null
var _sprite := Sprite2D.new()
var _fps: float = BodyArt.fps("corpo.png", "brilho", BodyArt.DEFAULT_CORPSE_FPS)
var _time := 0.0


func _ready() -> void:
	_sprite.texture = BodyArt.CORPSE_TEXTURE
	_sprite.offset = BodyArt.ANCHOR_OFFSET
	_sprite.hframes = BodyArt.FRAMES
	add_child(_sprite)
	_label = Label.new()
	_label.theme = UiTheme.get_theme()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size.x = LABEL_WIDTH
	_label.position = Vector2(-LABEL_WIDTH * 0.5, -36)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.visible = false
	add_child(_label)
	if corpse != null:
		corpse.changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_sprite.frame = BodyArt.frame_at(_time, _fps)
	if _label != null:
		_label.visible = get_local_mouse_position().distance_to(BodyArt.ANCHOR_OFFSET) <= HOVER_RADIUS


## Texto do rótulo ("Seus itens x5").
func label_text() -> String:
	return _label.text if _label != null else ""


func _refresh() -> void:
	if _label != null and corpse != null:
		_label.text = "Seus itens x%d" % corpse.item_count()
