# SPDX-License-Identifier: MIT
class_name PredationProfile
extends Resource
## Como uma espécie caça (M1 etapa 5b, `m1-ameaca-e-corpo.md` seção 10), só dados. Espécie com perfil caça; sem perfil
## (null em `DinoBaseStats.predation`), não. O alcance NÃO está aqui: vem da percepção de agressividade da espécie.
## Números de convivência do mundo (piso do bando, reposição, escudo do dono) ficam em `PredationRules`.

@export_group("Presa")
## Tipos de atacante (`TamingRules.ATTACKER_*`) que viram presa. Carnívoro nunca é presa de carnívoro (`DinoRelation`).
@export var prey_kinds: Array[String] = ["herbivore"]
## Espécies (id) que não são presa mesmo com o tipo certo.
@export var prey_exclude_ids: Array[String] = []
## Quantos portes acima do dele ainda é presa (0 = igual ou menor).
@export_range(0, 2) var max_prey_size_delta: int = 0
## Com tantos acordados do bando a `PredationRules.pack_radius_tiles`, o porte da presa sobe um. 0 = desligado.
@export_range(0, 8) var pack_size_bonus_min_members: int = 0
@export_group("Escolha do alvo")
@export_range(0.05, 5.0) var reevaluate_s: float = 0.5
@export_range(0.0, 30.0) var lock_min_seconds: float = 2.0
## Histerese: o alvo novo precisa estar a menos de tanto vezes a distância do atual.
@export_range(0.1, 1.0) var switch_ratio: float = 0.7
## A presa travada a até tantos tiles (ou já mordida) é combate: o jogador deixa de ser candidato.
@export_range(0.5, 16.0) var engage_tiles: float = 4.0
@export_range(1.0, 300.0) var hunt_max_seconds: float = 40.0
@export_range(0.0, 600.0) var fail_cooldown_s: float = 60.0
@export_range(0.0, 30.0) var no_sight_seconds: float = 5.0
## O jogador causou dano ao caçador: larga a presa e vira o jogador (o "ignorar" não vira escudo).
@export var switch_to_player_on_damage: bool = true
@export_group("Refeição")
@export_range(0.0, 30.0) var eat_seconds_per_meat: float = 2.0
@export_range(0.0, 120.0) var eat_seconds_max: float = 20.0
@export_range(0.0, 600.0) var sated_seconds_per_meat: float = 60.0
@export_range(0.0, 3600.0) var sated_max_seconds: float = 600.0
@export_group("Mordida")
## A mordida que fere atrasa a presa: velocidade x fator por tantos segundos.
@export_range(0.1, 1.0) var wound_slow_factor: float = 0.5
@export_range(0.0, 30.0) var wound_slow_seconds: float = 3.0
## Vida abaixo desta fração encerra a caçada (só contra presa).
@export_range(0.0, 0.9) var retreat_health_ratio: float = 0.25


func eat_seconds(meat: float) -> float:
	return minf(eat_seconds_per_meat * maxf(meat, 0.0), eat_seconds_max)


func sated_seconds(meat: float) -> float:
	return minf(sated_seconds_per_meat * maxf(meat, 0.0), sated_max_seconds)
