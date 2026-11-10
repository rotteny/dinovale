# SPDX-License-Identifier: MIT
class_name DodoTests
extends WildGroupsTests
## E13, o Dodo (Covarde): dado da espécie, aproximação e ronda a 3 tiles, susto e fuga, alarme do grupo, nunca revida, Soco que
## derruba em 6 a 7 golpes, doma com baga em 6 refeições, carcaça 2 + 1, Lança que mata em 2, população na Mata-baixa, respawn
## de 10 min, save e o custo por quadro. Chamado por `run_tests.gd`.

const DODO: DinoBaseStats = preload("res://data/dino/dodo.tres")
const TILE := 16.0
const PUNCH_TORPOR := 10.0
const PUNCH_PAUSE := 0.6


func run() -> void:
	_test_species_data()
	_test_approach_and_patrol()
	_test_scare_and_flee()
	_test_wary_after_flee()
	_test_never_strikes_back()
	_test_punch_knockout()
	_test_taming_with_berries()
	_test_save_states()
	await _test_world_population()
	_release_worlds()
	await _test_alarm_and_spear()
	_release_worlds()
	await _test_carcass_and_taming_in_world()
	_release_worlds()
	await _test_respawn_ten_minutes()
	_release_worlds()
	await _test_tamed_dodo_survives_continue()
	_release_worlds()
	await _test_frame_cost()
	_release_worlds()


func _coward_machine() -> DinoStateMachine:
	var machine: DinoStateMachine = _track.call(DinoStateMachine.new())
	machine.torpor = _track.call(TorporComponent.new())
	machine.rng.seed = 42
	machine.start()
	machine.configure(DODO, 40.0, TILE)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	return machine


## Dodo no nível `level`, no ponto `at`, sem física própria (o teste o move).
func _dodo(at: Vector2, level: int, herd: String = "") -> Dino:
	var dino: Dino = preload("res://src/entities/dino/Dino.tscn").instantiate()
	dino.stats = DODO
	dino.level = level
	_root.add_child(dino)
	_track.call(dino)
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	dino.torpor.set_physics_process(false)
	dino.position = at
	dino.herd_id = herd
	dino.state_machine.rng.seed = 7
	return dino


func _test_species_data() -> void:
	var rules := DinoLevelRules.new()
	_check(DODO.id == "dodo" and DODO.spawn_key == "dodo" and DODO.ideal_food == Items.BERRY and not DODO.aggressive
			and DODO.coward != null and DODO.size == Enums.DinoSize.SMALL, "o Dodo é Covarde, pequeno, não agressivo e come baga")
	_check(is_equal_approx(DODO.base_health, 24.0) and is_equal_approx(DODO.base_torpor, 50.0)
			and DODO.carcass_meat == 2 and DODO.carcass_leather == 1, "vida 24, torpor 50 e carcaça 2 de carne e 1 de couro")
	_check(is_equal_approx(rules.max_health(DODO.base_health, 10), 24.0) and is_equal_approx(rules.max_torpor(DODO.base_torpor, 10), 50.0)
			and is_equal_approx(rules.max_torpor(DODO.base_torpor, 3), 43.0), "L10: vida 24 e torpor 50; L3: torpor 43")
	var coward := DODO.coward
	_check(is_equal_approx(coward.perception_tiles, 6.0) and is_equal_approx(coward.approach_tiles, 3.0)
			and is_equal_approx(coward.patrol_speed, 35.0) and is_equal_approx(coward.scare_seconds, 0.8)
			and is_equal_approx(coward.flee_max_tiles, 16.0) and is_equal_approx(coward.flee_max_seconds, 10.0)
			and is_equal_approx(coward.alarm_radius_tiles, 8.0) and is_equal_approx(coward.alarm_delay_s, 0.5)
			and is_equal_approx(DODO.chase_speed, 90.0), "ronda 35, susto 0,8 s, fuga a 90 até 16 tiles ou 10 s, alarme 8 tiles em 0,5 s")
	_check(is_equal_approx(DODO.group_respawn_seconds, 600.0) and DODO.spawn_terrains.size() == 1
			and DODO.spawn_terrains[0] == IslandMap.WOODLAND
			and DODO.spawn_level_band(Vector2i(5, 25)) == Vector2i(3, 10), "respawn de 10 min, só Mata-baixa, nível de 3 a 10")
	_check(WildPopulation.species_by_id("dodo") == DODO, "o mundo conhece a espécie")


