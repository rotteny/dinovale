# SPDX-License-Identifier: MIT
class_name ServerRules
extends RefCounted
## Regras do mundo que o operador do servidor pode mudar (ADR-004, GDD 13): lidas de `server_rules.json` uma vez, ao
## carregar o mundo, e imutáveis na sessão. As `.tres` seguem sendo o padrão do jogo; este arquivo diz "neste mundo,
## este valor". Só o host lê o arquivo (`load_file`). Valor inválido NUNCA vira o limite: volta ao padrão, com
## aviso em `problems`. O arquivo é do operador: o jogo o escreve só quando ele não existe e nunca o regrava.
##
## Chave nova entra no mesmo commit em que ganha consumidor (ADR-004, "Chaves desta etapa").

const FORMAT_VERSION := 1
const MAX_FILE_BYTES := 16384
const FILE_NAME := "server_rules.json"
const PATH_ARG := "--server-rules="

const KEY_COLLECT := "multiplicador_coleta"
const KEY_RESOURCE_RESPAWN := "respawn_recurso"
const KEY_LEVEL_BANDS := "faixas_de_nivel"
const KEY_PROTECTION := "respawn_protecao_s"
const KEY_HUNGER := "respawn_fome_pct"
const KEY_PLAYER_LOSS := "eficiencia_fixa_ataque_jogador"
const KEY_CARNIVORE_LOSS := "eficiencia_fixa_ataque_carnivoro"
const KEY_PVP := "pvp"
const KEY_DEN_ANCHOR := "toca_ancora_tiles"
const KEY_DEN_PATROL := "toca_ronda_tiles"
const KEY_SNORE := "ronco_tiles"
const KEY_SLEEPER_ALERT := "aviso_dormindo_s"
const KEY_DAY_CYCLE := "ciclo_dia_s"

## Tipo e faixa válida de cada chave de número (contrato, não balanceamento): [mínimo, máximo].
const NUMBER_RANGES: Dictionary = {
	KEY_COLLECT: [0.1, 10.0],
	KEY_RESOURCE_RESPAWN: [0.1, 10.0],
	KEY_PROTECTION: [0.0, 30.0],
	KEY_PLAYER_LOSS: [0.0, 100.0],
	KEY_CARNIVORE_LOSS: [0.0, 100.0],
	KEY_DEN_ANCHOR: [2.0, 128.0],
	KEY_DEN_PATROL: [1.0, 64.0],
	KEY_SNORE: [1.0, 32.0],
	KEY_SLEEPER_ALERT: [0.0, 10.0],
	KEY_DAY_CYCLE: [60.0, 7200.0],
}
const INTEGER_RANGES: Dictionary = {
	KEY_HUNGER: [10, 100],
}
## Id de bioma (ADR-003) -> terreno do `IslandMap`, na ordem em que o arquivo os escreve.
const BIOMES: Dictionary = {
	"campina": IslandMap.GRASSLAND,
	"mata_baixa": IslandMap.WOODLAND,
	"pedreira": IslandMap.QUARRY,
}
const LEVEL_RANGE := [1, 50]
const _INVALID_INT := -(1 << 40)

## Multiplicadores: 1,0 é a identidade (não é número de balanceamento).
var collect_multiplier: float = 1.0
var resource_respawn_rate: float = 1.0
## Terreno do `IslandMap` -> [mínimo, máximo] de nível, só dos biomas do arquivo.
var level_bands: Dictionary[int, Vector2i] = {}
var respawn_protection_seconds: float = 0.0
var respawn_hunger_pct: int = 50
var player_attack_fixed_loss: float = 0.0
var carnivore_attack_fixed_loss: float = 0.0
## PvP: golpe em área de criatura domada acerta domados de OUTRO jogador (o do mesmo dono, nunca). Padrão: desligado.
var pvp: bool = false
## Toca e vigília (E3): raio da âncora e da ronda em tiles, alcance do ronco do dormindo em doma e segundos do "!" de farejada.
var den_anchor_tiles: float = 24.0
var den_patrol_tiles: float = 10.0
var sleeper_snore_tiles: float = 8.0
var sleeper_alert_seconds: float = 1.5
## Dia e noite (E9): duração do ciclo inteiro em segundos de jogo (as faixas são partes dele, `DayCycleRules`).
var day_cycle_seconds: float = 720.0
## Avisos da leitura (chave inválida, desconhecida, arquivo ruim). O host os imprime uma vez com `push_warning`.
var problems: PackedStringArray = PackedStringArray()


