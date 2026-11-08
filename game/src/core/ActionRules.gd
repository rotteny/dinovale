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

## Escolha do alvo do golpe (`AttackTargeting`). 0 = meio-plano da frente: quem está de lado a 90 graus ainda conta;
## quem está atrás, não. A autoridade usa o mesmo valor para recusar golpe em quem está atrás.
@export_range(-1.0, 1.0) var front_dot_min: float = 0.0
## Vantagem de distância (px) que um candidato precisa ter sobre o alvo atual para tomar o lugar dele (destaque estável).
@export_range(0.0, 32.0) var hysteresis_px: float = 6.0

## Raio (px) em volta do cursor em que uma criatura ou objeto conta como "sob o cursor" (golpe e menu do mouse).
## Anti-spam da coleta: pedido repetido no MESMO nó dentro deste tempo (s) é recusado ("em recarga"). Não há espera
## entre nós diferentes: coletar um arbusto nunca trava o vizinho. Curto de propósito (<= 0,15 s).
@export_range(0.0, 0.15) var gather_repeat_seconds: float = 0.12
@export_range(2.0, 48.0) var mouse_pick_radius_px: float = 12.0


func reach_px() -> float:
	return reach_tiles * tile_size


func command_reach_px() -> float:
	return command_reach_tiles * tile_size

