# SPDX-License-Identifier: MIT
class_name CraftRules
extends Resource
## Regras de fabricação e de colocação de peças (E7a). Valores em `res://data/balance/craft_rules.tres`.

## Distância máxima (em tiles) do jogador à Bancada para fabricar nela (GDD: 2 tiles).
@export_range(0.5, 8.0) var workbench_reach_tiles: float = 2.0
## Distância máxima (em tiles) do jogador ao ponto onde coloca uma peça.
@export_range(0.5, 8.0) var place_reach_tiles: float = 3.0
## Teto de Bancadas no mundo (dado de fora não é confiável: save e pedido).
@export_range(1, 1000) var max_workbenches: int = 64
