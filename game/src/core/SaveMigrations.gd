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
const CURRENT_VERSION := 5
## Teto do `entity_id` e do `next_entity_id` lidos de arquivo, na migração e na carga (um valor só para os dois lados).
const MAX_ENTITY_ID := 1 << 30

## Revisão do mapa na primeira exportação com ids (`content_hash` do `lunata.json` de então) e a numeração que ela
## deu aos pontos (ADR-007): selvagem pelo índice do `populate` (`w<i>`), nó pela lista na ordem alfabética dos tipos
## (`n<k>`). Constantes CONGELADAS: nunca leem o mapa de hoje.
const V4_MAP_REVISION := 2
const FIRST_ID_MAP_HASH := "203bc7d1abf04874"
## Tipo de nó -> [id do que antecede o primeiro, quantos há]; o id de `<tipo>_<k>` é `n<antes + k>`.
const V4_NODE_BLOCKS := {
	"bush_baga": [0, 91], "bush_sono": [91, 40], "iron_seam": [131, 18],
	"loose_stone": [149, 24], "rock": [173, 142], "tree": [315, 1029],
}
const V4_SPAWN_COUNT := 117
const LOCAL_PLAYER_ID_V4 := "local"
const SEXES := ["f", "m"]


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
	return {1: v1_to_v2, 2: v2_to_v3, 3: v3_to_v4, 4: _v4_to_v5_with_new_player_id}


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


