# SPDX-License-Identifier: MIT
class_name DownedTests
extends PredationTamedTests
## M1, etapa 6: caído, morte, corpo e renascer (`m1-ameaca-e-corpo.md` seção 5, aceite A13 a A17) e as correções da revisão
## das etapas 5 e 5b. Usa a montagem de `PredationTests` e o `_main` de `SaveTests`.

const DOWN_RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
const DOWN_PAQUI: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
const DOWN_RULES: DownedRules = preload("res://data/balance/downed_rules.tres")
const DOWN_STEP := 0.05
const DOWN_ITEMS: Array[String] = ["berry", "meat", "fern", "wood", "wooden_spear", "sleep_staff"]


func run() -> void:
	_test_rules_data()
	_test_a13_downed_by_health()
	_test_a14_downed_by_torpor()
	_test_downed_cannot_act()
	_test_a15_who_attacks_the_downed()
	_test_hud_bar()
	_test_corpse_partial_recover()
	_test_corpse_restore_garbage()
	await _test_a16_death_corpse_recover()
	await _test_corpse_expiry_and_closed_game()
	await _test_a17_saves()
	_test_review_raptor_calms_after_biting()
	_test_review_tamed_bag_keeps_tools()
	_test_review_bitten_only_by_carnivores()
	_test_review_sated_cap()
	_test_review_floor_two_bites_same_frame()
	_test_review_pack_once_and_relation()
	_test_review_cursor_throttle()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

func _arena(raptors: int) -> Dictionary:
	var player := _spawn_player()
	for node: Node in [player, player.hunger, player.stamina]:
		node.set_physics_process(false)
	var authority: WorldAuthority = player.authority
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	var list: Array[Dino] = []
	for _i in raptors:
		var dino: Dino = DinoScene.instantiate()
		dino.stats = DOWN_RAPTOR
		_root.add_child(dino)
		_track.call(dino)
		dino.set_physics_process(false)
		dino.state_machine.set_physics_process(false)
		authority.register(dino)
		list.append(dino)
	return {"player": player, "authority": authority, "events": events, "raptors": list}


## Mordida de 8 a cada 1,5 s por raptor, com fase deslocada (a tabela da seção 5), pela porta real da autoridade.
func _bite_sim(arena: Dictionary, steps: int) -> void:
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	var raptors: Array[Dino] = []
	raptors.assign(arena["raptors"])
	var period := 30  # 1,5 s em passos de 0,05 s
	for step in steps:
		for index in raptors.size():
			var phase := period * index / raptors.size()
			if step >= phase and (step - phase) % period == 0:
				authority.resolve_dino_attack(authority.id_of(raptors[index]), authority.id_of(player), 8.0)
		player.tick(DOWN_STEP)
		authority.clock.advance(DOWN_STEP)


func _die_with_items(main: Main) -> PlayerCorpse:
	var player := main.player
	player.set_physics_process(false)
	player.inventory.add(Items.WOOD, 5)
	if player.inventory.count("wooden_spear") + player.equipment.count("wooden_spear") == 0:
		player.inventory.add("wooden_spear", 1)
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		if slot.get("id", "") == "wooden_spear" and player.equipment.count("wooden_spear") == 0:
			player.request_equip(str(slot["iid"]))
	TestWorld.kill(player)
	return main.corpses.corpse_of(player.player_id)


func _filled(slots: Array) -> int:
	var total := 0
	for slot: Dictionary in slots:
		total += 0 if slot.is_empty() else 1
	return total


func _totals(player: Player) -> Dictionary:
	var totals := {}
	for item_id in DOWN_ITEMS:
		totals[item_id] = player.inventory.count(item_id) + player.equipment.count(item_id)
	return totals


func _kept(body: PlayerCorpse) -> Dictionary:
	var totals := {}
	for item_id in DOWN_ITEMS:
		totals[item_id] = body.count(item_id)
	return totals


# ----------------------------------------------------------------------------- testes

func _test_rules_data() -> void:
	_check(DOWN_RULES.downed_seconds == 10.0 and DOWN_RULES.downed_health == 70.0 and DOWN_RULES.body_minutes == 10.0
			and DOWN_RULES.wake_torpor == 50.0 and DOWN_RULES.wake_grace_seconds == 2.0 and DOWN_RULES.body_seconds() == 600.0,
			"DownedRules em .tres: 10 s, vida 70, torpor 50, graça 2 s, corpo de 10 min")


