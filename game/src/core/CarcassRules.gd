# SPDX-License-Identifier: MIT
class_name CarcassRules
extends Resource
## Números das carcaças do mundo (GDD 5.6), só dados. Valores em `res://data/balance/carcass_rules.tres`
## (os padrões abaixo só valem para um recurso novo e vazio). Quem usa: `CarcassField`.

## Quanto tempo a carcaça fica fresca, em segundos (10 min); depois some.
@export_range(10.0, 3600.0) var fresh_seconds: float = 600.0
## No máximo de carcaças no mundo; a mais antiga some quando passa disso.
@export_range(1, 64) var max_carcasses: int = 8
