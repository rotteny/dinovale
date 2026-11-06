# SPDX-License-Identifier: MIT
class_name DeathScreen
extends Control
## Tela de morte (GDD 12.2): lista as regiões de `RespawnRules` (dados) com a distância até o corpo e
## só pede (`region_chosen`); quem liga (a `Main`) valida e faz o jogador renascer. A primeira região
## vem pré-selecionada, então nunca falta opção. Não pausa o jogo: o relógio do mundo segue. Com a
## pausa aberta, o teclado é da pausa (a árvore pausada não entrega `_input` a esta tela).

signal region_chosen(region_id: String)

@export var rules: RespawnRules = preload("res://data/balance/respawn_rules.tres")

var is_open: bool = false
## Segundos desde que a tela abriu (para o atraso de `RespawnRules.accept_delay`).
var open_seconds: float = 0.0
var _column := MenuColumn.new()


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0, 0, 0.6)
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
	title.text = "Você morreu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Onde renascer?"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(hint)
	box.add_child(_column)
	_column.activated.connect(_on_activated)


## Abre a lista, com a distância de cada região até `body_position` (pixels do mundo).
func open(body_position: Vector2) -> void:
	_column.setup(_items(body_position))
	_column.reset_selection()
	open_seconds = 0.0
	is_open = true
	visible = true


func close() -> void:
	is_open = false
	visible = false


func column() -> MenuColumn:
	return _column


func _process(delta: float) -> void:
	if is_open:
		open_seconds += delta


## Escolha só depois do atraso (dado): quem morreu apertando Espaço não renasce sem ver a tela.
func _on_activated(id: String) -> void:
	if open_seconds >= rules.accept_delay:
		region_chosen.emit(id)


func _items(body_position: Vector2) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for region in rules.available_regions():
		var anchor := region.area.get_center() if region.area.size != Vector2.ZERO else region.fallback_point
		var tiles := int(round(body_position.distance_to(anchor) / float(rules.tile_size)))
		items.append({"id": region.id, "label": "%s  (%d tiles)" % [region.display_name, tiles]})
	return items


func _input(event: InputEvent) -> void:
	if is_open and _column.handle_event(event):
		get_viewport().set_input_as_handled()
