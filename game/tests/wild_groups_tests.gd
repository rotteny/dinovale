# SPDX-License-Identifier: MIT
class_name WildGroupsTests
extends WildPersistenceTests
## Bandos selvagens em posição sorteada pela semente do mundo (ADR-007, emenda de 07/11): distâncias, região, determinismo,
## respawn do bando e save. Reaproveita `_main`, `_save_and_continue` e `_tame`.

## Quantas sementes cada propriedade de posição percorre (a disposição leva alguns milissegundos por semente).
const SEEDS := 64
const SEED_STEP := 7919
## Orçamento do sorteio da carga (ms, headless): medido em 2 ms (24 bandos); 50 ms é folga de ~20x para o ruído da máquina e
## ainda pega um custo que cresça por ordem de grandeza.
const BUDGET_MS := 50.0


func run() -> void:
	_test_spacing_and_start_clearance()
	_test_members_in_the_right_region()
	_test_determinism()
	_test_stuck_new_slot_does_not_move_the_others()
	_test_slot_size_limits()
	_test_unknown_species_and_empty_slots()
	_test_rules_data()
	await _test_load_cost()
	_release_worlds()
	await _test_respawn_far_from_player()
	_release_worlds()
	await _test_respawn_waits_and_relaxes()
	_release_worlds()
	await _test_save_keeps_a_living_group()
	_release_worlds()
	await _test_save_keeps_the_waiting_group()
	_release_worlds()
	await _test_save_does_not_change_the_respawn_center()
	_release_worlds()
	await _test_other_seed_is_relaid()
	_release_worlds()
	await _test_old_v5_keeps_the_tamed()
	_release_worlds()
	await _test_bad_groups_are_discarded()
	_release_worlds()


func _layout_for(seed_value: int) -> WildLayout:
	return WildLayout.new(IslandMap.default_map(), WORLD_RULES, seed_value * SEED_STEP, WildPopulation.SPECIES)


func _fixed_centers() -> Array[Dictionary]:
	var map := IslandMap.default_map()
	var kind := WildPopulation.SPECIES[0]
	return [WildLayout.placed_center(map.landmarks["paquicefalo_tutorial"], kind.spawn_key, kind.min_group_spacing_tiles)]


## Distância exigida entre dois bandos: a global, ou a da espécie se for a mesma e maior.
func _needed(layout: WildLayout, a: Dictionary, b: Dictionary) -> float:
	var kind := layout.species_of(a)
	var needed := WORLD_RULES.min_group_spacing_any_tiles
	if a["species"] == b["species"]:
		needed = maxf(needed, kind.min_group_spacing_tiles)
	return needed


func _slot_by_id(map: IslandMap, slot_id: String) -> Dictionary:
	for slot in map.spawn_slots:
		if slot["id"] == slot_id:
			return slot
	return {}


## Nenhum par de bandos a menos da distância exigida, nenhum centro a menos de 12 tiles do início, e nenhuma vaga fica vazia.
func _test_spacing_and_start_clearance() -> void:
	var map := IslandMap.default_map()
	var tutorial: Vector2i = map.landmarks["paquicefalo_tutorial"]
	var worst_gap := INF
	var closest_start := INF
	var empties := 0
	var bad_pairs := 0
	var placed_total := 0
	for n in range(1, SEEDS + 1):
		var layout := _layout_for(n)
		var empty: Array[String] = []
		var centers := layout.layout(_fixed_centers(), empty)
		empties += empty.size()
		var ids: Array = centers.keys()
		placed_total += ids.size()
		for i in ids.size():
			var a := _slot_by_id(map, ids[i])
			closest_start = minf(closest_start, Vector2(centers[ids[i]] - map.start_cell).length())
			var kind := layout.species_of(a)
			if Vector2(centers[ids[i]] - tutorial).length() < _needed(layout, a, {"species": "paquicefalo"}):
				bad_pairs += 1
			for j in range(i + 1, ids.size()):
				var b := _slot_by_id(map, ids[j])
				var gap := Vector2(centers[ids[i]] - centers[ids[j]]).length()
				worst_gap = minf(worst_gap, gap / _needed(layout, a, b))
				if gap < _needed(layout, a, b) or kind == null:
					bad_pairs += 1
	_check(bad_pairs == 0,
			"nenhum par de bandos (nem o do tutorial) abaixo da distância exigida, em %d sementes (%d ruins)" % [SEEDS, bad_pairs])
	_check(worst_gap >= 1.0, "a menor folga relativa entre dois bandos é %.3f (>= 1)" % worst_gap)
	_check(closest_start >= WORLD_RULES.group_start_clearance_tiles, "nenhum centro a menos de 12 tiles do início (%.1f)" % closest_start)
	# Disposição de passada única (nenhuma vaga existente se move por causa de outra): uma vaga travada fica vazia, e o
	# chamador avisa. Em 64 sementes isto acontece em no máximo 2 (medido: 1); mais que isso é regressão da regra.
	_check(empties <= SEEDS / 32 and placed_total >= SEEDS * 24 - empties,
			"quase toda vaga de espécie conhecida acha lugar nas %d sementes (%d vazias)" % [SEEDS, empties])


