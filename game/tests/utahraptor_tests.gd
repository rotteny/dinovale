# SPDX-License-Identifier: MIT
class_name UtahraptorTests
extends WildPersistenceTests
## Utahraptor nas 6 tocas da Mata-baixa (MUN-03 parte 2): o dado da espécie, onde nasce, a perseguição do Agressivo
## (percepção em elipse, desistência, alerta), a doma pela comida da espécie e o save que lembra a espécie.
## Chamado por `run_tests.gd`.

const UTAHRAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
const PER_DEN: Dictionary = {"U1": 1, "U2": 2, "U3": 2, "U4": 1, "U5": 2, "U6": 2}
## Raio de nascimento do exportador, em tiles em volta da toca.
const DEN_RADIUS_TILES := 5.0


func run() -> void:
	_test_species_data()
	_test_map_spawns()
	_test_chase_rules()
	await _test_population_and_chase()
	_release_worlds()
	await _test_taming_and_save()
	_release_worlds()


func _test_species_data() -> void:
	_check(
		(
			UTAHRAPTOR.id == "utahraptor"
			and UTAHRAPTOR.aggressive
			and UTAHRAPTOR.spawn_key == "utahraptor"
			and UTAHRAPTOR.ideal_food == Items.MEAT
		),
		"o Utahraptor é agressivo, nasce pela chave utahraptor e come carne"
	)
	_check(
		(
			is_equal_approx(UTAHRAPTOR.base_health, 80.0)
			and is_equal_approx(UTAHRAPTOR.base_damage, 8.0)
			and is_equal_approx(UTAHRAPTOR.base_torpor, 120.0)
			and is_equal_approx(UTAHRAPTOR.chase_speed, 90.0)
		),
		"vida 80, dano 8, torpor 120 e perseguição a 90 px/s (GDD)"
	)
	var sheet := SpriteSheetDef.from_json_file(UTAHRAPTOR.sheet_path)
	_check(sheet != null and sheet.frame_size.x > 0, "a folha do Utahraptor carrega")
	_check(
		(
			WildPopulation.species_by_id("utahraptor") == UTAHRAPTOR
			and WildPopulation.species_by_id("placeholder_dino").id == "placeholder_dino"
			and WildPopulation.species_by_id("outra").id == "placeholder_dino"
		),
		"espécie por id; desconhecida cai na primeira"
	)


func _test_map_spawns() -> void:
	var map := IslandMap.default_map()
	var cells: Array = map.spawns.get("utahraptor", [])
	var expected := 0
	for count: int in PER_DEN.values():
		expected += count
	_check(cells.size() == expected and expected == 10, "10 utahraptores no mapa")
	var next := 0
	var all_ok := true
	var seen := {}
	var paquicefalos: Array = map.spawns["paquicefalo"]
	for den_name: String in PER_DEN:
		var den: Vector2i = map.dens[den_name]
		for i in PER_DEN[den_name]:
			var cell: Vector2i = cells[next]
			next += 1
			all_ok = (
				all_ok
				and map.terrain_at(cell) == IslandMap.WOODLAND
				and Vector2(cell - den).length() <= DEN_RADIUS_TILES
				and not seen.has(cell)
				and not paquicefalos.has(cell)
			)
			seen[cell] = true
	_check(
		all_ok,
		"cada utahraptor nasce em Mata-baixa, a até 5 tiles da própria toca (U1 com 1; U2 a U6 com 1 ou 2), sem repetir célula"
	)


func _make_machine() -> DinoStateMachine:
	var machine: DinoStateMachine = _track.call(DinoStateMachine.new())
	machine.torpor = _track.call(TorporComponent.new())
	machine.rng.seed = 42
	machine.start()
	return machine


func _machine_for(stats: DinoBaseStats) -> DinoStateMachine:
	var machine := _make_machine()
	machine.configure(stats, 40.0, 16.0)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	return machine


