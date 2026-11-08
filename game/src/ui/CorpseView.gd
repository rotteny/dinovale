# SPDX-License-Identifier: MIT
class_name CorpseView
extends Node2D
## Desenho do corpo do jogador no chão: um montinho escuro com sombra e, com o mouse por cima, quantos itens guarda. É um
## desenho provisório feito em código (sem arte nova); a arte definitiva do corpo fica para a passada de arte da v0.2.
## Só observa o `PlayerCorpse`; não decide nada.

const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.3)
const MOUND_COLOR := Color("#4a3a32")
const MOUND_LIGHT := Color("#6b5648")
const MARK_COLOR := Color("#e8d9a0")
const HOVER_RADIUS := 12.0
const FONT_SIZE := 8
const LABEL_WIDTH := 90.0

@export var corpse: PlayerCorpse

var _label: Label = null


func _ready() -> void:
	_label = Label.new()
	_label.theme = UiTheme.get_theme()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size.x = LABEL_WIDTH
	_label.position = Vector2(-LABEL_WIDTH * 0.5, -22)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.visible = false
	add_child(_label)
	if corpse != null:
		corpse.changed.connect(_refresh)
	_refresh()
	queue_redraw()


func _process(_delta: float) -> void:
	if _label != null:
		_label.visible = get_local_mouse_position().length() <= HOVER_RADIUS


## Texto do rótulo ("Seus itens x5").
func label_text() -> String:
	return _label.text if _label != null else ""


func _refresh() -> void:
	if _label != null and corpse != null:
		_label.text = "Seus itens x%d" % corpse.item_count()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var mound := PackedVector2Array([Vector2(-7, 0), Vector2(-5, -5), Vector2(5, -5), Vector2(7, 0), Vector2(3, 2), Vector2(-3, 2)])
	draw_colored_polygon(mound, MOUND_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(-3, -7), Vector2(3, -7), Vector2(5, -5)]), MOUND_LIGHT)
	draw_line(Vector2(0, -12), Vector2(0, -6), MARK_COLOR, 1.0)  # marca: um graveto fincado
	draw_line(Vector2(-2, -10), Vector2(2, -10), MARK_COLOR, 1.0)
