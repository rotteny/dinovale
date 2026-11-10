# SPDX-License-Identifier: MIT
class_name SaveV5Tests
extends WorldTests
## Save v5 (ADR-006 e ADR-007): relógio do mundo e prazos absolutos, selvagem pela semente do spawn (nível e sexo),
## sexo do dino, recusa de espécie errada, ids do mapa e `player_id` aleatório. A migração v4 para v5 e a fixture
## `v5.json` estão em `WorldTests`.


func run() -> void:
	_test_map_ids()
	_test_wild_seed_streams()
	_test_dino_species_and_sex()
	_test_seed_golden_values()
	_test_next_entity_id_migration()
	_test_map_rejects_bad_ids()
	_test_wake_drops_reservation()
	await _test_world_clock()
	_release_worlds()
	await _test_deadlines_are_absolute()
	_release_worlds()
	await _test_carcass_born_at_limits()
	_release_worlds()
	await _test_wild_from_spawn_seed()
	_release_worlds()
	await _test_wild_delta_species_mismatch()
	_release_worlds()
	await _test_new_world_player_id()
	_release_worlds()


func _test_map_ids() -> void:
	var map := IslandMap.default_map()
	var seen := {}
	var unique := true
	var total := 0
	for lists: Dictionary in [map.node_ids]:
		for kind: String in lists:
			for id: String in lists[kind]:
				total += 1
				unique = unique and id != "" and not seen.has(id)
				seen[id] = true
	_check(unique and total == 1029 + 91 + 40 + 142 + 24 + 18, "todo nó do mapa tem id próprio, sem repetir (%d)" % total)
	var slot_ids := {}
	for slot in map.spawn_slots:
		slot_ids[slot["id"]] = true
	_check(slot_ids.size() == map.spawn_slots.size() and slot_ids.size() == 37, "toda vaga de bando tem id próprio (%d)" % slot_ids.size())
	for kind: String in map.nodes:
		_check((map.node_ids[kind] as Array).size() == (map.nodes[kind] as Array).size(), "ids de nó de %s alinhados com os pontos" % kind)
	_check(map.content_hash.length() == 16 and map.content_hash.is_valid_hex_number(false), "o mapa traz o hash do conteúdo (16 hex)")
	# Mapa de teste sem ids (arquivo que não os traz): ids sintéticos e únicos, sem abortar.
	var plain := IslandMap.new()
	var rows: Array = []
	for y in 16:
		rows.append("3".repeat(16))
	plain.load_dict({"format": 2, "size": 16, "rows": rows, "nodes": {"tree": [[1, 1], [2, 2]]}})
	_check(plain.is_valid() and plain.node_ids["tree"] == ["ntree:0", "ntree:1"], "sem ids no arquivo: ids sintéticos")


