# SPDX-License-Identifier: MIT
class_name HealthComponent
extends Node
## Vida de uma entidade. Não conhece apresentação: a UI e as animações
## reagem aos sinais. Independente de torpor.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

const DEFAULT_MAX_HEALTH := 100.0
## Teto de sanidade para um valor vindo de save.
const MAX_SAVED := 1.0e7

## Quem está com a vida cheia continua cheio quando o máximo muda.
@export var max_health: float = DEFAULT_MAX_HEALTH:
	set(value):
		var was_full := is_equal_approx(current_health, max_health)
		max_health = maxf(value, 1.0)
		current_health = max_health if was_full else minf(current_health, max_health)
		health_changed.emit(current_health, max_health)

var current_health: float = DEFAULT_MAX_HEALTH


func is_dead() -> bool:
	return current_health <= 0.0


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	var dealt := minf(amount, current_health)
	current_health -= dealt
	damaged.emit(dealt)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	var restored := minf(amount, max_health - current_health)
	if restored <= 0.0:
		return
	current_health += restored
	healed.emit(restored)
	health_changed.emit(current_health, max_health)


## Muda o máximo preservando a vida PERDIDA (não a atual): 132/140 com o máximo indo a
## 180 fica 172/180. Quem está morto continua morto; quem está vivo fica com pelo menos 1
## quando o máximo muda.
func set_max_keeping_lost(new_max: float) -> void:
	# Mesmo máximo: nada a fazer (o piso de 1 só vale quando o máximo muda, e carregar
	# não cura vida fracionária).
	if is_equal_approx(maxf(new_max, 1.0), max_health):
		return
	var lost := maxf(max_health - current_health, 0.0)
	var dead := is_dead()
	max_health = new_max
	current_health = 0.0 if dead else clampf(max_health - lost, minf(1.0, max_health), max_health)
	health_changed.emit(current_health, max_health)


func to_dict() -> Dictionary:
	return {"current": current_health, "max": max_health}


## Restaura sem emitir `died` nem `damaged`: carregar um save não é um evento de jogo.
func from_dict(data: Dictionary) -> void:
	# O `max` salvo é ignorado: o máximo vem de quem compõe a criatura (o nível).
	current_health = SafeRead.number(data.get("current"), current_health, 0.0, max_health)
	health_changed.emit(current_health, max_health)