func _test_approach_and_patrol() -> void:
	var machine := _coward_machine()
	machine.observe_target(Vector2(6.5 * TILE, 0.0), true)
	machine.tick(0.1)
	_check(machine.current_id != Enums.DinoStateId.CURIOUS, "a 6,5 tiles o Dodo não percebe")
	machine.observe_target(Vector2(5.5 * TILE, 0.0), true)
	machine.tick(0.1)
	_check(machine.current_id == Enums.DinoStateId.CURIOUS and is_equal_approx(machine.speed_multiplier, 35.0 / 40.0)
			and machine.desired_direction.dot(Vector2.RIGHT) > 0.99, "a 5,5 tiles vem na direção do jogador a 35 px/s")
	var vertical := _coward_machine()
	vertical.observe_target(Vector2(0.0, 4.0 * TILE), true)
	vertical.tick(0.1)
	_check(vertical.current_id != Enums.DinoStateId.CURIOUS, "a 4 tiles na vertical não percebe (elipse como a do GDD)")
	# anda de verdade: vem até 3 tiles e fica rondando, sem encostar e sem ficar bravo
	var walker := _coward_machine()
	var position := Vector2(5.5 * TILE, 0.0)
	var closest := INF
	var fastest := 0.0
	var angry := false
	for step in 400:
		walker.observe(position, Vector2.ZERO, false)
		walker.observe_target(Vector2.ZERO, true)
		walker.tick(0.05)
		var velocity := walker.desired_direction * 40.0 * walker.speed_multiplier
		fastest = maxf(fastest, velocity.length())
		position += velocity * 0.05
		angry = angry or walker.is_aggressive
		if step > 100:
			closest = minf(closest, position.length())
	_check(fastest <= 35.01 and not angry, "nunca passa de 35 px/s e nunca fica bravo (%.1f)" % fastest)
	_check(closest >= 2.5 * TILE and position.length() <= 4.5 * TILE,
			"chega a 3 tiles e ronda sem encostar (mais perto %.0f px, agora %.0f px)" % [closest, position.length()])
	# some o alvo ou ele passa da percepção: volta ao normal
	walker.observe_target(Vector2(8.0 * TILE, 0.0) + position, true)
	walker.tick(0.05)
	_check(walker.current_id == Enums.DinoStateId.IDLE and is_equal_approx(walker.speed_multiplier, 1.0),
			"o jogador se afasta além de 6 tiles: volta a Idle")


