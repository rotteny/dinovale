# SPDX-License-Identifier: MIT
class_name CampRules
extends Resource
## Números da base (E12, PRO-18 e SOB-13), só dados em `res://data/balance/camp_rules.tres`: a Fogueira que assa, e a espera da
## Cama. Limites por jogador (3 Camas, 1 Saco) ficam na peça (`PieceDef.max_per_owner`) e a luz da Fogueira no ciclo do dia
## (`DayCycleRules.campfire_light_radius_tiles`). Quem lê: `CampService` (assar) e `RespawnPointService` (Cama e Saco).

## Segundos para assar 1 carne (GDD 5.12: 2 s por carne).
@export_range(0.1, 60.0) var cook_seconds: float = 2.0
## Quantas carnes 1 madeira de combustível assa (GDD 5.12: 1 madeira para 4).
@export_range(1, 100) var meat_per_wood: int = 4
## Distância máxima (tiles) entre o jogador e a Fogueira para começar e manter o assar.
@export_range(0.5, 10.0) var fire_reach_tiles: float = 2.0
## Itens do assar: crua, assada e combustível (ids estáveis).
@export var raw_item: String = "meat"
@export var cooked_item: String = "cooked_meat"
@export var fuel_item: String = "wood"
## Espera de uma Cama entre respawns, em segundos de mundo rodando (GDD 12.3: 60 s, por Cama).
@export_range(0.0, 3600.0) var bed_wait_seconds: float = 60.0
