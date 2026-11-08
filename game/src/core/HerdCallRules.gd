# SPDX-License-Identifier: MIT
class_name HerdCallRules
extends Resource
## A chamada do bando (M1, `m1-ameaca-e-corpo.md` seção 3), só dados. Valores em `res://data/balance/herd_call_rules.tres`.
## Quem usa: `HerdCall` (a autoridade escolhe e atrasa os ajudantes) e a máquina do ajudante (o teto de tempo).

## Membros do mesmo bando a até tantos tiles do golpeado ouvem a chamada.
@export_range(1.0, 32.0) var call_radius_tiles: float = 8.0
## Atraso entre o golpe e a entrada do ajudante.
@export_range(0.0, 5.0) var call_delay_s: float = 0.5
## Quantos ajudantes no máximo por bando (os mais próximos do atacante).
@export_range(0, 8) var max_helpers: int = 2
## Teto de tempo bravo do ajudante, contado da entrada. Se ele mesmo é golpeado, vira principal e o teto cai.
@export_range(1.0, 120.0) var helper_max_seconds: float = 12.0


func radius_px(tile_px: float) -> float:
	return call_radius_tiles * tile_px