func _test_wild_seed_streams() -> void:
	var band := Vector2i(5, 25)
	var seed_value := 7
	var level_5 := WildPopulation.roll_level(band, seed_value, "w5")
	_check(WildPopulation.roll_level(band, seed_value, "w5") == level_5, "o nível do mesmo spawn é sempre o mesmo")
	var seen_levels := {}
	var males := 0
	var kind := WildPopulation.SPECIES[0]
	for i in 107:
		var spawn_id := "w%d" % i
		var level := WildPopulation.roll_level(band, seed_value, spawn_id)
		seen_levels[level] = true
		if level < band.x or level > band.y:
			_check(false, "nível de %s fora da faixa (%d)" % [spawn_id, level])
		males += 1 if kind.roll_sex(seed_value, spawn_id) == DinoBaseStats.SEX_MALE else 0
	_check(seen_levels.size() > 10, "os níveis variam entre spawns (%d valores)" % seen_levels.size())
	_check(males > 107 * 0.3 and males < 107 * 0.7, "sexo meio a meio: %d machos de 107" % males)
	var sex_5 := kind.roll_sex(seed_value, "w5")
	_check(kind.roll_sex(seed_value, "w5") == sex_5, "o sexo do mesmo spawn é sempre o mesmo")
	# Fluxos separados: a proporção muda o sexo sem mexer no nível, e 0 e 1 são os extremos.
	var all_male := kind.duplicate() as DinoBaseStats
	all_male.male_ratio = 1.0
	var all_female := kind.duplicate() as DinoBaseStats
	all_female.male_ratio = 0.0
	var extremes := true
	for i in 50:
		extremes = extremes and all_male.roll_sex(seed_value, "w%d" % i) == "m" and all_female.roll_sex(seed_value, "w%d" % i) == "f"
	_check(extremes, "proporção 1,0 só dá macho e 0,0 só dá fêmea")
	_check(kind.male_ratio == 0.5 and WildPopulation.SPECIES[1].male_ratio == 0.5, "0,5 em cada espécie do mapa")
	_check(WildPopulation.roll_level(band, 8, "w5") != WildPopulation.roll_level(band, 7, "w5")
			or WildPopulation.roll_level(band, 9, "w5") != WildPopulation.roll_level(band, 7, "w5"), "a semente do mapa entra no sorteio")


## Valores fixos (golden), calculados à parte com FNV-1a + xorshift: se a semente mudar, o mundo de todo save muda.
func _test_seed_golden_values() -> void:
	var band := Vector2i(5, 25)
	var kind := WildPopulation.SPECIES[0]
	var cases := [
		[7, "w0", 11, "f"], [7, "w5", 21, "f"], [7, "w50", 25, "f"], [7, "w106", 12, "m"],
		[8, "w0", 17, "f"], [8, "w5", 9, "m"], [8, "w50", 19, "m"], [8, "w106", 13, "f"],
	]
	var all_match := true
	for entry: Array in cases:
		var level := WildPopulation.roll_level(band, entry[0], entry[1])
		var sex := kind.roll_sex(entry[0], entry[1])
		if level != entry[2] or sex != entry[3]:
			all_match = false
			printerr("golden: semente %d %s deu nível %d sexo %s" % [entry[0], entry[1], level, sex])
	_check(all_match, "nível e sexo por semente têm valores fixos")
	_check(SeededRng.hash_parts(["a"]) == 488232310, "o hash das partes é FNV-1a próprio (estável entre versões do Godot)")
	_check(SaveMigrations.v4_sex(2) == "m" and SaveMigrations.v4_sex(5) == "m" and SaveMigrations.v4_sex(9) == "f",
			"sexo de save v4 tem valores fixos")
	# Fluxos separados: o sexo nunca mexe no nível (nem o contrário) e as duas sequências diferem.
	var level_stream := SeededRng.new()
	level_stream.seed_from(["wild", 7, "w5", "level"])
	var sex_stream := SeededRng.new()
	sex_stream.seed_from(["wild", 7, "w5", "sex"])
	_check(level_stream.next_below(1 << 30) != sex_stream.next_below(1 << 30), "fluxo de nível e de sexo são independentes")
	var skewed := kind.duplicate() as DinoBaseStats
	skewed.male_ratio = 0.9
	_check(WildPopulation.roll_level(band, 7, "w5") == 21 and skewed.roll_sex(7, "w5") == "m"
			and kind.roll_sex(7, "w5") == "f", "mudar a proporção muda o sexo e deixa o nível como estava")