## Todo membro de todo bando em tile da região da vaga e do terreno da espécie (nunca fora do bioma).
func _test_members_in_the_right_region() -> void:
	var map := IslandMap.default_map()
	var members := 0
	var wrong := 0
	var too_far := 0
	var shared := 0
	var woodland_only_wrong := 0
	for n in range(1, 17):
		var layout := _layout_for(n)
		var centers := layout.layout(_fixed_centers())
		for slot_id: String in centers:
			var slot := _slot_by_id(map, slot_id)
			var kind := layout.species_of(slot)
			var cells := layout.members_of(slot, 0, centers[slot_id])
			var used := {}
			for k: int in cells:
				var cell: Vector2i = cells[k]
				members += 1
				shared += 1 if used.has(cell) else 0
				used[cell] = true
				wrong += 0 if map.region_has(slot["region"], cell) and kind.spawn_terrains.has(map.terrain_at(cell)) else 1
				too_far += 1 if Vector2(cell - centers[slot_id]).length() > kind.cohesion_radius_tiles else 0
				if slot["species"] == "utahraptor" and map.terrain_at(cell) != IslandMap.WOODLAND:
					woodland_only_wrong += 1
	_check(members > 16 * 60 and wrong == 0 and woodland_only_wrong == 0,
			"todo membro nasce em tile da região da vaga e do terreno da espécie (%d membros, %d fora)" % [members, wrong])
	_check(too_far == 0 and shared == 0, "membros dentro do raio de coesão e sem dividir tile (%d longe, %d repetidos)" % [too_far, shared])


func _test_determinism() -> void:
	var map := IslandMap.default_map()
	var first := _layout_for(5).layout(_fixed_centers())
	var again := _layout_for(5).layout(_fixed_centers())
	_check(first == again and first.size() == 24, "a mesma semente dá as mesmas posições")
	var same_members := true
	for slot_id: String in first:
		var slot := _slot_by_id(map, slot_id)
		same_members = same_members and _layout_for(5).members_of(slot, 0, first[slot_id]) == _layout_for(5).members_of(slot, 0, first[slot_id])
	_check(same_members, "e os mesmos membros em volta de cada centro")
	var other := _layout_for(6).layout(_fixed_centers())
	var different := 0
	for slot_id: String in first:
		different += 1 if first[slot_id] != other.get(slot_id) else 0
	_check(different >= int(first.size() * 0.9), "sementes diferentes dão posições diferentes (%d de %d bandos mudaram)"
			% [different, first.size()])
	# Acrescentar uma vaga no fim do mapa não move as existentes (a ordem é a do id).
	var longer := IslandMap.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IslandMap.DEFAULT_PATH))
	data["spawn_slots"].append({"id": "g99", "species": "utahraptor", "region": "r_mata", "size": 2, "size_min": 2, "size_max": 3})
	_check(longer.load_dict(data) and longer.spawn_slots.size() == 37, "preparo: mapa com uma vaga a mais")
	var extended := WildLayout.new(longer, WORLD_RULES, 5 * SEED_STEP, WildPopulation.SPECIES).layout(_fixed_centers())
	var kept := true
	for slot_id: String in first:
		kept = kept and extended.get(slot_id) == first[slot_id]
	_check(kept and extended.has("g99"), "vaga nova no fim não move as existentes")


