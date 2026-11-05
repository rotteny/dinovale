# SPDX-License-Identifier: MIT
class_name TorporComponent
extends Node
## Torpor: barra independente de Health. Em `current >= max_torpor` a criatura
## desmaia. Ela só acorda quando o torpor cai até `wake_ratio * max_torpor`.

signal torpor_changed(current: float, maximum: float)
signal knocked_out
signal woke_up

@export var max_torpor: float = 100.0:
	set(value):
		max_torpor = maxf(value, 1.0)
		current_torpor = minf(current_torpor, max_torpor)

## Queda de torpor por segundo enquanto consciente.
@export var decay_per_second: float = 5.0
## Queda de torpor por segundo enquanto inconsciente. Define quanto tempo o
## jogador tem para domesticar.
@export var unconscious_decay_per_second: float = 1.0
## Fração do máximo em que a criatura acorda.
@export_range(0.0, 0.99) var wake_ratio: float = 0.0

var current_torpor: float = 0.0
var is_unconscious: bool = false


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	var rate := unconscious_decay_per_second if is_unconscious else decay_per_second
	_set_current(current_torpor - rate * delta)
	_update_consciousness()


func add_torpor(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current_torpor + amount)
	_update_consciousness()


func reduce_torpor(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current_torpor - amount)
	_update_consciousness()


## Zera o torpor e acorda a criatura, se ela estiver desmaiada.
func reset() -> void:
	_set_current(0.0)
	_update_consciousness()


func to_dict() -> Dictionary:
	return {
		"current": current_torpor,
		"max": max_torpor,
		"is_unconscious": is_unconscious,
	}


## Restaura sem emitir `knocked_out` nem `woke_up`: carregar um save não é um
## evento de jogo. Quem depende do estado lê `is_unconscious` depois.
func from_dict(data: Dictionary) -> void:
	max_torpor = float(data.get("max", max_torpor))
	current_torpor = clampf(float(data.get("current", current_torpor)), 0.0, max_torpor)
	is_unconscious = bool(data.get("is_unconscious", is_unconscious)) \
			or current_torpor >= max_torpor
	torpor_changed.emit(current_torpor, max_torpor)


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_torpor)
	if clamped == current_torpor:
		return
	current_torpor = clamped
	torpor_changed.emit(current_torpor, max_torpor)


func _update_consciousness() -> void:
	if not is_unconscious and current_torpor >= max_torpor:
		is_unconscious = true
		knocked_out.emit()
	elif is_unconscious and current_torpor <= max_torpor * wake_ratio:
		is_unconscious = false
		woke_up.emit()
