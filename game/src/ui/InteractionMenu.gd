# SPDX-License-Identifier: MIT
class_name InteractionMenu
extends PanelContainer
## Menu de opções do clique direito numa criatura ou objeto do MUNDO, junto do cursor. As opções vêm da autoridade
## (`WorldAuthority.interaction_options`); a desabilitada mostra o motivo ao lado ("Longe demais"), para o jogador saber
## o que fazer em vez de achar que o jogo travou. Só apresentação: escolher emite `option_chosen`; quem executa é o `Player`
## (pedido à autoridade). Esc ou clique fora fecha, e o clique que fecha não vira golpe no mundo.

signal option_chosen(option_id: String, target_id: int)
signal closed

var _column := VBoxContainer.new()
var _target_id: int = 0


func _ready() -> void:
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_child(_column)


## Abre em `at` (tela) para o alvo `target_id`, com o `title` (nome do alvo) e as opções da autoridade. Sem opção, não abre.
func open_for(at: Vector2, title: String, target_id: int, options: Array[Dictionary]) -> bool:
	if options.is_empty():
		return false
	_clear()
	_target_id = target_id
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", UiTheme.INK)
	_column.add_child(heading)
	for option in options:
		var button := Button.new()
		var enabled := bool(option["enabled"])
		button.text = str(option["label"]) if enabled else "%s (%s)" % [option["label"], GameMessages.reason_text(str(option["reason"]))]
		button.disabled = not enabled
		button.set_meta(&"option_id", option["id"])
		button.pressed.connect(_choose.bind(str(option["id"])))
		_column.add_child(button)
	visible = true
	reset_size()
	var limit := get_viewport_rect().size if is_inside_tree() else Vector2(320, 180)
	position = at.clamp(Vector2.ZERO, (limit - size).max(Vector2.ZERO))
	return true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func is_open() -> bool:
	return visible


## Botão da opção (teste).
func option_button(option_id: String) -> Button:
	for child in _column.get_children():
		if child is Button and child.get_meta(&"option_id", "") == option_id:
			return child
	return null


func option_ids() -> Array[String]:
	var ids: Array[String] = []
	for child in _column.get_children():
		if child is Button:
			ids.append(str(child.get_meta(&"option_id", "")))
	return ids


func _choose(option_id: String) -> void:
	option_chosen.emit(option_id, _target_id)
	close()


func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
