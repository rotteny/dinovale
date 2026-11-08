# SPDX-License-Identifier: MIT
class_name DinoStuckState
extends DinoState
## Domado em Seguir que travou longe do dono e fora da tela: desistiu, fica parado, SEM teleporte (decisão de 08/11).
## Sai para TAMED quando o jogador dá ordem nova (`DinoStateMachine.set_order`) ou quando o dono volta a menos de
## `stuck_far_tiles` ou à tela, respeitado o intervalo `stuck_retry_min_seconds` entre tentativas.

var _since := 0.0


func enter() -> void:
	_since = 0.0
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO
	machine.begin_stuck_episode()


func tick(delta: float) -> void:
	machine.desired_direction = Vector2.ZERO
	_since += delta
	if not machine.owner_known or _since < machine.nav_rules.stuck_retry_min_seconds:
		return
	if not machine.nav_rules.is_far_and_offscreen(machine.self_position, machine.owner_position):
		machine.transition_to(Enums.DinoStateId.TAMED)
