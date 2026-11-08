# SPDX-License-Identifier: MIT
class_name MenuColumn
extends VBoxContainer
## Coluna de botões de menu (`Button` de verdade, variação `MenuItemButton` do `UiTheme`). A seleção é de
## `MenuNavigation` (lógica pura) e acompanha o foco do botão: mouse (hover foca, clique ativa), setas
## (`handle_event`) e Tab/direcional do controle (foco nativo) levam ao mesmo lugar. Enter/Espaço ativam.
## Botão desabilitado não recebe foco nem clique. Quem usa chama `handle_event` no seu `_input` e escuta `activated(id)`.

signal activated(id: String)

## Linha do menu para o viewport de 320x180 (a arte do botão pede altura mínima de 20).
const ROW_SIZE := Vector2(108, 20)

var navigation := MenuNavigation.new()
var _ids: Array[String] = []
var _buttons: Array[Button] = []


func _init() -> void:
	add_theme_constant_override("separation", 2)


## Monta os itens `{id, label, enabled?}`.
func setup(items: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ids.clear()
	_buttons.clear()
	navigation.set_items(items)
	for i in items.size():
		var button := Button.new()
		button.theme_type_variation = UiTheme.MENU_BUTTON
		button.text = str(items[i]["label"])
		button.custom_minimum_size = ROW_SIZE
		button.mouse_entered.connect(_on_hover.bind(i))
		button.focus_entered.connect(_on_focus.bind(i))
		button.pressed.connect(_on_pressed.bind(i))
		add_child(button)
		_ids.append(str(items[i]["id"]))
		_buttons.append(button)
		_apply_enabled(i)


## Seleciona o primeiro item habilitado e leva o foco a ele (abrir ou reabrir um menu).
func reset_selection() -> void:
	navigation.reset()
	focus_selected()


## Foca o botão selecionado. Sem efeito enquanto a coluna não está visível na árvore.
func focus_selected() -> void:
	var i := navigation.index()
	if i >= 0 and i < _buttons.size() and _buttons[i].is_visible_in_tree():
		_buttons[i].grab_focus()


func set_label(id: String, text: String) -> void:
	var i := _ids.find(id)
	if i >= 0:
		_buttons[i].text = text


func label_of(id: String) -> String:
	var i := _ids.find(id)
	return _buttons[i].text if i >= 0 else ""


func button_of(id: String) -> Button:
	var i := _ids.find(id)
	return _buttons[i] if i >= 0 else null


func selected_id() -> String:
	return navigation.current_id()


## Teclado: ui_up/ui_down movem o foco, ui_accept ativa. Devolve true se tratou o evento.
func handle_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_down"):
		navigation.move(1)
	elif event.is_action_pressed("ui_up"):
		navigation.move(-1)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		var id := navigation.activate()
		if id != "":
			activated.emit(id)
		return true
	else:
		return false
	focus_selected()
	return true


func _on_hover(i: int) -> void:
	if navigation.select(i):
		focus_selected()


func _on_focus(i: int) -> void:
	navigation.select(i)


func _on_pressed(i: int) -> void:
	navigation.select(i)
	if navigation.index() == i and navigation.activate() != "":
		activated.emit(navigation.current_id())


func _apply_enabled(i: int) -> void:
	var enabled := navigation.is_enabled(i)
	_buttons[i].disabled = not enabled
	_buttons[i].focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