## v4: o mapa deixa de ser o retângulo de 640x360 e passa a ser a ilha Lunata (`world.map_id` "lunata",
## `world.map_revision`), ESTÁTICO e fora do save. `world.resource_nodes` leva só os nós esgotados ou parciais
## (o resto nasce cheio) e `world.wild` leva o delta dos selvagens. Um save v3 é do mapa antigo: os ids dos nós
## não existem mais, então a migração ZERA `resource_nodes` e põe `wild` vazio; a revisão 0 nunca bate com a do
## mapa, e quem carrega não aplica nós nem selvagens de outra revisão. As coordenadas também não valem na ilha:
## `world.legacy_coordinates` faz quem carrega mandar o jogador (e a criatura, se ficar fora) ao ponto seguro.
## A migração é pura e não conhece o mapa. Jogador, inventário, dino e domesticação passam intactos.
static func v3_to_v4(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	if typeof(next.get("world")) != TYPE_DICTIONARY:
		return next  # `world` que não é dicionário continua inválido: a validação do envelope recusa
	var world: Dictionary = next["world"]
	world["map_id"] = "lunata"
	world["map_revision"] = 0
	world["resource_nodes"] = []
	world["wild"] = []
	world["legacy_coordinates"] = true
	return next




## Passo da tabela: o id aleatório do jogador vem de fora da função pura (`v4_to_v5`), mas o salto de `steps()` tem de
## trazer um (`Crypto`, 16 bytes em 32 hex; ADR-003). Fora da simulação: só roda ao abrir um save v4.
static func _v4_to_v5_with_new_player_id(data: Dictionary) -> Dictionary:
	return v4_to_v5(data, Crypto.new().generate_random_bytes(16).hex_encode())


## v5 (ADR-006 e ADR-007), tudo numa migração só e pura (não lê mapa nem `Resource`):
## - delta de selvagem `{"index": i}` vira `{"id": "w<i>"}` e nó `<tipo>_<k>` vira `n<...>`, só se o save é da revisão 2
##   do mapa e sem coordenadas legadas; senão o delta de selvagens e de nós é descartado (domados em `entities` ficam).
## - `map_revision` vira texto (o hash da primeira exportação com ids, ou o número antigo como texto).
## - `world.time` = 0; nó `respawn_left = r` vira `due_at = r`; carcaça `age = a` vira `born_at = -a`.
## - `player_id` "local" vira `new_player_id` (em `players`, `owner_player_id`, `feeder_player_id`) e `world.local_player_id`
##   aponta para o jogador local; sem `new_player_id`, o id fica.
## - todo dino de `entities` sem `sex` ganha o sexo determinístico `["sex", "v4", entity_id]` (idempotente).
## - `world.next_entity_id` passa a ser maior que todo id de `entities`.
static func v4_to_v5(data: Dictionary, new_player_id: String = "") -> Dictionary:
	var next := data.duplicate(true)
	if typeof(next.get("world")) != TYPE_DICTIONARY:
		return next  # `world` que não é dicionário continua inválido: a validação do envelope recusa
	var world: Dictionary = next["world"]
	if typeof(world.get("map_revision")) == TYPE_STRING and world.has("time"):
		return next  # já é v5 (revisão em texto e relógio): migrar de novo zeraria o relógio e os prazos
	var same_map := SafeRead.text(world.get("map_id"), "") == "lunata" \
			and typeof(world.get("map_revision")) != TYPE_STRING \
			and SafeRead.integer(world.get("map_revision"), -1, -1, 1 << 30) == V4_MAP_REVISION \
			and not SafeRead.flag(world.get("legacy_coordinates"), false)
	if typeof(world.get("map_revision")) != TYPE_STRING:  # já em texto = dado de um v5 mal numerado: não mexe
		world["map_revision"] = FIRST_ID_MAP_HASH if same_map else str(SafeRead.integer(world.get("map_revision"), 0, 0, 1 << 30))
	world["wild"] = _wild_by_id(SafeRead.list(world.get("wild"))) if same_map else []
	world["resource_nodes"] = _nodes_by_id(SafeRead.list(world.get("resource_nodes"))) if same_map else []
	world["time"] = 0.0
	var carcasses := SafeRead.list(world.get("carcasses"))
	for entry: Variant in carcasses:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("age"):
			var age := SafeRead.number((entry as Dictionary).get("age"), 0.0, 0.0, SafeRead.MAX_SAVED)
			(entry as Dictionary).erase("age")
			(entry as Dictionary)["born_at"] = -age
	_rename_local_player(next, world, new_player_id)
	var highest := 2
	for entry: Variant in _list_of(next.get("entities")):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entity_id := SafeRead.integer((entry as Dictionary).get("id"), 0, 0, MAX_ENTITY_ID)
		highest = maxi(highest, entity_id)
		var state: Variant = (entry as Dictionary).get("state")
		if typeof(state) == TYPE_DICTIONARY and not (state as Dictionary).has("sex"):
			(state as Dictionary)["sex"] = v4_sex(entity_id)
	world["next_entity_id"] = maxi(SafeRead.integer(world.get("next_entity_id"), 0, 0, MAX_ENTITY_ID), highest + 1)
	return next


## Sexo do domado de um save v4, pelo id da entidade: determinístico, sem ler mapa. O id entra como inteiro (o JSON o
## devolve como número real, e `hash` de 5 e de 5.0 difere).
static func v4_sex(entity_id: int) -> String:
	var rng := SeededRng.new()
	rng.seed_from(["sex", "v4", entity_id])
	return SEXES[rng.next_below(2)]


static func _wild_by_id(entries: Array) -> Array:
	var out: Array = []
	for entry: Variant in entries:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("index"):
			var raw: Variant = (entry as Dictionary)["index"]
			var number := float(raw) if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT else -1.0
			if number >= 0.0 and number == floorf(number) and number < V4_SPAWN_COUNT:
				var converted: Dictionary = (entry as Dictionary).duplicate()
				converted.erase("index")
				converted["id"] = "w%d" % int(number)
				out.append(converted)
				continue
		out.append(entry)  # malformada ou fora da lista: segue como veio (a carga a recusa ou a ignora)
	return out


static func _nodes_by_id(entries: Array) -> Array:
	var out: Array = []
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			out.append(entry)
			continue
		var converted: Dictionary = (entry as Dictionary).duplicate()
		var old_id := SafeRead.text(converted.get("id"), "")
		var cut := old_id.rfind("_")
		var kind := old_id.substr(0, cut) if cut > 0 else ""
		var k := old_id.substr(cut + 1).to_int() if cut > 0 and old_id.substr(cut + 1).is_valid_int() else 0
		if V4_NODE_BLOCKS.has(kind) and k >= 1 and k <= int((V4_NODE_BLOCKS[kind] as Array)[1]):
			converted["id"] = "n%d" % (int((V4_NODE_BLOCKS[kind] as Array)[0]) + k)
		if converted.has("respawn_left"):
			converted["due_at"] = converted["respawn_left"]  # `world.time` = 0: o que faltava é o instante
			converted.erase("respawn_left")
		out.append(converted)
	return out


## O `player_id` fixo "local" dá lugar a `new_player_id`; `world.local_player_id` é o do primeiro jogador do save.
static func _rename_local_player(data: Dictionary, world: Dictionary, new_player_id: String) -> void:
	var local := LOCAL_PLAYER_ID_V4
	for entry: Variant in _list_of(data.get("players")):
		if typeof(entry) == TYPE_DICTIONARY:
			local = SafeRead.text((entry as Dictionary).get("player_id"), local)
			break
	if new_player_id == "" or local != LOCAL_PLAYER_ID_V4:
		world["local_player_id"] = local
		return
	world["local_player_id"] = new_player_id
	for entry: Variant in _list_of(data.get("players")):
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).get("player_id") == LOCAL_PLAYER_ID_V4:
			(entry as Dictionary)["player_id"] = new_player_id
	for entry: Variant in _list_of(data.get("entities")):
		var state: Variant = (entry as Dictionary).get("state") if typeof(entry) == TYPE_DICTIONARY else null
		if typeof(state) != TYPE_DICTIONARY:
			continue
		for key: String in ["owner_player_id", "feeder_player_id"]:
			if (state as Dictionary).get(key) == LOCAL_PLAYER_ID_V4:
				(state as Dictionary)[key] = new_player_id
	for entry: Variant in _list_of(world.get("wild")):  # estado de selvagem no delta (feeder) também aponta para o jogador
		var state: Variant = (entry as Dictionary).get("state") if typeof(entry) == TYPE_DICTIONARY else null
		if typeof(state) == TYPE_DICTIONARY and (state as Dictionary).get("feeder_player_id") == LOCAL_PLAYER_ID_V4:
			(state as Dictionary)["feeder_player_id"] = new_player_id


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
