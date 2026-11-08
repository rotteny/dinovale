# SPDX-License-Identifier: MIT
class_name ServerRulesTests
extends SaveTests
## `ServerRules` (ADR-004, ARQ-05): padrões, tabela por chave, arquivo malformado, arquivo ausente, chave desconhecida,
## faixas de nível, não vazar para o `preload`, o caminho e o consumidor de cada chave da E1 nos dois estados
## ("trocar a chave muda o jogo"). Chamado por `run_tests.gd`.

const RESPAWN_RULES: RespawnRules = preload("res://data/balance/respawn_rules.tres")
const WORLD_RULES_RES: WorldRules = preload("res://data/world/world_rules.tres")
const TAMING_RES: TamingRules = preload("res://data/balance/taming_rules.tres")
## Chave -> campo do `ServerRules` que ela preenche.
const FIELD_OF: Dictionary = {
	"multiplicador_coleta": "collect_multiplier",
	"respawn_recurso": "resource_respawn_rate",
	"respawn_protecao_s": "respawn_protection_seconds",
	"respawn_fome_pct": "respawn_hunger_pct",
	"eficiencia_fixa_ataque_jogador": "player_attack_fixed_loss",
	"eficiencia_fixa_ataque_carnivoro": "carnivore_attack_fixed_loss",
}
## Valores do arquivo de mundo "trocado": um por chave, todos diferentes do padrão.
const CUSTOM_FILE := {
	"version": 1,
	"multiplicador_coleta": 2.0,
	"respawn_recurso": 2.0,
	"faixas_de_nivel": {"mata_baixa": [30, 31]},
	"respawn_protecao_s": 10.0,
	"respawn_fome_pct": 80,
	"eficiencia_fixa_ataque_jogador": 20.0,
	"eficiencia_fixa_ataque_carnivoro": 30.0,
	"pvp": true,
}

var _case_dir: String = ""


func run() -> void:
	_case_dir = SaveTests.root_dir.path_join("server_rules_cases")
	_test_defaults()
	_test_key_table()
	_test_malformed_files()
	_test_absent_file()
	_test_unknown_key()
	_test_level_bands()
	_test_pvp()
	_test_no_leak_into_preload()
	_test_path()
	await _test_consumers()
	SaveTests.remove_tree(_case_dir)


func _defaults() -> ServerRulesDefaults:
	return ServerRulesDefaults.new(RESPAWN_RULES, WORLD_RULES_RES, TAMING_RES)


func _default_of(rules: ServerRules, key: String) -> Variant:
	return rules.get(FIELD_OF[key])


func _test_defaults() -> void:
	var rules := ServerRules.parse("{}", _defaults())
	_check(rules.problems.is_empty(), "{} não registra problema")
	_check(
		is_equal_approx(rules.collect_multiplier, 1.0) and is_equal_approx(rules.resource_respawn_rate, 1.0),
		"multiplicadores padrão são 1,0 (identidade)"
	)
	_check(
		(
			is_equal_approx(rules.respawn_protection_seconds, RESPAWN_RULES.protection_seconds)
			and rules.respawn_hunger_pct == roundi(RESPAWN_RULES.hunger_ratio * 100.0)
		),
		"proteção e fome padrão vêm do respawn_rules.tres"
	)
	_check(
		(
			is_equal_approx(rules.player_attack_fixed_loss, TAMING_RES.attack_fixed_loss["player"])
			and is_equal_approx(rules.carnivore_attack_fixed_loss, TAMING_RES.attack_fixed_loss["carnivore"])
		),
		"perda por ataque padrão vem do taming_rules.tres"
	)
	var bands_ok := true
	for biome: String in ServerRules.BIOMES:
		bands_ok = (
			bands_ok and rules.level_bands[ServerRules.BIOMES[biome]] == WORLD_RULES_RES.level_band_of(ServerRules.BIOMES[biome])
		)
	_check(bands_ok, "faixas de nível padrão vêm do world_rules.tres")