## Caminho do arquivo: `--server-rules=<caminho>` nos argumentos de usuário, senão `<pasta do mundo>/server_rules.json`.
## Argumento vazio cai no padrão.
static func path_for(world_dir: String, user_args: PackedStringArray) -> String:
	for arg in user_args:
		if arg.begins_with(PATH_ARG) and arg.length() > PATH_ARG.length():
			return arg.substr(PATH_ARG.length())
	return world_dir.path_join(FILE_NAME)


## Lê o arquivo. Ausente: escreve-o com os padrões e segue. Ilegível, grande demais ou inválido: tudo no padrão, com
## aviso, e o arquivo fica intocado.
static func load_file(path: String, defaults: ServerRulesDefaults) -> ServerRules:
	if not FileAccess.file_exists(path):
		var fresh := _from_defaults(defaults)
		fresh._write_new(path)
		return fresh
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failed(defaults, "não foi possível abrir %s (erro %d)" % [path, FileAccess.get_open_error()])
	if file.get_length() > MAX_FILE_BYTES:
		return _failed(defaults, "%s passa de %d bytes" % [path, MAX_FILE_BYTES])
	return parse(file.get_as_text(), defaults)


## Regras do texto de um arquivo. Pura (sem disco): o que não vale volta ao padrão, com aviso em `problems`.
static func parse(text: String, defaults: ServerRulesDefaults) -> ServerRules:
	var rules := _from_defaults(defaults)
	if text.length() > MAX_FILE_BYTES:
		rules._warn("texto passa de %d bytes; usando os padrões" % MAX_FILE_BYTES)
		return rules
	var json := JSON.new()
	if json.parse(text) != OK:
		rules._warn("JSON inválido (linha %d: %s); usando os padrões" % [json.get_error_line(), json.get_error_message()])
		return rules
	if typeof(json.data) != TYPE_DICTIONARY:
		rules._warn("a raiz não é um objeto; usando os padrões")
		return rules
	return from_data(json.data, defaults)


## Regras de um dicionário já lido (o JSON aceita `1e99999`, que vira `inf`: aqui chega como número e é recusado).
static func from_data(data: Dictionary, defaults: ServerRulesDefaults) -> ServerRules:
	var rules := _from_defaults(defaults)
	if SafeRead.format_version(data, FORMAT_VERSION) == 0:
		rules._warn("version inválida ou mais nova que %d; usando os padrões" % FORMAT_VERSION)
		return rules
	rules._read(data)
	return rules


## Cópia das regras de nascimento com proteção e fome deste mundo. Nunca escreve na Resource original (cache do `preload`).
func apply_respawn(base: RespawnRules) -> RespawnRules:
	var copy: RespawnRules = base.duplicate()
	copy.protection_seconds = respawn_protection_seconds
	copy.hunger_ratio = float(respawn_hunger_pct) / 100.0
	return copy


## Cópia das regras de doma com a perda fixa por ataque deste mundo.
func apply_taming(base: TamingRules) -> TamingRules:
	var copy: TamingRules = base.duplicate()
	var losses: Dictionary[String, float] = {}
	for kind: String in base.attack_fixed_loss:
		losses[kind] = base.attack_fixed_loss[kind]
	losses[TamingRules.ATTACKER_PLAYER] = player_attack_fixed_loss
	losses[TamingRules.ATTACKER_CARNIVORE] = carnivore_attack_fixed_loss
	copy.attack_fixed_loss = losses
	copy.snore_tiles = sleeper_snore_tiles
	return copy


## Cópia das regras da toca com a âncora e a ronda deste mundo.
func apply_home(base: HomeRules) -> HomeRules:
	var copy: HomeRules = base.duplicate()
	copy.anchor_tiles = den_anchor_tiles
	copy.patrol_tiles = minf(den_patrol_tiles, den_anchor_tiles)  # a ronda nunca passa da âncora
	return copy


## Cópia das regras da predação com o aviso de farejada deste mundo.
func apply_predation(base: PredationRules) -> PredationRules:
	var copy: PredationRules = base.duplicate()
	copy.sleeper_alert_s = sleeper_alert_seconds
	return copy


