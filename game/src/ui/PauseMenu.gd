# SPDX-License-Identifier: MIT
class_name PauseMenu
extends Control
## Pausa do jogo (Esc, quando nenhuma tela está aberta): Continuar e Voltar ao menu (sem Salvar: o jogador não
## escolhe quando salvar). Pausa a árvore enquanto aberta (`process_mode` sempre) e só pede: quem liga decide
## o que fazer com `menu_requested`. Esc fecha, igual a Continuar. Não pergunta
## nada: Voltar ao menu salva (quem liga) e volta direto; se o salvamento falhar, quem liga mostra o
## motivo em `show_status` e a partida continua aberta.

signal resumed
signal menu_requested

const RESUME := "resume"
const MENU := "menu"

## A tela de inventário: com ela aberta, o Esc é dela (fecha), não abre a pausa.
@export var screen: InventoryScreen

var is_open: bool = false
var _column := MenuColumn.new()
var _status := Label.new()
var _menu_available: bool = true


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
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 160
	_status.add_theme_color_override("font_color", UiTheme.INK)
	_status.visible = false
	box.add_child(_status)
	box.add_child(_column)
	_column.activated.connect(_on_activated)
	_rebuild()


## Sem cena de menu configurada, o item "Voltar ao menu" não existe.
func set_menu_available(available: bool) -> void:
	_menu_available = available
	_rebuild()


## Resultado do último pedido de voltar ao menu, mostrado acima da lista ("" esconde).
func show_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""


func status_text() -> String:
	return _status.text if _status.visible else ""


func _rebuild() -> void:
	var items: Array[Dictionary] = [{"id": RESUME, "label": "Continuar"}]
	if _menu_available:
		items.append({"id": MENU, "label": "Voltar ao menu"})
	_column.setup(items)


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	show_status("")
	_column.reset_selection()  # com a pausa visível: o foco vai ao primeiro botão
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
		close()
		viewport.set_input_as_handled()
	elif _column.handle_event(event):
		viewport.set_input_as_handled()


func _on_activated(id: String) -> void:
	if id == RESUME:
		close()
	elif id == MENU:
		menu_requested.emit()
