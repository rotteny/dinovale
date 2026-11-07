# SPDX-License-Identifier: MIT
class_name WildPersistenceTests
extends WorldTests
## Selvagens do mapa no save (delta por índice de `spawns`), colheita parcial do arbusto e a regra da pedra
## sem ferramenta. Reaproveita `_main`, `_near` e a raiz de saves de `WorldTests`.


func run() -> void:
	await _test_tamed_wild_survives_continue()
	_release_worlds()
	await _test_taming_in_progress_survives_continue()
	_release_worlds()
	await _test_unconscious_and_dead_wild()
	_release_worlds()
	await _test_tamed_wild_death_triggers_save()
	_release_worlds()
	await _test_other_revision_applies_by_id()
	_release_worlds()
	await _test_tamed_wild_follow_after_continue()
	_release_worlds()
	await _test_each_change_is_saved()
	_release_worlds()
	await _test_other_revision_keeps_tamed_and_items()
	_release_worlds()
	await _test_malformed_wild_falls_back()
	_release_worlds()
	await _test_hostile_values()
	_release_worlds()
	await _test_restore_refuses_malformed()
	_release_worlds()
	await _test_restore_tolerates_and_dead_rollback()
	_release_worlds()
	await _test_bak_after_partial_apply()
	_release_worlds()
	await _test_recreated_death_and_notices()
	_release_worlds()
	await _test_complete_harvest_with_tool()
	_release_worlds()
	await _test_views_bookkeeping()
	_release_worlds()
	await _test_partial_tree_costs_once()
	_release_worlds()
	await _test_partial_bush()
	_release_worlds()
	await _test_rock_tool_before_space()
	_release_worlds()


## Cria um mundo, deixa `prepare` mexer nele, grava e devolve um mundo novo carregado pelo Continuar.
func _save_and_continue(world: String, prepare: Callable) -> Main:
	var tree := _root.get_tree()
	var before := _main(world, 20, true)
	await tree.physics_frame
	prepare.call(before)
	_check(before.save_game(SaveManager.Reason.BED), "%s: salvou" % world)
	GameSession.continue_requested = true
	var after := _main(world, 20, true)
	await tree.physics_frame
	return after


## Doma o selvagem de verdade: nocaute, comida e refeições até virar domado (o número de refeições depende do nível).
func _tame(main: Main, creature: Dino) -> void:
	creature.feeder_player_id = main.player.player_id
	creature.torpor.add_torpor(creature.torpor.max_torpor)
	creature.inventory.add("berry", 60)
	var guard := 0
	while not creature.state_machine.is_tamed and guard < 100:
		guard += 1
		creature.taming.tick(5.1)


func _test_tamed_wild_survives_continue() -> void:
	var spot := [Vector2.ZERO]
	var after := await _save_and_continue("wild_tamed", func(main: Main) -> void:
		var creature := main.wild.creature_at("w0")
		_tame(main, creature)
		spot[0] = creature.position)
	var back := _tamed_wild(after)
	_check(back != null and back.owner_player_id == after.player.player_id,
			"selvagem domado continua domado e com dono depois do Continuar (recriado da entidade)")
	_check(back != null and back.position == spot[0], "o domado continua onde estava")
	_check(after.wild.creature_at("w0") == null and after.wild.is_taken("w0"), "o índice dele fica consumido: não nasce outro selvagem")
	_check(after.wild.get_child_count() == after.world_rules.wild_population_max - 1 + 10 and after.wild.adopted().size() == 1,
			"nenhum duplicado: 116 do mapa (106 paquicéfalos e 10 utahraptores) e 1 recriado")
	_check(after.authority.id_of(back) > 0 and after.zone.dinos().has(back), "o recriado está na autoridade e na zona")
	# Segundo ciclo de salvar e carregar.
	_check(after.save_game(SaveManager.Reason.BED), "salva de novo")
	GameSession.continue_requested = true
	var third := _main("wild_tamed", 20, true)
	await _root.get_tree().physics_frame
	_check(_tamed_wild(third) != null and third.wild.get_child_count() == third.world_rules.wild_population_max - 1 + 10
			and third.wild.adopted().size() == 1, "segundo ciclo: o domado segue um só")


func _tamed_wild(main: Main) -> Dino:
	for creature in main.wild.get_children():
		if (creature as Dino).state_machine.is_tamed:
			return creature as Dino
	return null


func _tamed_count(main: Main) -> int:
	var total := 0
	for creature in main.wild.get_children():
		total += 1 if (creature as Dino).state_machine.is_tamed else 0
	return total + (1 if main.dino.state_machine.is_tamed else 0)


