# SPDX-License-Identifier: MIT
class_name TorporComponent
extends Node
## Torpor: barra independente de Health. Em `current >= max_torpor` a criatura
## desmaia. Ela só acorda quando o torpor cai até `wake_ratio * max_torpor`.
##
## Acordada, a criatura não mostra barra: só a faixa (0 a 3) do torpor, com histerese.
## Velocidade, pausas e cooldown por faixa são regra de simulação (`movement_multiplier`,
## `is_paused`, `attack_cooldown_multiplier`); bocejo e cambaleio são só apresentação,
## disparados por `band_changed`. Limiares e efeitos vêm de `band_rules`.

signal torpor_changed(current: float, maximum: float)
signal band_changed(band: int)
signal knocked_out
signal woke_up

## Teto de sanidade para um valor vindo de save.
const MAX_SAVED := 1.0e7

@export var max_torpor: float = 100.0:
	set(value):
		max_torpor = maxf(value, 1.0)
		current_torpor = minf(current_torpor, max_torpor)
		_update_band()
		torpor_changed.emit(current_torpor, max_torpor)

## Queda de torpor por segundo enquanto consciente.
@export var decay_per_second: float = 5.0
## Queda de torpor por segundo enquanto inconsciente. Define quanto tempo o
## jogador tem para domesticar.
@export var unconscious_decay_per_second: float = 1.0
## Fração do máximo em que a criatura acorda.
@export_range(0.0, 0.99) var wake_ratio: float = 0.0

@export var band_rules: TorporBandRules = preload("res://data/balance/torpor_bands.tres")
## Deslocamento determinístico das pausas, para que dois dinos na mesma faixa não parem
## juntos. Quem compõe a criatura o define (o `Dino` o deriva da posição de nascimento até
## existir id de entidade, ADR-003) e ele vai para o save com o relógio da pausa.
@export var pause_phase: float = 0.0

var current_torpor: float = 0.0
var is_unconscious: bool = false
## Faixa 0 a 3 pela fração `current / max`, com histerese (por isso vai para o save).
var band: int = 0

var _pause_clock: float = 0.0
var _quiet_band: bool = false


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	var rate := unconscious_decay_per_second if is_unconscious else decay_per_second
	_set_current(current_torpor - rate * delta)
	_update_consciousness()
	if not is_unconscious and band == band_rules.pause_band:
		_pause_clock += delta
	else:
		_pause_clock = 0.0


## Fator de velocidade da criatura acordada: 0 numa pausa, senão o da faixa.
func movement_multiplier() -> float:
	if is_unconscious:
		return 1.0
	if is_paused():
		return 0.0
	return band_rules.speed_multiplier(band)


## Na faixa de pausa, para por `pause_duration` ao fim de cada `pause_period`.
## Determinística: depende só do tempo acumulado na faixa e de `pause_phase`.
func is_paused() -> bool:
	if is_unconscious or band != band_rules.pause_band or band_rules.pause_period <= 0.0:
		return false
	var cycle := fposmod(_pause_clock + pause_phase, band_rules.pause_period)
	return cycle >= band_rules.pause_period - band_rules.pause_duration


func attack_cooldown_multiplier() -> float:
	return band_rules.attack_cooldown_multiplier(band)


func add_torpor(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current_torpor + amount)
	_update_consciousness()


func reduce_torpor(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current_torpor - amount)
	_update_consciousness()


## Zera o torpor e acorda a criatura, se ela estiver desmaiada.
func reset() -> void:
	_set_current(0.0)
	_update_consciousness()


func to_dict() -> Dictionary:
	return {
		"current": current_torpor,
		"max": max_torpor,
		"is_unconscious": is_unconscious,
		"band": band,
		"pause_clock": _pause_clock,
		"pause_phase": pause_phase,
	}


## Restaura sem emitir `knocked_out` nem `woke_up`: carregar um save não é um
## evento de jogo. Quem depende do estado lê `is_unconscious` depois.
func from_dict(data: Dictionary) -> void:
	# O `max` salvo é ignorado: o máximo vem de quem compõe a criatura (o nível).
	current_torpor = SafeRead.number(data.get("current"), current_torpor, 0.0, max_torpor)
	is_unconscious = SafeRead.flag(data.get("is_unconscious"), is_unconscious)
	# A faixa salva é revalidada contra a fração: dentro da zona de histerese, ela vale.
	# Silencioso: `band_changed` é evento de jogo, restaurar não o dispara.
	var saved_band := SafeRead.integer(data.get("band"), 0, 0, band_rules.max_band())
	band = band_rules.next_band(saved_band, current_torpor / max_torpor)
	pause_phase = SafeRead.number(data.get("pause_phase"), pause_phase, 0.0, band_rules.pause_period)
	_pause_clock = SafeRead.number(data.get("pause_clock"), 0.0, 0.0, MAX_SAVED)
	torpor_changed.emit(current_torpor, max_torpor)


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_torpor)
	if clamped == current_torpor:
		return
	current_torpor = clamped
	_update_band()
	torpor_changed.emit(current_torpor, max_torpor)


## Muda o máximo sem anunciar mudança de faixa (carga de save): a faixa é recalculada, mas
## `band_changed` é evento de jogo.
func set_max_quietly(value: float) -> void:
	_quiet_band = true
	max_torpor = value
	_quiet_band = false


func _update_band() -> void:
	var next := band_rules.next_band(band, current_torpor / max_torpor)
	if next == band:
		return
	band = next
	_pause_clock = 0.0
	if not _quiet_band:
		band_changed.emit(band)


func _update_consciousness() -> void:
	if not is_unconscious and current_torpor >= max_torpor:
		is_unconscious = true
		knocked_out.emit()
	elif is_unconscious and current_torpor <= max_torpor * wake_ratio:
		is_unconscious = false
		woke_up.emit()
