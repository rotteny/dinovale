# SPDX-License-Identifier: MIT
class_name ServerRulesDefaults
extends RefCounted
## As Resources de onde o `ServerRules` tira o padrão de cada chave (ADR-004): agrupá-las aqui evita que o
## `parse` dependa de `preload`, e os testes podem passar outras. O host (`Main`) monta com as do jogo.

var respawn: RespawnRules
var world: WorldRules
var taming: TamingRules


func _init(respawn_rules: RespawnRules, world_rules: WorldRules, taming_rules: TamingRules) -> void:
	respawn = respawn_rules
	world = world_rules
	taming = taming_rules
