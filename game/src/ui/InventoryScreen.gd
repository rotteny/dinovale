# SPDX-License-Identifier: MIT
class_name InventoryScreen
extends Control
## Tela de inventário: o do jogador e, se houver, o da criatura (compartilhado).
## Clique, ou setas + Enter/Espaço, transfere o slot inteiro para o outro lado.
## Atalhos: com o cursor (ou o foco) sobre um item do jogador, as teclas 1 a 9 o atribuem à
## barra de atalhos; o botão direito o atribui à primeira posição livre (ou o tira, se já
## estiver). O pedido sai por `hotbar_assign_requested` (quem liga muda o `HotbarComponent`).
## Fecha com Esc, I, Tab ou E. Só apresentação: a transferência é a do `InventoryComponent`
## e a regra de "quando pode abrir" fica na entidade (`InteractableArea.availability_changed`).

signal opened
signal closed
## Pede para atribuir `item_id` à posição `slot` (0 a 8) da barra; "" pede para limpá-la.
signal hotbar_assign_requested(slot: int, item_id: String)

const COLUMNS := 4
const SLOT_SIZE := Vector2(72, 32)
const SLOT_FONT_SIZE := 8

@export var player_inventory: InventoryComponent
## Só leitura: marca na célula a tecla de atalho do item.
@export var hotbar: HotbarComponent

var is_open: bool = false

var _other: InventoryComponent = null
var _source: InteractableArea = null
var _title := Label.new()
var _player_grid := GridContainer.new()
var _other_column := VBoxContainer.new()
var _other_title := Label.new()
var _other_grid := GridContainer.new()
var _player_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []
var _hover_index := -1


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	_title.text = "Inventário"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var player_column := VBoxContainer.new()
	var player_title := Label.new()
	player_title.text = "Jogador"
	player_column.add_child(player_title)
	player_column.add_child(_player_grid)
	row.add_child(player_column)
	_other_column.add_child(_other_title)
	_other_column.add_child(_other_grid)
	row.add_child(_other_column)
	for grid in [_player_grid, _other_grid]:
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)

	var hint := Label.new()
	hint.text = "Clique ou Enter: transferir   1-9 ou botão direito: atalho   Esc/I/E: fechar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	for label: Label in [_title, player_title, _other_title, hint]:
		label.add_theme_color_override("font_color", UiTheme.INK)


## Abre o inventário próprio sozinho (ação `inventory`).
func open_own() -> void:
	if player_inventory != null:
		open_with(player_inventory, null, null, "")


## Abre o inventário do jogador ao lado de `other` (pode ser null). `source` é a área
## cuja disponibilidade mantém a tela aberta: se ela ficar indisponível, fecha.
func open_with(own: InventoryComponent, other: InventoryComponent, source: InteractableArea,
		title: String) -> void:
	if is_open:
		close()
	player_inventory = own
	_other = other
	_source = source
	_other_title.text = title
	_other_column.visible = other != null
	_title.text = "Inventário" if other == null else "Inventário compartilhado"
	_build_buttons(_player_grid, _player_buttons, own, true)
	_build_buttons(_other_grid, _other_buttons, other, false)
	own.changed.connect(_refresh)
	if hotbar != null:
		hotbar.changed.connect(_refresh)
	if other != null:
		other.changed.connect(_refresh)
	if source != null:
		source.availability_changed.connect(_on_availability_changed)
		source.tree_exiting.connect(close)
	_refresh()
	is_open = true
	visible = true
	if not _player_buttons.is_empty():
		_player_buttons[0].grab_focus()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if player_inventory != null and player_inventory.changed.is_connected(_refresh):
		player_inventory.changed.disconnect(_refresh)
	if hotbar != null and hotbar.changed.is_connected(_refresh):
		hotbar.changed.disconnect(_refresh)
	_hover_index = -1
	if _other != null and is_instance_valid(_other) and _other.changed.is_connected(_refresh):
		_other.changed.disconnect(_refresh)
	if _source != null and is_instance_valid(_source):
		if _source.availability_changed.is_connected(_on_availability_changed):
			_source.availability_changed.disconnect(_on_availability_changed)
		if _source.tree_exiting.is_connected(close):
			_source.tree_exiting.disconnect(close)
	_other = null
	_source = null
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null:
		focused.release_focus()
	closed.emit()


