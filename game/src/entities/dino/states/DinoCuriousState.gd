# SPDX-License-Identifier: MIT
class_name DinoCuriousState
extends DinoState
## Covarde que vê o jogador (E13): vem andando até `approach_tiles` dele e, perto, ronda (passeios laterais curtos e pausas),
## sem nunca encostar nem atacar. Sai para IDLE quando o alvo some ou passa da percepção. Não vai para o save.

var _time_left := 0.0
var _walking := false
var _side := 1.0


func enter() -> void:
	machine.follower.forget()
	machine.desired_direction = Vector2.ZERO
	machine.speed_multiplier = machine.patrol_speed_multiplier()
	_time_left = 0.0
	_walking = false


func exit() -> void:
	machine.desired_direction = Vector2.ZERO
	machine.speed_multiplier = 1.0


func tick(delta: float) -> void:
	var profile := machine.stats.coward
	if profile == null or not machine.target_known or machine.target_distance() > profile.perception_px(machine.tile_px):
		machine.transition_to(Enums.DinoStateId.IDLE)
		return
	machine.speed_multiplier = machine.patrol_speed_multiplier()
	var offset := machine.target_position - machine.self_position
	var close := profile.approach_px(machine.tile_px)
	if offset.length() > close:  # longe: vem em direção ao jogador
		machine.desired_direction = machine.follower.update(delta, machine.self_position, machine.target_position)
		if machine.follower.stuck:
			machine.follower.clear_stuck()
			machine.desired_direction = offset.normalized()
		return
	_time_left -= delta  # perto: ronda
	if _time_left <= 0.0:
		_walking = not _walking
		_time_left = machine.rng.randf_range(profile.patrol_seconds.x, profile.patrol_seconds.y)
		_side = -1.0 if machine.rng.randf() < 0.5 else 1.0
	machine.desired_direction = offset.normalized().orthogonal() * _side if _walking else Vector2.ZERO
