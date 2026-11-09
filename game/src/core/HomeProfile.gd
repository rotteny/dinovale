# SPDX-License-Identifier: MIT
class_name HomeProfile
extends Resource
## Marca que a espécie tem toca (null em `DinoBaseStats.home` = sem toca: passeia livre, como sempre). Os números ficam
## em `HomeRules`; aqui só se liga a espécie a eles.

@export var rules: HomeRules = preload("res://data/balance/home_rules.tres")
## O bando nasce na toca que a vaga do mapa indica (`den`); falso = nasce onde a semente sortear.
@export var uses_den: bool = true
