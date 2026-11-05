# SPDX-License-Identifier: MIT
class_name PauseMenu
extends Control
## Pausa do jogo (Esc, quando nenhuma tela está aberta): Continuar e Voltar ao menu. Pausa a árvore
## enquanto aberta (`process_mode` sempre) e só pede: quem liga decide o que fazer com
## `menu_requested`. Esc fecha, igual a Continuar. "Voltar ao menu" descarta a partida (não há save
## em arquivo), então pede confirmação antes de emitir `menu_requested` (`confirm_discard`).

signal resumed
signal menu_requested

const RESUME := "resume"
const MENU := "menu"
const CANCEL := "cancel"
const CONFIRM := "confirm"
const WARNING := "A partida atual será perdida: ainda não há save."

## A tela de inventário: com ela aberta, o Esc é dela (fecha), não abre a pausa.
@export var screen: InventoryScreen

## Pede confirmação ao voltar ao menu. Desligue quando houver save em arquivo.
@export var confirm_discard: bool = true

## Cliques na confirmação são ignorados por este tempo depois que ela abre: a lista troca sob o
## ponteiro e o segundo clique de um duplo clique em "Voltar ao menu" cairia em "Descartar".
@export var confirm_guard_msec: int = 300

var is_open: bool = false
var _confirm_since: int = 0
var _column := MenuColumn.new()
var _warning := Label.new()
var _menu_available: bool = true
var _confirming: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(title)
	_warning.text = WARNING
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 8)
	_warning.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(_warning)
	box.add_child(_column)
	_column.activated.connect(_on_activated)
	set_menu_available(true)


## Sem cena de menu configurada, o item "Voltar ao menu" não existe.
func set_menu_available(available: bool) -> void:
	_menu_available = available
	_show_list(false)


## Lista principal (Continuar, Voltar ao menu) ou a confirmação (Cancelar primeiro: o padrão seguro).
func _show_list(confirming: bool) -> void:
	_confirming = confirming
	if confirming:
		_confirm_since = Time.get_ticks_msec()
	_warning.visible = confirming
	var items: Array[Dictionary] = []
	if confirming:
		items = [{"id": CANCEL, "label": "Cancelar"}, {"id": CONFIRM, "label": "Descartar e voltar ao menu"}]
	else:
		items = [{"id": RESUME, "label": "Continuar"}]
		if _menu_available:
			items.append({"id": MENU, "label": "Voltar ao menu"})
	_column.setup(items)


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	if _confirming:
		_show_list(false)
	else:
		_column.reset_selection()
	get_tree().paused = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()


func column() -> MenuColumn:
	return _column


## Esc sem nenhuma tela aberta abre a pausa. A tela de inventário trata o Esc dela por último na
## ordem de entrada (está antes na árvore), então aqui basta olhar se ela está aberta.
func _unhandled_input(event: InputEvent) -> void:
	if is_open or (screen != null and screen.is_open):
		return
	if event.is_action_pressed("ui_cancel"):
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var viewport := get_viewport()  # guardado antes: "Voltar ao menu" troca de cena
	if event.is_action_pressed("ui_cancel"):
		if _confirming:
			_show_list(false)  # Esc na confirmação volta à lista, não fecha a pausa
		else:
			close()
		viewport.set_input_as_handled()
	elif _column.handle_event(event):
		viewport.set_input_as_handled()


func _on_activated(id: String) -> void:
	if id == RESUME:
		close()
	elif id == MENU:
		if confirm_discard:
			_show_list(true)
		else:
			menu_requested.emit()
	elif id == CANCEL:
		_show_list(false)
	elif id == CONFIRM and Time.get_ticks_msec() - _confirm_since >= confirm_guard_msec:
		menu_requested.emit()
