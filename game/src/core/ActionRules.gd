# SPDX-License-Identifier: MIT
class_name ActionRules
extends Resource
## Alcances das ações do jogador validadas pela autoridade, só dados (AGENTS.md: nada de
## balanceamento no código). Valores em `res://data/balance/action_rules.tres`.
## Quem usa: `WorldAuthority`.

## Lado do tile do mapa, em pixels (16 px, ESTILO.md).
@export_range(4, 64) var tile_size: int = 16
## Alcance, em tiles, do centro do jogador ao centro do alvo, para golpe, interação e transferência.
## ADR-001: a autoridade mede a distância real com folga para os raios das áreas (o detector tem
## 22 px e a área da criatura também, então a interação já aparece a 44 px): 3 tiles = 48 px.
@export_range(1.0, 12.0) var reach_tiles: float = 3.0
## Alcance, em tiles, para mandar um domado seguir ou ficar (menu a 2 tiles, GDD 6.11, mais a folga acima).
@export_range(1.0, 12.0) var command_reach_tiles: float = 3.0


func reach_px() -> float:
	return reach_tiles * tile_size


func command_reach_px() -> float:
	return command_reach_tiles * tile_size
