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

## Alcance próprio da arma em tiles; 0 = usa o `reach_tiles` das regras de ação (a Lança é mais curta: 1,8).
@export_range(0.0, 8.0) var reach_tiles: float = 0.0
## Stamina gasta por golpe (GDD 5.4). Ainda não cobrada: o campo é o dado; a cobrança entra com o combate (M1).
@export_range(0.0, 50.0) var stamina_cost: float = 0.0

## A arma corta carcaça (a Lança): esfolar com ela não machuca a mão e gasta 1 de durabilidade por carcaça esvaziada.
@export var cuts_carcass: bool = false
## Multiplicador do tempo de esfolar com esta arma (a Lança: 0,5, de 3 s e 6 s para 1,5 s e 3 s). 1 = como à mão.
@export_range(0.1, 1.0) var skin_seconds_factor: float = 1.0