## Cópia das regras do ciclo de dia e noite com a duração deste mundo.
func apply_day_cycle(base: DayCycleRules) -> DayCycleRules:
	var copy: DayCycleRules = base.duplicate()
	copy.cycle_seconds = day_cycle_seconds
	return copy


## Cópia das regras do mundo com as faixas de nível deste mundo.
func apply_world(base: WorldRules) -> WorldRules:
	var copy: WorldRules = base.duplicate()
	var bands: Dictionary[int, Vector2i] = {}
	for terrain: int in base.level_bands:
		bands[terrain] = base.level_bands[terrain]
	for terrain: int in level_bands:
		bands[terrain] = level_bands[terrain]
	copy.level_bands = bands
	return copy


## O que o arquivo novo leva: `version`, todas as chaves declaradas e os valores efetivos.
func as_file_data() -> Dictionary:
	var bands := {}
	for biome: String in BIOMES:
		var band: Vector2i = level_bands[BIOMES[biome]]
		bands[biome] = [band.x, band.y]
	return {
		"version": FORMAT_VERSION,
		KEY_COLLECT: collect_multiplier,
		KEY_RESOURCE_RESPAWN: resource_respawn_rate,
		KEY_LEVEL_BANDS: bands,
		KEY_PROTECTION: respawn_protection_seconds,
		KEY_HUNGER: respawn_hunger_pct,
		KEY_PLAYER_LOSS: player_attack_fixed_loss,
		KEY_CARNIVORE_LOSS: carnivore_attack_fixed_loss,
		KEY_PVP: pvp,
		KEY_DEN_ANCHOR: den_anchor_tiles,
		KEY_DEN_PATROL: den_patrol_tiles,
		KEY_SNORE: sleeper_snore_tiles,
		KEY_SLEEPER_ALERT: sleeper_alert_seconds,
		KEY_DAY_CYCLE: day_cycle_seconds,
	}


static func _from_defaults(defaults: ServerRulesDefaults) -> ServerRules:
	var rules := ServerRules.new()
	rules.respawn_protection_seconds = defaults.respawn.protection_seconds
	rules.respawn_hunger_pct = roundi(defaults.respawn.hunger_ratio * 100.0)
	rules.player_attack_fixed_loss = defaults.taming.attack_fixed_loss.get(TamingRules.ATTACKER_PLAYER, 0.0)
	rules.carnivore_attack_fixed_loss = defaults.taming.attack_fixed_loss.get(TamingRules.ATTACKER_CARNIVORE, 0.0)
	rules.den_anchor_tiles = defaults.home.anchor_tiles
	rules.den_patrol_tiles = defaults.home.patrol_tiles
	rules.sleeper_snore_tiles = defaults.taming.snore_tiles
	rules.sleeper_alert_seconds = defaults.predation.sleeper_alert_s
	rules.day_cycle_seconds = defaults.day_cycle.cycle_seconds
	for biome: String in BIOMES:
		rules.level_bands[BIOMES[biome]] = defaults.world.level_band_of(BIOMES[biome])
	return rules


static func _failed(defaults: ServerRulesDefaults, reason: String) -> ServerRules:
	var rules := _from_defaults(defaults)
	rules._warn("%s; usando os padrões" % reason)
	return rules


func _warn(message: String) -> void:
	problems.append(message)


func _read(data: Dictionary) -> void:
	for key: Variant in data:
		if str(key) != "version" and not _is_known(str(key)):
			_warn("chave desconhecida '%s' ignorada" % str(key))
	collect_multiplier = _number(data, KEY_COLLECT, collect_multiplier)
	resource_respawn_rate = _number(data, KEY_RESOURCE_RESPAWN, resource_respawn_rate)
	respawn_protection_seconds = _number(data, KEY_PROTECTION, respawn_protection_seconds)
	player_attack_fixed_loss = _number(data, KEY_PLAYER_LOSS, player_attack_fixed_loss)
	carnivore_attack_fixed_loss = _number(data, KEY_CARNIVORE_LOSS, carnivore_attack_fixed_loss)
	respawn_hunger_pct = _integer(data, KEY_HUNGER, respawn_hunger_pct)
	pvp = _boolean(data, KEY_PVP, pvp)
	den_anchor_tiles = _number(data, KEY_DEN_ANCHOR, den_anchor_tiles)
	den_patrol_tiles = _number(data, KEY_DEN_PATROL, den_patrol_tiles)
	sleeper_snore_tiles = _number(data, KEY_SNORE, sleeper_snore_tiles)
	sleeper_alert_seconds = _number(data, KEY_SLEEPER_ALERT, sleeper_alert_seconds)
	day_cycle_seconds = _number(data, KEY_DAY_CYCLE, day_cycle_seconds)
	if den_patrol_tiles > den_anchor_tiles:
		_warn("%s: a ronda (%s) não pode passar da âncora (%s); a ronda usa a âncora" % [KEY_DEN_PATROL, den_patrol_tiles, den_anchor_tiles])
	_read_bands(data)


