# SPDX-License-Identifier: MIT
class_name HungerComponent
extends Node
## Fome: `current_hunger` é a saciedade (cheio = 100, vazio = 0) e cai com o tempo.
## Em zero, emite `starved(damage)` periodicamente. Quem tem vida liga esse sinal
## ao `HealthComponent.take_damage`: o componente não conhece a vida (sinal para cima).

signal hunger_changed(current: float, maximum: float)
signal starved(damage: float)

@export var max_hunger: float = 100.0:
	set(value):
		max_hunger = maxf(value, 1.0)
		current_hunger = minf(current_hunger, max_hunger)
## Queda de saciedade por segundo. Padrão do componente isolado; o `Player` aplica o valor
## de `player_rules.tres` no `_ready`.
@export var decay_per_second: float = 0.5
## Dano e intervalo, em segundos, enquanto a saciedade está zerada.
@export var starvation_damage: float = 5.0
@export var starvation_interval: float = 2.0

var current_hunger: float = 100.0

var _starvation_timer: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func is_starving() -> bool:
	return current_hunger <= 0.0


func tick(delta: float) -> void:
	_set_current(current_hunger - decay_per_second * delta)
	if not is_starving():
		_starvation_timer = 0.0
		return
	_starvation_timer += delta
	while _starvation_timer >= starvation_interval and starvation_interval > 0.0:
		_starvation_timer -= starvation_interval
		starved.emit(starvation_damage)


## Come: devolve a saciedade. Comer interrompe o dano na hora.
func eat(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current_hunger + amount)
	if not is_starving():
		_starvation_timer = 0.0


## Põe a saciedade em `ratio` do máximo (respawn) e zera o dano de fome em andamento.
func set_ratio(ratio: float) -> void:
	_set_current(max_hunger * clampf(ratio, 0.0, 1.0))
	_starvation_timer = 0.0


func to_dict() -> Dictionary:
	return {
		"current": current_hunger,
		"max": max_hunger,
		"starvation_timer": _starvation_timer,
	}


## Restaura sem emitir `starved`: carregar um save não causa dano.
func from_dict(data: Dictionary) -> void:
	# O `max` salvo é ignorado (ADR-002): o máximo vem da cena, não de um arquivo não confiável.
	current_hunger = SafeRead.number(data.get("current"), current_hunger, 0.0, max_hunger)
	_starvation_timer = SafeRead.number(data.get("starvation_timer"), 0.0, 0.0, starvation_interval)
	hunger_changed.emit(current_hunger, max_hunger)


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_hunger)
	if clamped == current_hunger:
		return
	current_hunger = clamped
	hunger_changed.emit(current_hunger, max_hunger)
