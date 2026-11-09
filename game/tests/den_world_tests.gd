# SPDX-License-Identifier: MIT
class_name DenWorldTests
extends WildGroupsTests
## E3a no mundo montado: B4 (nascimento e renascimento na toca) e B5 (faixa de nível por toca). Usa a montagem de `WildGroupsTests`.

const DEN_SLOTS: Array[String] = ["g29", "g30", "g31", "g32", "g37", "g38"]


func run() -> void:
	await _test_b4_birth_and_respawn_at_the_den()
	_release_worlds()
	await _test_b5_level_band_per_den()
	_release_worlds()


## B4: o bando de toca nasce com centro na célula da toca; membros em mata a até 4 tiles; renasce na mesma toca; jogador perto adia.
func _test_b4_birth_and_respawn_at_the_den() -> void:
	var tree := _root.get_tree()
	var main := _main("den_birth", 20, true)
	await tree.physics_frame
	var wrong_center := 0
	var wrong_cells := 0
	var tiles_far := 0.0
	for slot_id in DEN_SLOTS:
		var slot := _slot_by_id(main.map, slot_id)
		var den: Vector2i = main.map.dens[slot["den"]]
		var info := main.wild.slot_info(slot_id)
		wrong_center += 0 if info["center"] == den else 1
		for member_id: String in info["members"]:
			var cell := main.map.cell_of(main.wild.creature_at(member_id).position)
			tiles_far = maxf(tiles_far, Vector2(cell - den).length())
			wrong_cells += 0 if main.map.terrain_at(cell) == IslandMap.WOODLAND else 1
	_check(wrong_center == 0 and wrong_cells == 0 and tiles_far <= 4.0,
			"B4: os 6 bandos nascem na célula da toca, em mata, a até 4 tiles (%.1f)" % tiles_far)
	var slot_id := "g30"
	var den: Vector2i = main.map.dens[_slot_by_id(main.map, slot_id)["den"]]
	main.player.global_position = Vector2(den) * float(main.dino.level_rules.tile_size)  # o jogador na toca: renascer adia
	_wipe(main, slot_id)
	main.wild.tick(main.authority.clock.now())
	main.authority.clock.advance(1300.0)
	main.wild.tick(main.authority.clock.now())
	var waiting := main.wild.slot_info(slot_id)
	_check(waiting["waiting"] and waiting["tries"] >= 1,
			"B4: com o jogador a menos de 40 tiles o renascimento adia (waiting, %d tentativas)" % waiting["tries"])
	main.player.global_position = Vector2(main.map.start_cell) * float(main.dino.level_rules.tile_size)
	main.authority.clock.advance(70.0)
	main.wild.tick(main.authority.clock.now())
	var born := main.wild.slot_info(slot_id)
	_check(not born["waiting"] and born["gen"] == 1 and born["center"] == den,
			"B4: longe do jogador renasce na mesma toca (geração %d)" % born["gen"])
	var inside := true
	for member_id: String in born["members"]:
		var creature := main.wild.creature_at(member_id)
		inside = inside and creature != null and main.wild.get_children().has(creature) and creature.state_machine.home != null
	_check(inside, "B4: e o bando novo nasce com a toca ligada")


## B5: 200 sorteios por toca ficam dentro da faixa da toca; vaga sem toca usa a do terreno.
func _test_b5_level_band_per_den() -> void:
	var tree := _root.get_tree()
	var main := _main("den_band", 20, true)
	await tree.physics_frame
	var rules := (load("res://data/dino/utahraptor.tres") as DinoBaseStats).home.rules
	var bad := 0
	for slot_id in DEN_SLOTS:
		var den_id: String = _slot_by_id(main.map, slot_id)["den"]
		var band := rules.band_of(den_id, Vector2i(1, 1))
		for n in 200:
			var level := WildPopulation.roll_level(band, main.world_seed, "%s.0.%d" % [slot_id, n])
			bad += 0 if level >= band.x and level <= band.y else 1
		for member_id: String in main.wild.slot_info(slot_id)["members"]:
			var level := main.wild.creature_at(member_id).level
			bad += 0 if level >= band.x and level <= band.y else 1
	_check(bad == 0 and rules.band_of("U1", Vector2i(1, 1)) != rules.band_of("U3", Vector2i(1, 1)),
			"B5: 200 sorteios por toca e os membros nascem na faixa da toca (%d fora)" % bad)
	var fallback := Vector2i(7, 9)
	_check(rules.band_of("U99", fallback) == fallback, "B5: sem toca na tabela vale a faixa de reserva (a do terreno)")
	var plain := 0
	for slot in main.map.spawn_slots:
		if slot["den"] != "" or slot["species"] != "paquicefalo":
			continue
		for member_id: String in main.wild.slot_info(slot["id"]).get("members", []):
			var creature := main.wild.creature_at(member_id)
			var band := main.world_rules.level_band_of(main.map.terrain_at(main.map.cell_of(creature.position)))
			plain += 0 if creature != null and creature.level >= band.x and creature.level <= band.y else 1
	_check(plain == 0, "B5: a vaga sem toca segue a faixa do terreno (%d fora)" % plain)