## Grava duas vezes (o `.bak` fica igual), deixa `edit` mexer no principal e carrega.
func _save_edit_continue(world: String, prepare: Callable, edit: Callable) -> Main:
	var tree := _root.get_tree()
	var before := _main(world, 20, true)
	await tree.physics_frame
	prepare.call(before)
	before.save_game(SaveManager.Reason.BED)
	before.save_game(SaveManager.Reason.BED)
	var path := before.save_manager.main_path()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	edit.call(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	GameSession.continue_requested = true
	var after := _main(world, 20, true)
	await tree.physics_frame
	return after


func _test_tamed_wild_follow_after_continue() -> void:
	var after := await _save_and_continue("wild_follow", func(main: Main) -> void:
		var creature := main.wild.creature_at("w0")
		_tame(main, creature)
		creature.state_machine.set_order(Enums.DinoOrder.STAY))
	var back := _tamed_wild(after)
	var id := after.authority.id_of(back)
	after.player.position = back.position + Vector2(10, 0)  # a ordem exige estar perto
	_check(after.authority.request_command(1, id, "FOLLOW") == RESULT.OK and back.state_machine.order == Enums.DinoOrder.FOLLOW,
			"a ordem Seguir de um selvagem domado recriado passa pela autoridade")
	after.player.position = back.position + Vector2(200, 0)
	back.process_mode = Node.PROCESS_MODE_PAUSABLE  # o pai dos selvagens está desligado nos testes
	var start := back.position.distance_to(after.player.position)
	for _frame in 20:
		await _root.get_tree().physics_frame
	_check(back.position.distance_to(after.player.position) < start - 4.0, "o domado recriado anda atrás do dono")
	after.player.position = back.position + Vector2(10, 0)
	_check(after.authority.request_command(1, id, "STAY") == RESULT.OK, "e aceita Ficar")


func _test_each_change_is_saved() -> void:
	var after := await _save_and_continue("wild_changes", func(main: Main) -> void:
		main.wild.creature_at("w6").torpor.current_torpor = 5.0  # só torpor
		main.wild.creature_at("w7").inventory.add("berry", 3)  # só comida
		var hurt := main.wild.creature_at("w8")
		hurt.health.current_health = hurt.health.max_health - 5.0)  # só ferido
	_check(is_equal_approx(after.wild.creature_at("w6").torpor.current_torpor, 5.0), "só torpor: volta")
	_check(after.wild.creature_at("w7").inventory.count("berry") == 3, "só comida depositada: volta")
	_check(is_equal_approx(after.wild.creature_at("w8").health.current_health, after.wild.creature_at("w8").health.max_health - 5.0),
			"só ferido: volta")
	_check(after.wild.creature_at("w9").torpor.current_torpor == 0.0 and after.wild.to_list().size() == 3,
			"o delta tem só os 3 que mudaram")


func _test_other_revision_keeps_tamed_and_items() -> void:
	var saved := [0.0, 0]
	var after := await _save_edit_continue("wild_rev", func(main: Main) -> void:
		_tame(main, main.wild.creature_at("w0"))
		main.dino.torpor.add_torpor(main.dino.torpor.max_torpor)
		main.dino.state_machine.mark_tamed()
		main.dino.owner_player_id = main.player.player_id
		var prog := main.wild.creature_at("w1")
		prog.feeder_player_id = main.player.player_id
		prog.torpor.add_torpor(prog.torpor.max_torpor)
		prog.inventory.add("berry", 20)
		prog.taming.tick(5.1)
		saved[0] = prog.taming.taming_progress
		saved[1] = prog.inventory.count("berry"),
		func(data: Dictionary) -> void: data["world"]["map_revision"] = "0123456789abcdef")
	_check(_tamed_count(after) == 2, "outra revisão: o tutorial domado e o selvagem domado sobrevivem (%d)" % _tamed_count(after))
	_check(after.hud.notice_label().text.contains("mapa mudou"), "outra revisão: a HUD avisa que o mapa mudou")
	var back := after.wild.creature_at("w1")
	_check(back != null and back.inventory.count("berry") == saved[1] and saved[1] == 19
			and is_equal_approx(back.taming.taming_progress, saved[0]),
			"outra revisão: o delta vale por id, e a doma em andamento volta no próprio selvagem com a comida (nada some)")
	_check(after.wild.is_taken("w0") and after.wild.adopted().size() == 1,
			"o domado do mapa segue como entidade e o ponto dele não nasce de novo")
	# O save seguinte já sai na revisão atual e não perde ninguém.
	_check(after.save_game(SaveManager.Reason.BED), "salva depois de carregar a outra revisão")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(after.save_manager.main_path()))
	_check(raw["world"]["map_revision"] == IslandMap.default_map().content_hash, "o save seguinte leva o hash atual")
	GameSession.continue_requested = true
	var third := _main("wild_rev", 20, true)
	await _root.get_tree().physics_frame
	_check(_tamed_count(third) == 2 and third.wild.adopted().size() == 1
			and third.wild.creature_at("w1").inventory.count("berry") == saved[1],
			"segundo ciclo depois da outra revisão: os dois domados e a doma seguem (%d)" % _tamed_count(third))
	_check(not third.hud.notice_label().text.contains("mapa mudou"), "sem novo aviso quando a revisão já é a atual")