## A13: vida 0 de pé vira caído com vida 70 por 10 s; 1 raptor não mata, 2 e 3 matam.
func _test_a13_downed_by_health() -> void:
	var one := _arena(1)
	var player: Player = one["player"]
	var events: Array[String] = one["events"]
	player.health.take_damage(100.0)
	_check(player.downed.is_downed and not player.health.is_dead() and player.health.current_health == 70.0
			and is_equal_approx(player.downed.left, 10.0) and events == ["player_downed"],
			"A13: vida 0 de pé vira caído (vida 70, 10 s), não morte")
	_bite_sim(one, 230)
	_check(not player.downed.is_downed and not player.health.is_dead() and events.has("player_woke") and not events.has("player_died"),
			"A13: 1 raptor não mata o caído; ele acorda")
	_check(player.health.current_health == 20.0 and player.downed.torpor <= 50.0 and player.downed.torpor > 0.0,
			"A13: acorda com a vida mínima (20) e torpor 50 (vida %.0f)" % player.health.current_health)
	_check(player.health.protection_left > 0.0 and player.health.protection_left <= 2.0, "A13: acorda com a graça de 2 s sem dano")
	for count in [2, 3]:
		var many := _arena(count)
		var victim: Player = many["player"]
		victim.health.take_damage(100.0)
		_bite_sim(many, 130)
		var seen: Array[String] = many["events"]
		_check(victim.health.is_dead() and not victim.downed.is_downed and seen.has("player_died"),
				"A13: %d raptores matam o caído" % count)
	var early := _arena(2)
	var early_player: Player = early["player"]
	early_player.health.take_damage(100.0)
	_bite_sim(early, 110)  # 5,5 s: ainda vivo; a morte vem aos 6,0 s da tabela
	_check(not early_player.health.is_dead(), "A13: 2 raptores ainda não mataram aos 5,5 s")


## A14: fome zerada sobe o torpor (+2/s); 100 derruba; acorda com 50; comer corta a subida; fome nunca tira vida.
func _test_a14_downed_by_torpor() -> void:
	var arena := _arena(0)
	var player: Player = arena["player"]
	var events: Array[String] = arena["events"]
	player.hunger.current_hunger = 0.0
	for _i in 49:
		player.tick(1.0)
	_check(not player.downed.is_downed and is_equal_approx(player.downed.torpor, 98.0) and player.health.current_health == 100.0,
			"A14: aos 49 s de fome zerada o torpor é 98 e a vida segue em 100")
	player.tick(1.0)
	_check(player.downed.is_downed and events == ["player_downed"] and player.health.current_health == 100.0,
			"A14: aos 50 s o torpor chega a 100 e o jogador cai, sem perder vida")
	for _i in 10:
		player.tick(1.0)
	_check(not player.downed.is_downed and player.downed.torpor == 50.0 and player.health.current_health == 100.0
			and events.has("player_woke"),
			"A14: acorda depois de 10 s com torpor 50")
	player.hunger.current_hunger = 30.0  # comeu
	var before := player.downed.torpor
	player.tick(5.0)
	_check(player.downed.torpor < before and not player.downed.is_downed, "A14: comer corta a subida do torpor")


func _test_downed_cannot_act() -> void:
	var arena := _arena(0)
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	authority.register(dino)
	dino.global_position = Vector2(10.0, 0.0)
	player.global_position = Vector2.ZERO
	player.inventory.add(Items.BERRY, 2)
	player.hotbar.assign(0, Items.BERRY)
	player.health.take_damage(100.0)
	var actor := authority.id_of(player)
	_check(authority.request_move(actor, Vector2.RIGHT) == Enums.ActionResult.ACTOR_DEAD
			and player.apply_input(Vector2.RIGHT, true, 0.1) == Vector2.ZERO, "caído não anda")
	_check(authority.request_attack(actor, authority.id_of(dino)) == Enums.ActionResult.ACTOR_DEAD and not player.attack(),
			"caído não ataca")
	var berries := player.inventory.count(Items.BERRY)
	_check(authority.request_use_item(actor, 0) == Enums.ActionResult.ACTOR_DEAD and player.inventory.count(Items.BERRY) == berries,
			"caído não usa item")
	_check(authority.request_pickup(actor, authority.id_of(dino)) == Enums.ActionResult.ACTOR_DEAD
			and authority.request_drop(actor, 0) == Enums.ActionResult.ACTOR_DEAD, "caído não pega nem larga")
	_check(not player.try_interact() and player.is_incapacitated(), "caído não interage")


