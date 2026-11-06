# SPDX-License-Identifier: MIT
class_name DinoTamedState
extends DinoState
## Domesticado e acordado, aguardando ordens. STAY fica parado; FOLLOW anda até o dono e para a
## `arrive_distance_tiles` dele (números em `DinoOrderRules`).

var _moving := false


func enter() -> void:
	_moving = false
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO
	if machine.order == Enums.DinoOrder.FOLLOW:
		machine.speed_multiplier = machine.order_rules.follow_speed_multiplier
		_steer()


func exit() -> void:
	machine.speed_multiplier = 1.0


func tick(_delta: float) -> void:
	_steer()


## Aponta para o dono (ou para quando a ordem é Ficar ou o dono não está no mundo).
func _steer() -> void:
	if machine.order != Enums.DinoOrder.FOLLOW or not machine.owner_known:
		_moving = false
		machine.desired_direction = Vector2.ZERO
		return
	var direction := machine.order_rules.follow_direction(machine.self_position, machine.owner_position, _moving)
	_moving = direction != Vector2.ZERO
	machine.desired_direction = direction