func _test_malformed_wild_falls_back() -> void:
	var cases := {
		"id negativo": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = -3,
		"id que não é texto": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = 0,
		"id fracionado": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = 1.5,
		"wild não é lista": func(data: Dictionary) -> void: data["world"]["wild"] = "x",
		"lixo na frente": func(data: Dictionary) -> void:
			var junk: Array = [5, "x", {"index": -3}]
			junk.append_array(data["world"]["wild"])
			data["world"]["wild"] = junk,
		"entrada sem tipo": func(data: Dictionary) -> void: data["world"]["wild"].append({"id": "w9"}),
		"estado da entidade recusado": func(data: Dictionary) -> void:
			for entry: Dictionary in data["entities"]:
				if entry["type"] == "tamed_dino":
					entry["state"]["inventory"] = {"version": 99, "slots": 7},
		"estado do delta recusado": func(data: Dictionary) -> void:
			data["world"]["wild"].append({"id": "w9", "state": {"inventory": {"version": 99, "slots": 7}}}),
	}
	for label: String in cases:
		var after := await _save_edit_continue("wild_bad", func(main: Main) -> void:
			_tame(main, main.wild.creature_at("w0")), cases[label])
		_check(not after._load_failed and _tamed_count(after) == 1,
				"%s: o save recusado cai no .bak e o domado fica (domados %d)" % [label, _tamed_count(after)])
		_release_worlds()


## `restore` devolve false e deixa TUDO como estava (jogador, tutorial, selvagens): é o que manda o `SaveManager` ao `.bak`.
func _test_restore_refuses_malformed() -> void:
	var tree := _root.get_tree()
	var source := _main("refuse_src", 20, true)
	await tree.physics_frame
	_tame(source, source.wild.creature_at("w0"))
	source.player.position += Vector2(33, 0)
	source.player.inventory.add("wood", 5)
	var good := WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild)
	var good_json := JSON.stringify(good)
	var target := _main("refuse_dst", 20, true)
	await tree.physics_frame
	_check(WorldSnapshot.restore(JSON.parse_string(good_json), target.player, target.dino, target.resources, target.wild),
			"preparo: o envelope sem defeito carrega")
	_release_worlds()
	var cases := {
		"id negativo": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = -3,
		"id que não é texto": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = 0,
		"id fracionado": func(data: Dictionary) -> void: data["world"]["wild"][0]["id"] = 1.5,
		"dead e tamed juntos": func(data: Dictionary) -> void: data["world"]["wild"][0]["dead"] = true,
		"tamed false": func(data: Dictionary) -> void: data["world"]["wild"][0]["tamed"] = false,
		"state que não é dicionário": func(data: Dictionary) -> void: data["world"]["wild"].append({"id": "w9", "state": 5}),
		"lista grande demais": func(data: Dictionary) -> void:
			for i in 1100:
				data["world"]["wild"].append({"id": "w%d" % (2000 + i), "dead": true}),
		"entidades demais": func(data: Dictionary) -> void:
			for i in 1100:
				data["entities"].append({"id": 5000 + i, "type": "tamed_dino", "state": {"health": {"current": 0.0}}}),
		"entidade com estado vazio": func(data: Dictionary) -> void:
			data["entities"].append({"id": 9000, "type": "tamed_dino", "state": {}}),
		"índice repetido": func(data: Dictionary) -> void: data["world"]["wild"].append(data["world"]["wild"][0].duplicate()),
		"wild não é lista": func(data: Dictionary) -> void: data["world"]["wild"] = {"a": 1},
		"entrada que não é dicionário": func(data: Dictionary) -> void: data["world"]["wild"].append(7),
		"entrada sem o que fazer": func(data: Dictionary) -> void: data["world"]["wild"].append({"id": "w9"}),
		"estado da entidade recusado": func(data: Dictionary) -> void:
			for entry: Dictionary in data["entities"]:
				if entry["type"] == "tamed_dino":
					entry["state"]["inventory"] = {"version": 99, "slots": 7},
	}
	for label: String in cases:
		var fresh := _main("refuse_case", 20, true)
		await tree.physics_frame
		var data: Dictionary = JSON.parse_string(good_json)
		(cases[label] as Callable).call(data)
		var player_before := fresh.player.to_dict()
		var dino_before := fresh.dino.to_dict()
		var refused := not WorldSnapshot.restore(data, fresh.player, fresh.dino, fresh.resources, fresh.wild)
		_check(refused and fresh.player.to_dict() == player_before and fresh.dino.to_dict() == dino_before
				and fresh.wild.to_list().is_empty() and fresh.wild.adopted().is_empty() and fresh.wild.creature_at("w0") != null,
				"%s: recusa e não muda nada" % label)
		_release_worlds()


