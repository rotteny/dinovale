# SPDX-License-Identifier: MIT
class_name WorldGuardTests
extends WorldTests
## Regras da etapa B que só uma mutação sentia: fixação da zona, selvagem na autoridade, arma sem dano a si,
## recarga do toque, ponto de respawn em terra, passeio do distante, nascimento dos selvagens e tempo de volta
## do nó. Mais a Main com zona e selvagens realmente ligados (física e apresentação).


func run() -> void:
	await _test_zone_pinning()
	_release_worlds()
	await _test_wild_through_authority()
	_release_worlds()
	await _test_staff_and_touch_cooldown()
	_release_worlds()
	await _test_respawn_point_on_land()
	_release_worlds()
	await _test_far_dino_stays_on_land()
	_release_worlds()
	await _test_wild_birth_rules()
	_release_worlds()
	await _test_full_bush_gives_everything()
	_release_worlds()
	await _test_respawn_clamp_uses_node_time()
	_release_worlds()
	await _test_zone_and_wild_running()
	_release_worlds()


func _test_zone_pinning() -> void:
	var tree := _root.get_tree()
	var main := _main("pin", 20, true)
	await tree.physics_frame
	main.player.position = Vector2(8, 8)  # no mar, longe de todos: quem não é fixado dorme
	main.zone.reclassify()
	var idle := main.wild.creature_at(_wid(main, 10))
	_check(main.zone.mode_of(idle) == ActivityZone.Mode.DORMANT and not main.zone.is_pinned(idle), "preparo: o selvagem comum longe dorme")
	var cases := {
		"só progresso de doma": func(c: Dino) -> void: c.taming.taming_progress = 10.0,
		"só torpor": func(c: Dino) -> void: c.torpor.current_torpor = 5.0,
		"só o estado (não é rotina)": func(c: Dino) -> void: c.state_machine.current_id = Enums.DinoStateId.UNCONSCIOUS,
		"só o dono": func(c: Dino) -> void: c.owner_player_id = "local",
		"só domado": func(c: Dino) -> void: c.state_machine.is_tamed = true,
	}
	var index := 11
	for label: String in cases:
		var creature := main.wild.creature_at(_wid(main, index))
		index += 1
		(cases[label] as Callable).call(creature)
		main.zone.reclassify()
		_check(main.zone.is_pinned(creature) and main.zone.mode_of(creature) == ActivityZone.Mode.ACTIVE,
				"fica ativo longe do jogador: %s" % label)


func _test_wild_through_authority() -> void:
	var tree := _root.get_tree()
	var main := _main("wild_auth", 20, true)
	await tree.physics_frame
	var creature := main.wild.creature_at(_wid(main, 20))
	var id := main.authority.id_of(creature)
	_check(id != 0, "o selvagem do mapa está registrado na autoridade")
	main.player.position = creature.position - Vector2(0, 12)  # o jogador olha para baixo: o selvagem fica à frente
	main.player.tick(60.0)
	_check(main.authority.request_attack(1, id) == RESULT.OK, "o golpe no selvagem passa pela autoridade")
	var sleeper := main.wild.creature_at(_wid(main, 21))
	sleeper.torpor.add_torpor(sleeper.torpor.max_torpor)
	main.player.position = sleeper.position + Vector2(0, 12)
	_check(main.authority.request_interact(1, main.authority.id_of(sleeper)) == RESULT.OK,
			"a interação com o selvagem inconsciente passa pela autoridade")
	var far := main.wild.creature_at(_wid(main, 22))
	main.player.position = far.position + Vector2(2000, 0)
	_check(main.authority.request_attack(1, main.authority.id_of(far)) != RESULT.OK, "longe demais: a autoridade nega")