## A15: o Paquicéfalo nunca ataca o caído; o Utahraptor ataca (`attacks_downed` do perfil, hoje lido).
func _test_a15_who_attacks_the_downed() -> void:
	var arena := _arena(1)
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	var raptor: Dino = (arena["raptors"] as Array[Dino])[0]
	var paqui: Dino = DinoScene.instantiate()
	paqui.stats = DOWN_PAQUI
	_root.add_child(paqui)
	_track.call(paqui)
	paqui.set_physics_process(false)
	paqui.state_machine.set_physics_process(false)
	authority.register(paqui)
	_check(raptor.attacks_downed() and not paqui.attacks_downed(), "A15: o perfil do Utahraptor ataca o caído e o do Paquicéfalo não")
	var standing := authority.resolve_dino_attack(authority.id_of(paqui), authority.id_of(player), 6.0)
	_check(standing.size() == 1 and player.health.current_health == 94.0, "A15: o Paquicéfalo acerta o jogador de pé")
	player.health.take_damage(1000.0)
	_check(player.downed.is_downed, "preparo: caído")
	var life := player.health.current_health
	_check(authority.resolve_dino_attack(authority.id_of(paqui), authority.id_of(player), 6.0).is_empty()
			and player.health.current_health == life, "A15: o Paquicéfalo nunca acerta o caído")
	_check(authority.resolve_dino_attack(authority.id_of(raptor), authority.id_of(player), 8.0).size() == 1
			and player.health.current_health == life - 8.0, "A15: o Utahraptor acerta o caído")
	paqui.state_machine.provoke()
	paqui.target_locator = func() -> Array: return [player]
	paqui.observe_targets()
	_check(not paqui.state_machine.target_known, "A15: o Paquicéfalo bravo larga o alvo caído (e acalma)")
	raptor.target_locator = func() -> Array: return [player]
	raptor.observe_targets()
	_check(raptor.state_machine.target_known, "A15: o Utahraptor segue com o caído como alvo")


func _test_hud_bar() -> void:
	var player := _spawn_player()
	player.set_physics_process(false)
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(not hud.downed_bar().visible, "HUD: a barra do caído não aparece de pé")
	player.health.take_damage(100.0)
	player.tick(3.0)
	_check(hud.downed_bar().visible and hud.downed_bar().value_text() == "7" and hud.downed_bar().max_value() == 10.0,
			"HUD: caído, a barra mostra o tempo para acordar (7 s) em 10")
	player.tick(8.0)
	_check(not hud.downed_bar().visible, "HUD: acordou, a barra some")


func _test_corpse_partial_recover() -> void:
	var corpse := PlayerCorpse.new()
	_track.call(corpse)
	_root.add_child(corpse)
	corpse.entries = [{"id": "berry", "count": 5}] as Array[Dictionary]
	var bag: InventoryComponent = _track.call(InventoryComponent.new())
	bag.capacity = 1
	bag.max_stack = 3
	var gone: Array[PlayerCorpse] = []
	corpse.depleted.connect(func(c: PlayerCorpse) -> void: gone.append(c))
	_check(corpse.recover_into(bag) == 3 and corpse.count("berry") == 2 and gone.is_empty(), "corpo: o que não cabe fica nele")
	bag.remove("berry", 3)
	_check(corpse.recover_into(bag) == 2 and corpse.is_empty() and gone.size() == 1, "corpo: esvaziou, avisa o campo")


func _test_corpse_restore_garbage() -> void:
	var field := CorpseField.new()
	var clock := TestWorld.TestClock.new()
	clock.time = 100.0
	field.clock = clock.now
	_root.add_child(field)
	_track.call(field)
	field.restore_list([5, "x", {}, {"player_id": "a", "items": [{"id": "zzz", "count": 3}]},
			{"player_id": "a", "x": 1.0, "y": 2.0, "due_at": 1.0e30,
			"items": [{"id": "berry", "count": 99999999}, {"id": "meat", "count": 3}, {"id": "wooden_spear"}]}])
	var body := field.corpse_of("a")
	_check(field.count() == 1 and body != null and body.due_at <= 100.0 + 600.0 and body.count("meat") == 3
			and body.count("berry") == 0 and body.count("wooden_spear") == 0,
			"save corrompido: só o corpo válido entra, prazo e entradas ruins limitados")


