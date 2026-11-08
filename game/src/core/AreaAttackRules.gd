# SPDX-License-Identifier: MIT
class_name AreaAttackRules
extends Resource
## Dano em área de uma espécie (`docs/design/corte-v02/bandos-e-dano-em-area.md`, seção 4), só dados. Quem tem
## isto, ao acertar um alvo principal, também acerta quem está perto dele, com a fração do dano que cai com a
## distância ao alvo principal. Só vale para porte Grande (`DinoBaseStats.area_rules`).

## Alcance a partir do alvo principal, em tiles; a esta distância ou mais, a fração é 0.
@export_range(0.1, 16.0) var radius_tiles: float = 3.0
## Até esta distância (tiles) o secundário leva `near_fraction`; dali até o raio, cai em linha reta até 0.
@export_range(0.0, 16.0) var near_tiles: float = 1.0
## Fração do dano do golpe (e do torpor) no secundário mais próximo. Abaixo de 1: o adjacente nunca iguala o principal.
@export_range(0.0, 0.99) var near_fraction: float = 0.6
## Quantos alvos além do principal o golpe acerta no máximo; valem os mais próximos do principal.
@export_range(0, 8) var max_extra_targets: int = 3
## Fração menor que isto não acerta.
@export_range(0.0, 1.0) var min_fraction: float = 0.05


## Fração do dano do golpe que sofre quem está a `distance_tiles` do alvo principal. Nunca cresce com a distância.
func fraction(distance_tiles: float) -> float:
	if distance_tiles < 0.0 or distance_tiles >= radius_tiles:
		return 0.0
	var value := near_fraction
	if distance_tiles > near_tiles and radius_tiles > near_tiles:
		value = near_fraction * (radius_tiles - distance_tiles) / (radius_tiles - near_tiles)
	return value if value >= min_fraction else 0.0