func _test_next_entity_id_migration() -> void:
	var v4 := {"world": {"map_id": "x", "map_revision": 7, "next_entity_id": 3},
			"entities": [{"id": 50, "state": {}}, {"id": 12.0, "state": {}}]}
	_check(SaveMigrations.v4_to_v5(v4, "")["world"]["next_entity_id"] == 51, "v4 com contador abaixo do maior id: vira maior id + 1")
	v4["world"]["next_entity_id"] = 50
	_check(SaveMigrations.v4_to_v5(v4, "")["world"]["next_entity_id"] == 51, "contador igual ao maior id: também vira maior + 1")
	v4["world"]["next_entity_id"] = 900
	_check(SaveMigrations.v4_to_v5(v4, "")["world"]["next_entity_id"] == 900, "contador acima de tudo fica como está")
	v4["world"]["next_entity_id"] = 1 << 40
	_check(SaveMigrations.v4_to_v5(v4, "")["world"]["next_entity_id"] == 51, "contador absurdo é limitado ao mesmo teto da carga")
	var at_cap := {"world": {"next_entity_id": SaveMigrations.MAX_ENTITY_ID}}
	var over_cap := {"world": {"next_entity_id": SaveMigrations.MAX_ENTITY_ID + 1}}
	_check(WorldSnapshot.next_entity_id_of(at_cap) == SaveMigrations.MAX_ENTITY_ID and WorldSnapshot.next_entity_id_of(over_cap) == 0,
			"a carga aceita até o teto e recusa o que passa dele")
	var migrated_at := SaveMigrations.v4_to_v5({"world": at_cap["world"].duplicate(), "entities": []}, "")
	var migrated_over := SaveMigrations.v4_to_v5({"world": over_cap["world"].duplicate(), "entities": []}, "")
	_check(migrated_at["world"]["next_entity_id"] == SaveMigrations.MAX_ENTITY_ID and migrated_over["world"]["next_entity_id"] == 3,
			"a migração usa o mesmo teto da carga")
	# Migrar de novo um v5 não mexe em nada (nem zera o relógio).
	var once := SaveMigrations.v4_to_v5(v4, "")
	once["world"]["time"] = 123.0
	_check(SaveMigrations.v4_to_v5(once, "outro") == once, "v4_to_v5 sobre save já migrado devolve o mesmo save")


func _test_map_rejects_bad_ids() -> void:
	var rows: Array = []
	for y in 16:
		rows.append("3".repeat(16))
	var region := {"terrains": [3], "runs": [[1, 1, 8]]}
	var base := {"format": 2, "size": 16, "rows": rows, "spawn_regions": {"r": region},
			"spawn_slots": [{"id": "g1", "species": "paquicefalo", "region": "r", "size": 3},
			{"id": "g2", "species": "paquicefalo", "region": "r", "size": 3}],
			"nodes": {"tree": [[3, 3]]}, "node_ids": {"tree": ["n1"]}}
	var ok := IslandMap.new()
	_check(ok.load_dict(base) and ok.is_valid(), "preparo: ids únicos e não vazios são aceitos")
	for bad: Array in [[["g1", ""], "n1"], [["g1", "g1"], "n1"], [["g1", "g2"], ""]]:
		var broken := base.duplicate(true)
		broken["spawn_slots"][0]["id"] = bad[0][0]
		broken["spawn_slots"][1]["id"] = bad[0][1]
		broken["node_ids"]["tree"] = [bad[1]]
		var map := IslandMap.new()
		_check(not map.load_dict(broken) and not map.is_valid() and map.spawn_slots.is_empty(),
				"mapa com id vazio ou repetido (%s / %s) é recusado" % [bad[0], bad[1]])


## Reserva da doma só existe com o selvagem desacordado (alimentar exige isso) e cai quando ele acorda; um save que
## traga reserva num selvagem acordado não a prende.
func _test_wake_drops_reservation() -> void:
	var dino := _spawn_dino()
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	dino.feeder_player_id = "p1"
	dino.torpor.reset()  # acorda
	_check(not dino.state_machine.is_tamed and dino.state_machine.current_id != Enums.DinoStateId.UNCONSCIOUS
			and dino.feeder_player_id == "", "reserva some quando o dino acorda")
	var asleep := _spawn_dino()
	asleep.torpor.add_torpor(asleep.torpor.max_torpor)
	asleep.feeder_player_id = "p1"
	var saved := asleep.to_dict()
	var restored := _spawn_dino()
	_check(restored.from_dict(saved) and restored.feeder_player_id == "p1", "desacordado: a reserva volta do save")
	var awake_state := saved.duplicate(true)
	awake_state["torpor"] = _spawn_dino().torpor.to_dict()
	awake_state["state_machine"] = _spawn_dino().state_machine.to_dict()
	var other := _spawn_dino()
	_check(other.from_dict(awake_state) and other.state_machine.current_id != Enums.DinoStateId.UNCONSCIOUS
			and other.feeder_player_id == "", "save de selvagem acordado com reserva: a reserva não vale")


