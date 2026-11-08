# SPDX-License-Identifier: MIT
class_name ThreatCycle
extends RefCounted
## Relógio das fases do bravo: THREAT, APPROACH, CIRCLE, WINDUP, LUNGE e RECOVER (`m1-ameaca-e-corpo.md` seção 2).
## Só decide a fase e o rumo; não anda, não vê o mundo e não aplica dano (publica `struck`, e a autoridade resolve).
##
## THREAT só ocorre na entrada do episódio (`begin`). Com o alvo a mais de `run_threat_tiles`, a ameaça é feita correndo
## (`runs_threat`). O golpe só sai com a recarga vencida; sem alvo no alcance no fim da investida ele erra e a recarga
## corre inteira. Depois do golpe, RECOVER e de volta ao rodeio, sem nova ameaça.

## Uma vez por golpe. `in_reach` = havia alvo no alcance (falso = errou).
signal struck(in_reach: bool)
signal phase_changed(phase: Enums.ThreatPhase)

var profile: ThreatProfile
var rng: RandomNumberGenerator
var phase := Enums.ThreatPhase.NONE
## Fez a ameaça correndo (alvo longe na entrada). Vale durante THREAT.
var runs_threat := false
## Sentido do rodeio (+1 ou -1), sorteado por episódio.
var circle_sign := 1.0
var cooldown_left := 0.0
## Segundos na fase atual.
var phase_time := 0.0

var _circle_length := 0.0


func _init(threat_profile: ThreatProfile, generator: RandomNumberGenerator) -> void:
	profile = threat_profile
	rng = generator


## Abre um episódio: ameaça primeiro. A recarga que sobrou do episódio anterior se mantém.
func begin(distance_px: float, tile_px: float) -> void:
	runs_threat = distance_px > profile.run_threat_tiles * tile_px
	circle_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_enter(Enums.ThreatPhase.THREAT)


func end() -> void:
	runs_threat = false
	_enter(Enums.ThreatPhase.NONE)


## Passa o tempo da recarga (também fora do episódio, para não "congelar" a mordida ao acalmar).
func cool(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func tick(delta: float, distance_px: float, tile_px: float) -> void:
	cool(delta)
	phase_time += delta
	match phase:
		Enums.ThreatPhase.THREAT:
			if phase_time >= profile.threat_seconds:
				_enter(Enums.ThreatPhase.APPROACH)
		Enums.ThreatPhase.APPROACH:
			if distance_px <= profile.circle_radius_px(tile_px):
				_enter(Enums.ThreatPhase.CIRCLE)
		Enums.ThreatPhase.CIRCLE:
			if distance_px > profile.circle_radius_px(tile_px) * 1.6:
				_enter(Enums.ThreatPhase.APPROACH)  # o alvo se afastou: fecha de novo
			elif phase_time >= _circle_length:
				_enter(Enums.ThreatPhase.WINDUP)
		Enums.ThreatPhase.WINDUP:
			if phase_time >= profile.windup_s and cooldown_left <= 0.0:
				_enter(Enums.ThreatPhase.LUNGE)
		Enums.ThreatPhase.LUNGE:
			if distance_px <= profile.attack_reach_px:
				_strike(true)
			elif phase_time >= profile.lunge_max_s:
				_strike(false)
		Enums.ThreatPhase.RECOVER:
			if phase_time >= profile.recover_s:
				_enter(Enums.ThreatPhase.CIRCLE)


func _strike(in_reach: bool) -> void:
	cooldown_left = profile.cooldown_s
	struck.emit(in_reach)
	_enter(Enums.ThreatPhase.RECOVER)


func _enter(next: Enums.ThreatPhase) -> void:
	phase = next
	phase_time = 0.0
	if next == Enums.ThreatPhase.CIRCLE:
		_circle_length = rng.randf_range(profile.circle_seconds.x, profile.circle_seconds.y)
	phase_changed.emit(next)