## A16: a morte deixa o corpo com TODOS os itens; "Recuperar" devolve; renascer; log e tela.
func _test_a16_death_corpse_recover() -> void:
	var main := _main("dw_corpse")
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	player.inventory.add(Items.WOOD, 5)
	var before_dino := main.dino.health.current_health
	player.set_physics_process(false)
	var body := _die_with_items(main)
	var expected := _totals(player)  # já vazio: confere abaixo contra o corpo
	_check(body != null and body.count("wooden_spear") == 1 and body.count("berry") == 10 and body.count("wood") == 10
			and player.inventory.is_empty() and player.equipment.item_in(EquipmentLayout.WEAPON).is_empty()
			and player.hotbar.item_at(0) == "" and expected["berry"] == 0,
			"A16: a morte deixa o corpo com a grade, o equipado e os atalhos; o jogador fica sem nada")
	_check(events == ["player_downed", "player_died"] and main.pending_death_choice and main.death_screen.is_open,
			"A16: log player_downed e player_died; a tela de morte abre só na morte (%s)" % [events])
	_check(main.death_screen.column().label_of("campina") == "Local aleatório (Campina)" and main.dino.health.current_health == before_dino,
			"A16: a tela oferece Local aleatório na Campina; os dinos ficam como estavam")
	var kept := _kept(body)
	_check(main.request_respawn("campina") == "" and events.has("player_respawned") and not player.health.is_dead()
			and player.inventory.is_empty() and player.downed.torpor == 0.0 and player.health.current_health == player.health.max_health,
			"A16: renascer: vida cheia, torpor 0, inventário vazio, log player_respawned")
	player.set_physics_process(false)
	var corpse_id := authority.id_of(body)
	player.global_position = body.global_position + Vector2(500.0, 0.0)
	_check(authority.request_recover_corpse(1, corpse_id) == Enums.ActionResult.OUT_OF_RANGE, "A16: longe do corpo não recupera")
	player.global_position = body.global_position
	body.owner_player_id = "outro"
	_check(authority.request_recover_corpse(1, corpse_id) == Enums.ActionResult.NOT_OWNER, "A16: só o dono recupera")
	body.owner_player_id = player.player_id
	_check(authority.request_recover_corpse(1, corpse_id) == Enums.ActionResult.OK and events.has("corpse_recovered"),
			"A16: Recuperar itens devolve o corpo")
	var back := _totals(player)
	var same := true
	for item_id: String in kept:
		same = same and back[item_id] == kept[item_id]
	_check(same and main.corpses.count() == 0 and authority.entity(corpse_id) == null, "A16: todos os itens voltam e o corpo some")


## Corpo expira em 10 min de MUNDO RODANDO e os itens somem; com o jogo fechado o relógio não corre (D4).
func _test_corpse_expiry_and_closed_game() -> void:
	var main := _main("dw_expire")
	await _root.get_tree().physics_frame
	var events: Array[String] = []
	main.authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	var body := _die_with_items(main)
	var corpse_id := main.authority.id_of(body)
	TestWorld.pass_time(main, 599.0)
	_check(main.corpses.count() == 1 and not events.has("corpse_expired"), "corpo: aos 599 s ainda está lá")
	TestWorld.pass_time(main, 2.0)
	_check(main.corpses.count() == 0 and events.has("corpse_expired") and main.authority.entity(corpse_id) == null,
			"corpo: passados 10 min com o mundo rodando, o corpo e os itens somem (corpse_expired)")
	var live := _main("dw_closed")
	await _root.get_tree().physics_frame
	_die_with_items(live)
	TestWorld.pass_time(live, 100.0)
	_check(live.save_game(R.BED), "preparo: salva aos 100 s de corpo")
	var closed_events: Array[String] = []
	GameSession.continue_requested = true
	var reopened := _main("dw_closed")  # o jogo ficou fechado quanto tempo quis: o relógio do mundo não correu
	reopened.authority.game_event.connect(func(code: String, _params: Dictionary) -> void: closed_events.append(code))
	var again := reopened.corpses.corpse_of(reopened.player.player_id)
	_check(again != null and is_equal_approx(again.due_at - reopened.authority.clock.now(), 500.0),
			"D4: reaberto, o corpo ainda tem 500 s (o tempo fechado não conta)")
	reopened.corpses.tick()
	_check(reopened.corpses.count() == 1 and closed_events.is_empty(), "D4: reabrir não expira nem avisa nada")
	TestWorld.pass_time(reopened, 499.0)
	_check(reopened.corpses.count() == 1, "D4: rodando o mundo, aos 499 s restantes ainda existe")
	TestWorld.pass_time(reopened, 2.0)
	_check(reopened.corpses.count() == 0 and closed_events.has("corpse_expired"), "D4: com o mundo rodando, expira no prazo")