static func _is_known(key: String) -> bool:
	return NUMBER_RANGES.has(key) or INTEGER_RANGES.has(key) or key == KEY_LEVEL_BANDS or key == KEY_PVP


func _number(data: Dictionary, key: String, fallback: float) -> float:
	if not data.has(key):
		return fallback
	var raw: Variant = data[key]
	var limits: Array = NUMBER_RANGES[key]
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		_warn("%s: precisa ser número; mantido o padrão" % key)
		return fallback
	var value := SafeRead.number(raw, NAN, -INF, INF)  # sem limitar: fora da faixa é erro do operador, não limite
	if is_nan(value):
		_warn("%s: valor não finito; mantido o padrão" % key)
		return fallback
	if value < float(limits[0]) or value > float(limits[1]):
		_warn("%s: %s fora de [%s, %s]; mantido o padrão" % [key, value, limits[0], limits[1]])
		return fallback
	return value


func _boolean(data: Dictionary, key: String, fallback: bool) -> bool:
	if not data.has(key):
		return fallback
	if typeof(data[key]) != TYPE_BOOL:
		_warn("%s: precisa ser true ou false; mantido o padrão" % key)
		return fallback
	return data[key]


func _integer(data: Dictionary, key: String, fallback: int) -> int:
	if not data.has(key):
		return fallback
	var limits: Array = INTEGER_RANGES[key]
	var value := SafeRead.integer(data[key], _INVALID_INT, limits[0], limits[1])
	if value == _INVALID_INT:
		_warn("%s: precisa ser inteiro em [%d, %d]; mantido o padrão" % [key, limits[0], limits[1]])
		return fallback
	return value


## Cada bioma vale sozinho: entrada inválida mantém só o padrão daquele bioma.
func _read_bands(data: Dictionary) -> void:
	if not data.has(KEY_LEVEL_BANDS):
		return
	if typeof(data[KEY_LEVEL_BANDS]) != TYPE_DICTIONARY:
		_warn("%s: precisa ser um objeto; mantidos os padrões" % KEY_LEVEL_BANDS)
		return
	var raw: Dictionary = data[KEY_LEVEL_BANDS]
	for biome: Variant in raw:
		if not BIOMES.has(str(biome)):
			_warn("%s: bioma desconhecido '%s' ignorado" % [KEY_LEVEL_BANDS, str(biome)])
			continue
		var band := _band(raw[biome])
		if band == Vector2i.ZERO:
			_warn("%s.%s: precisa ser [mínimo, máximo] inteiros em [%d, %d], mínimo não maior que o máximo; mantido o padrão"
					% [KEY_LEVEL_BANDS, str(biome), LEVEL_RANGE[0], LEVEL_RANGE[1]])
			continue
		level_bands[BIOMES[str(biome)]] = band


## [mínimo, máximo] válido, ou `Vector2i.ZERO` (nenhum nível 0 é válido, então serve de "inválido").
static func _band(raw: Variant) -> Vector2i:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != 2:
		return Vector2i.ZERO
	var low := SafeRead.integer(raw[0], _INVALID_INT, LEVEL_RANGE[0], LEVEL_RANGE[1])
	var high := SafeRead.integer(raw[1], _INVALID_INT, LEVEL_RANGE[0], LEVEL_RANGE[1])
	if low == _INVALID_INT or high == _INVALID_INT or low > high:
		return Vector2i.ZERO
	return Vector2i(low, high)


## Escreve o arquivo novo. Falhou: segue com os padrões em memória, com aviso. Nunca sobrescreve.
func _write_new(path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		_warn("não foi possível criar a pasta de %s (erro %d); regras só em memória" % [path, error])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_warn("não foi possível escrever %s (erro %d); regras só em memória" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(as_file_data(), "\t") + "\n")
