# SPDX-License-Identifier: MIT
class_name DayCycle
extends RefCounted
## Ciclo de dia e noite (SOB-03, E9): função pura do tempo do mundo. A fase é LÓGICA (a autoridade a usa para a percepção
## do Agressivo) e a tinta é só um valor que a apresentação lê; nada aqui conhece nó, sprite ou luz. O tempo é o do
## `WorldClock`, que o save já guarda (`world.time`): a hora do dia é derivada dele, não há campo novo no save. As
## faixas são meio-abertas, `[início, fim)`: no instante exato da fronteira já vale a faixa nova. Sem `Time`: o relógio
## real nunca entra na simulação.

enum Phase { DAY, DUSK, NIGHT, DAWN }

## Nome estável de cada faixa (o que vai a log e a teste; nunca o número).
const NAMES: Dictionary = {
	Phase.DAY: "day",
	Phase.DUSK: "dusk",
	Phase.NIGHT: "night",
	Phase.DAWN: "dawn",
}
const ORDER: Array[Phase] = [Phase.DAY, Phase.DUSK, Phase.NIGHT, Phase.DAWN]

var rules: DayCycleRules


func _init(cycle_rules: DayCycleRules) -> void:
	rules = cycle_rules


## Faixa do instante `world_time`. Tempo negativo ou não finito conta como o começo do ciclo (dia).
func phase_at(world_time: float) -> Phase:
	var position := _position(world_time)
	for phase in ORDER:
		if position < end_of(phase):
			return phase
	return Phase.DAWN


func is_night(world_time: float) -> bool:
	return phase_at(world_time) == Phase.NIGHT


## Multiplicador da percepção do Agressivo agora: 1,5 só na faixa da noite (dado em `night_perception_multiplier`).
func perception_scale(world_time: float) -> float:
	return rules.night_perception_multiplier if is_night(world_time) else 1.0


## Segundos, dentro do ciclo, em que a faixa começa.
func start_of(phase: Phase) -> float:
	var index := ORDER.find(phase)
	return 0.0 if index <= 0 else end_of(ORDER[index - 1])


## Segundos, dentro do ciclo, em que a faixa termina (e a próxima começa).
func end_of(phase: Phase) -> float:
	var total := _total_parts()
	var parts := 0.0
	for each in ORDER:
		parts += _parts_of(each)
		if each == phase:
			break
	return rules.cycle_seconds * parts / total


## Tinta do instante: a da faixa, caminhando para a da próxima nos últimos `blend_seconds` dela. Nunca abaixo de
## `min_tint_channel`, por canal.
func tint_at(world_time: float) -> Color:
	var phase := phase_at(world_time)
	var position := _position(world_time)
	var end := end_of(phase)
	var length := end - start_of(phase)
	var window := minf(rules.blend_seconds, length)
	var tint := _tint_of(phase)
	if window > 0.0 and position > end - window:
		var next: Phase = ORDER[(ORDER.find(phase) + 1) % ORDER.size()]
		var amount := smoothstep(0.0, 1.0, (position - (end - window)) / window)
		tint = tint.lerp(_tint_of(next), amount)
	var floor_value := rules.min_tint_channel
	return Color(maxf(tint.r, floor_value), maxf(tint.g, floor_value), maxf(tint.b, floor_value), 1.0)


static func name_of(phase: Phase) -> String:
	return NAMES[phase]


## Faixa pelo nome estável; nome desconhecido devolve `fallback`.
static func phase_from_name(phase_name: String, fallback: Phase = Phase.DAY) -> Phase:
	for phase: Phase in NAMES:
		if NAMES[phase] == phase_name:
			return phase
	return fallback


func _position(world_time: float) -> float:
	if not is_finite(world_time) or world_time < 0.0:
		return 0.0
	return fposmod(world_time, rules.cycle_seconds)


func _total_parts() -> float:
	return rules.day_parts + rules.dusk_parts + rules.night_parts + rules.dawn_parts


func _parts_of(phase: Phase) -> float:
	match phase:
		Phase.DAY:
			return rules.day_parts
		Phase.DUSK:
			return rules.dusk_parts
		Phase.NIGHT:
			return rules.night_parts
	return rules.dawn_parts


func _tint_of(phase: Phase) -> Color:
	match phase:
		Phase.DAY:
			return rules.day_tint
		Phase.DUSK:
			return rules.dusk_tint
		Phase.NIGHT:
			return rules.night_tint
	return rules.dawn_tint
