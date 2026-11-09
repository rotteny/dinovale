# SPDX-License-Identifier: MIT
class_name ProgressionRules
extends Resource
## Curva de XP, nível e Saber do JOGADOR (E6, PRO-11). Só dados e contas puras: valores em
## `res://data/balance/progression_rules.tres` (AGENTS.md: nada de balanceamento no código). Todos os números são
## [premissa] até o playtest. Sem pontos de atributo (cortados na v0.2): o nível só rende Saber.

## Nível máximo do jogador (`jogador_nivel_max` do GDD 5.16). No teto o XP para de acumular.
@export_range(2, 100) var level_max: int = 20
## XP para sair do nível 1 e acréscimo por nível seguinte: sair do nível L custa `xp_first + xp_step x (L - 1)` (GDD 5.1:
## 810 XP somados até o nível 10 e 3.135 até o 20).
@export_range(1, 10000) var xp_first: int = 30
@export_range(0, 10000) var xp_step: int = 15
## XP por coleta concluída, por fabricação (o gancho existe; fabricar entra na E7a) e por doma: `base + por_nível x nível final`.
@export_range(0, 1000) var xp_per_gather: int = 1
@export_range(0, 1000) var xp_per_craft: int = 2
@export_range(0, 1000) var xp_tame_base: int = 15
@export_range(0, 1000) var xp_tame_per_level: int = 3
## Saber: `saber_per_level` por nível a partir do 2, mais `saber_bonus` nos níveis de `saber_bonus_levels`.
@export_range(0, 100) var saber_per_level: int = 1
@export_range(0, 100) var saber_bonus: int = 1
@export var saber_bonus_levels: Array[int] = [5, 10, 15, 20]
## Segundos do aviso de nível na HUD.
@export_range(0.5, 30.0) var notice_seconds: float = 3.0


## XP que falta para sair de `level` (0 no teto ou em nível inválido).
func xp_to_next(level: int) -> int:
	if level < 1 or level >= level_max:
		return 0
	return xp_first + xp_step * (level - 1)


## XP somado desde o nível 1 até chegar em `level` (conferência da curva).
func xp_total_to_reach(level: int) -> int:
	var total := 0
	for from in range(1, mini(level, level_max)):
		total += xp_to_next(from)
	return total


## Saber que subir PARA `level` rende (o nível 1 não rende nada).
func saber_at(level: int) -> int:
	if level < 2 or level > level_max:
		return 0
	return saber_per_level + (saber_bonus if saber_bonus_levels.has(level) else 0)


## Saber acumulado de quem está em `level` (gasto não entra: veja `ProgressionComponent.saber_free`).
func saber_until(level: int) -> int:
	var total := 0
	for each in range(2, mini(level, level_max) + 1):
		total += saber_at(each)
	return total


## XP de domar um dino que ficou em `final_level`.
func tame_xp(final_level: int) -> int:
	return xp_tame_base + xp_tame_per_level * maxi(final_level, 0)
