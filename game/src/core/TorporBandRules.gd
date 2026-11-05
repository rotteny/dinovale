# SPDX-License-Identifier: MIT
class_name TorporBandRules
extends Resource
## Faixas de torpor da criatura acordada (0 a 3): dado puro. Quem decide a faixa
## é o `TorporComponent`; aqui ficam limiares, histerese e efeitos de simulação.
## Valores em `res://data/balance/torpor_bands.tres`.

## Fração do torpor máximo em que se sobe para as faixas 1, 2 e 3.
@export var thresholds: Array[float] = [0.25, 0.5, 0.75]
## Para descer, a fração precisa cair esta distância abaixo do limiar (3 pontos).
@export var hysteresis: float = 0.03
## Multiplicador de velocidade por faixa.
@export var speed_multipliers: Array[float] = [1.0, 1.0, 0.85, 0.65]
## Multiplicador do cooldown de ataque por faixa.
@export var attack_cooldown_multipliers: Array[float] = [1.0, 1.0, 1.0, 1.5]
## Faixa em que a criatura faz pausas.
@export var pause_band: int = 3
## A cada `pause_period` segundos, para por `pause_duration`.
@export var pause_period: float = 4.0
@export var pause_duration: float = 0.8


func max_band() -> int:
	return thresholds.size()


## Nova faixa para a fração atual, dada a faixa anterior (histerese).
func next_band(current: int, fraction: float) -> int:
	var band := clampi(current, 0, max_band())
	while band < max_band() and fraction >= thresholds[band]:
		band += 1
	while band > 0 and fraction < thresholds[band - 1] - hysteresis:
		band -= 1
	return band


func speed_multiplier(band: int) -> float:
	return speed_multipliers[clampi(band, 0, speed_multipliers.size() - 1)]


func attack_cooldown_multiplier(band: int) -> float:
	return attack_cooldown_multipliers[clampi(band, 0, attack_cooldown_multipliers.size() - 1)]
