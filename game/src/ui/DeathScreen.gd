# SPDX-License-Identifier: MIT
class_name DeathScreen
extends Control
## Tela de morte (GDD 12.2): lista única com as Camas do jogador (cinza e com o tempo que falta, se esperam), o Saco de dormir e
## "Local aleatório" em cada região de `RespawnRules` (dados; hoje só a Campina). Só pede (`region_chosen`, com o id da opção);
## quem liga (a `Main`) valida, sorteia o ponto e faz o jogador renascer. A primeira opção habilitada vem pré-selecionada
## (a Cama pronta, ou o Local aleatório), então nunca falta opção. As Camas vêm do `RespawnPointService` e a lista acompanha o mundo
## com a tela aberta: Cama destruída some, a espera desce. Avisa que os itens ficaram no corpo e por quantos minutos.
## Não pausa o jogo: o relógio do mundo segue. Com a pausa aberta, o teclado é da pausa (a árvore pausada não entrega
## `_input` a esta tela).

signal region_chosen(region_id: String)

## Rótulo da opção de renascer (o ponto é sorteado na região).
const RANDOM_LABEL := "Local aleatório"

@export var rules: RespawnRules = preload("res://data/balance/respawn_rules.tres")
## Quantos minutos o corpo guarda os itens (`DownedRules.body_minutes`; a `Main` o liga).
@export var corpse_minutes: float = 10.0

## Onde estão as Camas e o Saco (a `Main` liga; sem isto a lista só tem os Locais aleatórios) e de quem são.
var points: RespawnPointService = null
var viewer: Player = null
var is_open: bool = false
## Segundos desde que a tela abriu (para o atraso de `RespawnRules.accept_delay`).
var open_seconds: float = 0.0
var _column := MenuColumn.new()
var _corpse_hint := Label.new()
var _body_position: Vector2 = Vector2.ZERO
## Ids e estado habilitado da lista montada: se mudou, a coluna é refeita; se só o texto mudou (a espera descendo), troca o rótulo.
var _structure: String = ""


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
	hint.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(hint)
	_corpse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corpse_hint.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(_corpse_hint)
	box.add_child(_column)
	_column.activated.connect(_on_activated)


## Abre a lista, com a distância de cada região até `body_position` (pixels do mundo).
func open(body_position: Vector2) -> void:
	_corpse_hint.text = "Seus itens ficam no corpo por %d min." % roundi(corpse_minutes)
	_body_position = body_position
	var items := _items(body_position)
	_structure = _structure_of(items)
	_column.setup(items)
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
		_follow_world()


## A lista segue o mundo com a tela aberta: peça que sumiu ou espera que acabou refaz a coluna (mantendo a seleção se ela
## continua valendo); só o tempo mudando troca os rótulos.
func _follow_world() -> void:
	var items := _items(_body_position)
	if _structure_of(items) == _structure:
		for item in items:
			_column.set_label(str(item["id"]), str(item["label"]))
		return
	var before := _column.selected_id()
	_structure = _structure_of(items)
	_column.setup(items)
	_column.reset_selection()
	for index in items.size():
		if str(items[index]["id"]) == before and bool(items[index].get("enabled", true)) and _column.navigation.select(index):
			_column.focus_selected()


static func _structure_of(items: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append("%s=%s" % [item["id"], item.get("enabled", true)])
	return "|".join(parts)


## Escolha só depois do atraso (dado): quem morreu apertando Espaço não renasce sem ver a tela.
func _on_activated(id: String) -> void:
	if open_seconds >= rules.accept_delay:
		region_chosen.emit(id)


## As Camas e o Saco do jogador ("Cama 1 (23 tiles)"; em espera, cinza: "Cama 1 (espera 42 s)") e uma opção por região dos dados:
## "Local aleatório (Campina)", que não tem distância porque o ponto é sorteado.
func _items(body_position: Vector2) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if points != null and viewer != null:
		for option in points.options(viewer.player_id, body_position):
			var suffix := "%d tiles" % int(option["distance_tiles"])
			if float(option["wait_left"]) > 0.0:
				suffix = "espera %d s" % ceili(float(option["wait_left"]))
			elif not bool(option["enabled"]):
				suffix = "sem lugar"
			items.append({"id": option["id"], "label": "%s (%s)" % [option["name"], suffix], "enabled": option["enabled"]})
	for region in rules.available_regions():
		items.append({"id": region.id, "label": "%s (%s)" % [RANDOM_LABEL, region.display_name]})
	return items


func _input(event: InputEvent) -> void:
	if is_open and _column.handle_event(event):
		get_viewport().set_input_as_handled()
