# SPDX-License-Identifier: MIT
class_name DinoAggressiveState
extends DinoState
## Bravo (M1, seção 2): vai até o alvo pelo caminho do `PathFollower`, na velocidade brava da espécie, e para na
## distância mínima (`chase_stop_px`) para não empurrar o jogador. Ainda não ataca (etapa 4).
##
## Entra quando o dino leva golpe do jogador ou, sendo Agressivo, avista o alvo. Sai para o natural SEM rancor quando:
## 8 s se passam sem dano (`AggressionRules.calm_seconds`; `reset_calm` o zera), o alvo fica a mais de `far_tiles` por
## `far_seconds`, o alvo passa de `chase_give_up_tiles`, `chase_max_seconds` de episódio, não há alvo ou o caminho
## travou. Não vai para o save: ao carregar, todo mundo volta calmo.

var _elapsed := 0.0
var _calm_left := 0.0
var _far_time := 0.0


func enter() -> void:
	_elapsed = 0.0
	_far_time = 0.0
	reset_calm()
	machine.speed_multiplier = machine.chase_speed_multiplier()
	machine.follower.forget()
	_steer(0.0)


func exit() -> void:
	machine.speed_multiplier = 1.0
	machine.desired_direction = Vector2.ZERO
	machine.start_alert()


## Dano dado ou recebido: o relógio de calma recomeça (o limite do episódio, não).
func reset_calm() -> void:
	_calm_left = machine.aggression.calm_seconds


## Quanto falta para acalmar sem novo dano (para teste e diagnóstico).
func calm_left() -> float:
	return _calm_left


func tick(delta: float) -> void:
	_elapsed += delta
	_calm_left -= delta
	if _far_from_target():
		_far_time += delta
	else:
		_far_time = 0.0
	if _should_calm():
		machine.transition_to(Enums.DinoStateId.IDLE)
		return
	_steer(delta)


func _should_calm() -> bool:
	var stats := machine.stats
	if not machine.target_known or _calm_left <= 0.0 or _far_time >= machine.aggression.far_seconds:
		return true
	if stats == null:
		return false
	return _elapsed >= stats.chase_max_seconds or machine.target_distance() > stats.chase_give_up_tiles * machine.tile_px


func _far_from_target() -> bool:
	return machine.target_known and machine.target_distance() > machine.aggression.far_px(machine.tile_px)


func _steer(delta: float) -> void:
	# Na distância mínima o dino para: perseguir "para dentro" do alvo só espreme o corpo dele. O Agressivo, sem ataque
	# ainda (M1), desiste ali e fica em alerta longo; o que só revida fica parado, bravo, até o relógio acabar.
	if machine.stats != null and machine.target_distance() <= machine.stats.chase_stop_px:
		machine.desired_direction = Vector2.ZERO
		if machine.stats.aggressive:
			machine.transition_to(Enums.DinoStateId.IDLE)
			machine.start_reached_alert()
		return
	machine.desired_direction = machine.follower.update(delta, machine.self_position, machine.target_position)
	if machine.follower.stuck:
		machine.desired_direction = Vector2.ZERO
		machine.transition_to(Enums.DinoStateId.IDLE)  # travou: desiste e fica em alerta