## Cada chave: o válido aplica; ausente, null, texto, lista, bool, fracionário (inteiro), fora da faixa e `inf` caem
## no padrão e registram problema (fora da faixa NÃO vira o limite).
func _test_key_table() -> void:
	var base := ServerRules.parse("{}", _defaults())
	for key: String in FIELD_OF:
		var default_value: Variant = _default_of(base, key)
		var is_integer := ServerRules.INTEGER_RANGES.has(key)
		var limits: Array = ServerRules.INTEGER_RANGES[key] if is_integer else ServerRules.NUMBER_RANGES[key]
		var valid: Variant = limits[1] if is_integer else (float(limits[1]) + float(limits[0])) * 0.5
		if is_integer:
			valid = int(limits[0]) + 7
		var ok := ServerRules.parse(JSON.stringify({key: valid}), _defaults())
		_check(
			is_equal_approx(float(_default_of(ok, key)), float(valid)) and ok.problems.is_empty(),
			"%s: valor válido é aplicado" % key
		)
		var bad_texts: Array[String] = [
			'{"%s": null}',
			'{"%s": "texto"}',
			'{"%s": [1]}',
			'{"%s": true}',
			'{"%s": {"a": 1}}',
			'{"%s": %s}' % ["%s", str(limits[0] - 1)],
			'{"%s": %s}' % ["%s", str(limits[1] + 1)]
		]
		if is_integer:
			bad_texts.append('{"%s": 50.5}')
		for non_finite: float in [INF, -INF, NAN]:
			var infinite := ServerRules.from_data({key: non_finite}, _defaults())
			_check(
				is_equal_approx(float(_default_of(infinite, key)), float(default_value)) and infinite.problems.size() == 1,
				"%s: valor não finito (%s) cai no padrão com um aviso" % [key, non_finite]
			)
		for pattern in bad_texts:
			var bad := ServerRules.parse(pattern % key, _defaults())
			_check(
				is_equal_approx(float(_default_of(bad, key)), float(default_value)) and bad.problems.size() == 1,
				"%s: %s cai no padrão com um aviso" % [key, pattern % key]
			)


func _write_case(name: String, content: String) -> String:
	var path := _case_dir.path_join(name + ".json")
	_write_raw(path, content)
	return path


func _test_malformed_files() -> void:
	var long_text := '{"version": 1, "pad": "%s"}' % "x".repeat(ServerRules.MAX_FILE_BYTES)
	var cases := {
		"json_invalido": "{lixo",
		"raiz_lista": "[1, 2]",
		"grande": long_text,
		"version_0": '{"version": 0, "multiplicador_coleta": 5}',
		"version_2": '{"version": 2, "multiplicador_coleta": 5}',
		"version_texto": '{"version": "1", "multiplicador_coleta": 5}',
	}
	for name: String in cases:
		var path := _write_case(name, cases[name])
		var rules := ServerRules.load_file(path, _defaults())
		_check(
			is_equal_approx(rules.collect_multiplier, 1.0) and not rules.problems.is_empty(),
			"%s: todos os padrões, com aviso" % name
		)
		_check(_read_raw(path) == cases[name], "%s: o arquivo fica intocado" % name)


func _test_absent_file() -> void:
	var path := _case_dir.path_join("novo/server_rules.json")
	var first := ServerRules.load_file(path, _defaults())
	_check(FileAccess.file_exists(path) and first.problems.is_empty(), "arquivo ausente é criado, sem problema")
	var parsed: Variant = JSON.parse_string(_read_raw(path))
	var keys_ok := parsed is Dictionary and (parsed as Dictionary).has("version")
	for key: String in FIELD_OF:
		keys_ok = keys_ok and parsed is Dictionary and (parsed as Dictionary).has(key)
	keys_ok = keys_ok and (parsed as Dictionary).has(ServerRules.KEY_LEVEL_BANDS)
	_check(keys_ok, "o arquivo novo traz version e todas as chaves declaradas")
	var bytes_before := _read_raw(path)
	var time_before := FileAccess.get_modified_time(path)
	var second := ServerRules.load_file(path, _defaults())
	var same_values := true
	for key: String in FIELD_OF:
		same_values = same_values and is_equal_approx(float(_default_of(first, key)), float(_default_of(second, key)))
	_check(same_values and second.problems.is_empty(), "a segunda carga devolve os mesmos valores")
	_check(_read_raw(path) == bytes_before and FileAccess.get_modified_time(path) == time_before, "a segunda carga não reescreve")
	# o operador muda o arquivo: o jogo lê e nunca regrava
	var edited := bytes_before.replace('"multiplicador_coleta": 1.0', '"multiplicador_coleta": 3.0')
	_write_raw(path, edited)
	var third := ServerRules.load_file(path, _defaults())
	_check(
		is_equal_approx(third.collect_multiplier, 3.0) and _read_raw(path) == edited,
		"valor trocado pelo operador vale e o arquivo não é regravado"
	)