## A17 e save: morto e caído gravados; corpo persistido; save antigo (sem `downed` e sem `corpses`) carrega.
func _test_a17_saves() -> void:
	var dead := _main("dw_dead")
	await _root.get_tree().physics_frame
	var body := _die_with_items(dead)
	_check(dead.save_game(R.BED), "preparo: salva morto")
	var file := dead.save_manager.read_file(dead.save_manager.main_path()).data as Dictionary
	_check(file["players"][0]["life"] == WorldSnapshot.LIFE_DEAD_PENDING_CHOICE and (file["world"]["corpses"] as Array).size() == 1
			and _filled(file["players"][0]["state"]["inventory"]["slots"]) == 0,
			"A17: o arquivo guarda morto, escolha pendente, e o corpo com os itens")
	GameSession.continue_requested = true
	var reopened := _main("dw_dead")
	var restored := reopened.corpses.corpse_of(reopened.player.player_id)
	_check(reopened.pending_death_choice and reopened.death_screen.is_open and reopened.player.health.is_dead() and restored != null
			and restored.count("wooden_spear") == 1 and restored.count("berry") == body.count("berry") and reopened.player.inventory.is_empty(),
			"A17: fechar na tela de morte e abrir volta à tela, com o corpo e os itens")
	var down := _main("dw_down")
	down.player.set_physics_process(false)
	down.player.health.take_damage(1000.0)
	down.player.tick(3.0)
	_check(down.save_game(R.BED), "preparo: salva caído")
	var down_file := down.save_manager.read_file(down.save_manager.main_path()).data as Dictionary
	_check(down_file["players"][0]["life"] == WorldSnapshot.LIFE_DOWNED and down_file["players"][0]["state"]["downed"]["is_downed"] == true
			and down_file["players"][0]["state"]["health"]["current"] == 70.0, "save de caído: life \"downed\", vida 70, tempo que falta")
	GameSession.continue_requested = true
	var woke := _main("dw_down")
	woke.player.set_physics_process(false)
	_check(woke.player.downed.is_downed and is_equal_approx(woke.player.downed.left, 7.0) and not woke.pending_death_choice,
			"save de caído: carrega caído, com 7 s para acordar, sem abrir a tela de morte")
	for _i in 8:
		woke.player.tick(1.0)
	_check(not woke.player.downed.is_downed and woke.player.health.current_health == 70.0, "save de caído: o desmaio acaba e ele acorda")
	var pair := _fresh_pair()
	var envelope := WorldSnapshot.capture(pair[0], null, "t", "agora", null, 0, 5)
	(envelope["world"] as Dictionary).erase("corpses")
	(envelope["players"][0]["state"] as Dictionary).erase("downed")
	var fresh := _fresh_pair()
	_check(WorldSnapshot.restore(envelope, fresh[0], fresh[1]) and not (fresh[0] as Player).downed.is_downed,
			"migração: save sem `downed` e sem `corpses` carrega de pé")


# ----------------------------------------------------------------------------- correções da revisão (etapas 5 e 5b)

