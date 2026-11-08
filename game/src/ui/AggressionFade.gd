# SPDX-License-Identifier: MIT
class_name AggressionFade
extends RefCounted
## Fade do sinal de bravo (apresentação): `alpha` sobe a 1 enquanto o dino está bravo e desce a 0 ao acalmar, em
## `AggressionRules.fade_seconds`. Só mede tempo: quem decide se está bravo é a máquina do dino.

var alpha := 0.0


## Avança `delta` segundos rumo ao alvo (1 se bravo, 0 se calmo) e devolve o `alpha` novo.
func step(delta: float, aggressive: bool, rules: AggressionRules) -> float:
	alpha = move_toward(alpha, 1.0 if aggressive else 0.0, delta / maxf(rules.fade_seconds, 0.01))
	return alpha