func _test_unknown_key() -> void:
	var rules := ServerRules.parse('{"multiplicador_coleta": 2, "multiplicador_colet": 9, "dano_fome": 3}', _defaults())
	var names := " ".join(rules.problems)
	_check(
		(
			is_equal_approx(rules.collect_multiplier, 2.0)
			and rules.problems.size() == 2
			and names.contains("multiplicador_colet")
			and names.contains("dano_fome")
		),
		"chave desconhecida é ignorada com o nome no aviso e as demais valem"
	)


func _test_level_bands() -> void:
	var quarry := ServerRules.parse('{"faixas_de_nivel": {"pedreira": [20, 40]}}', _defaults())
	_check(
		(
			quarry.level_bands[IslandMap.QUARRY] == Vector2i(20, 40)
			and quarry.problems.is_empty()
			and quarry.level_bands[IslandMap.WOODLAND] == WORLD_RULES_RES.level_band_of(IslandMap.WOODLAND)
		),
		"sobrescrita parcial: só a pedreira muda"
	)
	var mixed := ServerRules.parse(
		'{"faixas_de_nivel": {"campina": [3, 2], "mata_baixa": [1, 2, 3], "pedreira": [0, 60], ' + '"ilha": [1, 2]}}', _defaults()
	)
	var kept := true
	for biome: String in ServerRules.BIOMES:
		kept = kept and mixed.level_bands[ServerRules.BIOMES[biome]] == WORLD_RULES_RES.level_band_of(ServerRules.BIOMES[biome])
	_check(
		kept and mixed.problems.size() == 4,
		"mínimo > máximo, três elementos, fora de [1, 50] e bioma desconhecido: padrões, 4 avisos"
	)
	var one_bad := ServerRules.parse('{"faixas_de_nivel": {"campina": [2, 3], "pedreira": [9, 1]}}', _defaults())
	_check(
		(
			one_bad.level_bands[IslandMap.GRASSLAND] == Vector2i(2, 3)
			and one_bad.problems.size() == 1
			and one_bad.level_bands[IslandMap.QUARRY] == WORLD_RULES_RES.level_band_of(IslandMap.QUARRY)
		),
		"bioma inválido mantém só o próprio padrão"
	)
	var wrong_type := ServerRules.parse('{"faixas_de_nivel": [1, 2]}', _defaults())
	var fractional := ServerRules.parse('{"faixas_de_nivel": {"campina": [1.5, 3]}}', _defaults())
	_check(wrong_type.problems.size() == 1 and fractional.problems.size() == 1, "faixas fora de forma e nível fracionário avisam")


## `pvp` é booleano: só `true`/`false` valem; qualquer outro tipo volta a falso com um aviso.
func _test_pvp() -> void:
	_check(not ServerRules.parse("{}", _defaults()).pvp, "pvp: padrão falso")
	var on := ServerRules.parse('{"pvp": true}', _defaults())
	_check(on.pvp and on.problems.is_empty(), "pvp: true liga")
	for bad in ['null', '"true"', '1', '0', '[true]', '{"a": 1}']:
		var rules := ServerRules.parse('{"pvp": %s}' % bad, _defaults())
		_check(not rules.pvp and rules.problems.size() == 1, "pvp: %s cai em falso com um aviso" % bad)
	_check(ServerRules.parse("{}", _defaults()).as_file_data().get("pvp", null) == false, "pvp: o arquivo novo traz a chave, falsa")


