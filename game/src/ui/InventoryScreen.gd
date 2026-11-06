# SPDX-License-Identifier: MIT
class_name InventoryScreen
extends Control
## Tela de inventário: o do jogador e, se houver, o da criatura (compartilhado).
## Clique, ou setas + Enter/Espaço, transfere o slot inteiro para o outro lado.
## Atalhos: com o cursor (ou o foco) sobre um item do jogador, as teclas 1 a 9 o atribuem à
## barra de atalhos; o botão direito o atribui à primeira posição livre (ou o tira, se já
## estiver). O pedido sai por `hotbar_assign_requested` (quem liga muda o `HotbarComponent`).
## Fecha com Esc, I, Tab ou E. Só apresentação: a transferência é pedida por `transfer_requested`
## (a `Main` a leva à autoridade, que valida e executa) e a regra de "quando pode abrir" fica na
## entidade (`InteractableArea.availability_changed`).

signal opened
signal closed
## Pede para atribuir `item_id` (ou o item `iid`) à posição `slot` (0 a 8) da barra; `item_id`
## "" e `iid` "" pedem para limpá-la.
## Para um item individual vai também o `iid` (a barra segue o item); senão `iid` é "".
signal hotbar_assign_requested(slot: int, item_id: String, iid: String)
## Pede para equipar o item `iid` da grade (duplo clique ou teclado) ou tirar o da vaga `slot_id`.
## Quem liga (a `Main`) pede ao `Player`, que valida; a tela não muda nada.
signal equip_requested(iid: String)
signal unequip_requested(slot_id: String)
## Pede para mover o slot `index` para o outro lado (`from_player`: do jogador para a criatura).
## A tela não muda nada; recusa volta por `show_transfer_refusal`.
signal transfer_requested(from_player: bool, index: int)

const COLUMNS := 4
const SLOT_SIZE := Vector2(84, 32)
const SLOT_FONT_SIZE := 8

@export var player_inventory: InventoryComponent
## Só leitura: marca na célula a tecla de atalho do item.
@export var hotbar: HotbarComponent
## Só leitura: o que está nas vagas de equipamento (a coluna ao lado da grade).
@export var equipment: EquipmentComponent

var is_open: bool = false
## Bloqueada (jogador morto): não abre, nem pelo atalho nem pela criatura. Quem liga é a `Main`.
var locked: bool = false

var _other: InventoryComponent = null
## O último pedido de transferência, para dizer por que foi recusado.
var _asked_slot: Dictionary = {}
var _asked_destination: InventoryComponent = null
var _source: InteractableArea = null
var _title := Label.new()
var _player_grid := GridContainer.new()
var _other_column := VBoxContainer.new()
var _other_title := Label.new()
var _other_grid := GridContainer.new()
var _player_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []
var _hover_index := -1
var _equipment_column := VBoxContainer.new()
var _equipment_buttons: Dictionary = {}
var _notice := Label.new()


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
	row.add_child(_equipment_column)
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

	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_notice)
	var hint := Label.new()
	hint.text = "Clique ou Enter: transferir   1-9 ou botão direito: atalho   Esc/I/E: fechar\n" \
			+ "Equipamento: duplo clique ou Enter equipa (na vaga, tira)   Shift+clique: transferir equipamento"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	for label: Label in [_title, player_title, _other_title, hint, _notice]:
		label.add_theme_color_override("font_color", UiTheme.INK)


## Abre o inventário próprio sozinho (ação `inventory`).
func open_own() -> void:
	if player_inventory != null and not locked:
		open_with(player_inventory, null, null, "")


