# SPDX-License-Identifier: MIT
class_name SaveMigrations
extends RefCounted
## Migrações do envelope do save (ADR-002): funções puras encadeadas, de `Dictionary` para
## `Dictionary`, uma por salto de versão (`v1_to_v2`, ...). Congeladas no tempo: não leem registry,
## cena nem classe de jogo, porque esses mudam. Rodam em memória; o arquivo só é regravado no
## próximo save. Cada versão tem uma fixture em `tests/fixtures/saves/vN.json` que nunca é removida.

## Aninhamento acima disto não é save: é ataque ou lixo. Dado real tem uns 8 níveis.
const MAX_DEPTH := 32

## Versão do FORMATO do envelope (não é a versão do jogo). Só sobe quando o formato muda.
const CURRENT_VERSION := 3


## O dado não aninha além de `MAX_DEPTH`? (Copiar um dado mais fundo estoura a recursão da engine.)
static func is_shallow(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	if typeof(value) == TYPE_DICTIONARY:
		for item: Variant in (value as Dictionary).values():
			if not is_shallow(item, depth + 1):
				return false
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if not is_shallow(item, depth + 1):
				return false
	return true


## Tabela de saltos: chave N = função que leva da versão N para N+1.
static func steps() -> Dictionary:
	return {1: v1_to_v2, 2: v2_to_v3}


## v2 guarda no `world` o estado dos nós de recurso (MUN-02) e o contador de respawns (SOB-01). Um
## save v1 não tinha nós colhidos: todos nascem cheios, e o contador começa em 0. `life` (em
## `players`) já existia na v1 e não muda.
static func v1_to_v2(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	if typeof(next.get("world")) != TYPE_DICTIONARY:
		return next  # `world` que não é dicionário continua inválido: a validação do envelope recusa
	var world: Dictionary = next["world"]
	if not world.has("resource_nodes"):
		world["resource_nodes"] = []
	if not world.has("respawn_count"):
		world["respawn_count"] = 0
	return next


## v3 guarda no dino o dono (`owner_player_id`, ADR-003: o `player_id` do personagem), quem alimentou por
## último (`feeder_player_id`) e a ordem (`state_machine.order`, CRI-05). Um save v2 não tinha nada disso:
## o domesticado vira do primeiro jogador do save e fica ("STAY", como o v2 já se comportava; congelada:
## não usa o enum do jogo); o selvagem com domesticação em andamento (progresso ou comida na criatura)
## ganha o primeiro jogador como quem alimentou, para não terminar domado sem dono. Selvagem sem andamento
## não ganha nada. Nada mais muda.
static func v2_to_v3(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	var player_id := "local"
	for entry: Variant in _list_of(next.get("players")):
		if typeof(entry) == TYPE_DICTIONARY:
			player_id = SafeRead.text((entry as Dictionary).get("player_id"), player_id)
			break
	for entry: Variant in _list_of(next.get("entities")):
		if typeof(entry) != TYPE_DICTIONARY or typeof((entry as Dictionary).get("state")) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = (entry as Dictionary)["state"]
		var machine: Variant = state.get("state_machine")
		var tamed: bool = typeof(machine) == TYPE_DICTIONARY and SafeRead.flag((machine as Dictionary).get("is_tamed"), false)
		if tamed:
			if not state.has("owner_player_id"):
				state["owner_player_id"] = player_id
			if not (machine as Dictionary).has("order"):
				(machine as Dictionary)["order"] = "STAY"
		if (tamed or _taming_started(state)) and not state.has("feeder_player_id"):
			state["feeder_player_id"] = player_id
	return next


## Tem domesticação em andamento: progresso acima de 0 ou algum item no inventário da criatura.
static func _taming_started(state: Dictionary) -> bool:
	var taming: Variant = state.get("taming")
	if typeof(taming) == TYPE_DICTIONARY:
		var progress: Variant = (taming as Dictionary).get("progress")
		if (typeof(progress) == TYPE_FLOAT or typeof(progress) == TYPE_INT) and progress > 0:
			return true
	var inventory: Variant = state.get("inventory")
	if typeof(inventory) == TYPE_DICTIONARY:
		for slot: Variant in _list_of((inventory as Dictionary).get("slots")):
			if typeof(slot) == TYPE_DICTIONARY and not (slot as Dictionary).is_empty():
				return true
	return false


static func _list_of(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


## Leva `data` até `target` encadeando os saltos de `table`. Devolve uma cópia; o original não muda.
## Falta de um salto no caminho, ou um salto que não devolve dicionário, resulta em `{}` (recusa).
static func migrate(data: Dictionary, target: int = CURRENT_VERSION, table: Dictionary = steps()) -> Dictionary:
	if not is_shallow(data):
		return {}
	var result := data.duplicate(true)
	var version := SafeRead.integer(result.get("format_version"), 0, 1, target)
	if version == 0:
		return {}
	while version < target:
		var step: Variant = table.get(version)
		if typeof(step) != TYPE_CALLABLE or not (step as Callable).is_valid():
			return {}
		var next: Variant = (step as Callable).call(result)
		if typeof(next) != TYPE_DICTIONARY:
			return {}
		result = next
		version += 1
		result["format_version"] = version
	result["format_version"] = version
	return result