func _test_chase_rules() -> void:
	var tile := 16.0
	var machine := _machine_for(UTAHRAPTOR)
	machine.observe_target(Vector2(9.0 * tile, 0.0), true)
	machine.tick(0.1)
	_check(machine.current_id != Enums.DinoStateId.CHASE, "a 9 tiles na horizontal ele não percebe")
	machine.observe_target(Vector2(7.5 * tile, 0.0), true)
	machine.tick(0.1)
	_check(machine.current_id == Enums.DinoStateId.CHASE, "a 7,5 tiles na horizontal ele persegue")
	_check(
		machine.desired_direction.is_equal_approx(Vector2.RIGHT) and is_equal_approx(machine.speed_multiplier, 90.0 / 40.0),
		"corre na direção do alvo a 90 px/s"
	)
	var vertical := _machine_for(UTAHRAPTOR)
	vertical.observe_target(Vector2(0.0, 5.5 * tile), true)
	vertical.tick(0.1)
	_check(vertical.current_id != Enums.DinoStateId.CHASE, "a 5,5 tiles na vertical não percebe (elipse 8 x 5)")
	vertical.observe_target(Vector2(0.0, 4.9 * tile), true)
	vertical.tick(0.1)
	_check(vertical.current_id == Enums.DinoStateId.CHASE, "a 4,9 tiles na vertical percebe")
	# desiste além de 20 tiles, volta a Idle e fica 5 s em alerta
	machine.observe_target(Vector2(21.0 * tile, 0.0), true)
	machine.tick(0.1)
	_check(
		machine.current_id == Enums.DinoStateId.IDLE and is_equal_approx(machine.speed_multiplier, 1.0),
		"alvo além de 20 tiles: desiste"
	)
	machine.observe_target(Vector2(3.0 * tile, 0.0), true)
	machine.tick(1.0)
	_check(machine.current_id != Enums.DinoStateId.CHASE, "em alerta de 5 s não volta a perseguir")
	machine.tick(4.5)
	_check(machine.current_id == Enums.DinoStateId.CHASE, "passado o alerta, persegue de novo")
	# desiste depois de 15 s mesmo com o alvo perto
	var long_chase := _machine_for(UTAHRAPTOR)
	long_chase.observe_target(Vector2(3.0 * tile, 0.0), true)
	for i in 148:
		long_chase.tick(0.1)
	_check(long_chase.current_id == Enums.DinoStateId.CHASE, "aos 14,8 s ainda persegue")
	for i in 3:
		long_chase.tick(0.1)
	_check(long_chase.current_id == Enums.DinoStateId.IDLE, "desiste depois de 15 s de perseguição, mesmo com o alvo perto")
	# sem alvo, desiste
	var lost := _machine_for(UTAHRAPTOR)
	lost.observe_target(Vector2(2.0 * tile, 0.0), true)
	lost.tick(0.1)
	lost.observe_target(Vector2.ZERO, false)
	lost.tick(0.1)
	_check(lost.current_id == Enums.DinoStateId.IDLE, "sem alvo, desiste")
	# quem não é agressivo, quem é domado e quem dorme não perseguem
	var passive := _machine_for(preload("res://data/dino/placeholder_dino.tres"))
	passive.observe_target(Vector2(2.0 * tile, 0.0), true)
	passive.tick(0.1)
	_check(passive.current_id != Enums.DinoStateId.CHASE, "o Paquicéfalo (não agressivo) não persegue")
	var tamed := _machine_for(UTAHRAPTOR)
	tamed.is_tamed = true
	tamed.observe_target(Vector2(2.0 * tile, 0.0), true)
	tamed.tick(0.1)
	_check(tamed.current_id != Enums.DinoStateId.CHASE, "o domado não persegue")
	var chaser := _machine_for(UTAHRAPTOR)
	chaser.observe_target(Vector2(2.0 * tile, 0.0), true)
	chaser.tick(0.1)
	chaser.torpor.add_torpor(chaser.torpor.max_torpor)
	_check(
		(
			chaser.current_id == Enums.DinoStateId.UNCONSCIOUS
			and chaser.desired_direction == Vector2.ZERO
			and is_equal_approx(chaser.speed_multiplier, 1.0)
		),
		"nocauteado, para de perseguir"
	)
	chaser.tick(1.0)
	_check(chaser.current_id == Enums.DinoStateId.UNCONSCIOUS, "dormindo não percebe nem persegue")


func _utahraptor_body(at: Vector2, targets: Array) -> Dino:
	var creature: Dino = DinoScene.instantiate()
	creature.stats = UTAHRAPTOR
	creature.position = at
	creature.target_locator = func() -> Array: return targets
	_root.add_child(creature)
	_track.call(creature)
	return creature