## Vaga nova que TRAVA (região de duas células, perto demais dos bandos que a disposição normal põe): só ela fica sem
## lugar; as existentes não se movem para dar espaço a ela. (Semente e célula achadas por busca: na regra antiga, a
## disposição inteira era refeita com outra variante e as 24 existentes mudavam de lugar.)
func _test_stuck_new_slot_does_not_move_the_others() -> void:
	var seed_value := 38 * SEED_STEP
	var base := IslandMap.default_map()
	var before := WildLayout.new(base, WORLD_RULES, seed_value, WildPopulation.SPECIES).layout(_fixed_centers())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IslandMap.DEFAULT_PATH))
	data["spawn_regions"]["r_apertada"] = {"terrains": [IslandMap.GRASSLAND], "runs": [[162, 60, 61]]}
	data["spawn_slots"].append({"id": "g99", "species": "paquicefalo", "region": "r_apertada", "size": 2, "size_min": 1, "size_max": 4})
	var longer := IslandMap.new()
	_check(longer.load_dict(data) and longer.spawn_slots.size() == 37, "preparo: mapa com uma vaga apertada a mais")
	var empty: Array[String] = []
	var after := WildLayout.new(longer, WORLD_RULES, seed_value, WildPopulation.SPECIES).layout(_fixed_centers(), empty)
	var kept := true
	for slot_id: String in before:
		kept = kept and after.get(slot_id) == before[slot_id]
	_check(kept and empty == ["g99"], "vaga nova que trava fica sem lugar e não move as existentes (%s)" % str(empty))


## `size_min` e `size_max` da vaga limitam o tamanho do bando (depois dos limites da espécie).
func _test_slot_size_limits() -> void:
	var layout := _layout_for(3)
	var slot := {"id": "gx", "species": "paquicefalo", "region": "r_campina", "size": 4, "size_min": 1, "size_max": 2}
	_check(layout.size_of(slot) == 2, "tamanho do bando: o size_max da vaga limita (4 -> 2)")
	slot["size"] = 3
	slot["size_min"] = 4
	slot["size_max"] = 4
	_check(layout.size_of(slot) == 4, "tamanho do bando: o size_min da vaga limita (3 -> 4)")


## Espécie que o jogo não tem (Dodo, Triceratops) é ignorada sem erro; vaga sem região é descartada na carga.
func _test_unknown_species_and_empty_slots() -> void:
	var layout := _layout_for(3)
	var centers := layout.layout(_fixed_centers())
	var map := IslandMap.default_map()
	var known := true
	for slot_id: String in centers:
		known = known and _slot_by_id(map, slot_id)["species"] in ["paquicefalo", "utahraptor"]
	_check(known and layout.species_of(_slot_by_id(map, "g1")) == null and layout.size_of(_slot_by_id(map, "g1")) == 0,
			"Dodo e Triceratops (sem espécie no jogo) não ganham centro nem erro")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IslandMap.DEFAULT_PATH))
	data["spawn_slots"].append({"id": "g98", "species": "paquicefalo", "region": "r_que_nao_existe", "size": 3})
	var map_2 := IslandMap.new()
	_check(map_2.load_dict(data) and map_2.spawn_slots.size() == 36, "vaga de região desconhecida é descartada na carga")
	# Tile de terreno que a região não declara nunca entra na máscara.
	var bad_region := data.duplicate(true)
	bad_region["spawn_regions"]["r_campina"]["terrains"] = [4]
	var map_3 := IslandMap.new()
	map_3.load_dict(bad_region)
	var leaked := 0
	for index in map_3.region_cells("r_campina"):
		leaked += 1 if map_3.terrain_at(Vector2i(index % map_3.size, index / map_3.size)) != IslandMap.WOODLAND else 0
	_check(leaked == 0, "a máscara só guarda tile do terreno declarado pela região")


func _test_rules_data() -> void:
	var zone: ZoneRules = load("res://data/world/zone_rules.tres")
	_check(WORLD_RULES.group_respawn_player_clearance_tiles >= zone.far_radius_tiles,
			"o bando que renasce nasce fora da zona distante (%.0f >= %.0f)" % [WORLD_RULES.group_respawn_player_clearance_tiles,
					zone.far_radius_tiles])
	_check(WORLD_RULES.group_respawn_relaxed_clearance_tiles <= WORLD_RULES.group_respawn_player_clearance_tiles
			and WORLD_RULES.min_group_spacing_any_tiles == 16.0 and WORLD_RULES.group_start_clearance_tiles == 12.0,
			"os números do documento de bandos estão no Resource")
	for kind in WildPopulation.SPECIES:
		_check(kind.group_size_min >= 1 and kind.group_size_max >= kind.group_size_min and kind.cohesion_radius_tiles > 0.0
				and kind.min_group_spacing_tiles >= WORLD_RULES.min_group_spacing_any_tiles, "dado de bando de %s coerente" % kind.id)


