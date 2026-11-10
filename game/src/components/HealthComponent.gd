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
## Teto da proteção lida de um save (segundos). Quem salva a proteção é o `Player`, o único que a faz correr.
const MAX_PROTECTION := 60.0

## Quem está com a vida cheia continua cheio quando o máximo muda.
@export var max_health: float = DEFAULT_MAX_HEALTH:
	set(value):
		var was_full := is_equal_approx(current_health, max_health)
		max_health = maxf(value, 1.0)
		current_health = max_health if was_full else minf(current_health, max_health)
		health_changed.emit(current_health, max_health)

var current_health: float = DEFAULT_MAX_HEALTH
## Segundos que faltam de proteção (GDD 12.4): enquanto > 0, `take_damage` não tira vida. Quem
## concede e quem faz o tempo correr é o dono do componente (`grant_protection`, `tick`).
var protection_left: float = 0.0
## Cura contínua (a carne assada, GDD 5.12): `regen_rate` de vida por segundo durante `regen_left` segundos. Comer de novo RENOVA a
## janela (não soma a taxa). Não vai ao save (dura 10 s). Quem concede e quem a cancela (a morte) é o dono do componente.
var regen_left: float = 0.0
var regen_rate: float = 0.0


func is_dead() -> bool:
	return current_health <= 0.0


func is_protected() -> bool:
	return protection_left > 0.0


## Concede `seconds` de proteção (nunca encurta a que já existe).
func grant_protection(seconds: float) -> void:
	protection_left = maxf(protection_left, maxf(seconds, 0.0))


## Faz a proteção correr. Só quem concede a usa (o jogador); os demais nunca a têm.
func tick(delta: float) -> void:
	protection_left = maxf(protection_left - delta, 0.0)
	if regen_left > 0.0:
		var span := minf(delta, regen_left)
		regen_left -= span
		heal(regen_rate * span)


## Passa a curar `amount` de vida ao longo de `seconds` (taxa constante); renova a janela que já corria.
func start_regen(amount: float, seconds: float) -> void:
	if amount <= 0.0 or seconds <= 0.0:
		return
	regen_left = seconds
	regen_rate = amount / seconds


func cancel_regen() -> void:
	regen_left = 0.0
	regen_rate = 0.0


## Volta à vida com `ratio` do máximo (respawn). Não emite `died` nem `damaged`: é o fim da morte, não
## um golpe. Só tem efeito em quem está morto.
func revive(ratio: float = 1.0) -> void:
	if not is_dead():
		return
	current_health = clampf(max_health * ratio, minf(1.0, max_health), max_health)
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_dead() or is_protected():
		return
	var dealt := minf(amount, current_health)
	current_health -= dealt
	damaged.emit(dealt)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit()


## Tira vida, mas nunca abaixo de `floor_hp` (dano a si mesmo que não mata). Devolve quanto tirou de fato.
func take_damage_down_to(amount: float, floor_hp: float) -> float:
	var wanted := minf(maxf(amount, 0.0), maxf(current_health - floor_hp, 0.0))
	if wanted <= 0.0:
		return 0.0
	var before := current_health
	take_damage(wanted)
	return before - current_health


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
