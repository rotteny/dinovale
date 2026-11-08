# SPDX-License-Identifier: MIT
class_name DownedComponent
extends Node
## Estado de caído do jogador (M1, etapa 6) e o torpor dele. Só conta: o torpor sobe com a fome zerada, o desmaio
## corre. Quem DECIDE cair, acordar ou morrer é a autoridade (`WorldAuthority`): este componente só avisa
## (`torpor_full`, `time_over`) e executa `enter`/`wake`/`clear` quando mandam. Não conhece vida, sprite nem input.

## O torpor chegou ao máximo (a fome o levou lá): a autoridade decide se cai.
signal torpor_full
## O tempo do desmaio acabou: a autoridade decide se acorda.
signal time_over
signal torpor_changed(current: float, maximum: float)
## Segundos que faltam do desmaio (a HUD mostra a barra do caído).
signal time_changed(left: float, total: float)
signal state_changed(downed: bool)

## Teto de sanidade para um valor vindo de save.
const MAX_SAVED := 1.0e6

@export var rules: DownedRules = preload("res://data/balance/downed_rules.tres")

var is_downed: bool = false
## Segundos que faltam para acordar (0 quando de pé).
var left: float = 0.0
var torpor: float = 0.0


## Passo de tempo (mandado pelo `Player.tick`, que sabe se a fome está zerada). Caído: o desmaio corre.
## De pé: o torpor sobe com `starving` e desce sem ele.
func tick(delta: float, starving: bool) -> void:
	if is_downed:
		left = maxf(left - delta, 0.0)
		time_changed.emit(left, rules.downed_seconds)
		if left <= 0.0:
			time_over.emit()  # a autoridade acorda; um save com o tempo já esgotado acorda no primeiro passo
		return
	var before_torpor := torpor
	var rate := rules.starving_torpor_per_second if starving else -rules.fed_torpor_per_second
	_set_torpor(torpor + rate * delta)
	if before_torpor < rules.max_torpor and torpor >= rules.max_torpor:
		torpor_full.emit()


## Cai: o torpor vai ao máximo e o desmaio começa. Só a autoridade chama.
func enter() -> void:
	is_downed = true
	left = rules.downed_seconds
	_set_torpor(rules.max_torpor)
	state_changed.emit(true)
	time_changed.emit(left, rules.downed_seconds)


## Acorda: volta de pé com o torpor de `wake_torpor`. Só a autoridade chama.
func wake() -> void:
	is_downed = false
	left = 0.0
	_set_torpor(minf(rules.wake_torpor, rules.max_torpor - 0.001))
	state_changed.emit(false)
	time_changed.emit(0.0, rules.downed_seconds)


## Volta ao estado limpo (morte e renascer): de pé e com o torpor em `torpor_value`.
func clear(torpor_value: float = 0.0) -> void:
	var was := is_downed
	is_downed = false
	left = 0.0
	_set_torpor(torpor_value)
	if was:
		state_changed.emit(false)
	time_changed.emit(0.0, rules.downed_seconds)


func to_dict() -> Dictionary:
	return {"is_downed": is_downed, "left": left, "torpor": torpor}


## Restaura sem emitir `torpor_full`, `time_over` nem `state_changed` de jogo: carregar não é evento. Só emite as
## mudanças de valor (a HUD relê). Campo inválido cai no padrão; `left` nunca passa da duração das regras.
func from_dict(data: Dictionary) -> void:
	is_downed = SafeRead.flag(data.get("is_downed"), false)
	left = SafeRead.number(data.get("left"), 0.0, 0.0, rules.downed_seconds) if is_downed else 0.0
	_set_torpor(SafeRead.number(data.get("torpor"), 0.0, 0.0, minf(rules.max_torpor, MAX_SAVED)))
	if is_downed:
		torpor = rules.max_torpor
	time_changed.emit(left, rules.downed_seconds)


func _set_torpor(value: float) -> void:
	var clamped := clampf(value, 0.0, rules.max_torpor)
	if clamped == torpor:
		return
	torpor = clamped
	torpor_changed.emit(torpor, rules.max_torpor)