func _test_staff_and_touch_cooldown() -> void:
	var tree := _root.get_tree()
	var main := _main("staff", 20, true)
	await tree.physics_frame
	var player := main.player
	var target := main.dino
	player.inventory.add(Items.SLEEP_STAFF, 1)
	var iid := ""
	for index in player.inventory.slot_count():
		if player.inventory.get_slot(index).get("id", "") == Items.SLEEP_STAFF:
			iid = str(player.inventory.get_slot(index).get("iid", ""))
	_check(iid != "" and player.equipment.equip(iid) == "", "preparo: o Bastão está em mãos")
	var hp := player.health.current_health
	player.tick(60.0)
	_check(player.strike(target) and player.health.current_health == hp and Items.weapon_of(Items.SLEEP_STAFF).self_damage == 0.0,
			"o Bastão não machuca quem bate")
	player.equipment.unequip(EquipmentLayout.WEAPON)
	# Toque na pedra: a recarga vale, o segundo toque logo depois não custa nada.
	var rock := main.resources.node_by_id("n174")
	_near(main, rock)
	hp = player.health.current_health
	main.authority.request_gather(1, main.authority.id_of(rock))
	var after_first := player.health.current_health
	var second := player.perform_gather(rock)
	_check(after_first == hp - 1.0 and second == Player.COOLDOWN and player.health.current_health == after_first,
			"o toque na pedra tem recarga: o segundo logo depois é recusado e não custa vida")


func _test_respawn_point_on_land() -> void:
	var tree := _root.get_tree()
	var main := _main("respawn_land", 20, true)
	await tree.physics_frame
	var shallow := _open_shallow_cell(main.map)
	_check(shallow.x >= 0 and main.map.is_walkable(shallow) and not main.map.is_land(shallow), "preparo: água rasa aberta, longe do anel")
	_check(not main._is_free_point(main.map.center_of(shallow)), "o respawn nunca cai na água rasa")
	_check(main._is_free_point(main.respawn_rules.default_fallback_point), "preparo: o ponto reserva da Campina (terra firme) é aceito")


## Célula de água rasa sem água funda nem anel por perto (nada além da água a impede de ser escolhida).
func _open_shallow_cell(map: IslandMap) -> Vector2i:
	for y in range(8, map.size - 8):
		for x in range(8, map.size - 8):
			var cell := Vector2i(x, y)
			if map.terrain_at(cell) != IslandMap.SHALLOW:
				continue
			var clear := true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var terrain := map.terrain_at(cell + Vector2i(dx, dy))
					clear = clear and terrain != IslandMap.DEEP and terrain != IslandMap.DEEP_RING
			if clear:
				return cell
	return Vector2i(-1, -1)


func _test_far_dino_stays_on_land() -> void:
	var tree := _root.get_tree()
	var main := _main("far_land", 20, true)
	await tree.physics_frame
	var map := main.map
	# Um distante na faixa de 16 a 40 tiles, parado na terra encostada na água rasa: o passeio não entra nela.
	var coast := Vector2i(-1, -1)
	for y in range(1, map.size - 1):
		for x in range(1, map.size - 1):
			var cell := Vector2i(x, y)
			var focus := map.cell_of(main.player.position)
			var tiles := Vector2(cell - focus).length()
			if map.is_land(cell) and tiles > 25.0 and tiles < 35.0 and map.terrain_at(cell + Vector2i(1, 0)) == IslandMap.SHALLOW:
				coast = cell
				break
		if coast.x >= 0:
			break
	_check(coast.x >= 0, "preparo: há terra encostada na água rasa a 25 a 35 tiles do jogador")
	var creature := main.wild.creature_at(_wid(main, 30))
	creature.position = map.center_of(coast)
	main.zone.reclassify()
	_check(main.zone.mode_of(creature) == ActivityZone.Mode.FAR, "preparo: o dino da costa é distante")
	var wet := 0
	for i in 200:
		main.zone.tick(main.zone.rules.far_step_seconds)
		if main.zone.mode_of(creature) != ActivityZone.Mode.FAR:
			break
		if not map.is_land(map.cell_of(creature.position)):
			wet += 1
	_check(wet == 0, "o distante nunca pisa na água rasa (%d passos molhados)" % wet)