func _test_carcass_born_at_limits() -> void:
	var main := _main("carcass_limits", 20, true)
	await _root.get_tree().physics_frame
	main.authority.clock.advance(1000.0)
	var now := main.authority.clock.now()
	var fresh := main.carcasses.rules.fresh_seconds
	var entry := {"species": "placeholder_dino", "level": 10, "x": 5.0, "y": 5.0}
	var future := entry.duplicate()
	future["born_at"] = now + 500.0
	var ancient := entry.duplicate()
	ancient["born_at"] = now - fresh * 10.0
	var absurd := entry.duplicate()
	absurd["born_at"] = 1.0e30
	main.carcasses.restore_list([future, absurd])
	var born: Array = []
	for item: Dictionary in main.carcasses.to_list():
		born.append(float(item["born_at"]))
	_check(born.size() == 2 and born[0] <= now and born[1] <= now and born[0] >= now - fresh,
			"born_at no futuro é normalizado para o relógio, nunca acima dele")
	TestWorld.pass_time(main, fresh - 1.0)
	_check(main.carcasses.count() == 2, "o born_at do futuro não dá vida extra: vence fresh_seconds depois da carga")
	TestWorld.pass_time(main, 2.0)
	_check(main.carcasses.count() == 0, "passado fresh_seconds depois da carga, some")
	main.carcasses.restore_list([ancient])
	main.carcasses.tick()
	_check(main.carcasses.count() == 0, "born_at mais velho que o prazo vence no primeiro tick")


func _test_dino_species_and_sex() -> void:
	var dino := _spawn_dino()
	dino.sex = DinoBaseStats.SEX_MALE
	dino.level = 17
	var state := dino.to_dict()
	_check(state["sex"] == "m" and state["species"] == dino.stats.id, "to_dict grava sexo e espécie")
	var twin := _spawn_dino()
	_check(twin.from_dict(JSON.parse_string(JSON.stringify(state))) and twin.sex == "m" and twin.level == 17, "o sexo volta no roundtrip")
	var other := state.duplicate(true)
	other["species"] = "utahraptor"
	var before := twin.to_dict()
	_check(not twin.from_dict(other) and twin.to_dict() == before, "espécie diferente: from_dict recusa e nada muda")
	var legacy := state.duplicate(true)
	legacy.erase("species")
	legacy["level"] = 21
	_check(twin.from_dict(legacy) and twin.level == 21, "estado sem species (save antigo) segue aceito")
	var bad_sex := state.duplicate(true)
	bad_sex["sex"] = "x"
	var keeper := _spawn_dino()
	keeper.sex = "f"
	_check(keeper.from_dict(bad_sex) and keeper.sex == "f", "sexo inválido no arquivo: fica o que a criatura já tem")
	twin.sex = "f"
	_check(twin.from_dict(state) and twin.sex == "m", "gravado e derivado diferentes: vale o gravado")