func _test_scare_and_flee() -> void:
	var machine := _coward_machine()
	machine.observe(Vector2(100.0, 0.0), Vector2.ZERO, false)
	machine.observe_target(Vector2(60.0, 0.0), true)
	machine.provoke()
	_check(machine.current_id == Enums.DinoStateId.FLEEING and machine.is_scared() and not machine.is_aggressive,
			"o golpe assusta o Covarde (e nunca o deixa bravo)")
	machine.tick(0.7)
	_check(machine.is_scared() and machine.desired_direction == Vector2.ZERO, "durante 0,8 s fica parado de susto")
	machine.tick(0.15)
	machine.tick(0.05)
	_check(not machine.is_scared() and machine.desired_direction.x > 0.99 and is_equal_approx(machine.speed_multiplier, 90.0 / 40.0),
			"passado o susto corre para longe do atacante a 90 px/s")
	# a fuga acaba aos 16 tiles (256 px): anda de verdade
	var position := Vector2(100.0, 0.0)
	var seconds := 0.0
	while machine.current_id == Enums.DinoStateId.FLEEING and seconds < 20.0:
		machine.observe(position, Vector2.ZERO, false)
		machine.tick(0.05)
		position += machine.desired_direction * 40.0 * machine.speed_multiplier * 0.05
		seconds += 0.05
	var run := position.x - 100.0
	_check(machine.current_id == Enums.DinoStateId.IDLE and run >= 16.0 * TILE and run < 16.0 * TILE + 10.0 and seconds < 4.0,
			"a fuga acaba ao andar 16 tiles (%.0f px em %.1f s) e o Dodo volta a Idle" % [run, seconds])
	# encurralado (não sai do lugar): a fuga acaba em 10 s depois do susto
	var cornered := _coward_machine()
	cornered.observe_target(Vector2(-20.0, 0.0), true)
	cornered.provoke()
	for i in 100:
		cornered.tick(0.1)
	_check(cornered.current_id == Enums.DinoStateId.FLEEING, "aos 10 s (0,8 de susto + 9,2 de fuga) ainda foge")
	for i in 12:
		cornered.tick(0.1)
	_check(cornered.current_id == Enums.DinoStateId.IDLE, "aos 10,8 s acaba a fuga por tempo")
	# quem dorme não se assusta, o domado também não
	var asleep := _coward_machine()
	asleep.torpor.add_torpor(asleep.torpor.max_torpor)
	asleep.provoke()
	_check(asleep.current_id == Enums.DinoStateId.UNCONSCIOUS, "dormindo não se assusta nem foge")
	var tamed := _coward_machine()
	tamed.is_tamed = true
	tamed.provoke()
	_check(tamed.current_id != Enums.DinoStateId.FLEEING, "o domado não é Covarde de fuga")


func _test_wary_after_flee() -> void:
	var machine := _coward_machine()
	machine.observe_target(Vector2(-20.0, 0.0), true)
	machine.provoke()
	for i in 120:
		machine.tick(0.1)
	_check(machine.current_id != Enums.DinoStateId.FLEEING, "fuga acabou")
	machine.observe_target(Vector2(3.0 * TILE, 0.0), true)
	for i in 80:
		machine.tick(0.1)
	_check(machine.current_id != Enums.DinoStateId.CURIOUS, "10 s depois da fuga ainda desconfia e não se aproxima (8 s)")
	for i in 30:
		machine.tick(0.1)
	_check(machine.current_id == Enums.DinoStateId.CURIOUS, "passada a desconfiança, volta a ser curioso")


func _test_never_strikes_back() -> void:
	var player: Player = _spawn_player_at(Vector2(0.0, 0.0))
	var dodo := _dodo(Vector2(12.0, 0.0), 10)
	dodo.target_locator = func() -> Array: return [player]
	var strikes: Array[int] = [0]
	var provoked: Array[int] = [0]
	dodo.attack_requested.connect(func(_t: Node2D, _d: float, _e: int) -> void: strikes[0] += 1)
	dodo.provoked.connect(func(_id: String) -> void: provoked[0] += 1)
	_check(dodo.receive_hit(1.0, PUNCH_TORPOR, TamingRules.ATTACKER_PLAYER, player.player_id), "o Soco acerta")
	var angry := dodo.state_machine.is_aggressive
	for i in 200:
		dodo.observe_owner()
		dodo.observe_targets()
		dodo.state_machine.tick(0.05)
		angry = angry or dodo.state_machine.is_aggressive
	_check(not angry and strikes[0] == 0 and provoked[0] == 1 and dodo.attack_damage == 0.0,
			"atacado, o Dodo foge: nunca fica bravo, nunca pede golpe (provoked %d) e o dano dele é 0" % provoked[0])
	_check(dodo.stats.threat_profile == null and dodo.stats.predation == null, "não tem ciclo de ameaça nem caça")


func _spawn_player_at(at: Vector2) -> Player:
	var player: Player = preload("res://src/entities/player/Player.tscn").instantiate()
	_root.add_child(player)
	_track.call(player)
	player.set_physics_process(false)
	player.position = at
	player.player_id = "dodo_tester"
	return player


