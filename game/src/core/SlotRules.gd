# SPDX-License-Identifier: MIT
class_name SlotRules
extends Resource
## Slots do inventário do jogador (GDD 5.21, CRI-42), só dados (`res://data/balance/slot_rules.tres`). O slot limita a
## variedade; o Peso (`CarryRules`) limita a massa. Quem usa: `Items` (o catálogo expõe `Items.slots`) e `Player`.

## Posições da grade do jogador (o limite de variedade). Pilha de comida, material e Ração ocupa uma posição.
@export_range(1, 64) var player_slots: int = 4
## Posições do cinto: ferramentas e armas (os itens com `belt` no catálogo), FORA da grade. Contam no Peso, não no slot.
@export_range(0, 8) var belt_slots: int = 4