func _test_world_clock() -> void:
	var tree := _root.get_tree()
	var main := _main("clock", 20, true)
	await tree.physics_frame
	var authority := main.authority
	var start := authority.clock.now()
	authority.clock.advance(2.5)
	_check(is_equal_approx(authority.clock.now(), start + 2.5), "a autoridade avança o relógio")
	authority.clock.advance(-3.0)
	authority.clock.advance(NAN)
	authority.clock.advance(INF)
	_check(is_equal_approx(authority.clock.now(), start + 2.5), "delta negativo ou inválido não mexe no relógio")
	var paused_at := authority.clock.now()
	tree.paused = true
	for i in 5:
		await tree.physics_frame
	tree.paused = false
	_check(authority.clock.now() == paused_at, "na pausa o relógio do mundo para")
	await tree.physics_frame
	await tree.physics_frame
	_check(authority.clock.now() > paused_at, "e volta a andar quando o jogo segue")
	# Nó esgotado não processa: o prazo só compara instantes.
	var node := main.resources.node_by_id("n316")
	node.harvest()
	_check(not node.component.is_physics_processing() and not node.is_physics_processing(), "nó esgotado não liga `_physics_process`")
	# O relógio vai ao save e não avança no carregamento.
	main.save_game(SaveManager.Reason.BED)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_manager.main_path()))
	_check(absf(float(saved["world"]["time"]) - authority.clock.now()) < 0.001, "world.time vai ao save")
	GameSession.continue_requested = true
	var again := _main("clock", 20, true)
	_check(absf(again.authority.clock.now() - float(saved["world"]["time"])) < 0.001, "carregar repõe o relógio sem avançá-lo")


func _test_deadlines_are_absolute() -> void:
	var tree := _root.get_tree()
	var main := _main("absolute", 20, true)
	await tree.physics_frame
	main.authority.clock.advance(100.0)
	var node := main.resources.node_by_id("n316")
	var at := main.authority.clock.now()
	node.harvest()
	_check(absf(node.component.due_at - (at + node.component.respawn_total())) < 0.001, "a colheita marca QUANDO vence (relógio + duração)")
	var entry := node.component.to_dict()
	_check(entry.has("due_at") and not entry.has("respawn_left"), "o save leva o instante, não o que falta")
	# Mudar a regra depois não move o prazo já marcado.
	var marked := node.component.due_at
	node.component.respawn_rate = 4.0
	_check(node.component.due_at == marked, "mudar a regra do servidor não move prazo já marcado")
	# Idade da carcaça: nasce com born_at = relógio e some por diferença.
	var dead := main.wild.creature_at(_wid(main, 0))
	dead.health.take_damage(dead.health.max_health * 2.0)
	await tree.physics_frame
	_check(main.carcasses.count() == 1 and absf(float(main.carcasses.to_list()[0]["born_at"]) - main.authority.clock.now()) < 1.0,
			"a carcaça guarda quando nasceu")
	var fresh := main.carcasses.rules.fresh_seconds
	TestWorld.pass_time(main, fresh - 1.0)
	_check(main.carcasses.count() == 1, "antes de fresh_seconds a carcaça fica")
	TestWorld.pass_time(main, 2.0)
	_check(main.carcasses.count() == 0, "passado fresh_seconds ela some")
	# Selvagem distante segue congelado: o relógio andou 600 s e ele não mudou.
	var far := main.wild.creature_at(_wid(main, 50))
	var hunger_like := far.to_dict()
	TestWorld.pass_time(main, 600.0)
	_check(far.to_dict() == hunger_like, "selvagem distante continua congelado enquanto o relógio anda")
	# Sem a autoridade andando o nó não volta (o relógio manda, não os quadros do nó).
	var stuck := main.resources.node_by_id("n317")
	stuck.harvest()
	stuck.component.tick()
	_check(not stuck.is_available(), "sem o prazo vencer, tick do nó não o devolve")