## O custo do sorteio na carga (mundo novo), medido.
func _test_load_cost() -> void:
	var started := Time.get_ticks_usec()
	var layout := _layout_for(11)
	var centers := layout.layout(_fixed_centers())
	var map := IslandMap.default_map()
	var members := 0
	for slot_id: String in centers:
		members += layout.members_of(_slot_by_id(map, slot_id), 0, centers[slot_id]).size()
	var millis := (Time.get_ticks_usec() - started) / 1000.0
	print("   sorteio de 24 bandos e %d membros: %.1f ms (headless)" % [members, millis])
	_check(members >= 60 and millis < BUDGET_MS, "o sorteio da carga cabe no orçamento (%.1f ms, %d membros)" % [millis, members])
	await _root.get_tree().physics_frame


## Mata todos os membros selvagens do bando; devolve a vaga.
func _wipe(main: Main, slot_id: String) -> void:
	for member_id: String in main.wild.slot_info(slot_id)["members"]:
		var creature := main.wild.creature_at(member_id)
		if creature != null:
			creature.health.take_damage(creature.health.max_health * 2.0)


## O primeiro bando de paquicéfalo cujo centro fica a mais de 40 tiles do jogador (para o respawn poder ser testado).
func _distant_slot(main: Main) -> String:
	var start := main.map.start_cell
	for slot_id in main.wild.slot_ids():
		var info := main.wild.slot_info(slot_id)
		if info["species"] == "paquicefalo" and Vector2(info["center"] - start).length() > 60.0:
			return slot_id
	return ""


func _test_respawn_far_from_player() -> void:
	var tree := _root.get_tree()
	var main := _main("respawn_far", 20, true)
	await tree.physics_frame
	var slot_id := _distant_slot(main)
	var old_center: Vector2i = main.wild.slot_info(slot_id)["center"]
	var old_members: Array = main.wild.slot_info(slot_id)["members"]
	var spawned: Array = []
	main.wild.group_spawned.connect(func(creatures: Array[Dino]) -> void: spawned.append_array(creatures))
	_wipe(main, slot_id)
	main.wild.tick(main.authority.clock.now())
	var waiting := main.wild.slot_info(slot_id)
	_check(waiting["waiting"] and is_equal_approx(waiting["due_at"], main.authority.clock.now() + 1200.0) and spawned.is_empty(),
			"o último membro morreu: o prazo (1200 s) é marcado pelo relógio, e nada renasce ainda")
	_check(main.wild.to_list().size() == old_members.size() and main.wild.groups_to_list().size() == 1,
			"o save leva a vaga que espera (e o delta dos mortos)")
	main.authority.clock.advance(1199.0)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.is_empty(), "antes do prazo o bando não volta")
	main.authority.clock.advance(1.0)
	main.wild.tick(main.authority.clock.now())
	var info := main.wild.slot_info(slot_id)
	_check(not info["waiting"] and info["gen"] == 1 and not spawned.is_empty() and info["members"].size() == spawned.size(),
			"vencido o prazo, o bando renasce inteiro (geração 1, %d membros)" % spawned.size())
	var player_cell := main.map.cell_of(main.player.position)
	var center: Vector2i = info["center"]
	_check(Vector2(center - player_cell).length() >= WORLD_RULES.group_respawn_player_clearance_tiles,
			"o bando novo nasce a 40 tiles ou mais do jogador (%.1f)" % Vector2(center - player_cell).length())
	_check(center != old_center and main.map.region_has(info["region"], center), "em outro lugar, dentro da região")
	var spacing_ok := true
	var slot := _slot_by_id(main.map, slot_id)
	for other_id in main.wild.slot_ids():
		if other_id == slot_id:
			continue
		var other := main.wild.slot_info(other_id)
		var needed := _needed(main.wild._layout, slot, _slot_by_id(main.map, other_id))
		spacing_ok = spacing_ok and Vector2(center - other["center"]).length() >= needed
	_check(spacing_ok, "longe de todo bando vivo (distância global e da espécie)")
	var ids_new := true
	var in_region := true
	for creature: Dino in spawned:
		var new_id: String = main.wild.spawn_id_of(creature)
		ids_new = ids_new and not old_members.has(new_id) and new_id.begins_with(slot_id + ".1.")
		in_region = in_region and main.map.region_has(info["region"], main.map.cell_of(creature.position))
		in_region = in_region and main.authority.id_of(creature) > 0 and main.zone.dinos().has(creature)
	_check(ids_new and in_region, "membros novos com id de geração 1, na região, no registro da autoridade e na zona")
	# Domar o último membro também conta: o bando espera de novo.
	var tamed_one := spawned[0] as Dino
	for creature: Dino in spawned:
		if creature != tamed_one:
			creature.health.take_damage(creature.health.max_health * 2.0)
	_tame(main, tamed_one)
	main.wild.tick(main.authority.clock.now())
	_check(main.wild.slot_info(slot_id)["waiting"], "o último selvagem do bando foi domado: o bando espera renascer (o domado fica)")
	_check(not tamed_one.health.is_dead() and tamed_one.state_machine.is_tamed, "e o domado segue vivo")