## Abre o inventário do jogador ao lado de `other` (pode ser null). `source` é a área
## cuja disponibilidade mantém a tela aberta: se ela ficar indisponível, fecha.
func open_with(own: InventoryComponent, other: InventoryComponent, source: InteractableArea,
		title: String) -> void:
	if locked:
		return
	if is_open:
		close()
	player_inventory = own
	_other = other
	_source = source
	_other_title.text = title
	_other_column.visible = other != null
	_title.text = "Inventário" if other == null else "Inventário compartilhado"
	_build_equipment()
	_build_buttons(_player_grid, _player_buttons, own, true)
	_build_buttons(_other_grid, _other_buttons, other, false)
	own.changed.connect(_refresh)
	if hotbar != null:
		hotbar.changed.connect(_refresh)
	if equipment != null:
		equipment.changed.connect(_refresh)
	if other != null:
		other.changed.connect(_refresh)
	if source != null:
		source.availability_changed.connect(_on_availability_changed)
		source.tree_exiting.connect(close)
	_notice.text = ""
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
	if equipment != null and equipment.changed.is_connected(_refresh):
		equipment.changed.disconnect(_refresh)
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
## Sem item sob o cursor, a tecla só limpa um atalho ÓRFÃO (de item individual que saiu do
## inventário): é o jeito de tirá-lo da barra, já que ele não aparece em nenhuma célula.
func assign_to_hotbar(index: int, hotbar_slot: int) -> void:
	if not is_open or player_inventory == null:
		return
	var slot := player_inventory.get_slot(index)
	if not slot.is_empty():
		hotbar_assign_requested.emit(hotbar_slot, slot["id"], str(slot.get("iid", "")))
	elif hotbar != null and hotbar.iid_at(hotbar_slot) != "" and not _owns(hotbar.iid_at(hotbar_slot)):
		hotbar_assign_requested.emit(hotbar_slot, "", "")


## Botão direito: leva o item à primeira posição livre; se já está na barra, tira.
func toggle_hotbar(index: int) -> void:
	if not is_open or hotbar == null or player_inventory == null:
		return
	var slot := player_inventory.get_slot(index)
	if slot.is_empty():
		return
	var iid := str(slot.get("iid", ""))
	var current := hotbar.slot_of_iid(iid) if iid != "" else hotbar.slot_of(slot["id"])
	if current >= 0:
		hotbar_assign_requested.emit(current, "", "")
	elif hotbar.first_free() >= 0:
		hotbar_assign_requested.emit(hotbar.first_free(), slot["id"], iid)


## O item está na grade do jogador ou numa vaga de equipamento (atalho válido).
func _owns(iid: String) -> bool:
	return player_inventory.has_iid(iid) or (equipment != null and equipment.has_iid(iid))


## Aviso da recusa de equipar (vem do `Player`). Vaga errada recusa sem mensagem (GDD 5.20).
func show_refusal(reason: String) -> void:
	var message := EquipmentComponent.refusal_message(reason)
	if message != "":
		_notice.text = message


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
	_refresh_equipment()
	_refresh_buttons(_player_buttons, player_inventory)
	_refresh_buttons(_other_buttons, _other)


## Coluna de vagas: só as `shown` (no M1, a Arma). Vazia mostra o nome da vaga como silhueta.
func _build_equipment() -> void:
	for old in _equipment_column.get_children():
		_equipment_column.remove_child(old)
		old.queue_free()
	_equipment_buttons.clear()
	_equipment_column.visible = equipment != null
	if equipment == null:
		return
	var title := Label.new()
	title.text = "Equipado"
	title.add_theme_color_override("font_color", UiTheme.INK)
	_equipment_column.add_child(title)
	for def in equipment.layout.shown_slots():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
		button.gui_input.connect(_on_equipment_gui_input.bind(def.id))
		_equipment_column.add_child(button)
		_equipment_buttons[def.id] = button


func _refresh_equipment() -> void:
	if equipment == null:
		return
	for slot_id: String in _equipment_buttons:
		var button: Button = _equipment_buttons[slot_id]
		var item := equipment.item_in(slot_id)
		if item.is_empty():
			button.text = "(%s)" % equipment.layout.slot_def(slot_id).display_name
			button.icon = null
			button.modulate.a = 0.55
		else:
			button.text = "%s\n%d/%d" % [Items.display_name(item["id"]), item["durab"], item["durab_max"]]
			button.icon = ItemIcons.icon_of(item["id"])
			button.modulate.a = 1.0


## Botão da vaga (para testes). null se a vaga não está visível.
func equipment_button(slot_id: String) -> Button:
	return _equipment_buttons.get(slot_id) as Button