func _test_wild_from_spawn_seed() -> void:
	var tree := _root.get_tree()
	var main := _main("seed", 20, true)
	await tree.physics_frame
	var map := main.map
	var ok := true
	var males := 0
	var checked := 0
	for id in main.wild.member_ids():
		var creature := main.wild.creature_at(id)
		if creature == null:
			continue
		checked += 1
		var band := creature.stats.spawn_level_band(main.world_rules.level_band_of(map.terrain_at(map.cell_of(creature.position))))
		for slot in map.spawn_slots:  # o bando de toca tem faixa própria por toca (E3a)
			if slot["id"] == id.get_slice(".", 0) and slot["den"] != "" and creature.stats.home != null:
				band = creature.stats.home.rules.band_of(slot["den"], band)
		ok = ok and creature.level == WildPopulation.roll_level(band, main.world_seed, id) \
				and creature.sex == creature.stats.roll_sex(main.world_seed, id) and main.wild.spawn_id_of(creature) == id
		males += 1 if creature.sex == "m" else 0
	_check(checked >= 70 and ok, "nível e sexo de cada selvagem saem da semente do mundo e do id do membro (%d conferidos)" % checked)
	_check(males > checked * 0.3 and males < checked * 0.7, "sexo meio a meio no mundo (%d de %d machos)" % [males, checked])
	_check(main.dino.sex == "f" or main.dino.sex == "m", "o dino do tutorial também tem sexo")
	# Mesmo mundo, mesmo resultado (a ordem de criação não pesa).
	var twin := _main("seed_twin", 20, true)
	await tree.physics_frame
	var same := true
	for id in main.wild.member_ids():
		var a := main.wild.creature_at(id)
		var b := twin.wild.creature_at(id)
		same = same and ((a == null) == (b == null)) and (a == null or (a.level == b.level and a.sex == b.sex and a.position == b.position))
	_check(same and main.wild.member_ids() == twin.wild.member_ids(), "a mesma semente gera os mesmos dinos, nos mesmos lugares")


func _test_wild_delta_species_mismatch() -> void:
	var tree := _root.get_tree()
	var source := _main("mismatch_src", 20, true)
	await tree.physics_frame
	var raptor_id := ""
	for id in source.wild.member_ids():
		if source.wild.creature_at(id).stats.spawn_key == "utahraptor":
			raptor_id = id
			break
	var wild := source.wild.creature_at(_wid(source, 0))
	wild.torpor.add_torpor(wild.torpor.max_torpor)
	var envelope := WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild)
	# O estado de um paquicéfalo cai no ponto de um utahraptor: a entrada é ignorada e o utahraptor nasce novo.
	var entry: Dictionary = (envelope["world"]["wild"] as Array)[0].duplicate(true)
	entry["id"] = raptor_id
	envelope["world"]["wild"].append(entry)
	var target := _main("mismatch_dst", 20, true)
	await tree.physics_frame
	var raptor := target.wild.creature_at(raptor_id)
	var raptor_before := raptor.to_dict()
	_check(WorldSnapshot.restore(envelope, target.player, target.dino, target.resources, target.wild),
			"estado de outra espécie no delta não derruba a carga")
	_check(raptor.to_dict() == raptor_before and not raptor.torpor.is_unconscious and target.wild.creature_at(_wid(target,
			0)).torpor.is_unconscious,
			"o utahraptor nasce novo e o paquicéfalo certo recebe o dele")


func _test_new_world_player_id() -> void:
	var tree := _root.get_tree()
	var first := _main("new_a", 20, true)
	var second := _main("new_b", 20, true)
	await tree.physics_frame
	var id := first.player.player_id
	_check(id.length() == 32 and id.is_valid_hex_number(false) and id != Player.LOCAL_PLAYER_ID, "mundo novo: player_id de 32 hex")
	_check(second.player.player_id != id, "dois mundos novos têm ids diferentes")
	first.save_game(SaveManager.Reason.BED)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first.save_manager.main_path()))
	_check(saved["world"]["local_player_id"] == id and saved["players"][0]["player_id"] == id and saved["format_version"] == 5
			and int(saved["world"]["next_entity_id"]) >= 3, "o save leva world.local_player_id, o mesmo id e next_entity_id")
