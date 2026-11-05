# SPDX-License-Identifier: MIT
class_name DinoStateMachine
extends Node
## Cérebro da criatura. Não conhece física nem sprite: publica `desired_direction`
## para o corpo e `state_changed` para a apresentação, então roda igual em
## servidor headless.
##
##   IDLE <-> WANDER
##   qualquer estado -> UNCONSCIOUS   (TorporComponent.knocked_out)
##   UNCONSCIOUS -> IDLE              (acordou selvagem)
##   UNCONSCIOUS -> TAMED             (mark_tamed, ou acordou já domesticado)

signal state_changed(previous: Enums.DinoStateId, current: Enums.DinoStateId)

@export var torpor: TorporComponent
## Duração mínima e máxima, em segundos, de cada estado.
@export var idle_seconds := Vector2(1.0, 3.0)
@export var wander_seconds := Vector2(1.0, 4.0)

## Fixe `rng.seed` para ter um comportamento reproduzível.
var rng := RandomNumberGenerator.new()
var is_tamed := false
var desired_direction := Vector2.ZERO
var current_id := Enums.DinoStateId.IDLE

var _states: Dictionary = {}


func _ready() -> void:
	start()


func _physics_process(delta: float) -> void:
	tick(delta)


## Chamado pelo `_ready`. Pode ser chamado antes, por testes ou ao restaurar um save.
func start() -> void:
	if not _states.is_empty():
		return
	_states = {
		Enums.DinoStateId.IDLE: DinoIdleState.new(),
		Enums.DinoStateId.WANDER: DinoWanderState.new(),
		Enums.DinoStateId.UNCONSCIOUS: DinoUnconsciousState.new(),
		Enums.DinoStateId.TAMED: DinoTamedState.new(),
	}
	for state: DinoState in _states.values():
		state.machine = self
	torpor.knocked_out.connect(_on_knocked_out)
	torpor.woke_up.connect(_on_woke_up)
	current_id = Enums.DinoStateId.UNCONSCIOUS if torpor.is_unconscious else _awake_state()
	_states[current_id].enter()


func tick(delta: float) -> void:
	_states[current_id].tick(delta)


func transition_to(next_id: Enums.DinoStateId) -> void:
	if next_id == current_id:
		return
	var previous := current_id
	_states[previous].exit()
	current_id = next_id
	_states[next_id].enter()
	state_changed.emit(previous, next_id)


## Conclui a domesticação e acorda a criatura. Só vale para uma criatura
## selvagem desmaiada; retorna false nos outros casos.
func mark_tamed() -> bool:
	if is_tamed or current_id != Enums.DinoStateId.UNCONSCIOUS:
		return false
	is_tamed = true
	torpor.reset()
	return true


func to_dict() -> Dictionary:
	return {
		"state": Enums.DinoStateId.find_key(current_id),
		"is_tamed": is_tamed,
	}


## Restaure o TorporComponent ANTES: ele é a fonte da verdade sobre a consciência,
## e um save inconsistente é corrigido a partir dele.
func from_dict(data: Dictionary) -> void:
	start()
	is_tamed = SafeRead.flag(data.get("is_tamed"), is_tamed)
	var saved_id: int = Enums.DinoStateId.get(SafeRead.text(data.get("state"), ""), -1)
	transition_to(_restored_state(saved_id))


func _restored_state(saved_id: int) -> Enums.DinoStateId:
	if torpor.is_unconscious:
		return Enums.DinoStateId.UNCONSCIOUS
	if not is_tamed and saved_id == Enums.DinoStateId.WANDER:
		return Enums.DinoStateId.WANDER
	return _awake_state()


func _awake_state() -> Enums.DinoStateId:
	return Enums.DinoStateId.TAMED if is_tamed else Enums.DinoStateId.IDLE


func _on_knocked_out() -> void:
	transition_to(Enums.DinoStateId.UNCONSCIOUS)


func _on_woke_up() -> void:
	transition_to(_awake_state())
