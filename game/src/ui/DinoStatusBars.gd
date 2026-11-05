# SPDX-License-Identifier: MIT
class_name DinoStatusBars
extends Node2D
## Barras sobre um dino, a qualquer distância do jogador. Só apresentação: lê
## sinais do dino e o segue na tela; o dino não sabe que ela existe.
## Instancie FORA do `Dino.tscn` (a lógica não referencia a UI).
##
## - Dormindo: torpor, domesticação e Eficiência com o nível previsto ("Nv 20 -> 28").
##   A domesticação e a Eficiência não se aplicam a quem já é domesticado.
## - Vida: só depois de dano, e some `HEALTH_VISIBLE_SECONDS` depois do último.
## - Acordado e sem dano recente, nada aparece (sem barra de torpor acordado).

const BAR_SIZE := Vector2(40.0, 4.0)
const OFFSET := Vector2(-20.0, -34.0)
const HEALTH_VISIBLE_SECONDS := 5.0
const LABEL_FONT_SIZE := 8

@export var dino: Dino

var _health_bar := StatBar.new("", Color(0.85, 0.25, 0.25), BAR_SIZE)
var _torpor_bar := StatBar.new("", Color(0.6, 0.4, 0.85), BAR_SIZE)
var _taming_bar := StatBar.new("", Color(0.9, 0.7, 0.2), BAR_SIZE)
var _efficiency_bar := StatBar.new("", Color(0.3, 0.8, 0.85), BAR_SIZE)
var _level_label := Label.new()
var _taming_panel := VBoxContainer.new()
var _efficiency_row := HBoxContainer.new()
var _health_timer := 0.0


func _ready() -> void:
	z_index = 10
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.position = OFFSET
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taming_panel.add_theme_constant_override("separation", 1)
	_taming_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taming_panel.add_child(_torpor_bar)
	_taming_panel.add_child(_taming_bar)
	_level_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_level_label.add_theme_constant_override("outline_size", 3)
	_efficiency_row.add_theme_constant_override("separation", 3)
	_efficiency_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_efficiency_row.add_child(_efficiency_bar)
	_efficiency_row.add_child(_level_label)
	_taming_panel.add_child(_efficiency_row)
	box.add_child(_health_bar)
	box.add_child(_taming_panel)
	add_child(box)
	visible = false
	if dino == null:
		return
	dino.torpor.torpor_changed.connect(_on_torpor_changed)
	dino.taming.progress_changed.connect(_on_progress_changed)
	dino.taming.efficiency_changed.connect(_on_efficiency_changed)
	dino.taming.level_preview_changed.connect(_on_preview_changed)
	dino.health.health_changed.connect(_health_bar.set_values)
	dino.health.damaged.connect(_on_damaged)
	dino.state_machine.state_changed.connect(_on_state_changed)
	_on_torpor_changed(dino.torpor.current_torpor, dino.torpor.max_torpor)
	_on_progress_changed(dino.taming.taming_progress, TamingComponent.MAX_PROGRESS)
	_on_efficiency_changed(dino.taming.efficiency)
	_on_preview_changed(dino.taming.level, dino.taming.preview_level())
	_health_bar.set_values(dino.health.current_health, dino.health.max_health)
	_refresh()
	follow()


func _process(delta: float) -> void:
	tick(delta)


## Passo de tempo da barra de vida (separado do `_process` para testar sem frames).
func tick(delta: float) -> void:
	if not follow():
		return
	if _health_timer > 0.0:
		_health_timer = maxf(_health_timer - delta, 0.0)
		if _health_timer == 0.0:
			_refresh()


## Acompanha o dino; some junto com ele se for removido. Retorna false quando o dino se
## foi (a remoção da barra já está agendada).
func follow() -> bool:
	if not is_instance_valid(dino) or dino.is_queued_for_deletion():
		queue_free()
		return false
	global_position = dino.global_position
	return true


func health_bar() -> StatBar:
	return _health_bar


func torpor_bar() -> StatBar:
	return _torpor_bar


func taming_bar() -> StatBar:
	return _taming_bar


func efficiency_bar() -> StatBar:
	return _efficiency_bar


func level_label() -> Label:
	return _level_label


## O painel de domar (torpor, domesticação, Eficiência) está à mostra?
func panel_visible() -> bool:
	return visible and _taming_panel.visible


func health_bar_visible() -> bool:
	return visible and _health_bar.visible


## Estado atual (e não o evento) decide: vale também depois de `from_dict`.
func _refresh() -> void:
	var asleep := dino.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS
	var wild := not dino.state_machine.is_tamed
	_taming_panel.visible = asleep
	_taming_bar.visible = wild
	_efficiency_row.visible = wild
	_health_bar.visible = _health_timer > 0.0
	visible = asleep or _health_bar.visible


func _on_damaged(_amount: float) -> void:
	_health_timer = HEALTH_VISIBLE_SECONDS
	_refresh()


func _on_torpor_changed(current: float, maximum: float) -> void:
	_torpor_bar.set_values(current, maximum)
	_refresh()


func _on_progress_changed(current: float, maximum: float) -> void:
	_taming_bar.set_values(current, maximum)
	_refresh()


func _on_efficiency_changed(efficiency: float) -> void:
	_efficiency_bar.set_values(efficiency, TamingComponent.MAX_EFFICIENCY)


func _on_preview_changed(level: int, preview: int) -> void:
	_level_label.text = "Nv %d -> %d" % [level, preview]


func _on_state_changed(_previous: Enums.DinoStateId, _current: Enums.DinoStateId) -> void:
	_refresh()
