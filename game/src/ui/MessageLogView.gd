# SPDX-License-Identifier: MIT
class_name MessageLogView
extends Control
## Log do sistema no canto de baixo à esquerda: sem fundo, texto com contorno de 1 px, as últimas linhas somem aos poucos.
## A tecla L abre o histórico inteiro (rolagem, fundo bem claro). Fechado, ignora o mouse (não rouba clique do mundo);
## aberto, o histórico recebe o mouse. Só apresentação: lê o `MessageLog`.

## Ação da tecla L (histórico), criada por código para não mexer em `project.godot`.
const MESSAGE_LOG := &"message_log"
const MARGIN := 3.0
const BOTTOM_RESERVED := 40.0  # acima da barra de atalhos
const WIDTH := 150.0
const FONT_SIZE := 8
const OUTLINE_SIZE := 2
const HISTORY_SIZE := Vector2(190.0, 110.0)
const HISTORY_BG := Color(1.0, 1.0, 1.0, 0.12)
const KIND_COLORS: Dictionary[int, Color] = {
	GameMessages.Kind.INFO: Color("#ffffff"),
	GameMessages.Kind.SUCCESS: Color("#9be37a"),
	GameMessages.Kind.WARNING: Color("#ffd166"),
	GameMessages.Kind.DANGER: Color("#ff7a7a"),
}

var messages: MessageLog

var _recent_box: VBoxContainer = null
var _history_panel: PanelContainer = null
var _history_box: VBoxContainer = null
var _scroll: ScrollContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_recent_box = VBoxContainer.new()
	_recent_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recent_box.add_theme_constant_override("separation", 0)
	_recent_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_recent_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_recent_box.offset_left = MARGIN
	_recent_box.offset_bottom = -BOTTOM_RESERVED
	_recent_box.custom_minimum_size.x = WIDTH
	add_child(_recent_box)
	_build_history()
	if messages != null:
		messages.line_added.connect(func(_line: Dictionary) -> void: refresh())


static func ensure_action() -> void:
	if InputMap.has_action(MESSAGE_LOG):
		return
	InputMap.add_action(MESSAGE_LOG)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_L
	InputMap.action_add_event(MESSAGE_LOG, event)


func _unhandled_input(event: InputEvent) -> void:
	ensure_action()
	if event.is_action_pressed(MESSAGE_LOG):
		toggle_history()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if messages == null:
		return
	messages.tick(delta)
	refresh()


## Painel do histórico: fundo bem claro, rolagem; escondido e sem mouse até abrir.
func _build_history() -> void:
	_history_panel = PanelContainer.new()
	_history_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = HISTORY_BG
	_history_panel.add_theme_stylebox_override("panel", style)
	_history_panel.custom_minimum_size = HISTORY_SIZE
	_history_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_history_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_history_panel.offset_left = MARGIN
	_history_panel.offset_bottom = -BOTTOM_RESERVED
	_history_panel.visible = false
	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_box = VBoxContainer.new()
	_history_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_box.add_theme_constant_override("separation", 0)
	_scroll.add_child(_history_box)
	_history_panel.add_child(_scroll)
	add_child(_history_panel)


func toggle_history() -> void:
	set_history_open(not _history_panel.visible)


func set_history_open(open: bool) -> void:
	_history_panel.visible = open
	_recent_box.visible = not open
	var filter := Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	_history_panel.mouse_filter = filter
	_scroll.mouse_filter = filter
	refresh()


func is_history_open() -> bool:
	return _history_panel.visible


## Reconstrói as linhas visíveis (poucas, só quando algo muda ou envelhece).
func refresh() -> void:
	if messages == null or _recent_box == null:
		return
	if _history_panel.visible:
		_fill(_history_box, messages.history(), false)
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	else:
		_fill(_recent_box, messages.recent(), true)


func _fill(box: VBoxContainer, lines: Array[Dictionary], fading: bool) -> void:
	while box.get_child_count() > lines.size():
		var extra := box.get_child(box.get_child_count() - 1)
		box.remove_child(extra)
		extra.queue_free()
	while box.get_child_count() < lines.size():
		box.add_child(_new_label())
	for i in lines.size():
		var label := box.get_child(i) as Label
		label.text = lines[i]["text"]
		label.add_theme_color_override("font_color", KIND_COLORS.get(int(lines[i]["kind"]), Color.WHITE))
		label.modulate.a = messages.alpha_of(lines[i]) if fading else 1.0


func _new_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	return label