## Quantos Socos (um a cada 0,6 s, com a queda de 5/s entre eles) até o Dodo dormir.
func _punches_to_sleep(level: int) -> int:
	var dodo := _dodo(Vector2.ZERO, level)
	var hits := 0
	while not dodo.torpor.is_unconscious and hits < 30:
		hits += 1
		dodo.receive_hit(1.0, PUNCH_TORPOR, TamingRules.ATTACKER_PLAYER, "p1")
		if not dodo.torpor.is_unconscious:
			dodo.torpor.tick(PUNCH_PAUSE)
	_check(dodo.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not dodo.health.is_dead(),
			"L%d: o Soco derruba sem matar (vida %.1f de %.1f)" % [level, dodo.health.current_health, dodo.health.max_health])
	return hits


func _test_punch_knockout() -> void:
	var low := _punches_to_sleep(3)
	var high := _punches_to_sleep(10)
	_check(low == 6, "L3 (torpor 43): 6 Socos, 3,0 s (%d)" % low)
	_check(high == 7, "L10 (torpor 50): 7 Socos, 3,6 s (%d)" % high)
	# o torpor global cai 5/s acordado e 1/s dormindo (sem campo novo)
	var dodo := _dodo(Vector2.ZERO, 10)
	_check(is_equal_approx(dodo.torpor.decay_per_second, 5.0) and is_equal_approx(dodo.torpor.unconscious_decay_per_second, 1.0),
			"recuperação de torpor global: 5/s acordado, 1/s dormindo")
	dodo.torpor.add_torpor(dodo.torpor.max_torpor)
	var seconds := 0
	while dodo.torpor.is_unconscious and seconds < 200:
		dodo.torpor.tick(1.0)
		seconds += 1
	_check(seconds == 50, "dormindo no L10 dura 50 s de janela (%d)" % seconds)


func _tame_dodo(level: int, berries: int) -> Array:
	var dodo := _dodo(Vector2.ZERO, level)
	dodo.feeder_player_id = "p1"
	dodo.torpor.add_torpor(dodo.torpor.max_torpor)
	dodo.inventory.add("berry", berries)
	var meals := 0
	while not dodo.state_machine.is_tamed and meals < 30:
		dodo.taming.tick(5.1)
		meals += 1
	return [dodo, meals]


func _test_taming_with_berries() -> void:
	for level in [3, 10]:
		var low := _dodo(Vector2.ZERO, level)
		_check(low.taming.meals_required() == 6, "L%d: 6 refeições (%d)" % [level, low.taming.meals_required()])
	_check(_dodo(Vector2.ZERO, 20).taming.meals_required() == 7, "L20: 7 refeições")
	var result := _tame_dodo(10, 10)
	var dodo: Dino = result[0]
	_check(dodo.state_machine.is_tamed and result[1] == 6 and dodo.inventory.count("berry") == 4 and dodo.owner_player_id == "p1",
			"6 bagas domam o Dodo L10 (%d refeições, sobram %d) e ele fica com o dono" % [result[1], dodo.inventory.count("berry")])
	var meat := _dodo(Vector2.ZERO, 10)
	meat.feeder_player_id = "p1"
	meat.torpor.add_torpor(meat.torpor.max_torpor)
	meat.inventory.add("meat", 20)
	for i in 10:
		meat.taming.tick(5.1)
	_check(not meat.state_machine.is_tamed and meat.taming.taming_progress == 0.0, "carne não doma o Dodo: a comida ideal é baga")
	# a doma cabe na janela do torpor: 6 x 5 s = 30 s < 43 s (L3) e < 50 s (L10)
	_check(6.0 * 5.0 < 43.0, "30 s de doma cabem na janela de 43 s do L3 (e na de 50 s do L10)")


func _test_save_states() -> void:
	var fleeing := _dodo(Vector2.ZERO, 10)
	fleeing.state_machine.observe_target(Vector2(-20.0, 0.0), true)
	fleeing.state_machine.provoke()
	_check(fleeing.state_machine.current_id == Enums.DinoStateId.FLEEING and fleeing.to_dict()["state_machine"]["state"] == "IDLE",
			"em fuga o save grava Idle (nunca o susto)")
	var curious := _dodo(Vector2.ZERO, 10)
	curious.state_machine.observe_target(Vector2(3.0 * TILE, 0.0), true)
	curious.state_machine.tick(0.1)
	_check(curious.state_machine.current_id == Enums.DinoStateId.CURIOUS and curious.to_dict()["state_machine"]["state"] == "IDLE",
			"curioso o save grava Idle")
	var data := JSON.parse_string(JSON.stringify(curious.to_dict())) as Dictionary
	var back := _dodo(Vector2.ZERO, 10)
	data["state_machine"]["state"] = "CURIOUS"  # save hostil ou futuro: estado que não persiste volta a Idle
	_check(back.from_dict(data) and back.state_machine.current_id == Enums.DinoStateId.IDLE and data["species"] == "dodo",
			"save com estado CURIOUS carrega como Idle e guarda a espécie")
	_check(back.torpor.max_torpor == 50.0, "o torpor máximo vem do nível, não do save")


