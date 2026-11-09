# SPDX-License-Identifier: MIT
class_name MusicRules
extends Resource
## Regras da música, só dados (`res://data/balance/music_rules.tres`): quando a faixa de dia vira a de noite e quanto
## dura a troca. O relógio do mundo (`WorldClock`) só dá os segundos. No jogo a noite vem do `DayCycle` (SOB-03, E9):
## `MusicPlayer.follow_world(clock, cycle)` o usa e esta divisão só vale quando nenhum ciclo é passado (teste, menu).

## Duração de um dia completo (dia + noite), em segundos de jogo.
@export_range(60.0, 7200.0) var day_length_seconds: float = 1200.0
## Fração do dia em que a noite começa (o tempo 0 é o amanhecer); a noite vai até o fim do ciclo.
@export_range(0.1, 0.95) var night_start_fraction: float = 0.6
## Duração do crossfade entre faixas, em segundos (0 troca na hora).
@export_range(0.0, 10.0) var crossfade_seconds: float = 1.5


## O tempo de jogo `world_time` cai na noite? Tempo negativo ou não finito conta como dia.
func is_night(world_time: float) -> bool:
	if not is_finite(world_time) or world_time < 0.0:
		return false
	return fposmod(world_time, day_length_seconds) / day_length_seconds >= night_start_fraction
