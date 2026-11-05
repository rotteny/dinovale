# SPDX-License-Identifier: MIT
class_name DinoPanel
extends PanelContainer
## Painel da criatura: estado, torpor e progresso de domesticação.
## Só reage a sinais do dino; nenhuma regra aqui.

const STATE_NAMES := {
	"IDLE": "Selvagem",
	"WANDER": "Selvagem",
	"UNCONSCIOUS": "Inconsciente",
	"TAMED": "Domesticado",
}

var _title := Label.new()
var _torpor_bar := StatBar.new("Torpor", Color(0.6, 0.4, 0.85))
var _taming_bar := StatBar.new("Domest.", Color(0.9, 0.7, 0.2))
var _dino: Dino = null


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_child(_title)
	box.add_child(_torpor_bar)
	box.add_child(_taming_bar)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	margin.add_child(box)
	add_child(margin)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func current_dino() -> Dino:
	return _dino


func show_dino(dino: Dino) -> void:
	clear()
	if dino == null:
		return
	_dino = dino
	dino.torpor.torpor_changed.connect(_on_torpor_changed)
	dino.taming.progress_changed.connect(_on_progress_changed)
	dino.state_machine.state_changed.connect(_on_state_changed)
	_on_torpor_changed(dino.torpor.current_torpor, dino.torpor.max_torpor)
	_on_progress_changed(dino.taming.taming_progress, TamingComponent.MAX_PROGRESS)
	_refresh_title()
	visible = true


func clear() -> void:
	if is_instance_valid(_dino):
		_dino.torpor.torpor_changed.disconnect(_on_torpor_changed)
		_dino.taming.progress_changed.disconnect(_on_progress_changed)
		_dino.state_machine.state_changed.disconnect(_on_state_changed)
	_dino = null
	visible = false


func torpor_bar() -> StatBar:
	return _torpor_bar


func taming_bar() -> StatBar:
	return _taming_bar


func title_text() -> String:
	return _title.text


func _refresh_title() -> void:
	var key := str(Enums.DinoStateId.find_key(_dino.state_machine.current_id))
	_title.text = "Dino: %s" % STATE_NAMES.get(key, key)


func _on_torpor_changed(current: float, maximum: float) -> void:
	_torpor_bar.set_values(current, maximum)


func _on_progress_changed(current: float, maximum: float) -> void:
	_taming_bar.set_values(current, maximum)


func _on_state_changed(_previous: Enums.DinoStateId, _current: Enums.DinoStateId) -> void:
	_refresh_title()
