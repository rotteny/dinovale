# SPDX-License-Identifier: MIT
class_name TamingRules
extends Resource
## Regras da Eficiência durante a domesticação, só dados. A Eficiência (0 a 100)
## começa em 100 e só cai. Valores em `res://data/balance/taming_rules.tres`.

const ATTACKER_PLAYER := "player"
const ATTACKER_CARNIVORE := "carnivore"
const ATTACKER_HERBIVORE := "herbivore"

## Queda por segundo dormindo.
@export var time_drain_per_second: float = 0.3
## Queda por refeição, por id de comida. Comida ausente da tabela não derruba nada.
@export var meal_drain: Dictionary[String, float] = {}
## Parte fixa da queda por ataque recebido dormindo, por tipo de atacante.
@export var attack_fixed_loss: Dictionary[String, float] = {}
## Queda por 1% da vida máxima perdida no ataque.
@export var loss_per_health_percent: float = 0.5
@export_group("Ronco")
## Raio, em tiles, em que o dormindo em doma é ouvido por quem escuta (círculo, não a elipse da percepção). E3b.
@export_range(0.0, 32.0) var snore_tiles: float = 8.0
## Tiles somados ao ronco por comida (id do item). Vazio: nenhuma comida de hoje muda o ronco; a ração que o fizer entra como linha.
@export var snore_bonus_by_food: Dictionary[String, float] = {}
@export_group("")


func knows_attacker(attacker_kind: String) -> bool:
	return attack_fixed_loss.has(attacker_kind)


func meal_loss(food_id: String) -> float:
	return meal_drain.get(food_id, 0.0)


## `fixo[atacante] + loss_per_health_percent x % da vida máxima perdida`.
## Atacante desconhecido não perde nada (use `knows_attacker` para rejeitá-lo antes).
func attack_loss(attacker_kind: String, health_lost_percent: float) -> float:
	if not knows_attacker(attacker_kind):
		return 0.0
	return attack_fixed_loss[attacker_kind] + loss_per_health_percent * maxf(health_lost_percent, 0.0)


## Raio do ronco de quem está sendo domado com a comida `food_id`.
func snore_range(food_id: String) -> float:
	return snore_tiles + snore_bonus_by_food.get(food_id, 0.0)