func _test_population_and_chase() -> void:
	# o corpo: vê o alvo mais próximo vivo e anda até ele
	var prey := Node2D.new()
	_root.add_child(prey)
	_track.call(prey)
	prey.position = Vector2(1000.0, 1000.0)
	var creature := _utahraptor_body(Vector2(1000.0 - 6.0 * 16.0, 1000.0), [prey])
	creature.torpor.set_physics_process(false)
	var start_distance := creature.global_position.distance_to(prey.global_position)
	for i in 20:
		await _root.get_tree().physics_frame
	_check(creature.state_machine.current_id == Enums.DinoStateId.CHASE, "o corpo entra em perseguição ao ver o alvo")
	_check(creature.global_position.distance_to(prey.global_position) < start_distance - 20.0, "e anda até ele")
	_check(
		creature.velocity.length() > 80.0 and creature.velocity.length() < 100.0, "a 90 px/s (%.1f)" % creature.velocity.length()
	)
	creature.free()
	# no mundo: nasce na toca e persegue o jogador que chega perto
	var main := _main("utahraptor_world", 20, true)
	var raptors: Array[Dino] = []
	for child in main.wild.get_children():
		if (child as Dino).stats.id == "utahraptor":
			raptors.append(child as Dino)
	_check(
		(
			raptors.size() == 10
			and (main.wild.get_child(0) as Dino).stats.id == "placeholder_dino"
			and main.wild.creature_at("w107") == raptors[0]
		),
		"10 utahraptores depois dos 107 paquicéfalos do mapa (índices dos paquicéfalos intactos)"
	)
	var levels_ok := true
	for raptor in raptors:
		levels_ok = (
			levels_ok
			and raptor.level >= 5
			and raptor.level <= 25
			and is_equal_approx(raptor.health.max_health, 80.0 * main.dino.level_rules.health_factor(raptor.level))
		)
		levels_ok = levels_ok and raptor.target_locator.is_valid()
	_check(levels_ok, "nível na faixa da Mata-baixa e vida pela fórmula do nível")
	var sentinel := raptors[0]
	main.player.position = sentinel.position + Vector2(-6.0 * 16.0, 0.0)
	main.wild.process_mode = Node.PROCESS_MODE_INHERIT
	main.zone.reclassify()
	var before := sentinel.position.distance_to(main.player.position)
	for i in 25:
		await _root.get_tree().physics_frame
	_check(
		(
			sentinel.state_machine.current_id == Enums.DinoStateId.CHASE
			and sentinel.position.distance_to(main.player.position) < before - 20.0
		),
		"o sentinela da U1 persegue o jogador que chega a 6 tiles"
	)
	_check(main.zone.is_pinned(sentinel), "quem persegue fica ativo pelo estado")
	main.wild.process_mode = Node.PROCESS_MODE_DISABLED


func _test_taming_and_save() -> void:
	var seen := [null]
	var after := await _save_and_continue(
		"utahraptor_tamed",
		func(main: Main) -> void:
			var raptor := main.wild.creature_at("w107")
			raptor.level = 10
			raptor.feeder_player_id = main.player.player_id
			raptor.torpor.add_torpor(raptor.torpor.max_torpor)
			raptor.inventory.add("berry", 20)
			for i in 10:
				raptor.taming.tick(5.1)
			_check(
				raptor.taming.taming_progress == 0.0 and not raptor.state_machine.is_tamed,
				"baga não doma o Utahraptor: ele come carne"
			)
			raptor.inventory.add("meat", 30)
			_check(raptor.taming.meals_required() == 15, "15 refeições no nível 10 (%d)" % raptor.taming.meals_required())
			var guard := 0
			while not raptor.state_machine.is_tamed and guard < 100:
				guard += 1
				raptor.taming.tick(5.1)
			_check(
				raptor.state_machine.is_tamed,
				(
					"com carne, o Utahraptor é domado (progresso %s, carne %d)"
					% [raptor.taming.taming_progress, raptor.inventory.count("meat")]
				)
			)
			_check(raptor.to_dict().get("species") == "utahraptor", "o estado do dino guarda a espécie")
			seen[0] = raptor.position
	)
	var back: Dino = null
	for child in after.wild.get_children():
		if (child as Dino).state_machine.is_tamed:
			back = child as Dino
	_check(
		back != null and back.stats.id == "utahraptor" and back.taming.ideal_food == Items.MEAT and back.position == seen[0],
		"depois do Continuar o domado segue Utahraptor (espécie lembrada), no mesmo lugar"
	)
	_check(back != null and back.health.max_health > 0.0 and back.owner_player_id == after.player.player_id, "e com dono")
