# SPDX-License-Identifier: MIT
class_name DinoWanderState
extends DinoState
## Anda em uma direção aleatória por um tempo, depois para. Com toca (`DinoStateMachine.home`) o passeio só sorteia pontos
## dentro da ronda e, passado o raio dela, volta ao centro da toca na velocidade da volta, depois do alerta (E3a).

var _time_left := 0.0
var _returning := false


func enter() -> void:
	_returning = machine.wants_return()
	if _returning:
		machine.follower.forget()
		machine.desired_direction = Vector2.ZERO
		return
	var angle := machine.rng.randf() * TAU
	_time_left = machine.rng.randf_range(machine.wander_seconds.x, machine.wander_seconds.y)
	if machine.home == null:
		machine.desired_direction = Vector2.from_angle(angle)
	else:
		machine.desired_direction = machine.patrol_direction(angle, _time_left)


func exit() -> void:
	_returning = false
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO


func tick(delta: float) -> void:
	if machine.wants_return():
		_tick_return(delta)
		return
	if _returning:  # chegou à ronda: recomeça o passeio
		machine.transition_to(Enums.DinoStateId.IDLE)
		return
	_time_left -= delta
	if _time_left <= 0.0:
		machine.transition_to(Enums.DinoStateId.IDLE)


## Parado durante o alerta; depois vai ao centro da toca pelo caminho do `PathFollower`.
func _tick_return(delta: float) -> void:
	if not _returning:
		machine.follower.forget()
	_returning = true
	if machine.alert_left() > 0.0:
		machine.desired_direction = Vector2.ZERO
		machine.speed_multiplier = 1.0
		return
	machine.speed_multiplier = machine.return_speed_multiplier()
	var goal := machine.home.center
	machine.desired_direction = machine.follower.update(delta, machine.self_position, goal)
	if machine.follower.stuck:  # sem caminho: vai em linha reta, sem desistir da volta
		machine.follower.clear_stuck()
		machine.desired_direction = (goal - machine.self_position).normalized()