func _test_respawn_waits_and_relaxes() -> void:
	var tree := _root.get_tree()
	var main := _main("respawn_relax", 20, true)
	await tree.physics_frame
	var slot_id := _distant_slot(main)
	main.world_rules.group_respawn_player_clearance_tiles = 1000.0  # nenhum tile serve: o jogador "está em todo lugar"
	_wipe(main, slot_id)
	var now := main.authority.clock.now()
	main.wild.tick(now)
	var due := float(main.wild.slot_info(slot_id)["due_at"])
	var log: Array = []
	for attempt in 5:
		main.authority.clock.advance(maxf(due - main.authority.clock.now(), 0.0))
		main.wild.tick(main.authority.clock.now())
		var info := main.wild.slot_info(slot_id)
		log.append([info["waiting"], info["tries"]])
		due = float(info["due_at"])
		if not info["waiting"]:
			break
	_check(log[0] == [true, 1] and log[1] == [true, 2] and log[2] == [true, 3] and log[3] == [false, 0],
			"sem lugar: tenta a cada 60 s e, depois de 3 falhas, relaxa só a distância do jogador (24) e renasce %s" % str(log))
	var info := main.wild.slot_info(slot_id)
	var player_cell := main.map.cell_of(main.player.position)
	_check(Vector2(info["center"] - player_cell).length() >= WORLD_RULES.group_respawn_relaxed_clearance_tiles and info["gen"] == 1,
			"o relaxado ainda respeita os 24 tiles (%.1f)" % Vector2(info["center"] - player_cell).length())
	_check(is_equal_approx(main.world_rules.group_respawn_retry_seconds, 60.0), "o intervalo da nova tentativa é o do Resource (60 s)")


func _test_save_keeps_a_living_group() -> void:
	var tree := _root.get_tree()
	var seen := {}
	var after := await _save_and_continue("group_live", func(main: Main) -> void:
		var slot_id := _distant_slot(main)
		_wipe(main, slot_id)
		main.wild.tick(main.authority.clock.now())
		main.authority.clock.advance(1300.0)
		main.wild.tick(main.authority.clock.now())
		seen["slot"] = slot_id
		seen["info"] = main.wild.slot_info(slot_id)
		seen["count"] = main.wild.member_ids().size()
		# Um membro do bando renascido leva torpor: o delta é da geração nova.
		var member: Dino = main.wild.creature_at((seen["info"]["members"] as Array)[0])
		member.torpor.current_torpor = 9.0
		var data := WorldSnapshot.capture(main.player, main.dino, "t", "now", main.resources, 0, 10, main.wild, null, main.authority.clock.now())
		seen["groups"] = data["world"]["wild_groups"]
		seen["seed"] = data["world"]["seed"])
	var info := after.wild.slot_info(seen["slot"])
	_check(seen["groups"].size() == 1 and seen["groups"][0]["gen"] == 1 and not seen["groups"][0].has("due_at")
			and seen["seed"] == after.world_seed,
			"o save leva só a vaga não intacta (geração 1, sem prazo) e a semente do mundo")
	_check(info["gen"] == 1 and info["center"] == seen["info"]["center"] and info["members"] == seen["info"]["members"]
			and not info["waiting"],
			"carregar devolve o mesmo bando vivo: mesma geração, mesmo centro, mesmos ids")
	var back := after.wild.creature_at(info["members"][0])
	_check(back != null and is_equal_approx(back.torpor.current_torpor, 9.0) and after.wild.member_ids().size() == seen["count"],
			"o delta do membro novo volta, e ninguém duplica (%d membros)" % after.wild.member_ids().size())
	_check(after.wild.groups_to_list().size() == 1 and after.wild.groups_to_list()[0]["center"] == seen["groups"][0]["center"],
			"salvar de novo grava a mesma vaga")
	await tree.physics_frame


