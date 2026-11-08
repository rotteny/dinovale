# SPDX-License-Identifier: MIT
class_name DinoTamedState
extends DinoState
## Domesticado e acordado, aguardando ordens. STAY fica parado e FOLLOW anda até o dono, pelo caminho do
## `PathProvider`, e para a `arrive_distance_tiles` dele (números em `DinoOrderRules`).
##
## Se trava longe do dono e fora da tela, desiste (STUCK, sem teleporte). Perto ou à vista, segue tentando, sem aviso.

var _moving := false


func enter() -> void:
	_moving = false
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO
	machine.follower.forget()
	if machine.order == Enums.DinoOrder.FOLLOW:
		machine.speed_multiplier = machine.order_rules.follow_speed_multiplier
		_steer(0.0)


func exit() -> void:
	machine.speed_multiplier = 1.0


func tick(delta: float) -> void:
	machine.update_stuck_episode()
	_steer(delta)


## Aponta para o dono (ou para quando a ordem é Ficar ou o dono não está no mundo).
func _steer(delta: float) -> void:
	if machine.order != Enums.DinoOrder.FOLLOW or not machine.owner_known:
		_stop()
		return
	var wanted := machine.order_rules.follow_direction(machine.self_position, machine.owner_position, _moving)
	if wanted == Vector2.ZERO:
		_stop()
		return
	_moving = true
	machine.desired_direction = machine.follower.update(delta, machine.self_position, machine.owner_position)
	if machine.follower.stuck:
		_on_stuck()


func _stop() -> void:
	_moving = false
	machine.desired_direction = Vector2.ZERO
	machine.follower.forget()


func _on_stuck() -> void:
	if machine.nav_rules.is_far_and_offscreen(machine.self_position, machine.owner_position):
		machine.desired_direction = Vector2.ZERO
		machine.transition_to(Enums.DinoStateId.STUCK)
	else:
		machine.follower.clear_stuck()  # perto ou à vista: segue tentando, sem desistir e sem log
