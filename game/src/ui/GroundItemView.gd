# SPDX-License-Identifier: MIT
class_name GroundItemView
extends Node2D
## Desenho do item no chão: o ícone com uma sombra pequena e um pulinho ao cair; com o mouse por cima, o nome e a
## quantidade. Só observa o `GroundItem`; não decide nada.

const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.3)
const SHADOW_RADIUS := Vector2(5.0, 2.0)
const HOP_HEIGHT := 6.0
const HOP_SECONDS := 0.25
const HOVER_RADIUS := 9.0
const FONT_SIZE := 8
const LABEL_WIDTH := 80.0

@export var item: GroundItem

var _icon: Sprite2D = null  # criados no `_ready`: fora da árvore o nó não cria filhos soltos (vazaria)
var _label: Label = null


func _ready() -> void:
	_icon = Sprite2D.new()
	_label = Label.new()
	_icon.texture = ItemIcons.icon_of(item.item_id)
	_icon.position = Vector2(0, -6)
	add_child(_icon)
	_label.theme = UiTheme.get_theme()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size.x = LABEL_WIDTH
	_label.position = Vector2(-LABEL_WIDTH * 0.5, -26)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.visible = false
	add_child(_label)
	item.changed.connect(_refresh)
	_refresh()
	var tween := create_tween()  # pulinho ao cair
	tween.tween_property(_icon, "position:y", -6.0 - HOP_HEIGHT, HOP_SECONDS * 0.5)
	tween.tween_property(_icon, "position:y", -6.0, HOP_SECONDS * 0.5)
	queue_redraw()


func _process(_delta: float) -> void:
	if _label != null:
		_label.visible = get_local_mouse_position().length() <= HOVER_RADIUS


## Texto do rótulo ("Madeira x3").
func label_text() -> String:
	return _label.text if _label != null else ""


func _refresh() -> void:
	_label.text = item.label_text()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SHADOW_RADIUS.y / SHADOW_RADIUS.x))
	draw_circle(Vector2.ZERO, SHADOW_RADIUS.x, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	if _icon.texture == null:  # sem ícone: um quadrado na cor do item
		draw_rect(Rect2(Vector2(-4, -10), Vector2(8, 8)), Items.color_of(item.item_id))