# ----------------------------------------------------------------------------- no mundo

func _dodos_of(main: Main) -> Array[Dino]:
	var out: Array[Dino] = []
	for child in main.wild.get_children():
		if (child as Dino).stats.id == "dodo":
			out.append(child as Dino)
	return out


func _dodo_slots(main: Main) -> Array[String]:
	var out: Array[String] = []
	for slot_id in main.wild.slot_ids():
		if main.wild.slot_info(slot_id)["species"] == "dodo":
			out.append(slot_id)
	return out


func _test_world_population() -> void:
	var main := _main("dodo_world", 20, true)
	await _root.get_tree().physics_frame
	var dodos := _dodos_of(main)
	var slots := _dodo_slots(main)
	_check(dodos.size() == 140 and slots.size() == 7, "140 Dodos em 7 bandos de 20 (%d em %d)" % [dodos.size(), slots.size()])
	var woodland := true
	var levels_ok := true
	var health_ok := true
	for dodo in dodos:
		woodland = woodland and main.map.terrain_at(main.map.cell_of(dodo.position)) == IslandMap.WOODLAND
		levels_ok = levels_ok and dodo.level >= 3 and dodo.level <= 10
		health_ok = health_ok and is_equal_approx(dodo.health.max_health, 24.0 * main.dino.level_rules.health_factor(dodo.level))
	_check(woodland, "todo Dodo nasce em Mata-baixa")
	_check(levels_ok and health_ok, "nível de 3 a 10 e vida pela fórmula (24 no L10)")
	_check(main.wild.get_child_count() == 70 + 12 + 140, "o mundo: 70 paquicéfalos (com o do tutorial), 12 utahraptores e 140 Dodos")
	var ids_unique := {}
	for dodo in dodos:
		ids_unique[main.wild.spawn_id_of(dodo)] = true
	_check(ids_unique.size() == 140, "ids de spawn únicos")


func _wire_group(main: Main, slot_id: String, level: int) -> Array[Dino]:
	var out: Array[Dino] = []
	for member_id: String in main.wild.slot_info(slot_id)["members"]:
		var dodo := main.wild.creature_at(member_id)
		dodo.level = level
		out.append(dodo)
	return out


