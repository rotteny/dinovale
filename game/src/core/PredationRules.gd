# SPDX-License-Identifier: MIT
class_name PredationRules
extends Resource
## Números de convivência da predação (M1 etapa 5b, seção 10.4 e 10.5), só dados em
## `res://data/balance/predation_rules.tres`. Os números de cada caçador ficam no `PredationProfile` da espécie.

@export_group("Ecossistema")
## Bando com tantos vivos ou menos não é presa.
@export_range(0, 8) var herd_floor_alive: int = 2
## Cada vaga vazia de um bando com vivos renasce um membro a cada tanto tempo (relógio do mundo).
@export_range(1.0, 86400.0) var member_regen_seconds: float = 600.0
## Presa a menos de tantos tiles de uma região de nascimento (`RespawnRules`) está a salvo.
@export_range(0.0, 64.0) var spawn_safe_margin_tiles: float = 8.0
@export_group("Combate")
## Presa travada com o carnívoro a menos de tantos tiles foge (o domado também).
@export_range(1.0, 32.0) var prey_alarm_tiles: float = 6.0
## Presa a até tantos tiles do jogador não toma o alvo de quem já o persegue.
@export_range(0.0, 16.0) var owner_shield_tiles: float = 4.0
## Empate de distância (fração): o jogador vence.
@export_range(0.0, 0.5) var tie_ratio: float = 0.05
## Raio, em tiles, em que os do mesmo bando contam como "acordados juntos" para o bônus de porte.
@export_range(1.0, 32.0) var pack_radius_tiles: float = 8.0
## Depois de a caçada a um domado acabar, o aviso `tamed_attacked` rearma em tantos segundos.
@export_range(0.0, 600.0) var tamed_attacked_rearm_s: float = 30.0
## Quanto a presa em fuga segue fugindo sem a ordem do caçador ser renovada.
@export_range(0.1, 5.0) var flee_hold_seconds: float = 0.6