## Botão de um slot (para testes e navegação). null se não existir.
func slot_button(from_player: bool, index: int) -> Button:
	var buttons := _player_buttons if from_player else _other_buttons
	return buttons[index] if index >= 0 and index < buttons.size() else null


## Índice do slot do jogador sob o cursor ou com o foco; -1 se nenhum.
func cursor_slot() -> int:
	if _hover_index >= 0:
		return _hover_index
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return _player_buttons.find(focused) if focused != null else -1


## Atribui o item do slot do jogador `index` à posição `hotbar_slot` da barra.
func assign_to_hotbar(index: int, hotbar_slot: int) -> void:
	if not is_open or player_inventory == null or index < 0 or index >= _player_buttons.size():
		return
	var slot := player_inventory.get_slot(index)
	if not slot.is_empty():
		hotbar_assign_requested.emit(hotbar_slot, slot["id"])


## Botão direito: leva o item à primeira posição livre; se já está na barra, tira.
func toggle_hotbar(index: int) -> void:
	if not is_open or hotbar == null or player_inventory == null:
		return
	var slot := player_inventory.get_slot(index)
	if slot.is_empty():
		return
	var current := hotbar.slot_of(slot["id"])
	if current >= 0:
		hotbar_assign_requested.emit(current, "")
	elif hotbar.first_free() >= 0:
		hotbar_assign_requested.emit(hotbar.first_free(), slot["id"])


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		for number in HotbarComponent.SLOT_COUNT:
			if event.is_action_pressed("hotbar_%d" % (number + 1)):
				assign_to_hotbar(cursor_slot(), number)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("inventory") and not is_open:
		open_own()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("inventory") or event.is_action_pressed("interact")
			or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _build_buttons(grid: GridContainer, buttons: Array[Button], inventory: InventoryComponent,
		from_player: bool) -> void:
	for old in grid.get_children():
		grid.remove_child(old)
		old.queue_free()
	buttons.clear()
	if inventory == null:
		return
	for i in inventory.slot_count():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
		button.pressed.connect(_on_slot_pressed.bind(from_player, i))
		if from_player:
			button.mouse_entered.connect(func() -> void: _hover_index = i)
			button.mouse_exited.connect(func() -> void: _hover_index = -1 if _hover_index == i else _hover_index)
			button.gui_input.connect(_on_slot_gui_input.bind(i))
		var swatch := ColorRect.new()
		swatch.size = Vector2(6, 6)
		swatch.position = Vector2(3, 3)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.name = "Swatch"
		button.add_child(swatch)
		grid.add_child(button)
		buttons.append(button)


func _refresh() -> void:
	_refresh_buttons(_player_buttons, player_inventory)
	_refresh_buttons(_other_buttons, _other)


func _refresh_buttons(buttons: Array[Button], inventory: InventoryComponent) -> void:
	for i in buttons.size():
		var slot := inventory.get_slot(i)
		var swatch: ColorRect = buttons[i].get_node("Swatch")
		if slot.is_empty():
			buttons[i].text = ""
			buttons[i].icon = null
			swatch.visible = false
		else:
			var key := hotbar.slot_of(slot["id"]) if hotbar != null and buttons == _player_buttons else -1
			var tag := "[%d] " % (key + 1) if key >= 0 else ""
			buttons[i].text = "%s%s\nx%d" % [tag, Items.display_name(slot["id"]), slot["count"]]
			var icon := ItemIcons.icon_of(slot["id"])
			buttons[i].icon = icon
			swatch.color = Items.color_of(slot["id"])
			swatch.visible = icon == null


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		toggle_hotbar(index)
		accept_event()


func _on_slot_pressed(from_player: bool, index: int) -> void:
	if _other == null:
		return
	if from_player:
		player_inventory.transfer_slot(index, _other)
	else:
		_other.transfer_slot(index, player_inventory)


func _on_availability_changed(available: bool) -> void:
	if not available:
		close()
