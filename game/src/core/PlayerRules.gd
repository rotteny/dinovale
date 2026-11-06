# SPDX-License-Identifier: MIT
class_name PlayerRules
extends Resource
## Números do jogador, só dados (AGENTS.md: nada de balanceamento no código). Valores em
## `res://data/balance/player_rules.tres`. Quem usa: `Player`, `StaminaComponent`, `Items`.

## Queda de saciedade por segundo do JOGADOR (GDD 5.10: 0,2/s, 500 s ou 8,3 min de cheio a zero).
## Os 0,1/s do GDD são do dino domado e ficam nos dados dele.
@export var hunger_decay_per_second: float = 0.2
## Com a saciedade nesta fração do máximo (ou menos) a HUD avisa de fome, antes de o dano começar
## (premissa: 25%, ou 125 s antes de zerar a 0,2/s).
@export_range(0.01, 1.0) var hunger_warning_ratio: float = 0.25
## Recarga, em segundos, depois de comer (GDD 5.2, premissa).
@export var food_cooldown: float = 0.5
## Recarga, em segundos, da troca de equipamento pela tecla (GDD 5.2, premissa).
@export var equip_cooldown: float = 0.3
## Abaixo desta fração do máximo de stamina o jogador está ofegante (GDD 5.7).
@export_range(0.01, 1.0) var winded_ratio: float = 0.25
## Saciedade devolvida por 1 unidade, por id de item. Item ausente não é comida.
## Baga 25 é premissa do GDD 5.1; carne e samambaia são placeholders até o balanceamento.
@export var hunger_restore: Dictionary[String, float] = {}


## Hora de avisar de fome? Vale também com a saciedade zerada.
func is_hungry(current: float, maximum: float) -> bool:
	return maximum > 0.0 and current <= maximum * hunger_warning_ratio


func hunger_restore_of(item_id: String) -> float:
	return maxf(hunger_restore.get(item_id, 0.0), 0.0)