func _test_save_keeps_the_waiting_group() -> void:
	var seen := {}
	var after := await _save_and_continue("group_wait", func(main: Main) -> void:
		var slot_id := _distant_slot(main)
		_wipe(main, slot_id)
		main.wild.tick(main.authority.clock.now() + 100.0)
		seen["slot"] = slot_id
		seen["info"] = main.wild.slot_info(slot_id)
		main.authority.clock.advance(100.0))
	var info := after.wild.slot_info(seen["slot"])
	_check(info["waiting"] and info["gen"] == 0 and info["center"] == seen["info"]["center"] and is_equal_approx(info["due_at"],
			seen["info"]["due_at"])
			and _wild_alive_in(after, seen["slot"]) == 0, "o bando que espera renascer continua esperando, com o mesmo prazo e sem membros")
	var spawned := [0]
	after.wild.group_spawned.connect(func(creatures: Array[Dino]) -> void: spawned[0] += creatures.size())
	after.wild.tick(after.authority.clock.now())
	_check(spawned[0] == 0, "carregar não faz renascer: só o primeiro tick depois do prazo")
	after.authority.clock.advance(1300.0)
	after.wild.tick(after.authority.clock.now())
	_check(spawned[0] > 0 and after.wild.slot_info(seen["slot"])["gen"] == 1, "passado o prazo, o bando renasce")


## ADR-007 (emenda): matar o bando, salvar, carregar e avançar o relógio dá o MESMO centro de respawn que avançar sem salvar.
func _test_save_does_not_change_the_respawn_center() -> void:
	var tree := _root.get_tree()
	var control := _main("respawn_control", 20, true)
	await tree.physics_frame
	var slot_id := _distant_slot(control)
	_wipe(control, slot_id)
	control.wild.tick(control.authority.clock.now())
	control.authority.clock.advance(1300.0)
	control.wild.tick(control.authority.clock.now())
	var expected := control.wild.slot_info(slot_id)
	var after := await _save_and_continue("respawn_saved", func(main: Main) -> void:
		_wipe(main, slot_id)
		main.wild.tick(main.authority.clock.now()))
	after.authority.clock.advance(1300.0)
	after.wild.tick(after.authority.clock.now())
	var got := after.wild.slot_info(slot_id)
	_check(expected["gen"] == 1 and got["gen"] == 1 and got["center"] == expected["center"] and got["members"] == expected["members"],
			"salvar e carregar com o bando morto não muda o centro do respawn (%s x %s)" % [str(got["center"]), str(expected["center"])])
	await tree.physics_frame


func _wild_alive_in(main: Main, slot_id: String) -> int:
	var count := 0
	for member_id: String in main.wild.slot_info(slot_id)["members"]:
		count += 1 if main.wild.creature_at(member_id) != null else 0
	return count


## Mundo salvo com outra semente: o Continuar refaz a disposição pela semente salva, sem duplicar nem perder ninguém.
func _test_other_seed_is_relaid() -> void:
	var tree := _root.get_tree()
	var before := _main("group_seed", 20, true, 777)
	await tree.physics_frame
	var ids_before := before.wild.member_ids()
	var positions_before := {}
	for id in ids_before:
		positions_before[id] = before.wild.creature_at(id).position
	_check(before.world_seed == 777 and before.save_game(SaveManager.Reason.BED), "preparo: mundo de semente 777 salvo")
	GameSession.continue_requested = true
	var after := _main("group_seed", 20, true)  # nasce com a semente de teste e deve trocar pela salva
	await tree.physics_frame
	var same := after.wild.member_ids() == ids_before and after.world_seed == 777 and after.wild.world_seed == 777
	for id in ids_before:
		var creature := after.wild.creature_at(id)
		same = same and creature != null and creature.position == positions_before[id]
	_check(same, "o Continuar reconstrói a disposição pela semente salva (mesmos ids e lugares)")
	var registered := true
	for creature in after.wild.get_children():
		if not creature.is_queued_for_deletion():
			registered = registered and after.authority.id_of(creature) > 0 and after.zone.dinos().has(creature)
	_check(registered and after.zone.dino_count() == after.wild.get_child_count() - _queued(after) + 1,
			"os bandos refeitos estão na autoridade e na zona; os antigos saíram")