## Índice sem criatura hoje (o limite da população baixou) não é defeito: o save carrega e o índice é ignorado.
## Estado morto antes de uma entrada recusada não pode matar ninguém. Domado recriado: ordem em minúsculas é argumento inválido.
func _test_restore_tolerates_and_dead_rollback() -> void:
	var tree := _root.get_tree()
	var source := _main("tol_src", 20, true)
	await tree.physics_frame
	_tame(source, source.wild.creature_at("w0"))
	var good_json := JSON.stringify(WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild))
	_release_worlds()
	var fresh := _main("tol_dst", 20, true)
	await tree.physics_frame
	var data: Dictionary = JSON.parse_string(good_json)
	data["world"]["wild"].append({"id": "w5000", "state": {"torpor": {}}})
	data["world"]["wild"].append({"id": "w6000", "dead": true})
	_check(WorldSnapshot.restore(data, fresh.player, fresh.dino, fresh.resources, fresh.wild) and _tamed_wild(fresh) != null,
			"índice acima do limite da população não impede carregar um save válido")
	_release_worlds()
	var again := _main("tol_dead", 20, true)
	await tree.physics_frame
	var bad: Dictionary = JSON.parse_string(good_json)
	bad["world"]["wild"].append({"id": "w5", "state": {"health": {"current": 0.0}}})
	bad["world"]["wild"].append({"id": "w6", "state": {"inventory": {"version": 99, "slots": 7}}})
	_check(not WorldSnapshot.restore(bad, again.player, again.dino, again.resources, again.wild) and again.wild.creature_at("w5") != null
			and not again.wild.is_dead("w5"), "estado morto antes de uma entrada recusada: ninguém morre, nada é marcado")
	_release_worlds()
	# Recriado liberado não quebra `adopted()`.
	var third := _main("tol_free", 20, true)
	await tree.physics_frame
	_check(WorldSnapshot.restore(JSON.parse_string(good_json), third.player, third.dino, third.resources, third.wild),
			"preparo: carrega o domado")
	var back := _tamed_wild(third)
	_check(third.wild.adopted().size() == 1, "preparo: um recriado")
	back.free()
	_check(third.wild.adopted().is_empty(), "adopted() com a criatura liberada devolve vazio sem erro")


