# SPDX-License-Identifier: MIT
class_name GroundItemRules
extends Resource
## Números dos itens soltos no chão, só dados (`res://data/balance/ground_item_rules.tres`). Quem usa: `GroundItemField`,
## `WorldAuthority`. Todos provisórios [premissa] até a `SHIRO` revisar.

## Quanto o item fica no chão antes de sumir, em segundos do relógio do mundo (ADR-006).
@export_range(10.0, 3600.0) var despawn_seconds: float = 300.0
## Teto de itens soltos por área (célula de `area_px`); passando disso, o mais antigo da área some.
@export_range(1, 200) var max_per_area: int = 24
@export_range(32.0, 2048.0) var area_px: float = 256.0
## Distância, do ponto do nó, a que cada pilha cai (px).
@export_range(0.0, 64.0) var scatter_min_px: float = 4.0
@export_range(0.0, 64.0) var scatter_max_px: float = 12.0
## Unidades por pilha ao espalhar: 7 madeiras viram pilhas de até este tamanho.
@export_range(1, 99) var pile_max: int = 3
## Andar até esta distância do item o recolhe sozinho (px).
@export_range(2.0, 64.0) var auto_pickup_px: float = 14.0
## Gancho do co-op: quem largou ou derrubou tem prioridade por estes segundos. 0 = desligado (single-player: qualquer um pega).
@export_range(0.0, 600.0) var owner_seconds: float = 0.0
## Quanto o que a migração de save deixou no chão (inventário antigo maior que o atual) demora a sumir, em segundos do
## relógio do mundo. Bem mais que `despawn_seconds`: o jogador precisa de tempo para abrir espaço e recolher.
@export_range(300.0, 604800.0) var migration_keep_seconds: float = 86400.0
