# SPDX-License-Identifier: MIT
class_name CarcassRules
extends Resource
## Números das carcaças do mundo (GDD 5.6), só dados. Valores em `res://data/balance/carcass_rules.tres`
## (os padrões abaixo só valem para um recurso novo e vazio). Quem usa: `CarcassField`.

## Quanto tempo a carcaça fica fresca, em segundos (10 min); depois some.
@export_range(10.0, 3600.0) var fresh_seconds: float = 600.0
## No máximo de carcaças no mundo; a mais antiga some quando passa disso.
@export_range(1, 64) var max_carcasses: int = 8
## Só o dono esfola a carcaça do próprio dino morto por este tempo, em segundos (GDD 5.6: 120 s); depois é de todos.
@export_range(0.0, 3600.0) var owner_exclusive_seconds: float = 120.0
## Esfolar é uma ação com tempo: andar mais que isso, em tiles, a partir de onde começou interrompe (GDD 5.6: 3 tiles).
@export_range(0.5, 16.0) var skin_walk_cancel_tiles: float = 3.0