func _test_alarm_and_spear() -> void:
	var main := _main("dodo_alarm", 20, true)
	await _root.get_tree().physics_frame
	var slots := _dodo_slots(main)
	var group := _wire_group(main, slots[0], 10)
	var other_group := _wire_group(main, slots[1], 10)
	var origin := Vector2(2000.0, 2000.0)
	var player := main.player
	player.global_position = origin + Vector2(-20.0, 0.0)
	player.facing = Vector2.RIGHT
	for dodo in group:  # os de fora do raio e o do outro bando ficam longe; só 4 do bando perto
		dodo.global_position = origin + Vector2(0.0, 3000.0)
	var struck := group[0]
	var near := group[1]
	var edge := group[2]
	var far := group[3]
	var asleep := group[4]
	struck.global_position = origin
	near.global_position = origin + Vector2(5.0 * TILE, 0.0)
	edge.global_position = origin + Vector2(7.5 * TILE, 0.0)
	far.global_position = origin + Vector2(12.0 * TILE, 0.0)
	asleep.global_position = origin + Vector2(2.0 * TILE, 0.0)
	asleep.torpor.add_torpor(asleep.torpor.max_torpor)
	var stranger := other_group[0]
	stranger.global_position = origin + Vector2(3.0 * TILE, 0.0)
	for dodo: Dino in [struck, near, edge, far, asleep, stranger]:
		dodo.observe_owner()
	var authority := main.authority
	player.tick(1.0)
	var result := authority.request_attack(1, authority.id_of(struck))
	_check(result == Enums.ActionResult.OK and struck.state_machine.current_id == Enums.DinoStateId.FLEEING
			and not struck.state_machine.is_aggressive and struck.state_machine.flee_from.x < struck.global_position.x,
			"o Soco assusta o Dodo atingido, que foge para longe do jogador (%s)" % Enums.ActionResult.find_key(result))
	_check(main.authority.herd.alarm_count() == 2,
			"o alarme escala quem está a até 8 tiles no mesmo bando e acordado (%d)" % main.authority.herd.alarm_count())
	authority.tick_herd(0.4)
	_check(near.state_machine.current_id != Enums.DinoStateId.FLEEING, "antes de 0,5 s o grupo ainda não reagiu")
	authority.tick_herd(0.15)
	_check(near.state_machine.current_id == Enums.DinoStateId.FLEEING and edge.state_machine.current_id == Enums.DinoStateId.FLEEING,
			"depois de 0,5 s os do raio de 8 tiles fogem junto")
	_check(far.state_machine.current_id != Enums.DinoStateId.FLEEING and stranger.state_machine.current_id != Enums.DinoStateId.FLEEING
			and asleep.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS,
			"o de 12 tiles, o de outro bando e o que dorme não reagem")
	var bitten := false
	for dodo: Dino in [struck, near, edge]:
		bitten = bitten or dodo.state_machine.is_aggressive
	_check(not bitten and authority.herd.pending_count() == 0, "ninguém fica bravo: o alarme não chama para brigar")
	# o grupo volta a pastar depois da fuga (0,8 s + 10 s)
	for step in 130:
		for dodo: Dino in [struck, near, edge]:
			dodo.observe_owner()
			dodo.state_machine.tick(0.1)
	_check(struck.state_machine.current_id != Enums.DinoStateId.FLEEING and near.state_machine.current_id != Enums.DinoStateId.FLEEING,
			"13 s depois o grupo voltou a pastar")
	# alimentar não é ataque: quem transfere comida ao dormindo não assusta o bando
	var calm := authority.herd.alarm_count()
	_check(calm == 0, "sem golpe novo, sem alarme novo")
	# Lança: 2 golpes de 12 matam vida 24 (borda: vida <= 0) e 17,3 (L3)
	var spear_targets: Dictionary = {10: other_group[1], 3: other_group[2]}
	for level in [10, 3]:
		var target: Dino = spear_targets[level]
		target.level = level
		target.health.current_health = target.health.max_health
		target.global_position = origin + Vector2(0.0, 40.0)
		player.global_position = origin + Vector2(0.0, 40.0 + 20.0)
		player.facing = Vector2.UP
		player.inventory.add(Items.WOODEN_SPEAR, 1)
		player.request_equip(player.newest_iid(Items.WOODEN_SPEAR))
		player._equip_timer = 0.0
		player.tick(1.0)
		var first := authority.request_attack(1, authority.id_of(target))
		var alive_after_first := not target.health.is_dead()
		player.tick(1.0)
		var second := authority.request_attack(1, authority.id_of(target))
		_check(first == Enums.ActionResult.OK and second == Enums.ActionResult.OK and alive_after_first and target.health.is_dead(),
				"Lança L%d: o 1º golpe não mata (%.1f), o 2º mata" % [level, target.health.current_health])


func _test_carcass_and_taming_in_world() -> void:
	var main := _main("dodo_carcass", 20, true)
	await _root.get_tree().physics_frame
	var dodos := _dodos_of(main)
	for level in [3, 10]:
		var dodo := dodos[level]
		dodo.level = level
		dodo.health.take_damage(1.0e6)
		var carcass := main.carcasses.carcass_of(dodo)
		_check(carcass != null and carcass.component.pending_yields() == {"meat": 2, "leather": 1},
				"carcaça do Dodo L%d: 2 de carne e 1 de couro" % level)
	var tamer := dodos[20]
	tamer.level = 3
	_tame(main, tamer)
	_check(tamer.state_machine.is_tamed and tamer.owner_player_id == main.player.player_id, "o Dodo do mundo é domado com baga")


