# SPDX-License-Identifier: MIT
class_name DinoBaseStats
extends Resource
## Atributos base de uma criatura, no nível base (`DinoLevelRules.base_level`).
## Precursor do `SpeciesDef` (ADR-003): quando ele existir, estes campos migram para lá.

@export var id: String = "placeholder_dino"
@export var base_health: float = 100.0
## Dano do ataque do dino (sem uso até existir carnívoro).
@export var base_damage: float = 4.0
@export var base_torpor: float = 100.0
## Refeições para domesticar no nível base, com dificuldade 1,0.
@export var base_meals: int = 5
@export var difficulty: float = 1.0
## Caixa de colisão do corpo, em pixels (largura, altura). O corpo a lê ao nascer.
@export var hitbox_size: Vector2 = Vector2(24.0, 16.0)
