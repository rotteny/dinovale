# SPDX-License-Identifier: MIT
class_name ServerRulesDefaults
extends RefCounted
## As Resources de onde o `ServerRules` tira o padrão de cada chave (ADR-004): agrupá-las aqui evita que o
## `parse` dependa de `preload`, e os testes podem passar outras. O host (`Main`) monta com as do jogo.

var respawn: RespawnRules
var world: WorldRules
var taming: TamingRules
var home: HomeRules
var predation: PredationRules
var day_cycle: DayCycleRules


func _init(respawn_rules: RespawnRules, world_rules: WorldRules, taming_rules: TamingRules,
		home_rules: HomeRules = null, predation_rules: PredationRules = null, day_cycle_rules: DayCycleRules = null) -> void:
	respawn = respawn_rules
	world = world_rules
	taming = taming_rules
	home = home_rules if home_rules != null else preload("res://data/balance/home_rules.tres")
	predation = predation_rules if predation_rules != null else preload("res://data/balance/predation_rules.tres")
	day_cycle = day_cycle_rules if day_cycle_rules != null else preload("res://data/balance/day_cycle_rules.tres")