func _test_respawn_ten_minutes() -> void:
	var main := _main("dodo_respawn", 20, true)
	await _root.get_tree().physics_frame
	var slot_id := _dodo_slots(main)[0]
	var spawned: Array = []
	main.wild.group_spawned.connect(func(creatures: Array[Dino]) -> void: spawned.append_array(creatures))
	var now := main.authority.clock.now()
	_wipe(main, slot_id)
	main.wild.tick(now)
	var info := main.wild.slot_info(slot_id)
	_check(info["waiting"] and is_equal_approx(info["due_at"], now + 600.0), "o bando de Dodos morto espera 10 min (600 s)")
	main.authority.clock.advance(599.0)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.is_empty(), "aos 599 s ainda não voltou")
	main.authority.clock.advance(1.0)
	main.wild.tick(main.authority.clock.now())
	info = main.wild.slot_info(slot_id)
	var woodland := true
	for dodo: Dino in spawned:
		woodland = woodland and main.map.terrain_at(main.map.cell_of(dodo.position)) == IslandMap.WOODLAND \
				and dodo.stats.id == "dodo" and dodo.level >= 3 and dodo.level <= 10
	_check(not info["waiting"] and info["gen"] == 1 and spawned.size() >= 8 and woodland,
			"aos 600 s o bando renasce (geração 1, %d Dodos) na Mata-baixa, nível de 3 a 10" % spawned.size())


func _test_tamed_dodo_survives_continue() -> void:
	var seen := [Vector2.ZERO]
	var after := await _save_and_continue("dodo_tamed", func(main: Main) -> void:
		var dodo := _dodos_of(main)[5]
		dodo.level = 8
		_tame(main, dodo)
		seen[0] = dodo.position)
	var back := _tamed_wild(after)
	_check(back != null and back.stats.id == "dodo" and back.position == seen[0] and back.owner_player_id == after.player.player_id
			and back.taming.ideal_food == Items.BERRY, "depois do Continuar o Dodo domado segue Dodo, no lugar e com dono")
	_check(_dodos_of(after).size() == 140, "e o mundo tem os 140 Dodos (139 selvagens e o domado), sem duplicar")


## Custo por quadro dos 140 Dodos a mais: o mundo inteiro (222 selvagens), a zona reclassificando e os ativos pensando.
func _test_frame_cost() -> void:
	var started := Time.get_ticks_usec()
	var main := _main("dodo_cost", 20, true)
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	await _root.get_tree().physics_frame
	var group := _wire_group(main, _dodo_slots(main)[0], 10)
	var center := group[0].global_position
	main.player.global_position = center + Vector2(-60.0, 0.0)
	main.zone.reclassify()
	var active: Array[Dino] = []
	for dodo in _dodos_of(main):
		if main.zone.mode_of(dodo) == ActivityZone.Mode.ACTIVE:
			active.append(dodo)
	var batches: Array[float] = []
	for _batch in 5:  # o menor de 5 lotes: um pico de relógio ou de coleta não reprova
		var spent := 0.0
		for _frame in 100:
			var frame := Time.get_ticks_usec()
			main.zone.reclassify()
			for dodo in active:
				dodo.observe_owner()
				dodo.observe_targets()
				dodo.state_machine.tick(0.016)
			spent += float(Time.get_ticks_usec() - frame)
		batches.append(spent / 100.0)
	var best: float = batches.min()
	print("      Dodo: mundo de %d selvagens carrega em %.0f ms; %d Dodos ativos; zona + IA por quadro: %.0f us (menor de 5 lotes)"
			% [main.wild.get_child_count(), load_ms, active.size(), best])
	_check(main.wild.get_child_count() == 222 and active.size() <= 32 and best < 4000.0,
			"custo por quadro dos Dodos ativos cabe no orçamento (%.0f us < 4 ms, %d ativos)" % [best, active.size()])