func _test_hostile_values() -> void:
	# Vida 0 sem a marca de morte vale como morto.
	var after := await _save_edit_continue("wild_zero", func(main: Main) -> void:
		main.wild.creature_at("w5").torpor.current_torpor = 5.0,
		func(data: Dictionary) -> void: data["world"]["wild"][0]["state"]["health"] = {"current": 0.0})
	_check(after.wild.creature_at("w5") == null and after.wild.is_dead("w5"), "estado com vida 0 no delta: normalizado como morto")
	_release_worlds()
	# Dono que não existe no save: o domado vira do jogador (nunca preso sem dono).
	var owned := await _save_edit_continue("wild_ghost", func(main: Main) -> void:
		_tame(main, main.wild.creature_at("w0")),
		func(data: Dictionary) -> void:
			for entry: Dictionary in data["entities"]:
				if entry["type"] == "tamed_dino":
					entry["state"]["owner_player_id"] = "fantasma")
	_check(_tamed_wild(owned) != null and _tamed_wild(owned).owner_player_id == owned.player.player_id,
			"dono desconhecido no domado recriado vira o do primeiro jogador")
	_release_worlds()
	# Mapa de outro id: mesmo com a revisão igual, nós e delta não valem.
	var other := await _save_edit_continue("wild_mapid", func(main: Main) -> void:
		main.resources.node_by_id("n316").harvest(),
		func(data: Dictionary) -> void: data["world"]["map_id"] = "outra")
	_check(other.resources.node_by_id("n316").is_available() and other.hud.notice_label().text.contains("mapa mudou"),
			"outro map_id: nó não é aplicado e a HUD avisa")
	# Resto de colheita vindo do arquivo: só item do nó e no máximo o que ele rende.
	var bush := _first_bush(other)
	bush.component.from_dict({"def": "bush_baga", "depleted": false, "leftover": {"fiber": 99999, "nope": 5, "berry": -3}})
	_check(bush.component.leftover == {"fiber": bush.def.extra_yields["fiber"]}, "leftover do arquivo é limitado ao rendimento do nó")
	# Migração v3 para v4: nada de índice nem de nó do mapa antigo.
	var v3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V3))
	v3["world"]["resource_nodes"] = [{"id": "x", "def": "tree", "depleted": true}]
	var migrated := SaveMigrations.migrate(v3)
	_check(migrated["world"]["wild"] == [] and migrated["world"]["resource_nodes"] == [], "v3 para v4 zera nós e selvagens")


func _test_views_bookkeeping() -> void:
	var tree := _root.get_tree()
	var main := _main("views", 20, true)
	await tree.physics_frame
	var creature := main.wild.creature_at("w0")
	main._attach_wild_views(creature)
	main._attach_wild_views(creature)
	var views := 0
	for child in main.get_children():
		views += 1 if child is DinoView and child.dino == creature else 0
	_check(views == 1 and main._wild_views.has(creature), "a view do selvagem nasce uma vez só")
	creature.health.take_damage(creature.health.max_health * 2.0)
	_check(not main._wild_views.has(creature), "selvagem morto não deixa chave em `_wild_views`")


func _test_partial_tree_costs_once() -> void:
	var tree := _root.get_tree()
	var main := _main("partial_tree", 20, true)
	await tree.physics_frame
	var player := main.player
	var inventory := player.inventory
	_empty(inventory)
	inventory.capacity = 2
	inventory.add("wood", inventory.stack_limit("wood") - 1)  # cabe 1 de madeira
	inventory.add("stone", inventory.stack_limit("stone"))
	var wood := main.resources.node_by_id("n316")
	_near(main, wood)
	var hp := player.health.current_health
	var rounds := 0
	while wood.is_available() and rounds < 6:
		rounds += 1
		player.tick(60.0)
		main.authority.request_gather(1, main.authority.id_of(wood))
		inventory.remove("wood", 1)
	_check(rounds == wood.def.yield_amount and not wood.is_available(),
			"a árvore de %d sai em %d colheitas parciais" % [wood.def.yield_amount, rounds])
	_check(is_equal_approx(hp - player.health.current_health, wood.def.hand_self_damage),
			"colheita em %d parciais custa 1 só (custou %s)" % [rounds, str(hp - player.health.current_health)])


func _test_taming_in_progress_survives_continue() -> void:
	var saved := [0.0, 0]
	var after := await _save_and_continue("wild_progress", func(main: Main) -> void:
		var creature := main.wild.creature_at("w2")
		creature.feeder_player_id = main.player.player_id
		creature.torpor.add_torpor(creature.torpor.max_torpor)
		creature.inventory.add("berry", 20)
		creature.taming.tick(5.1)
		saved[0] = creature.taming.taming_progress
		saved[1] = creature.inventory.count("berry"))
	var back := after.wild.creature_at("w2")
	_check(saved[0] > 0.0 and saved[1] == 19, "preparo: uma refeição feita, 19 bagas")
	_check(back != null and is_equal_approx(back.taming.taming_progress, saved[0]) and back.inventory.count("berry") == saved[1]
			and back.torpor.is_unconscious and not back.state_machine.is_tamed,
			"doma em andamento: o progresso e as 19 bagas voltam, inconsciente")
	# A zona não pode soltar a doma em andamento ao reclassificar.
	after.player.position = after.map.center_of(Vector2i(10, 10))
	after.zone.reclassify()
	_check(after.zone.mode_of(back) == ActivityZone.Mode.ACTIVE, "doma em andamento fica ativa mesmo longe do jogador")


