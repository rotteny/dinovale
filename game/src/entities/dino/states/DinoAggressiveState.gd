# SPDX-License-Identifier: MIT
class_name DinoAggressiveState
extends DinoState
## Bravo (M1, seção 2): vai até o alvo pelo caminho do `PathFollower`, na velocidade brava da espécie, e para na
## distância mínima (`chase_stop_px`) para não empurrar o jogador. Com `threat_profile` na espécie (etapa 4) o bravo
## segue o ciclo do `ThreatCycle`: ameaça, aproxima, rodeia, avisa, investe e se recupera; sem perfil, só persegue.
##
## Entra quando o dino leva golpe do jogador ou, sendo Agressivo, avista o alvo. Sai para o natural SEM rancor quando:
## 8 s se passam sem dano (`AggressionRules.calm_seconds`; `reset_calm` o zera), o alvo fica a mais de `far_tiles` por
## `far_seconds`, o alvo passa de `chase_give_up_tiles`, `chase_max_seconds` de episódio, não há alvo ou o caminho
## travou. Não vai para o save: ao carregar, todo mundo volta calmo.

var _elapsed := 0.0
var _calm_left := 0.0
var _far_time := 0.0
var _lunge_direction := Vector2.ZERO
var _steered_phase := Enums.ThreatPhase.NONE


func enter() -> void:
	_elapsed = 0.0
	_far_time = 0.0
	reset_calm()
	machine.speed_multiplier = machine.chase_speed_multiplier()
	machine.follower.forget()
	machine.episode_id += 1
	_steered_phase = Enums.ThreatPhase.NONE
	if machine.threat_cycle != null:
		machine.threat_cycle.begin(machine.target_distance(), machine.tile_px)
	_steer(0.0)


func exit() -> void:
	if machine.threat_cycle != null:
		machine.threat_cycle.end()
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
	if machine.threat_cycle != null:
		machine.threat_cycle.tick(delta, machine.target_distance(), machine.tile_px)
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
	if machine.threat_cycle != null:
		_steer_cycle(delta)
		return
	_steer_chase(delta)


## Rumo e velocidade de cada fase do ciclo. Parado em THREAT (alvo perto), WINDUP e RECOVER; corre na ameaça de longe e
## na aproximação; gira no rodeio; investe em linha reta, na direção travada ao entrar em LUNGE.
func _steer_cycle(delta: float) -> void:
	var cycle := machine.threat_cycle
	var profile := cycle.profile
	var phase := cycle.phase
	var chase := machine.chase_speed_multiplier()
	machine.speed_multiplier = chase
	var to_target := machine.target_position - machine.self_position
	var toward := to_target.normalized()
	match phase:
		Enums.ThreatPhase.THREAT:
			if cycle.runs_threat and machine.target_distance() > profile.circle_radius_px(machine.tile_px):
				_follow(delta)
			else:
				machine.desired_direction = Vector2.ZERO
		Enums.ThreatPhase.APPROACH:
			_follow(delta)
		Enums.ThreatPhase.CIRCLE:
			machine.speed_multiplier = chase * profile.circle_speed_factor
			machine.desired_direction = _circle_direction(toward, profile)
		Enums.ThreatPhase.LUNGE:
			if _steered_phase != Enums.ThreatPhase.LUNGE:
				_lunge_direction = toward
			if profile.lunge_speed_px_s > 0.0:
				machine.speed_multiplier = profile.lunge_speed_px_s / machine.walk_speed
			machine.desired_direction = _lunge_direction
		_:
			machine.desired_direction = Vector2.ZERO
	_steered_phase = phase


## Tangente ao alvo, no sentido do episódio, com correção do raio: o dino não espirala para dentro nem para fora.
func _circle_direction(toward: Vector2, profile: ThreatProfile) -> Vector2:
	var tangent := toward.rotated(PI * 0.5 * machine.threat_cycle.circle_sign)
	var radius := profile.circle_radius_px(machine.tile_px)
	var distance := machine.target_distance()
	var correction := clampf((distance - radius) / radius, -0.5, 0.5)
	return (tangent + toward * correction).normalized()


func _follow(delta: float) -> void:
	machine.desired_direction = machine.follower.update(delta, machine.self_position, machine.target_position)
	if machine.follower.stuck:
		machine.desired_direction = Vector2.ZERO
		machine.transition_to(Enums.DinoStateId.IDLE)  # travou: desiste e fica em alerta


func _steer_chase(delta: float) -> void:
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
