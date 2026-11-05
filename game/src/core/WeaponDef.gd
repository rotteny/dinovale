# SPDX-License-Identifier: MIT
class_name WeaponDef
extends Resource
## Arma do jogador: dado puro. Vem de `res://data/weapons/`.

@export var id: String = ""
@export var display_name: String = ""
@export var damage: float = 0.0
@export var torpor: float = 0.0
@export var cooldown: float = 0.5