func _test_unconscious_and_dead_wild() -> void:
	var after := await _save_and_continue("wild_states", func(main: Main) -> void:
		main.wild.creature_at("w3").torpor.add_torpor(main.wild.creature_at("w3").torpor.max_torpor)
		var weak := main.wild.creature_at("w4")
		weak.health.take_damage(weak.health.max_health * 2.0))
	var sleeper := after.wild.creature_at("w3")
	_check(sleeper != null and sleeper.torpor.is_unconscious and not sleeper.state_machine.is_tamed,
			"selvagem inconsciente volta inconsciente")
	_check(after.wild.creature_at("w4") == null and after.wild.is_dead("w4"), "selvagem morto não volta")
	_check(after.wild.creature_at("w5") != null, "o vizinho que não mudou nasce")


func _test_tamed_wild_death_triggers_save() -> void:
	var tree := _root.get_tree()
	var main := _main("wild_death", 20, true)
	await tree.physics_frame
	var creature := main.wild.creature_at("w0")
	_tame(main, creature)
	_check(creature.state_machine.is_tamed, "preparo: o selvagem foi domado")
	var reasons: Array[SaveManager.Reason] = []
	main.scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _msg: String) -> void: reasons.append(reason))
	creature.health.take_damage(creature.health.max_health * 2.0)
	await tree.process_frame
	main.scheduler.tick(5.0)
	_check(reasons.has(SaveManager.Reason.TAMED_DINO_DEATH), "a morte de um domado selvagem pede o save TAMED_DINO_DEATH")
	reasons.clear()
	var other := main.wild.creature_at("w1")
	other.health.take_damage(other.health.max_health * 2.0)
	await tree.process_frame
	main.scheduler.tick(5.0)
	_check(not reasons.has(SaveManager.Reason.TAMED_DINO_DEATH), "a morte de um selvagem comum não pede esse save")


func _test_other_revision_applies_by_id() -> void:
	var tree := _root.get_tree()
	var source := _main("rev_source", 20, true)
	await tree.physics_frame
	source.wild.creature_at("w0").torpor.add_torpor(source.wild.creature_at("w0").torpor.max_torpor)
	source.resources.node_by_id("n316").harvest()
	var envelope := WorldSnapshot.capture(source.player, source.dino, "t", "now", source.resources, 0, 10, source.wild)
	_check(WorldSnapshot.same_map_revision(envelope), "o save novo tem a revisão do mapa do jogo")
	envelope["world"]["map_revision"] = "0123456789abcdef"
	var target := _main("rev_target", 20, true)
	await tree.physics_frame
	_check(not WorldSnapshot.same_map_revision(envelope)
			and WorldSnapshot.restore(envelope, target.player, target.dino, target.resources, target.wild),
			"save de outra revisão carrega")
	_check(not target.resources.node_by_id("n316").is_available() and target.wild.creature_at("w0").torpor.is_unconscious,
			"de outra revisão o delta de nó e de selvagem vale por id (ADR-007)")
	envelope["world"]["map_revision"] = "0"
	_check(not WorldSnapshot.same_map_revision(envelope), "a revisão '0' (migrada do v3) nunca bate")
	# Id que o mapa de hoje não tem é ignorado (ponto aposentado).
	envelope["world"]["wild"].append({"id": "w99999", "dead": true})
	envelope["world"]["resource_nodes"].append({"id": "n99999", "def": "tree", "depleted": true})
	var again := _main("rev_target2", 20, true)
	await tree.physics_frame
	_check(WorldSnapshot.restore(envelope, again.player, again.dino, again.resources, again.wild),
			"id que o mapa não tem é ignorado, sem recusar a carga")