func _test_wild_birth_rules() -> void:
	var tree := _root.get_tree()
	var main := _main("birth", 20, true)
	await tree.physics_frame
	var tutorial_cell: Vector2i = main.map.landmarks.get("paquicefalo_tutorial", Vector2i(-1, -1))
	var on_tutorial := 0
	var top := {}
	for creature in main.wild.get_children():
		var cell := main.map.cell_of((creature as Dino).position)
		on_tutorial += 1 if cell == tutorial_cell else 0
		var band := main.world_rules.level_band_of(main.map.terrain_at(cell))
		if (creature as Dino).level == band.y:
			top[band.y] = true
	_check(on_tutorial == 0 and main.map.cell_of(main.dino.position) == tutorial_cell,
			"a célula do tutorial é do dino do tutorial: nenhum outro nasce ali")
	_check(not top.is_empty(), "o nível máximo da faixa do bioma também é sorteado")


func _test_full_bush_gives_everything() -> void:
	var tree := _root.get_tree()
	var main := _main("bush_all", 20, true)
	await tree.physics_frame
	var player := main.player
	var bush: ResourceNode = null
	for node in main.resources.nodes():
		if node.def.id == "bush_baga":
			bush = node
			break
	_near(main, bush)
	var berries := player.inventory.count(Items.BERRY)
	var fiber := player.inventory.count(Items.FIBER)
	main.authority.request_gather(1, main.authority.id_of(bush))
	_check(player.inventory.count(Items.BERRY) == berries + bush.def.yield_amount
			and player.inventory.count(Items.FIBER) == fiber + bush.def.extra_yields["fiber"],
			"arbusto com vaga: entrega a baga e a fibra")
	_check(not bush.is_available() and not bush.component.is_partial(), "e esgota de vez")


func _test_respawn_clamp_uses_node_time() -> void:
	var tree := _root.get_tree()
	var main := _main("clamp", 20, true)
	await tree.physics_frame
	var fast: ResourceNode = null
	for node in main.resources.nodes():
		if node.def.id == "loose_stone" and node.component.respawn_total() == 300.0:
			fast = node
			break
	fast.component.from_dict({"def": "loose_stone", "depleted": true, "due_at": 1.0e9})
	_check(absf(fast.component.due_at - (main.authority.clock.now() + 300.0)) < 0.001,
			"o instante restaurado é limitado ao relógio mais o tempo do próprio nó (300 s), não ao do tipo")


## A Main com a zona e os selvagens realmente ligados: física correndo, apresentação só nos ativos, sem erro.
func _test_zone_and_wild_running() -> void:
	var tree := _root.get_tree()
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = "running"
	main.menu_scene = ""
	_root.add_child(main)
	_track.call(main)
	for node: Node in [main.scheduler]:
		node.set_physics_process(false)
	main.player.position = main.map.center_of(Vector2i(120, 190))
	main.zone.reclassify()
	var start_nodes := _count_nodes(main)
	for _i in 30:
		await tree.physics_frame
	var zone := main.zone
	_check(zone.active_count > 0 and zone.active_count <= 32, "a zona ligada tem ativos e respeita o teto (%d)" % zone.active_count)
	var views := 0
	for child in main.get_children():
		views += 1 if child is DinoView and child.dino != main.dino else 0
	_check(views == zone.active_count - (1 if zone.mode_of(main.dino) == ActivityZone.Mode.ACTIVE else 0),
			"só os selvagens ativos têm apresentação (%d views, %d ativos)" % [views, zone.active_count])
	for creature in main.wild.get_children():
		var active: bool = zone.mode_of(creature) == ActivityZone.Mode.ACTIVE
		_check((creature as Dino).process_mode == (Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED)
				and (creature as Dino).visible == active, "modo e apresentação do selvagem batem")
		break
	# Anda para longe: as views dos que saem da zona são liberadas.
	main.player.position = Vector2(8, 8)
	zone.reclassify()
	await tree.process_frame
	await tree.process_frame
	var after := 0
	for child in main.get_children():
		after += 1 if child is DinoView and child.dino != main.dino else 0
	_check(after == 0, "ninguém ativo: nenhuma apresentação de selvagem sobra (%d)" % after)
	var end_nodes := _count_nodes(main)
	_check(end_nodes < start_nodes + 400, "o custo em nós não cresce com os 108 selvagens (%d -> %d)" % [start_nodes, end_nodes])


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
