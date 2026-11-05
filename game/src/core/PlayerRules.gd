# SPDX-License-Identifier: MIT
class_name PlayerRules
extends Resource
## Números do jogador, só dados (AGENTS.md: nada de balanceamento no código). Valores em
## `res://data/balance/player_rules.tres`. Quem usa: `Player`, `StaminaComponent`, `Items`.

## Queda de saciedade por segundo (GDD 5.1: 0,1/s, cerca de 17 min de cheio a zero).
@export var hunger_decay_per_second: float = 0.1
## Recarga, em segundos, depois de comer (GDD 5.2, premissa).
@export var food_cooldown: float = 0.5
## Recarga, em segundos, da troca de equipamento pela tecla (GDD 5.2, premissa).
@export var equip_cooldown: float = 0.3
## Abaixo desta fração do máximo de stamina o jogador está ofegante (GDD 5.7).
@export_range(0.01, 1.0) var winded_ratio: float = 0.25
## Saciedade devolvida por 1 unidade, por id de item. Item ausente não é comida.
## Baga 25 é premissa do GDD 5.1; carne e samambaia são placeholders até o balanceamento.
@export var hunger_restore: Dictionary[String, float] = {}


func hunger_restore_of(item_id: String) -> float:
	return maxf(hunger_restore.get(item_id, 0.0), 0.0)