## Revisão 1: quem mordeu o jogador e o jogador se afastou acalma pelos 8 s (antes, o `restart_episode` a cada 0,5 s o impedia).
func _test_review_raptor_calms_after_biting() -> void:
	var world := _world()
	world["frozen"] = true
	var raptor := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	(world["player"] as Player).global_position = Vector2(0.0, 200.0)  # 12,5 tiles: fora da percepção de 8
	raptor.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	raptor.bit_player_episode = raptor.state_machine.episode_id
	_run(world, 3.0)
	_check(raptor.state_machine.is_aggressive, "revisão: aos 3 s o raptor que mordeu ainda está bravo")
	_run(world, 8.0)
	_check(not raptor.state_machine.is_aggressive, "revisão: o jogador longe, o raptor que o mordeu acalma em cerca de 8 s (%.1f s sobram)"
			% raptor.state_machine.calm_left())


## Revisão 2: o alforje do domado morto leva também as ferramentas, com a durabilidade.
func _test_review_tamed_bag_keeps_tools() -> void:
	var world := _world()
	world["frozen"] = true
	var ground: GroundItemField = world["ground"]
	var authority: WorldAuthority = world["authority"]
	var spot := Vector2(128.0, 128.0)
	var player: Player = world["player"]
	player.global_position = Vector2(128.0, 330.0)
	var hunter := _dino(world, _carnivore_stats(), spot + Vector2(-20.0, 0.0), "c1")
	var pet := _tamed(world, _herbivore_stats("test_herbivore_tamed"), spot)
	pet.inventory.accepts_individual = true
	pet.inventory.add_entry({"id": "wooden_spear", "iid": pet.inventory.issue_iid(), "durab": 17, "durab_max": 80})
	_run(world, 0.6)
	pet.health.current_health = 1.0
	authority.resolve_dino_attack(authority.id_of(hunter), authority.id_of(pet), 8.0)
	var dropped: GroundItem = null
	for item in ground.items():
		if item.item_id == "wooden_spear":
			dropped = item
	_check(dropped != null and int(dropped.entry.get("durab", -1)) == 17, "revisão: a Lança do alforje cai no chão com a durabilidade (17)")
	var again := GroundItemField.new()
	again.clock = (world["authority"] as WorldAuthority).clock.now
	_root.add_child(again)
	_track.call(again)
	again.restore_list(ground.to_list())
	var kept_durab := func(i: GroundItem) -> bool: return int(i.entry.get("durab", -1)) == 17
	_check(again.items().size() == ground.items().size() and again.items().any(kept_durab),
			"revisão: a ferramenta no chão vai ao save com a durabilidade")
	player.global_position = dropped.global_position
	_check(authority.request_pickup(authority.id_of(player), authority.id_of(dropped)) == Enums.ActionResult.OK, "preparo: recolhe")
	var back := false
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		back = back or (slot.get("id", "") == "wooden_spear" and int(slot.get("durab", -1)) == 17)
	_check(back, "revisão: recolhida, a Lança volta com a durabilidade de antes")


## Revisão 5: `bitten` só conta mordida de criatura, nunca dano do jogador.
func _test_review_bitten_only_by_carnivores() -> void:
	var world := _world()
	world["frozen"] = true
	var authority: WorldAuthority = world["authority"]
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 40.0), 4)
	_run(world, 1.0)
	var hunt: Variant = (world["system"] as PredationSystem)._hunts[hunter]
	_check(hunt.prey == prey[0] and not hunt.bitten, "preparo: presa travada, sem mordida")
	prey[0].take_damage(10.0, TamingRules.ATTACKER_PLAYER)
	_run(world, 0.2)
	_check(not hunt.bitten, "revisão: dano do jogador na presa não conta como mordida")
	authority.resolve_dino_attack(authority.id_of(hunter), authority.id_of(prey[0]), 5.0)
	_run(world, 0.2)
	_check(hunt.bitten, "revisão: mordida de criatura conta")


## Revisão 4: `sated_until` do save é limitado a agora + o teto da espécie; "ainda saciado" é comparado com o relógio.
func _test_review_sated_cap() -> void:
	var main := _main("dw_sated")
	var creature := main.wild.creature_at(_wid(main, 0))
	creature.sated_until = 1.0e9
	_check(main.save_game(R.BED), "preparo: salva com saciedade absurda")
	GameSession.continue_requested = true
	var reopened := _main("dw_sated")
	var back := reopened.wild.creature_at(_wid(reopened, 0))
	var ceiling := reopened.authority.clock.now() + (back.stats.predation.sated_max_seconds if back.stats.predation != null else 0.0)
	_check(back != null and back.sated_until <= ceiling,
			"revisão: saciedade de save corrompido limitada ao teto (%.0f <= %.0f)" % [back.sated_until, ceiling])
	var population := WildPopulation.new()
	_track.call(population)
	var clock := TestWorld.TestClock.new()
	clock.time = 100.0
	population.clock = clock.now
	var probe := _spawn_dino()
	probe.sated_until = 50.0
	_check(not population.is_changed(probe), "revisão: saciedade já vencida não conta como mudança")
	probe.sated_until = 150.0
	_check(population.is_changed(probe), "revisão: saciedade em curso conta")