## Duplo clique ou Enter/Espaço na vaga: pede para tirar o item para a grade.
func _on_equipment_gui_input(event: InputEvent, slot_id: String) -> void:
	if _is_activation(event):
		unequip_requested.emit(slot_id)
		accept_event()


## Duplo clique esquerdo ou Enter/Espaço (ação de aceitar do teclado).
func _is_activation(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click
	return event.is_action_pressed("ui_accept") and not event.is_echo()


func _refresh_buttons(buttons: Array[Button], inventory: InventoryComponent) -> void:
	for i in buttons.size():
		var slot := inventory.get_slot(i)
		var swatch: ColorRect = buttons[i].get_node("Swatch")
		if slot.is_empty():
			buttons[i].text = ""
			buttons[i].icon = null
			swatch.visible = false
		else:
			var key := -1
			if hotbar != null and buttons == _player_buttons:
				key = hotbar.slot_of_iid(slot["iid"]) if slot.has("iid") else hotbar.slot_of(slot["id"])
			var tag := "[%d] " % (key + 1) if key >= 0 else ""
			var detail := "%d/%d" % [slot["durab"], slot["durab_max"]] if slot.has("iid") else "x%d" % slot["count"]
			buttons[i].text = "%s\n%s%s" % [Items.display_name(slot["id"]), tag, detail]
			var icon := ItemIcons.icon_of(slot["id"])
			buttons[i].icon = icon
			swatch.color = Items.color_of(slot["id"])
			swatch.visible = icon == null


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if _is_activation(event):
		var slot := player_inventory.get_slot(index)
		if slot.has("iid") and Items.slot_of(slot["id"]) != "":
			equip_requested.emit(slot["iid"])
			accept_event()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		toggle_hotbar(index)
		accept_event()


func _on_slot_pressed(from_player: bool, index: int) -> void:
	_transfer(from_player, index, Input.is_key_pressed(KEY_SHIFT))


## Transfere o slot para o outro lado. Equipamento que o destino aceita só vai com Shift: o clique
## simples é o primeiro de um duplo clique (equipar) e não pode mover o item antes.
func _transfer(from_player: bool, index: int, forced: bool) -> void:
	if _other == null:
		return
	var source := player_inventory if from_player else _other
	var destination := _other if from_player else player_inventory
	var slot := source.get_slot(index)
	if not forced and slot.has("iid") and Items.slot_of(slot["id"]) != "" and destination.accepts_individual:
		_notice.text = "Duplo clique equipa; Shift+clique transfere o equipamento."
		return
	_notice.text = ""
	_asked_slot = slot
	_asked_destination = destination
	transfer_requested.emit(from_player, index)


## A autoridade negou o último pedido de transferência: mostra o motivo certo para o `result`. Recusa
## de regra (`REFUSED`: não vai para a criatura, sem espaço) usa o item pedido.
func show_transfer_refusal(result: Enums.ActionResult = Enums.ActionResult.REFUSED) -> void:
	match result:
		Enums.ActionResult.OUT_OF_RANGE:
			_notice.text = "Longe demais."
		Enums.ActionResult.NOT_OWNER:
			_notice.text = "Essa criatura é de outro."
		Enums.ActionResult.WRONG_STATE, Enums.ActionResult.INVALID_TARGET, Enums.ActionResult.UNKNOWN_TARGET:
			_notice.text = "A criatura não aceita isso agora."
		Enums.ActionResult.REFUSED:
			if not _asked_slot.is_empty() and _asked_destination != null:
				_notice.text = _refusal_text(_asked_slot, _asked_destination)
		_:
			_notice.text = "Não deu."


## Por que o item não foi: equipamento recusado pelo destino, ou sem espaço.
func _refusal_text(slot: Dictionary, destination: InventoryComponent) -> String:
	if Items.is_individual(slot["id"]) and not destination.accepts_individual:
		return "%s não vai para a criatura." % Items.display_name(slot["id"])
	return "Sem espaço para %s." % Items.display_name(slot["id"])


## Texto do aviso atual ("" = sem aviso).
func notice_text() -> String:
	return _notice.text


func _on_availability_changed(available: bool) -> void:
	if not available:
		close()