func _queued(main: Main) -> int:
	var count := 0
	for child in main.wild.get_children():
		count += 1 if child.is_queued_for_deletion() else 0
	return count


## Save v5 anterior à emenda (sem `world.seed` nem `wild_groups`, delta por `w<n>`): carrega, nada de domado se perde.
func _test_old_v5_keeps_the_tamed() -> void:
	var tree := _root.get_tree()
	var source := _main("old_v5_src", 20, true)
	await tree.physics_frame
	_tame(source, source.wild.creature_at(_wid(source, 0)))
	_tame(source, source.wild.creature_at(_wid(source, 1)))
	var data := WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild)
	_release_worlds()
	data["world"].erase("seed")
	data["world"].erase("wild_groups")
	data["world"]["wild"] = [{"id": "w3", "dead": true}, {"id": "w4", "tamed": true}, {"id": "w5", "state": {"torpor": {}}}]
	var target := _main("old_v5_dst", 20, true, 1234)
	await tree.physics_frame
	var ok := WorldSnapshot.restore(JSON.parse_string(JSON.stringify(data)), target.player, target.dino, target.resources, target.wild)
	var tamed := 0
	for creature in target.wild.get_children():
		tamed += 1 if (creature as Dino).state_machine.is_tamed else 0
	_check(ok and tamed == 2 and target.wild.adopted().size() == 2, "save v5 antigo carrega e os 2 domados ficam (%d)" % tamed)
	_check(target.wild.world_seed == IslandMap.default_map().seed_value and not target.wild.is_dead("w3"),
			"sem world.seed vale a semente do mapa; o delta w<n> é ignorado")
	_check(target.wild.groups_to_list().is_empty() and target.wild.to_list().is_empty(),
			"nenhuma vaga marcada como tocada: o domado é entidade, não delta, e os selvagens nascem novos")


func _test_bad_groups_are_discarded() -> void:
	var tree := _root.get_tree()
	var source := _main("bad_groups_src", 20, true)
	await tree.physics_frame
	var slot_id := _distant_slot(source)
	var original: Vector2i = source.wild.slot_info(slot_id)["center"]
	var data := WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild)
	_release_worlds()
	var bad_groups: Array = [
		{"slot": slot_id, "gen": 3, "center": [1, 1]},  # fora da região (mar)
		{"slot": slot_id, "gen": -2, "center": [original.x, original.y]},
		{"slot": "g_que_nao_existe", "gen": 1, "center": [original.x, original.y]},
		{"slot": "g1", "gen": 1, "center": [original.x, original.y]},  # Dodo: a espécie não existe no jogo
		5, "x", {"gen": 1},
		{"slot": slot_id, "gen": 1.5, "center": [original.x, original.y]},
		{"slot": slot_id, "gen": 1, "center": "no meio"},
	]
	data["world"]["wild_groups"] = bad_groups
	var target := _main("bad_groups_dst", 20, true)
	await tree.physics_frame
	var ok := WorldSnapshot.restore(data, target.player, target.dino, target.resources, target.wild)
	var info := target.wild.slot_info(slot_id)
	_check(ok and info["gen"] == 0 and info["center"] == original and not info["waiting"],
			"entradas de grupo malformadas, fora da região ou de vaga desconhecida são descartadas: a vaga volta à semente")
	# Prazo absurdo é limitado: vence no máximo `group_respawn_seconds` depois do relógio do save.
	var late := _main("bad_groups_late", 20, true)
	await tree.physics_frame
	data["world"]["wild_groups"] = [{"slot": slot_id, "gen": 0, "center": [original.x, original.y], "due_at": 1.0e9, "tries": 2}]
	data["world"]["time"] = 50.0
	_check(WorldSnapshot.restore(data, late.player, late.dino, late.resources, late.wild)
			and late.wild.slot_info(slot_id)["waiting"] and late.wild.slot_info(slot_id)["due_at"] <= 50.0 + 1200.0 + 0.001,
			"o prazo salvo é limitado ao relógio do save mais a espera da espécie")
