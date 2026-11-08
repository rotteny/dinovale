# SPDX-License-Identifier: MIT
class_name HotbarBar
extends HBoxContainer
## Barra de atalhos (GDD 5.2): nove posições, tecla no canto, ícone e quantidade (soma das
## pilhas). Sem estoque o atalho fica apagado mas atribuído. Só apresentação: lê o
## `HotbarComponent` e o inventário do jogador; quem usa a tecla é o `Player`.

## Arrastar pede a mudança da barra; quem liga (a `Main`) a aplica. A barra só desenha e observa.
signal assign_requested(slot: int, item_id: String, iid: String)
signal swap_requested(first: int, second: int)
signal clear_requested(slot: int)
## O item arrastado não pode ir ao atalho (feedback visual já mostrado na casa).
signal assign_refused(item_id: String)

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
## Tom da casa quando o item arrastado é recusado.
const REFUSED_TINT := Color(1.0, 0.3, 0.3)
## Tipo do arraste que sai de uma casa do inventário (`InventoryScreen`).
const DRAG_INVENTORY := &"inventory"
const DRAG_HOTBAR := &"hotbar"

@export var player: Player

var _dragging: int = -1
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
		slot.mouse_filter = Control.MOUSE_FILTER_STOP  # recebe o arraste; o clique não vai ao mundo
		slot.toggle_mode = true
		slot.toggled.connect(func(_on: bool) -> void: refresh())  # o clique não muda o destaque do equipado
		slot.set_drag_forwarding(_drag_from.bind(i), _can_drop_on.bind(i), _drop_on.bind(i))
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
		DurabilityBar.attach(slot)
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
			_slots[i].modulate = Color(1, 1, 1, 1.0 if not item.is_empty() else EMPTY_ALPHA)
			_mark_equipped(i, not item.is_empty() and iid == player.equipped_iid)
			(_slots[i].get_node("Durab") as DurabilityBar).show_item(item)
			continue
		(_slots[i].get_node("Durab") as DurabilityBar).show_item({})
		var stock := player.inventory.count(item_id) if item_id != "" else 0
		_mark_equipped(i, false)
		_slots[i].icon = ItemIcons.icon_of(item_id) if item_id != "" else null
		_counts[i].text = str(stock) if item_id != "" else ""
		_slots[i].modulate = Color(1, 1, 1, 1.0 if stock > 0 or item_id == "" else EMPTY_ALPHA)


## Começa o arraste de uma casa com atalho (casa vazia não arrasta). O preview é o ícone do item.
func _drag_from(_at: Vector2, index: int) -> Variant:
	if player == null or player.hotbar.entry_at(index).is_empty():
		return null
	_dragging = index
	if get_viewport().gui_is_dragging():  # o preview só existe com um arraste de verdade
		var preview := TextureRect.new()
		preview.texture = _slots[index].icon
		preview.modulate.a = 0.8
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots[index].set_drag_preview(preview)
	return {"kind": DRAG_HOTBAR, "slot": index}


## Aceita uma casa do atalho (troca) ou um item do inventário que a regra do atalho permite; o recusado tinge a casa.
func _can_drop_on(_at: Vector2, data: Variant, index: int) -> bool:
	if not data is Dictionary:
		return false
	var kind: Variant = data.get("kind")
	if kind == DRAG_HOTBAR:
		return int(data.get("slot", -1)) != index
	if kind != DRAG_INVENTORY or not bool(data.get("from_player", false)):
		return false
	if not Items.hotbar_allowed(str(data.get("item_id", ""))):
		_slots[index].modulate = REFUSED_TINT
		assign_refused.emit(str(data.get("item_id", "")))
		return false
	return true


func _drop_on(_at: Vector2, data: Variant, index: int) -> void:
	if data.get("kind") == DRAG_HOTBAR:
		swap_requested.emit(int(data["slot"]), index)
	else:
		assign_requested.emit(index, str(data["item_id"]), str(data.get("iid", "")))
	refresh()


## Fim de qualquer arraste: se a casa do atalho foi solta fora de um destino válido, a casa é limpa.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragging >= 0 and not get_viewport().gui_is_drag_successful():
		clear_requested.emit(_dragging)
	_dragging = -1
	if player != null and not _slots.is_empty():
		refresh()


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
