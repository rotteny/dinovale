# SPDX-License-Identifier: MIT
class_name DownedRules
extends Resource
## Números do jogador caído e do corpo (M1, etapa 6; `m1-ameaca-e-corpo.md` seção 5), só dados. Valores em
## `res://data/balance/downed_rules.tres` (os padrões abaixo só valem para um recurso novo e vazio).
## Quem usa: `DownedComponent`, `Player`, `WorldAuthority` e `CorpseField`. Quem pode atacar o caído é do
## perfil de cada espécie (`ThreatProfile.attacks_downed`), não daqui.

## Quanto dura o desmaio, em segundos [premissa, decisão D3; o playtest decide dentro de 8 a 20].
@export_range(1.0, 60.0) var downed_seconds: float = 10.0
## Vida do caído quando a vida de pé chegou a 0 (decisão D1: vira caído, não morte) [premissa, D3].
@export_range(1.0, 500.0) var downed_health: float = 70.0
## Segundos sem dano depois de acordar [premissa].
@export_range(0.0, 10.0) var wake_grace_seconds: float = 2.0
## Torpor com que o jogador acorda (GDD 5.10).
@export_range(0.0, 100.0) var wake_torpor: float = 50.0
## Vida mínima ao acordar: sobrou menos que isto, sobe a isto [premissa].
@export_range(1.0, 100.0) var wake_min_health: float = 20.0
## Torpor em que o jogador desmaia (a barra do jogador vai de 0 a isto).
@export_range(1.0, 1000.0) var max_torpor: float = 100.0
## Subida do torpor por segundo com a fome zerada (GDD 5.10: +2/s líquido, 50 s de 50 a 100).
@export_range(0.0, 20.0) var starving_torpor_per_second: float = 2.0
## Descida do torpor por segundo com fome acima de zero [premissa: o GDD só diz que comer corta a subida].
@export_range(0.0, 20.0) var fed_torpor_per_second: float = 1.0
## Quanto o corpo fica no chão, em minutos de MUNDO RODANDO (GDD 12.4; decisão D4: o relógio do mundo não corre com o jogo fechado).
@export_range(1.0, 120.0) var body_minutes: float = 10.0


## Duração do corpo em segundos do relógio do mundo.
func body_seconds() -> float:
	return body_minutes * 60.0
