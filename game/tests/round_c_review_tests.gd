# SPDX-License-Identifier: MIT
class_name RoundCReviewTests
extends RoundCTests
## Revisão da rodada C: escolha de alvo com a tecla de verdade (o mais perto só vale se tem ação a oferecer),
## prompt solto quando a carcaça some, regras de carcaça em dado e os detalhes que as mutações pegaram
## (carcaça mais antiga, tempo de coleta, ids e idades no save, nó que volta por quadros, placa e destaque).


func run() -> void:
	await _test_target_awake_wild_nearer()
	_release_worlds()
	await _test_target_sleeper_and_tamed()
	_release_worlds()
	await _test_target_carcass_with_awake_wild()
	_release_worlds()
	await _test_prompt_released_when_carcass_expires()
	_release_worlds()
	await _test_carcass_rules_and_oldest()
	_release_worlds()
	await _test_carcass_gather_time_and_recharge()
	_release_worlds()
	await _test_carcass_save_age_and_id()
	_release_worlds()
	await _test_carcass_restored_id_and_unregister()
	_release_worlds()
	await _test_target_foreign_tamed()
	_release_worlds()
	await _test_wild_level_tag_in_world()
	_release_worlds()
	await _test_loaded_depleted_node_returns_by_frames()
	_release_worlds()
	await _test_marker_follows_dino()
	_release_worlds()
	await _test_highlight_follows_availability()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_root.push_input(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	_root.push_input(release)


func _frames(count: int) -> void:
	for i in count:
		await _root.get_tree().physics_frame


## Mundo vivo (jogador e selvagens com física, como no jogo): a escolha de alvo só roda assim.
func _quiet_world(name: String) -> Main:
	GameSession.continue_requested = false
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = name
	main.dino_level = 20
	main.menu_scene = ""
	_root.add_child(main)
	_track.call(main)
	main.scheduler.frozen = true
	await _frames(3)
	main.player.global_position = main.map.start_point()
	return main


func _place(main: Main, creature: Dino, offset: Vector2) -> void:
	creature.state_machine.set_physics_process(false)
	creature.state_machine.desired_direction = Vector2.ZERO
	creature.global_position = main.player.global_position + offset
	main.zone.reclassify()
	await _frames(3)
	creature.global_position = main.player.global_position + offset
	await _frames(2)


func _knock(creature: Dino) -> void:
	creature.torpor.add_torpor(creature.torpor.max_torpor)


func _prompt(main: Main) -> String:
	var label: Label = main.hud.prompt_label()
	return label.text if label.visible else ""


# ----------------------------------------------------------------------------- alvo e prompt

func _test_target_awake_wild_nearer() -> void:
	var main := await _quiet_world("d_awake")
	var tamed := main.wild.creature_at(_wid(main, 0))
	var wild_one := main.wild.creature_at(_wid(main, 1))
	_tame_for(tamed, main.player.player_id)
	await _place(main, tamed, Vector2(0, -24))
	await _place(main, wild_one, Vector2(0, 16))
	_check(main.player.target == tamed.interactable, "selvagem acordado mais perto não tira o alvo do domado")
	_check(_prompt(main) == "E para abrir opções de Paquicéfalo", "o prompt diz o que o E faz, com o nome")
	var before := tamed.state_machine.order
	_press("interact")
	await _frames(2)
	_check(tamed.state_machine.order == before and wild_one.state_machine.order == Enums.DinoOrder.STAY,
			"tecla E nunca dá ordem (abre o menu); o selvagem não muda")
	_press("toggle_follow")
	await _frames(2)
	_check(tamed.state_machine.order != before and wild_one.state_machine.order == Enums.DinoOrder.STAY,
			"a tecla G manda o domado mais perto")


func _test_target_sleeper_and_tamed() -> void:
	var main := await _quiet_world("d_sleeper")
	var tamed := main.wild.creature_at(_wid(main, 0))
	var sleeper := main.wild.creature_at(_wid(main, 1))
	_tame_for(tamed, main.player.player_id)
	await _place(main, tamed, Vector2(0, -26))
	await _place(main, sleeper, Vector2(0, 18))
	_knock(sleeper)
	await _frames(2)
	_check(main.player.target == sleeper.interactable, "entre duas criaturas vale a mais perto: o desmaiado (a doma é a ação)")
	_check(_prompt(main) == "E para interagir", "e o prompt é o da doma, sem oferecer ordem ao domado")
	var before := tamed.state_machine.order
	_press("interact")
	await _frames(2)
	_check(main.screen.is_open and tamed.state_machine.order == before, "tecla E abre a tela de doma e não manda o domado")
	_check(sleeper.owner_player_id == "" and sleeper.state_machine.order == Enums.DinoOrder.STAY, "o selvagem segue sem dono nem ordem")


func _test_target_carcass_with_awake_wild() -> void:
	var main := await _quiet_world("d_gather")
	var dead := main.wild.creature_at(_wid(main, 0))
	var alive := main.wild.creature_at(_wid(main, 1))
	await _place(main, dead, Vector2(20, 0))
	await _place(main, alive, Vector2(0, 16))
	_kill(dead)
	await _frames(3)
	var carcass: ResourceNode = main.carcasses.nodes()[0]
	_check(main.player.target == carcass.interactable, "selvagem acordado perto não tira a carcaça do alvo")
	var meat := main.player.inventory.count("meat")
	_press("interact")
	await _frames(3)
	_check(main.player.inventory.count("meat") > meat, "tecla E colhe a carne da carcaça")


func _test_prompt_released_when_carcass_expires() -> void:
	var main := await _quiet_world("d_expire")
	var dead := main.wild.creature_at(_wid(main, 0))
	await _place(main, dead, Vector2(0, 14))
	_kill(dead)
	await _frames(3)
	var seen: Array = []
	main.player.target_changed.connect(func(t: InteractableArea) -> void: seen.append(t))
	_check(main.player.target != null and _prompt(main) != "", "com a carcaça ao lado há alvo e prompt")
	TestWorld.pass_time(main, 601.0)
	await _frames(10)
	var meat := main.player.inventory.count("meat")
	_press("interact")
	await _frames(2)
	_check(main.carcasses.count() == 0 and main.player.target == null and not seen.is_empty() and seen.back() == null,
			"a carcaça expirou: sem alvo e target_changed(null)")
	_check(_prompt(main) == "" and main.player.inventory.count("meat") == meat, "sem prompt preso, e E não faz nada")


# ----------------------------------------------------------------------------- carcaça

func _test_carcass_rules_and_oldest() -> void:
	var main := await _quiet_world("d_oldest")
	_check(main.carcasses.rules.fresh_seconds == 600.0 and main.carcasses.rules.max_carcasses == 8, "regras da carcaça vêm do dado (600 s, 8)")
	var list: Array = []
	for i in 8:
		list.append({"species": "placeholder_dino", "level": 10, "x": float(i), "y": 0.0})
	main.carcasses.restore_list(list)
	_check(main.carcasses.count() == 8, "oito carcaças restauradas")
	var victim := main.wild.creature_at(_wid(main, 0))
	await _place(main, victim, Vector2(0, 30))
	_kill(victim)
	await _frames(2)
	var xs: Array = []
	for node in main.carcasses.nodes():
		xs.append(node.position.x)
	_check(main.carcasses.count() == 8 and not xs.has(0.0) and xs.has(1.0) and xs.has(7.0),
			"a nona tira a MAIS ANTIGA (a primeira), não outra")
	var many: Array = []
	for i in 30:
		many.append({"species": "placeholder_dino", "level": 10, "x": float(i), "y": 0.0})
	main.carcasses.restore_list(many)
	xs.clear()
	for node in main.carcasses.nodes():
		xs.append(node.position.x)
	xs.sort()
	_check(xs == [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], "restaurar com excesso fica com as 8 primeiras")
	TestWorld.pass_time(main, 599.9)
	_check(main.carcasses.count() == 8, "aos 599,9 s a carcaça ainda está fresca")
	TestWorld.pass_time(main, 0.2)
	_check(main.carcasses.count() == 0, "aos 600,1 s ela some")


func _test_carcass_gather_time_and_recharge() -> void:
	var main := await _quiet_world("d_recharge")
	var player := main.player
	var carcasses: Array[ResourceNode] = []
	for i in 3:
		var creature := main.wild.creature_at(_wid(main, i))
		creature.level = 20  # 5 de carne
		await _place(main, creature, Vector2(0, 10 + i))
		_kill(creature)
		await _frames(2)
	carcasses.assign(main.carcasses.nodes())
	_check(carcasses.size() == 3 and carcasses[0].def.yield_amount == 5 and carcasses[0].def.gather_seconds == 15.0,
			"3 s por carne: 5 de carne levam 15 s")
	player.tick(60.0)
	_empty(player.inventory)
	var first := main.authority.id_of(carcasses[0])
	var second := main.authority.id_of(carcasses[1])
	var third := main.authority.id_of(carcasses[2])
	_check(main.authority.request_gather(1, first) == RESULT.OK and player.inventory.count("meat") == 5, "colheita inteira")
	player.tick(14.9)
	_check(main.authority.request_gather(1, second) == RESULT.COOLDOWN, "aos 14,9 s ainda recarrega (inteira = 15 s)")
	player.tick(0.2)
	_check(main.authority.request_gather(1, second) == RESULT.OK, "aos 15,1 s colhe de novo")
	# Parcial: cabem 2 de 5, a recarga é proporcional (6 s).
	player.tick(60.0)
	_empty(player.inventory)
	player.inventory.capacity = 1
	player.inventory.add("meat", Items.max_stack("meat") - 2)
	_check(main.authority.request_gather(1, third) == RESULT.OK and carcasses[2].component.pending_yields() == {"meat": 3},
			"parcial: leva 2, ficam 3")
	player.tick(5.9)
	_check(main.authority.request_gather(1, third) == RESULT.COOLDOWN, "parcial: aos 5,9 s ainda recarrega (2/5 de 15 s = 6 s)")
	player.tick(0.2)
	_check(main.authority.request_gather(1, third) != RESULT.COOLDOWN, "parcial: aos 6,1 s a recarga acabou (não os 15 s inteiros)")


func _test_carcass_save_age_and_id() -> void:
	var saved: Array = []
	var after := await _save_and_continue("d_carcass_age", func(main: Main) -> void:
		_kill(main.wild.creature_at(_wid(main, 0)))
		TestWorld.pass_time(main, 30.0)
		_kill(main.wild.creature_at(_wid(main, 1)))
		TestWorld.pass_time(main, 50.0)
		_kill(main.wild.creature_at(_wid(main, 2)))
		saved.append_array(main.carcasses.to_list()))
	var now := after.carcasses.to_list()
	_check(saved.size() == 3 and now.size() == 3, "três carcaças salvas e carregadas")
	var ok := saved.size() == now.size()
	for i in mini(saved.size(), now.size()):
		var drift := float(now[i]["born_at"]) - float(saved[i]["born_at"])
		ok = ok and int(now[i]["id"]) == int(saved[i]["id"]) and int(now[i]["id"]) > 0 and absf(drift) < 0.001
	_check(ok, "cada carcaça volta com o mesmo id e o mesmo instante de nascimento")
	_check(float(saved[0]["born_at"]) < float(saved[1]["born_at"]) and float(saved[1]["born_at"]) < float(saved[2]["born_at"]) \
			and float(now[2]["born_at"]) > float(now[0]["born_at"]) + 70.0, "os nascimentos são diferentes entre si (0, 30, 80 s)")


func _test_loaded_depleted_node_returns_by_frames() -> void:
	var main := await _quiet_world("d_return")
	var node := main.resources.node_by_id("n335")
	main.resources.restore_list([{"id": "n335", "def": "tree", "depleted": true, "due_at": 0.25}])
	node = main.resources.node_by_id("n335")
	_check(not node.is_available(), "o nó esgotado carregado está esgotado")
	await _frames(40)
	_check(node.is_available(), "e volta sozinho, contando quadros reais")


# ----------------------------------------------------------------------------- placa e destaque

func _test_marker_follows_dino() -> void:
	var main := await _quiet_world("d_marker")
	var mine := main.wild.creature_at(_wid(main, 0))
	_tame_for(mine, main.player.player_id)
	await _place(main, mine, Vector2(0, 30))
	await _root.get_tree().process_frame
	var marker := _marker_of(main, mine)
	_check(marker != null and marker.is_marked(), "a placa existe para o domado do jogador")
	mine.global_position += Vector2(37.0, -11.0)
	mine.visual.frame_coords = Vector2i(3, 2)
	mine.visual.flip_h = true
	marker._process(0.0)  # a view do dino também mexe no quadro a cada frame: aqui o quadro posto é o que vale
	_check(marker.global_position.is_equal_approx(mine.global_position), "a placa segue o dino")
	var copies := 0
	var synced := true
	for child in mine.visual.get_children():
		var copy := child as Sprite2D
		if copy != null and copy.material is ShaderMaterial:
			copies += 1
			synced = synced and copy.frame_coords == Vector2i(3, 2) and copy.flip_h and copy.hframes == mine.visual.hframes
	_check(copies == 4 and synced, "o contorno (4 cópias) segue o quadro e o espelhamento do sprite")


func _test_highlight_follows_availability() -> void:
	var main := await _quiet_world("d_highlight")
	var tree_node := main.resources.node_by_id("n335")
	var view := _view_of(tree_node)
	main.hud._on_target_changed(tree_node.interactable)
	_check(view.is_highlighted(), "alvo cheio: destaque ligado")
	tree_node.harvest()
	_check(not view.is_highlighted() and not main.hud.prompt_label().visible, "esgotado: o destaque e o prompt somem na hora")
	TestWorld.pass_time(main, tree_node.def.respawn_seconds)
	_check(tree_node.is_available() and view.is_highlighted(), "o nó volta cheio com o jogador ao lado: o destaque volta")


## O id gravado volta exatamente (um id fixo, que o sorteio de ids novos não produziria) e, quando a carcaça
## expira ou esvazia, sai da autoridade: o id antigo vira alvo desconhecido.
func _test_carcass_restored_id_and_unregister() -> void:
	var main := await _quiet_world("d_carcass_id")
	var entry := {"id": 424242, "species": "placeholder_dino", "level": 10, "x": 40.0, "y": 40.0, "born_at": -1.0}
	main.carcasses.restore_list([entry])
	var node: ResourceNode = main.carcasses.nodes()[0]
	_check(main.authority.id_of(node) == 424242, "a carcaça restaurada volta com o id gravado (424242)")
	main.player.global_position = node.global_position
	_check(main.authority.request_gather(1, 424242) != RESULT.UNKNOWN_TARGET, "com o id vivo, a colheita reconhece o alvo")
	main.carcasses.restore_list([entry])
	node = main.carcasses.nodes()[0]
	_check(main.authority.id_of(node) == 424242, "restaurar de novo mantém o id")
	TestWorld.pass_time(main, main.carcasses.rules.fresh_seconds + 1.0)
	await _frames(2)
	_check(main.carcasses.count() == 0 and main.authority.request_gather(1, 424242) == RESULT.UNKNOWN_TARGET,
			"expirou: o id antigo vira UNKNOWN_TARGET")
	# `entity()` já esconde nó liberado: só `is_registered` prova o `unregister` (senão o id ficaria vazando).
	_check(not main.authority.is_registered(424242), "expirou: o id saiu do registro da autoridade (unregister)")
	main.carcasses.restore_list([entry])
	node = main.carcasses.nodes()[0]
	node.harvest()  # esvaziada
	await _frames(3)
	_check(main.carcasses.count() == 0 and main.authority.request_gather(1, 424242) == RESULT.UNKNOWN_TARGET,
			"esvaziou: o id antigo também vira UNKNOWN_TARGET")
	_check(not main.authority.is_registered(424242), "esvaziou: o id saiu do registro da autoridade (unregister)")


## O domado de outro dono não disputa o alvo: nem toma o lugar da carcaça mais longe, nem vira alvo sozinho.
func _test_target_foreign_tamed() -> void:
	var main := await _quiet_world("d_foreign_target")
	var foreign := main.wild.creature_at(_wid(main, 0))
	var dead := main.wild.creature_at(_wid(main, 1))
	_tame_for(foreign, "outro")
	await _place(main, foreign, Vector2(0, 10))
	_check(main.player.target == null, "o domado de outro, sozinho ao lado, não é alvo")
	await _place(main, dead, Vector2(20, 0))
	_kill(dead)
	await _frames(3)
	var carcass: ResourceNode = main.carcasses.nodes()[0]
	_check(main.player.target == carcass.interactable, "o domado de outro, mais perto, não tira a carcaça do alvo")
	var mine := main.wild.creature_at(_wid(main, 2))
	_tame_for(mine, main.player.player_id)
	await _place(main, mine, Vector2(0, -12))
	_check(main.player.target == carcass.interactable, "recurso tem prioridade sobre criatura: a carcaça segue como alvo")
	main.carcasses.nodes()[0].queue_free()
	await _frames(3)
	_check(main.player.target == mine.interactable, "sem recurso por perto, o domado do próprio jogador é o alvo")


## Mundo real: o selvagem acordado a 3 tiles ganha o seu `WildLevelTag` (pendurado na `Main`), que mostra o nível
## e acompanha o dino.
func _test_wild_level_tag_in_world() -> void:
	var main := await _quiet_world("d_level_tag")
	var creature := main.wild.creature_at(_wid(main, 0))
	creature.level = 23
	await _place(main, creature, Vector2(48, 0))  # 3 tiles
	await _root.get_tree().process_frame  # a etiqueta se atualiza no `_process`, não na física
	await _root.get_tree().process_frame
	var tag: WildLevelTag = null
	for child in main.get_children():
		if child is WildLevelTag and (child as WildLevelTag).dino == creature:
			tag = child
	_check(tag != null, "o selvagem do mapa ganhou um WildLevelTag na Main")
	if tag == null:
		return
	_check(tag.tag_visible() and tag.tag_text() == "Nv 23", "a 3 tiles, acordado: 'Nv 23' visível")
	creature.global_position += Vector2(12, 7)
	tag.tick()
	_check(tag.global_position == creature.global_position, "a etiqueta acompanha o dino")
