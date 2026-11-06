# SPDX-License-Identifier: MIT
class_name MenuColumn
extends VBoxContainer
## Coluna de itens de menu com teclado e mouse. A seleção é de `MenuNavigation` (lógica pura); aqui
## só se desenha (marcador "> " no selecionado, item desabilitado esmaecido) e se traduz o input.
## Quem usa chama `handle_event` no seu `_input` (setas/Enter) e escuta `activated(id)`.

signal activated(id: String)

const MARKER := "> "
const DISABLED_ALPHA := 0.5
## Linha do menu para o viewport de 320x180 (o tema dá ao botão ao menos 16 px de altura).
const ROW_SIZE := Vector2(112, 14)

var navigation := MenuNavigation.new()
var _ids: Array[String] = []
var _markers: Array[Label] = []
var _buttons: Array[Button] = []


## Monta os itens `{id, label, enabled?}`.
func setup(items: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ids.clear()
	_markers.clear()
	_buttons.clear()
	navigation.set_items(items)
	for i in items.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var marker := Label.new()
		marker.custom_minimum_size.x = 9
		marker.add_theme_color_override("font_color", UiTheme.INK)
		var button := Button.new()
		button.text = str(items[i]["label"])
		button.disabled = not bool(items[i].get("enabled", true))
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(ROW_SIZE.x, ROW_SIZE.y)
		button.mouse_entered.connect(_on_hover.bind(i))
		button.pressed.connect(_on_pressed.bind(i))
		row.add_child(marker)
		row.add_child(button)
		add_child(row)
		_ids.append(str(items[i]["id"]))
		_markers.append(marker)
		_buttons.append(button)
	_redraw()


## Seleciona o primeiro item habilitado e redesenha o marcador (reabrir um menu que ficou guardado).
func reset_selection() -> void:
	navigation.reset()
	_redraw()


func set_label(id: String, text: String) -> void:
	var i := _ids.find(id)
	if i >= 0:
		_buttons[i].text = text


func label_of(id: String) -> String:
	var i := _ids.find(id)
	return _buttons[i].text if i >= 0 else ""


## Texto do marcador desenhado ao lado do item (MARKER no selecionado, vazio nos outros).
func marker_of(id: String) -> String:
	var i := _ids.find(id)
	return _markers[i].text if i >= 0 else ""


func button_of(id: String) -> Button:
	var i := _ids.find(id)
	return _buttons[i] if i >= 0 else null


func selected_id() -> String:
	return navigation.current_id()


## Teclado: ui_up/ui_down movem, ui_accept ativa. Devolve true se tratou o evento.
func handle_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_down"):
		navigation.move(1)
	elif event.is_action_pressed("ui_up"):
		navigation.move(-1)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		var id := navigation.activate()
		if id != "":
			activated.emit(id)
	else:
		return false
	_redraw()
	return true


func _on_hover(i: int) -> void:
	if navigation.select(i):
		_redraw()


func _on_pressed(i: int) -> void:
	navigation.select(i)
	_redraw()
	if navigation.index() == i and navigation.activate() != "":
		activated.emit(navigation.current_id())


func _redraw() -> void:
	for i in _buttons.size():
		_markers[i].text = MARKER if i == navigation.index() else ""
		_buttons[i].modulate.a = 1.0 if navigation.is_enabled(i) else DISABLED_ALPHA
