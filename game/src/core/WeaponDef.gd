# SPDX-License-Identifier: MIT
class_name WeaponDef
extends Resource
## Arma do jogador: dado puro. Vem de `res://data/weapons/`.

@export var id: String = ""
@export var display_name: String = ""
@export var damage: float = 0.0
@export var torpor: float = 0.0
@export var cooldown: float = 0.5
## Dano que o próprio jogador leva por golpe (o Soco: 1; o Bastão: 0). Para no piso de vida das regras.
@export_range(0.0, 20.0) var self_damage: float = 0.0