func _test_partial_bush() -> void:
	var tree := _root.get_tree()
	var main := _main("partial_bush", 20, true)
	await tree.physics_frame
	var player := main.player
	var bush := _first_bush(main)
	_check(bush != null and bush.def.extra_yields.get("fiber", 0) > 0, "há um arbusto com fibra extra")
	_empty(player.inventory)
	player.inventory.capacity = 3
	player.inventory.add("stone", player.inventory.stack_limit("stone") * 2)  # sobra 1 vaga
	_near(main, bush)
	var gained: Array[String] = []
	player.gathered.connect(func(item_id: String, amount: int) -> void: gained.append("%s:%d" % [item_id, amount]))
	var result := main.authority.request_gather(1, main.authority.id_of(bush))
	_check(result == RESULT.OK and player.inventory.count("berry") == bush.def.yield_amount and player.inventory.count("fiber") == 0,
			"vaga só para o principal: entra a baga, a fibra fica")
	_check(bush.is_available() and bush.component.is_partial() and bush.component.leftover == {"fiber": bush.def.extra_yields["fiber"]},
			"o arbusto segue disponível com a fibra que sobrou")
	_check(gained == ["berry:%d" % bush.def.yield_amount], "o aviso mostra só o que entrou")
	# O resto do nó sobrevive ao save.
	var data := bush.component.to_dict()
	_check(data.get("leftover") == {"fiber": bush.def.extra_yields["fiber"]}, "to_dict leva o que sobrou")
	var listed := main.resources.to_list()
	_check(listed.size() == 1, "o nó parcial entra no delta do save")
	var restored := _main("partial_bush_back", 20, true)
	await tree.physics_frame
	restored.resources.restore_list(listed)
	var again := restored.resources.node_by_id(bush.node_id)
	_check(again.is_available() and again.component.leftover == {"fiber": bush.def.extra_yields["fiber"]}, "o resto volta no Continuar")
	# Nada cabe: recusa sem gastar o nó.
	player.inventory.add("stone", player.inventory.stack_limit("stone"))
	player.tick(60.0)
	var left_before := bush.component.leftover.duplicate()
	var refused: Array[String] = []
	player.gather_refused.connect(func(reason: String) -> void: refused.append(reason))
	main.authority.request_gather(1, main.authority.id_of(bush))
	_check(refused == [Player.GATHER_FULL] and bush.component.leftover == left_before and bush.is_available(),
			"inventário cheio: recusa e o nó fica como estava")
	# Com vaga, a fibra sai e o nó esgota.
	player.inventory.remove("stone", player.inventory.stack_limit("stone"))
	player.tick(60.0)
	main.authority.request_gather(1, main.authority.id_of(bush))
	_check(player.inventory.count("fiber") == bush.def.extra_yields["fiber"] and not bush.is_available()
			and not bush.component.is_partial(), "com vaga, a fibra sai e o nó esgota")


func _empty(inventory: InventoryComponent) -> void:
	for index in inventory.slot_count():
		var slot := inventory.get_slot(index)
		if not slot.is_empty():
			if slot.has("iid"):
				inventory.remove_iid(str(slot["iid"]))
			else:
				inventory.remove(str(slot["id"]), int(slot["count"]))


func _first_bush(main: Main) -> ResourceNode:
	for node in main.resources.nodes():
		if node.def.id == "bush_baga":
			return node
	return null


func _test_rock_tool_before_space() -> void:
	var tree := _root.get_tree()
	var main := _main("rock_full", 20, true)
	await tree.physics_frame
	var player := main.player
	var rock := main.resources.node_by_id("n174")
	_empty(player.inventory)
	player.inventory.capacity = 1
	player.inventory.add("wood", player.inventory.stack_limit("wood"))  # inventário cheio
	_near(main, rock)
	var hp := player.health.current_health
	var refused: Array[String] = []
	player.gather_refused.connect(func(reason: String) -> void: refused.append(reason))
	main.authority.request_gather(1, main.authority.id_of(rock))
	_check(refused == [Player.GATHER_NEEDS_TOOL] and is_equal_approx(player.health.current_health, hp - 1.0) and rock.is_available(),
			"pedra no Soco com inventário cheio: 1 de dano e a recusa é de ferramenta")
	_check(main.hud.notice_label().visible and main.hud.notice_label().text.contains("Picareta"),
			"a HUD manda usar a Picareta (texto da recusa)")


## Entrada válida só no principal e depois uma recusa: a carga recua tudo e o `.bak` (sem essa entrada) é o que vale.
func _test_bak_after_partial_apply() -> void:
	var valid := [{}]
	var after := await _save_edit_continue("wild_bak", func(main: Main) -> void:
		var sleeper := main.wild.creature_at("w5")
		sleeper.torpor.current_torpor = 7.0
		valid[0] = sleeper.to_dict()
		sleeper.torpor.current_torpor = 0.0,
		func(data: Dictionary) -> void:
			data["world"]["wild"].append({"id": "w5", "state": valid[0]})
			data["world"]["wild"].append({"id": "w6", "state": {"inventory": {"version": 99, "slots": 7}}}))
	_check(not after._load_failed and after.wild.creature_at("w5") != null and after.wild.creature_at("w5").torpor.current_torpor == 0.0,
			"entrada válida só no principal, depois recusa: nada dela aparece, o .bak vale")


