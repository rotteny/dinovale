# SPDX-License-Identifier: MIT
class_name SlotRules
extends Resource
## Slots do inventário do jogador (GDD 5.21, CRI-42), só dados (`res://data/balance/slot_rules.tres`). O slot limita a
## variedade; o Peso (`CarryRules`) limita a massa. Quem usa: `Items` (o catálogo expõe `Items.slots`) e `Player`.

## Posições da grade do jogador (o limite de variedade). Pilha de comida, material e Ração ocupa uma posição.
@export_range(1, 64) var player_slots: int = 4
## Posições do cinto: ferramentas e armas (os itens com `belt` no catálogo), FORA da grade. Contam no Peso, não no slot.
@export_range(0, 8) var belt_slots: int = 4
## Slots que cada bolsa soma à grade (GDD 5.21, CRI-42 parte 2): id do item da bolsa -> bônus. Há uma só vaga de bolsa e vale
## a equipada (os bônus não somam). Bolsa sem entrada aqui não soma nada.
@export var bag_slots: Dictionary[String, int] = {}


## Slots a mais que a bolsa dá (0 se `item_id` não é bolsa).
func bag_bonus(item_id: String) -> int:
	return maxi(int(bag_slots.get(item_id, 0)), 0)


## Tamanho da grade com a bolsa `bag_id` na vaga ("" = vaga vazia).
func grid_size_for(bag_id: String) -> int:
	return player_slots + bag_bonus(bag_id)