func _test_no_leak_into_preload() -> void:
	var rules := ServerRules.parse(JSON.stringify(CUSTOM_FILE), _defaults())
	var before_protection := RESPAWN_RULES.protection_seconds
	var respawn := rules.apply_respawn(RESPAWN_RULES)
	var taming := rules.apply_taming(TAMING_RES)
	var world := rules.apply_world(WORLD_RULES_RES)
	_check(
		(
			is_equal_approx(respawn.protection_seconds, 10.0)
			and is_equal_approx(respawn.hunger_ratio, 0.8)
			and is_equal_approx(taming.attack_fixed_loss["player"], 20.0)
			and is_equal_approx(taming.attack_fixed_loss["carnivore"], 30.0)
			and world.level_band_of(IslandMap.WOODLAND) == Vector2i(30, 31)
		),
		"as cópias levam os valores do mundo"
	)
	var preload_respawn: RespawnRules = RESPAWN_RULES
	var preload_taming: TamingRules = TAMING_RES
	var preload_world: WorldRules = WORLD_RULES_RES
	_check(
		(
			is_equal_approx(preload_respawn.protection_seconds, before_protection)
			and is_equal_approx(preload_respawn.hunger_ratio, 0.5)
			and is_equal_approx(preload_taming.attack_fixed_loss["player"], 4.0)
			and is_equal_approx(preload_taming.attack_fixed_loss["carnivore"], 8.0)
			and preload_world.level_band_of(IslandMap.WOODLAND) == Vector2i(5, 25)
		),
		"a Resource do preload segue intacta"
	)


func _test_path() -> void:
	var world_dir := "user://saves/mundo"
	_check(
		ServerRules.path_for(world_dir, PackedStringArray()) == "user://saves/mundo/server_rules.json",
		"sem argumento: o arquivo do mundo"
	)
	_check(
		ServerRules.path_for(world_dir, PackedStringArray(["--outro", "--server-rules=x.json"])) == "x.json",
		"--server-rules=x.json vale"
	)
	_check(
		ServerRules.path_for(world_dir, PackedStringArray(["--server-rules="])) == "user://saves/mundo/server_rules.json",
		"argumento vazio cai no padrão"
	)
	_check(
		(
			ServerRules.path_for(world_dir, PackedStringArray(["--server-rules", "x.json"]))
			== "user://saves/mundo/server_rules.json"
		),
		"argumento malformado cai no padrão"
	)


