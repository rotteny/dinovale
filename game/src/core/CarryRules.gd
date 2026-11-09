# SPDX-License-Identifier: MIT
class_name CarryRules
extends Resource
## Peso: capacidade de carga do jogador e massa de cada item (GDD 5.1, PRO-09), só dados. Valores em
## `res://data/balance/carry_rules.tres`. Quem usa: `Items` (preenche `ItemDef.weight`) e `Player` (o limite do inventário).

## Capacidade de carga do jogador, em kg. Passou disso, nada mais entra (sem lentidão na 0.2).
@export_range(1.0, 1000.0) var capacity_kg: float = 50.0
## Peso de UMA unidade de cada item, em kg. Item sem entrada pesa 0 (um teste confere que o catálogo inteiro tem).
@export var item_weights: Dictionary[String, float] = {}


## Peso de uma unidade de `item_id`, em kg (0 se desconhecido).
func weight_of(item_id: String) -> float:
	return maxf(float(item_weights.get(item_id, 0.0)), 0.0)


## Capacidade em gramas inteiras.
func capacity_grams() -> int:
	return roundi(capacity_kg * 1000.0)