## Recriado que morre pede o save; a ordem em minúsculas é argumento inválido (INVALID_ARGUMENT), não erro de posse.
## Save da cópia anterior de outra revisão: um aviso só, com os dois motivos.
func _test_recreated_death_and_notices() -> void:
	var tree := _root.get_tree()
	var after := await _save_and_continue("wild_recreated", func(main: Main) -> void:
		_tame(main, main.wild.creature_at("w0")))
	var back := _tamed_wild(after)
	var reasons: Array[SaveManager.Reason] = []
	after.scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _msg: String) -> void: reasons.append(reason))
	after.player.position = back.position + Vector2(10, 0)
	_check(after.authority.request_command(1, after.authority.id_of(back), "follow") == RESULT.INVALID_ARGUMENT,
			"ordem em minúsculas: INVALID_ARGUMENT (nome do enum é FOLLOW), não é falha de posse")
	back.health.take_damage(back.health.max_health * 2.0)
	await tree.process_frame
	after.scheduler.tick(5.0)
	_check(reasons.has(SaveManager.Reason.TAMED_DINO_DEATH), "a morte de um domado recriado pede o save TAMED_DINO_DEATH")
	_release_worlds()
	var before := _main("wild_notice", 20, true)
	await tree.physics_frame
	before.save_game(SaveManager.Reason.BED)
	before.save_game(SaveManager.Reason.BED)
	var path := before.save_manager.main_path()
	var backup := ""
	for file in DirAccess.get_files_at(path.get_base_dir()):
		if file.ends_with(".bak"):
			backup = path.get_base_dir().path_join(file)
	_edit_file(backup, func(data: Dictionary) -> void: data["world"]["map_revision"] = IslandMap.default_map().revision + 1)
	_edit_file(path, func(data: Dictionary) -> void: data["world"]["wild"] = "x")
	GameSession.continue_requested = true
	var joined := _main("wild_notice", 20, true)
	await tree.physics_frame
	var text := joined.hud.notice_label().text
	_check(not joined._load_failed and text.contains("mapa mudou") and text.length() > Main.MAP_CHANGED_NOTICE.length(),
			"cópia anterior de outra revisão: um aviso só, com o motivo da queda no .bak e o do mapa")


func _edit_file(path: String, edit: Callable) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	edit.call(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Colheita completa com a ferramenta do nó não custa vida. A definição é só deste teste (o catálogo não tem ferramenta
## de coleta): usa o Bastão como "ferramenta" de um nó de teste.
func _test_complete_harvest_with_tool() -> void:
	var tree := _root.get_tree()
	var main := _main("tool_harvest", 20, true)
	await tree.physics_frame
	var def := ResourceNodeDef.new()
	def.id = "teste_com_ferramenta"
	def.item_id = Items.WOOD
	def.yield_amount = 2
	def.tool_item_id = Items.SLEEP_STAFF
	def.hand_self_damage = 1.0
	def.gather_seconds = 1.0
	def.reach = 40.0
	var player := main.player
	_empty(player.inventory)
	player.inventory.capacity = 4
	player.inventory.add(Items.SLEEP_STAFF, 1)
	var iid := ""
	for index in player.inventory.slot_count():
		if player.inventory.get_slot(index).get("id", "") == Items.SLEEP_STAFF:
			iid = str(player.inventory.get_slot(index).get("iid", ""))
	var with_tool := _test_node(main, def, "tool_a")
	var without := _test_node(main, def, "tool_b")
	_near(main, without)
	var hp := player.health.current_health
	main.authority.request_gather(1, main.authority.id_of(without))
	_check(player.inventory.count(Items.WOOD) == 2 and is_equal_approx(player.health.current_health, hp - 1.0),
			"sem a ferramenta, a colheita completa custa 1")
	_check(player.equipment.equip(iid) == "", "preparo: a ferramenta está em mãos")
	_near(main, with_tool)
	hp = player.health.current_health
	main.authority.request_gather(1, main.authority.id_of(with_tool))
	_check(player.inventory.count(Items.WOOD) == 4 and player.health.current_health == hp and not with_tool.is_available(),
			"com a ferramenta, a colheita completa não custa vida")


func _test_node(main: Main, def: ResourceNodeDef, node_id: String) -> ResourceNode:
	var node: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	node.node_id = node_id
	node.def = def
	node.position = main.player.position + Vector2(0, 8 if node_id == "tool_b" else 12)
	main.resources.add_node(node)
	main.authority.register(node)
	return node