## Cada chave da E1 muda o jogo sem recompilar: o mesmo código com `server_rules.json` diferente se comporta diferente.
func _test_consumers() -> void:
	var plain_dir := SaveTests.root_dir.path_join("sr_plain")
	var custom_dir := SaveTests.root_dir.path_join("sr_custom")
	_write_raw(custom_dir.path_join(ServerRules.FILE_NAME), JSON.stringify(CUSTOM_FILE))
	var plain := _main("sr_plain", 20, true)
	var custom := _main("sr_custom", 20, true)
	_check(
		FileAccess.file_exists(plain_dir.path_join(ServerRules.FILE_NAME)),
		"o mundo sem arquivo ganha o server_rules.json do host"
	)
	_check(
		custom.server_rules.problems.is_empty() and is_equal_approx(custom.server_rules.collect_multiplier, 2.0),
		"o mundo com arquivo lê as chaves"
	)
	# multiplicador_coleta e respawn_recurso
	var plain_bush := plain.resources.node_by_id("n1")
	var custom_bush := custom.resources.node_by_id("n1")
	var base_yields := plain_bush.component.pending_yields()
	var doubled := custom_bush.component.pending_yields()
	var yields_ok := not base_yields.is_empty() and base_yields.size() == doubled.size()
	for item_id: String in base_yields:
		yields_ok = (
			yields_ok
			and doubled.get(item_id, 0) == maxi(1, roundi(float(base_yields[item_id]) * 2.0))
			and doubled[item_id] > base_yields[item_id]
		)
	_check(yields_ok, "coleta x2 rende o dobro, também nos itens extras")
	_check(
		(
			is_equal_approx(plain_bush.component.respawn_total(), plain_bush.def.respawn_seconds)
			and is_equal_approx(custom_bush.component.respawn_total(), plain_bush.def.respawn_seconds * 0.5)
		),
		"respawn_recurso 2 volta na metade do tempo"
	)
	var low := ResourceNodeComponent.new()
	_track.call(low)
	low.def = plain_bush.def
	low.yield_multiplier = 0.1
	var floor_ok := true
	for amount: int in low.pending_yields().values():
		floor_ok = floor_ok and amount == 1
	_check(floor_ok, "multiplicador baixo nunca zera a colheita (mínimo 1)")
	# faixas_de_nivel (toca na mata: os utahraptores nascem em mata_baixa)
	var plain_levels_ok := true
	var custom_levels_ok := true
	for i in plain.wild.get_child_count():
		var left := plain.wild.get_child(i) as Dino
		var right := custom.wild.get_child(i) as Dino
		if left.stats.id == "utahraptor":
			plain_levels_ok = plain_levels_ok and left.level >= 5 and left.level <= 25
			custom_levels_ok = custom_levels_ok and right.level >= 30 and right.level <= 31
	_check(plain_levels_ok and custom_levels_ok, "faixas_de_nivel: com semente fixa, nível dentro da faixa padrão e da trocada")
	# respawn_protecao_s e respawn_fome_pct
	for main: Main in [plain, custom]:
		main.player.health.take_damage(10000.0)
		_check(main.request_respawn("campina") == "", "renasce na Campina")
	_check(
		is_equal_approx(plain.player.health.protection_left, 3.0) and is_equal_approx(custom.player.health.protection_left, 10.0),
		"proteção ao renascer: 3 s no padrão, 10 s trocada"
	)
	_check(
		(
			is_equal_approx(plain.player.hunger.current_hunger, plain.player.hunger.max_hunger * 0.5)
			and is_equal_approx(custom.player.hunger.current_hunger, custom.player.hunger.max_hunger * 0.8)
		),
		"fome ao renascer: 50% no padrão, 80% trocada"
	)
	# eficiencia_fixa_ataque_jogador e _carnivoro
	for main: Main in [plain, custom]:
		main.dino.torpor.add_torpor(main.dino.torpor.max_torpor)
	var plain_before := plain.dino.taming.efficiency
	plain.dino.take_damage(0.0, TamingRules.ATTACKER_PLAYER)
	custom.dino.take_damage(0.0, TamingRules.ATTACKER_PLAYER)
	_check(
		(
			is_equal_approx(plain_before - plain.dino.taming.efficiency, 4.0)
			and is_equal_approx(100.0 - custom.dino.taming.efficiency, 20.0)
		),
		"ataque do jogador no dormindo: -4 de Eficiência no padrão, -20 trocado"
	)
	var plain_mid := plain.dino.taming.efficiency
	var custom_mid := custom.dino.taming.efficiency
	plain.dino.take_damage(0.0, TamingRules.ATTACKER_CARNIVORE)
	custom.dino.take_damage(0.0, TamingRules.ATTACKER_CARNIVORE)
	_check(
		(
			is_equal_approx(plain_mid - plain.dino.taming.efficiency, 8.0)
			and is_equal_approx(custom_mid - custom.dino.taming.efficiency, 30.0)
		),
		"ataque de carnívoro no dormindo: -8 no padrão, -30 trocado"
	)
	# pvp
	_check(not plain.authority.pvp_enabled and custom.authority.pvp_enabled, "pvp: a autoridade recebe a chave do mundo")
	# os selvagens do mapa recebem as regras de doma do mundo
	_check(
		(
			(custom.wild.get_child(0) as Dino).taming.rules == custom.taming_rules
			and is_equal_approx(custom.taming_rules.attack_fixed_loss["player"], 20.0)
		),
		"os selvagens usam as regras de doma do mundo"
	)
	_release_worlds()
