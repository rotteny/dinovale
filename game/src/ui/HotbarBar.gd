# SPDX-License-Identifier: MIT
class_name HotbarBar
extends HBoxContainer
## Barra de atalhos (GDD 5.2): nove posições, tecla no canto, ícone e quantidade (soma das
## pilhas). Sem estoque o atalho fica apagado mas atribuído. Só apresentação: lê o
## `HotbarComponent` e o inventário do jogador; quem usa a tecla é o `Player`.

const SLOT_SIZE := Vector2(26, 26)
const EMPTY_ALPHA := 0.35
const FONT_SIZE := 8
## Destaque do item em mãos: fundo e borda amarelos claros (distinto do apagado, que só some).
const EQUIPPED_FILL := Color(1.0, 0.93, 0.45, 0.55)
const EQUIPPED_BORDER := Color(1.0, 0.85, 0.1)
const EQUIPPED_BORDER_WIDTH := 2

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
		slot.toggle_mode = true
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
	player.equipped_changed.connect(func(_iid: String) -> void: refresh())
	player.inventory.changed.connect(refresh)
	player.equipment.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for i in _slots.size():
		var iid := player.hotbar.iid_at(i)
		var item_id := player.hotbar.item_at(i)
		if iid != "":
			# Individual: segue o item; apagado se saiu do inventário (o ícone vem da dica de tipo
			# da barra); o que está em mãos ganha o destaque amarelo.
			var item := player.find_item(iid)
			item_id = str(item.get("id", player.hotbar.type_at(i)))
			_slots[i].icon = ItemIcons.icon_of(item_id) if item_id != "" else null
			_counts[i].text = ""
			_slots[i].modulate.a = 1.0 if not item.is_empty() else EMPTY_ALPHA
			_mark_equipped(i, not item.is_empty() and iid == player.equipped_iid)
			continue
		var stock := player.inventory.count(item_id) if item_id != "" else 0
		_mark_equipped(i, false)
		_slots[i].icon = ItemIcons.icon_of(item_id) if item_id != "" else null
		_counts[i].text = str(stock) if item_id != "" else ""
		_slots[i].modulate.a = 1.0 if stock > 0 or item_id == "" else EMPTY_ALPHA


func slot_button(index: int) -> Button:
	return _slots[index] if index >= 0 and index < _slots.size() else null


## Quantidade mostrada na posição ("" se vazia).
func count_text(index: int) -> String:
	return _counts[index].text if index >= 0 and index < _counts.size() else ""


## Individual em mãos (célula com o destaque amarelo).
func is_equipped(index: int) -> bool:
	return index >= 0 and index < _slots.size() and _slots[index].button_pressed


## Cor de fundo do destaque da célula, ou transparente se não está em mãos (para testes).
func highlight_color(index: int) -> Color:
	if index < 0 or index >= _slots.size() or not _slots[index].has_theme_stylebox_override("normal"):
		return Color(0, 0, 0, 0)
	return (_slots[index].get_theme_stylebox("normal") as StyleBoxFlat).bg_color


func _mark_equipped(index: int, equipped: bool) -> void:
	var slot := _slots[index]
	slot.button_pressed = equipped
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		if not equipped:
			slot.remove_theme_stylebox_override(state)
			continue
		var box := StyleBoxFlat.new()
		box.bg_color = EQUIPPED_FILL
		box.set_border_width_all(EQUIPPED_BORDER_WIDTH)
		box.border_color = EQUIPPED_BORDER
		slot.add_theme_stylebox_override(state, box)


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