## Revisão 8: duas mordidas no mesmo quadro que levariam o bando abaixo do piso: a segunda é negada.
func _test_review_floor_two_bites_same_frame() -> void:
	var world := _world()
	world["frozen"] = true
	var authority: WorldAuthority = world["authority"]
	var first := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var second := _dino(world, _carnivore_stats(), Vector2(30.0, 0.0), "c2")
	var floor_alive := (world["system"] as PredationSystem).rules.herd_floor_alive
	var herd := _herd(world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 40.0), floor_alive + 1)
	var a := authority.resolve_dino_attack(authority.id_of(first), authority.id_of(herd[0]), 1.0e5)
	var b := authority.resolve_dino_attack(authority.id_of(second), authority.id_of(herd[1]), 1.0e5)
	var alive := 0
	for member in herd:
		alive += 0 if member.health.is_dead() else 1
	_check(a.size() == 1 and b.is_empty() and alive == floor_alive,
			"revisão: a segunda mordida no mesmo quadro não leva o bando abaixo do piso (%d vivos)" % alive)


## Revisões 6 e 7: relação única para quem golpeia criatura, e bônus de bando uma vez por caçador.
func _test_review_pack_once_and_relation() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var twin := _dino(world, _carnivore_stats(), Vector2(500.0, 0.0), "c2")
	var mate := _dino(world, _herbivore_stats(), Vector2(500.0, 100.0), "c1")
	var other := _dino(world, _herbivore_stats(), Vector2(600.0, 100.0), "h9")
	_check(not DinoRelation.may_strike(hunter, twin) and not DinoRelation.may_hit_creature(hunter, mate)
			and DinoRelation.may_hit_creature(hunter, other) and not DinoRelation.may_strike(_tamed_of(world), other),
			"revisão: mesma espécie e mesmo bando nunca; domado segue sem atacar pela relação selvagem")
	var many_world := _world()
	many_world["frozen"] = true
	var hunters: Array[Dino] = []
	for i in 3:
		hunters.append(_dino(many_world, _carnivore_stats(), Vector2(float(i) * 20.0, 0.0), "c%d" % i))
	_herd(many_world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 30.0), 8)
	var system: PredationSystem = many_world["system"]
	_run(many_world, 1.0)
	system.refresh_active()
	var before := system.pack_evaluations
	for hunter_dino in hunters:
		system._hunts[hunter_dino].eval_left = 0.0
	system.tick(0.0001)
	_check(system.pack_evaluations - before <= hunters.size() * 2,
			"revisão: o bônus de bando sai uma vez por caçador (%d para %d caçadores)" % [system.pack_evaluations - before, hunters.size()])


func _tamed_of(world: Dictionary) -> Dino:
	return _tamed(world, _herbivore_stats("test_herbivore_tamed"), Vector2(2000.0, 2000.0))


## Revisão 3: no máximo uma varredura do mundo a cada 50 ms, e uma só por consulta (criatura e entidade juntas).
func _test_review_cursor_throttle() -> void:
	var player := _spawn_player()
	player.set_physics_process(false)
	var authority: WorldAuthority = player.authority
	var controller: PlayerController = _track.call(PlayerController.new())
	controller.player = player
	controller.authority = authority
	var before := authority.pick_queries
	controller.cursor_state(Vector2(30.0, 30.0))
	_check(authority.pick_queries - before == 1, "revisão: uma consulta de cursor faz uma varredura só")
	controller._mouse_in_use = true
	before = authority.pick_queries
	for _i in 10:
		controller.current_cursor()
	_check(authority.pick_queries - before == 1, "revisão: dez leituras do cursor no mesmo instante fazem uma varredura só")
