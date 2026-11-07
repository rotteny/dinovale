# SPDX-License-Identifier: MIT
class_name WorldClock
extends RefCounted
## Relógio do mundo (ADR-006): segundos de jogo, desde o mundo novo. Só a autoridade o avança (`WorldAuthority`, em
## `_physics_process`, logo parado na pausa e com o jogo fechado); quem tem prazo recebe só o leitor (`now`). O teste
## avança com `advance`. Nenhum outro sistema escreve aqui.

var _time: float = 0.0


## Soma `delta` ao relógio. Negativo ou não finito é ignorado: o tempo nunca recua.
func advance(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		_time += delta


## Segundos de jogo agora. É o que se injeta nos sistemas (`authority.clock.now`).
func now() -> float:
	return _time


## O carregamento do save repõe o relógio. Não avança nem dispara nada.
func restore(value: float) -> void:
	_time = maxf(value, 0.0)
