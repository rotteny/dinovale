# SPDX-License-Identifier: MIT
class_name DinoWanderState
extends DinoState
## Anda em uma direção aleatória por um tempo, depois para.

var _time_left := 0.0


func enter() -> void:
	machine.desired_direction = Vector2.from_angle(machine.rng.randf() * TAU)
	_time_left = machine.rng.randf_range(machine.wander_seconds.x, machine.wander_seconds.y)


func exit() -> void:
	machine.desired_direction = Vector2.ZERO


func tick(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		machine.transition_to(Enums.DinoStateId.IDLE)
