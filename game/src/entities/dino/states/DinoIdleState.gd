class_name DinoIdleState
extends DinoState
## Parado por um tempo aleatório, depois passeia.

var _time_left := 0.0


func enter() -> void:
	machine.desired_direction = Vector2.ZERO
	_time_left = machine.rng.randf_range(machine.idle_seconds.x, machine.idle_seconds.y)


func tick(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		machine.transition_to(Enums.DinoStateId.WANDER)
