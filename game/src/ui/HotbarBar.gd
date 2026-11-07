# SPDX-License-Identifier: MIT
class_name HotbarBar
extends HBoxContainer
## Barra de atalhos (GDD 5.2): nove posições, tecla no canto, ícone e quantidade (soma das
## pilhas). Sem estoque o atalho fica apagado mas atribuído. Só apresentação: lê o
## `HotbarComponent` e o inventário do jogador; quem usa a tecla é o `Player`.

## Célula do tamanho do ícone do pacote (16x16): nove atalhos ocupam 152x16 px dos 320x180.
const SLOT_SIZE := Vector2(16, 16)
const SLOT_GAP := 1
const SLOT_FILL := Color(0.0, 0.0, 0.0, 0.45)
const SLOT_BORDER := Color(0.0, 0.0, 0.0, 0.8)
const OUTLINE_SIZE := 2  # a Vale Mini em 8 px não desenha contorno de 1 px (arredonda para 0)
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
	theme = slot_theme()
	add_theme_constant_override("separation", SLOT_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in HotbarComponent.SLOT_COUNT:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.toggle_mode = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.expand_icon = false
		slot.clip_contents = true
		var key := _corner_label(str(i + 1))
		key.offset_left = 1.0
		key.offset_top = -1.0
		var count := _corner_label("")
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.offset_right = -1.0
		count.offset_bottom = 1.0
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


## Tema das células: fundo escuro translúcido de 1 px, sem a moldura de madeira do tema da UI (que come
## 3 px de cada lado de uma célula de 16). É um tema do container, então as células não levam
## override próprio: só a que está em mãos ganha o destaque.
static func slot_theme() -> Theme:
	var slot_theme := Theme.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = SLOT_FILL if state != "focus" else Color(0, 0, 0, 0)
		box.set_border_width_all(1)
		box.border_color = SLOT_BORDER
		box.set_content_margin_all(0)
		slot_theme.set_stylebox(state, "Button", box)
	slot_theme.set_constant("h_separation", "Button", 0)
	return slot_theme


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


## Etiqueta de canto: ancorada no canto, com o tamanho do próprio texto (nada de `MINSIZE` antes de o
## rótulo entrar na árvore, que mediria com a fonte padrão da engine).
func _corner_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	return label
