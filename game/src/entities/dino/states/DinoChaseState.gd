# SPDX-License-Identifier: MIT
class_name DinoChaseState
extends DinoState
## Perseguição do agressivo (GDD 6.7): anda em linha reta até o alvo na velocidade de perseguição. Desiste com o alvo
## além de `chase_give_up_tiles`, depois de `chase_max_seconds` ou sem alvo; volta a Idle e fica em alerta
## (`alert_seconds`) sem perseguir de novo. Sem navegação (a E2 traz): obstáculo no caminho trava o corpo.

var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	machine.speed_multiplier = machine.chase_speed_multiplier()
	_steer()


func exit() -> void:
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO
	machine.start_alert()


func tick(delta: float) -> void:
	_elapsed += delta
	if not machine.target_known or _elapsed >= machine.stats.chase_max_seconds \
			or machine.target_distance() > machine.stats.chase_give_up_tiles * machine.tile_px:
		machine.transition_to(Enums.DinoStateId.IDLE)
		return
	_steer()


func _steer() -> void:
	machine.desired_direction = (machine.target_position - machine.self_position).normalized()
