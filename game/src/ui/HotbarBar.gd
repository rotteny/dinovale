# SPDX-License-Identifier: MIT
class_name HotbarBar
extends HBoxContainer
## Barra de atalhos (GDD 5.2): nove posições, tecla no canto, ícone e quantidade (soma das
## pilhas). Sem estoque o atalho fica apagado mas atribuído. Só apresentação: lê o
## `HotbarComponent` e o inventário do jogador; quem usa a tecla é o `Player`.

const SLOT_SIZE := Vector2(26, 26)
const EMPTY_ALPHA := 0.35
const FONT_SIZE := 8

@export var player: Player

var _slots: Array[Button] = []
var _keys: Array[Label] = []
var _counts: Array[Label] = []


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in HotbarComponent.SLOT_COUNT:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.expand_icon = false
		var key := _corner_label(str(i + 1), Control.PRESET_TOP_LEFT, Vector2(3, 0))
		var count := _corner_label("", Control.PRESET_TOP_LEFT, Vector2.ZERO)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.offset_right = -2.0
		count.offset_bottom = 3.0
		slot.add_child(key)
		slot.add_child(count)
		add_child(slot)
		_slots.append(slot)
		_keys.append(key)
		_counts.append(count)
	if player == null:
		return
	player.hotbar.changed.connect(refresh)
	player.inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for i in _slots.size():
		var item_id := player.hotbar.item_at(i)
		var stock := player.inventory.count(item_id) if item_id != "" else 0
		_slots[i].icon = ItemIcons.icon_of(item_id) if item_id != "" else null
		_counts[i].text = str(stock) if item_id != "" else ""
		_slots[i].modulate.a = 1.0 if stock > 0 or item_id == "" else EMPTY_ALPHA


func slot_button(index: int) -> Button:
	return _slots[index] if index >= 0 and index < _slots.size() else null


## Quantidade mostrada na posição ("" se vazia).
func count_text(index: int) -> String:
	return _counts[index].text if index >= 0 and index < _counts.size() else ""


## Atribuído mas sem estoque.
func is_dimmed(index: int) -> bool:
	return index >= 0 and index < _slots.size() and _slots[index].modulate.a < 1.0


func _corner_label(text: String, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	label.position += offset
	return label
