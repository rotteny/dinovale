# SPDX-License-Identifier: MIT
class_name DinoChaseState
extends DinoState
## Perseguição do agressivo (GDD 6.7): vai até o alvo pelo caminho do `PathProvider` na velocidade de perseguição.
## Desiste com o alvo além de `chase_give_up_tiles`, depois de `chase_max_seconds`, sem alvo ou travado (sem caminho
## ou sem progresso por 3 s); volta a Idle e fica em alerta (`alert_seconds`) sem perseguir de novo.

var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	machine.speed_multiplier = machine.chase_speed_multiplier()
	machine.follower.forget()
	_steer(0.0)


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
	_steer(delta)


func _steer(delta: float) -> void:
	# Na distância mínima o dino para: perseguir "para dentro" do alvo só espreme o corpo dele. Sem ataque (M1) ele
	# desiste ali mesmo e fica em alerta longo, em vez de colar de novo a cada 20 s.
	if machine.target_distance() <= machine.stats.chase_stop_px:
		machine.desired_direction = Vector2.ZERO
		machine.transition_to(Enums.DinoStateId.IDLE)
		machine.start_reached_alert()
		return
	machine.desired_direction = machine.follower.update(delta, machine.self_position, machine.target_position)
	if machine.follower.stuck:
		machine.desired_direction = Vector2.ZERO
		machine.transition_to(Enums.DinoStateId.IDLE)  # travou: desiste e fica em alerta
