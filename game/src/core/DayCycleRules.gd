# SPDX-License-Identifier: MIT
class_name DayCycleRules
extends Resource
## Números do ciclo de dia e noite (SOB-03, E9), só dados em `res://data/balance/day_cycle_rules.tres`. A duração do
## ciclo inteiro é padrão aqui e o operador a troca pelo `ServerRules` (`ciclo_dia_s`). As faixas são PARTES do ciclo:
## 7 de dia, 1 de entardecer, 3 de noite e 1 de amanhecer valem 12 min com o ciclo de 720 s. O tempo vem do
## `WorldClock` (parado na pausa). Quem lê: `DayCycle` (lógica), `WorldAuthority` (percepção) e `DayNightView` (tinta e luz).

## Duração do ciclo inteiro, em segundos de jogo (12 min).
@export_range(60.0, 7200.0) var cycle_seconds: float = 720.0
@export_group("Faixas (partes do ciclo)")
@export_range(0.1, 100.0) var day_parts: float = 7.0
@export_range(0.1, 100.0) var dusk_parts: float = 1.0
@export_range(0.1, 100.0) var night_parts: float = 3.0
@export_range(0.1, 100.0) var dawn_parts: float = 1.0
@export_group("Regra")
## Percepção do Agressivo à noite: só ela cresce; a velocidade e a desistência da perseguição não mudam (spec E9).
@export_range(1.0, 3.0) var night_perception_multiplier: float = 1.5
@export_group("Tinta (multiplica a cor do mundo)")
@export var day_tint: Color = Color(1.0, 1.0, 1.0)
@export var dusk_tint: Color = Color(1.0, 0.8, 0.66)
@export var night_tint: Color = Color(0.42, 0.48, 0.74)
@export var dawn_tint: Color = Color(0.86, 0.82, 0.92)
## A tinta nunca fica abaixo disto em nenhum canal: sprite de 16 px tem de continuar legível, a noite não vai a preto.
@export_range(0.2, 1.0) var min_tint_channel: float = 0.35
## Janela, em segundos, no fim de cada faixa em que a tinta caminha para a da próxima (a faixa lógica troca seca).
@export_range(0.0, 600.0) var blend_seconds: float = 20.0
@export_group("Luz do jogador")
## Raio da luz ao redor do jogador, em tiles; devolve a cor do mundo no centro e cai até a tinta na borda.
@export_range(1.0, 32.0) var light_radius_tiles: float = 5.0
## Raio da luz da Fogueira, em tiles (GDD 5.12 e SOB-03: 4 tiles); a mesma luz do jogador, só que fixa na peça.
@export_range(1.0, 32.0) var campfire_light_radius_tiles: float = 4.0
