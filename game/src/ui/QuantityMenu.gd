# SPDX-License-Identifier: MIT
class_name QuantityMenu
extends PanelContainer
## Menu pequeno do clique direito numa pilha do inventário: "1", "Quantidade..." e "Todos" (e "Atalho" no lado do jogador).
## "Quantidade..." troca o conteúdo por um seletor numérico de 1 até o que cabe no destino e um botão de confirmar.
## Só apresentação: escolhe e avisa por sinal; quem move é a autoridade. Esc ou clique fora fecha.
## NÃO é o menu de interação do mundo (`InteractionMenu`): este tem o título "Mover" e só aparece dentro da tela de inventário.

signal amount_chosen(amount: int)
signal hotbar_chosen
signal cancelled

const TITLE := "Mover"

var _column := VBoxContainer.new()
var _maximum: int = 1
var _spin: SpinBox = null


func _ready() -> void:
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_child(_column)


## Abre junto de `at` (coordenadas da tela). `fits` = quanto cabe no destino (já limitado à pilha); 0 desabilita as três
## opções de quantidade e mostra o motivo.
func open_at(at: Vector2, stack: int, fits: int, with_hotbar: bool) -> void:
	_clear()
	_maximum = clampi(fits, 0, stack)
	_add_label(TITLE)
	if _maximum <= 0:
		_add_label("Sem espaço")
	_add_choice("1", _maximum >= 1, func() -> void: _choose(1))
	_add_choice("Quantidade...", _maximum >= 1, _open_spin)
	_add_choice("Todos (%d)" % _maximum, _maximum >= 1, func() -> void: _choose(_maximum))
	if with_hotbar:
		_add_choice("Atalho", true, func() -> void:
			hotbar_chosen.emit()
			close())
	visible = true
	reset_size()
	position = at
	_clamp_to_viewport()


func close() -> void:
	visible = false


## Quantidade que o seletor mostra agora (teste).
func spin_value() -> int:
	return int(_spin.value) if _spin != null else 0


func spin_maximum() -> int:
	return int(_spin.max_value) if _spin != null else 0


## Botão pelo texto (teste e teclado).
func choice(text: String) -> Button:
	for child in _column.get_children():
		if child is Button and (child as Button).text == text:
			return child
	return null


## Confirma o seletor aberto.
func confirm() -> void:
	if _spin != null:
		_choose(int(_spin.value))


func _open_spin() -> void:
	_clear()
	_add_label("Quantidade")
	_spin = SpinBox.new()
	_spin.min_value = 1
	_spin.max_value = _maximum
	_spin.value = 1
	_spin.rounded = true
	_column.add_child(_spin)
	var ok := Button.new()
	ok.text = "Confirmar"
	ok.pressed.connect(confirm)
	_column.add_child(ok)
	reset_size()
	_clamp_to_viewport()
	_spin.get_line_edit().grab_focus()


func _choose(amount: int) -> void:
	amount_chosen.emit(clampi(amount, 1, maxi(_maximum, 1)))
	close()


func _clear() -> void:
	_spin = null
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.INK)
	_column.add_child(label)


func _add_choice(text: String, enabled: bool, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(action)
	_column.add_child(button)


func _clamp_to_viewport() -> void:
	var limit := get_viewport_rect().size if is_inside_tree() else Vector2(320, 180)
	position = position.clamp(Vector2.ZERO, (limit - size).max(Vector2.ZERO))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		cancelled.emit()
		close()
		get_viewport().set_input_as_handled()
