# SPDX-License-Identifier: MIT
class_name ProgressionTests
extends AuthorityTests
## E6 (PRO-11 e UIX-12): curva de XP, as três fontes (coletar, fabricar, domar), Saber por nível, save e migração, e a HUD
## reagindo aos sinais. A autoridade concede o XP; o componente só guarda.

const RULES: ProgressionRules = preload("res://data/balance/progression_rules.tres")
const FIXTURE_V5 := "res://tests/fixtures/saves/v5.json"


func run() -> void:
	_test_curve()
	_test_saber_rule()
	_test_component_levels()
	_test_save_and_migration()
	await _test_gather_xp()
	await _test_partial_gather_xp()
	_release_worlds()
	_test_craft_hook()
	_test_tame_xp()
	_test_level_up_event_and_log()
	await _test_hud()


func _progress(player: Player = null) -> ProgressionComponent:
	return (player if player != null else _player_at(Vector2.ZERO)).progression


func _test_curve() -> void:
	_check(RULES.xp_to_next(1) == 30 and RULES.xp_to_next(2) == 45 and RULES.xp_to_next(19) == 300,
			"curva: 30 para sair do nível 1, 45 do 2 e 300 do 19 (30 + 15 x (L - 1))")
	_check(RULES.xp_total_to_reach(10) == 810 and RULES.xp_total_to_reach(20) == 3135,
			"curva: 810 XP até o nível 10 e 3.135 até o 20 (GDD 5.1)")
	_check(RULES.xp_to_next(20) == 0 and RULES.xp_to_next(0) == 0 and RULES.xp_to_next(-4) == 0 and RULES.xp_to_next(99) == 0,
			"curva: no teto e em nível inválido não falta XP")
	_check(RULES.xp_per_gather == 1 and RULES.xp_per_craft == 2 and RULES.tame_xp(10) == 45
			and RULES.tame_xp(1) == 18 and RULES.tame_xp(-5) == 15,
			"fontes em dado: coletar 1, fabricar 2, domar 15 + 3 x nível final")


func _test_saber_rule() -> void:
	_check(RULES.saber_at(1) == 0 and RULES.saber_at(2) == 1 and RULES.saber_at(4) == 1 and RULES.saber_at(6) == 1,
			"Saber: nível 1 não rende, os comuns rendem 1")
	for special in [3, 5, 10, 15, 20]:
		_check(RULES.saber_at(special) == 2, "Saber: o nível %d rende 2 (1 + 1 extra)" % special)
	_check(RULES.saber_at(21) == 0 and RULES.saber_until(1) == 0 and RULES.saber_until(4) == 4 and RULES.saber_until(5) == 6
			and RULES.saber_until(6) == 7 and RULES.saber_until(20) == 24 and RULES.saber_until(99) == 24,
			"Saber acumulado: 4 no nível 4, 7 no 6 e 24 no teto (+1 extra no 3, 5, 10, 15 e 20)")


func _test_component_levels() -> void:
	var comp := _progress()
	var levels: Array[Array] = []
	comp.leveled_up.connect(func(level: int, saber: int) -> void: levels.append([level, saber]))
	_check(comp.level == 1 and comp.xp == 0 and comp.saber_free() == 0 and comp.xp_needed() == 30, "começa no nível 1, sem XP e sem Saber")
	_check(comp.grant_xp(29) == 0 and comp.xp == 29 and levels.is_empty(), "29 de 30 XP: ainda não sobe")
	_check(comp.grant_xp(1) == 1 and comp.level == 2 and comp.xp == 0 and levels == [[2, 1]] and comp.saber_free() == 1,
			"30 XP: sobe para 2, +1 Saber")
	levels.clear()
	_check(comp.grant_xp(45 + 60 + 75 + 20) == 3 and comp.level == 5 and comp.xp == 20 and levels == [[5, 5]],
			"uma concessão cruza 3 níveis: UM sinal, nível 5, Saber somado (2 + 1 + 2 = 5)")
	_check(comp.saber_free() == 6 and comp.learn("nao_existe") == "unknown_recipe" and comp.learn("axe_stone") == "recipe_not_learnable"
			and comp.saber_free() == 6, "receita inexistente ou conhecida de início recusa e nada muda")
	_check(_progress().learn("workbench") == "no_saber", "sem Saber livre a receita recusa")
	_check(comp.learn("workbench") == "" and comp.learn("bed") == "" and comp.saber_free() == 4 and comp.saber_spent == 2,
			"aprender 2 receitas de 1 Saber, com 6, deixa 4 livres")
	_check(comp.grant_xp(0) == 0 and comp.grant_xp(-9) == 0 and comp.level == 5, "XP zero ou negativo não faz nada")
	comp.grant_xp(RULES.xp_total_to_reach(20))
	_check(comp.level == 20 and comp.is_max_level() and comp.xp == 0 and comp.saber_total() == 24, "chega ao teto 20 com 24 Saber no total")
	levels.clear()
	_check(comp.grant_xp(500) == 0 and comp.xp == 0 and comp.level == 20 and levels.is_empty(), "no teto o XP não acumula nem avisa")
	_check(comp.grant_xp(2000000000) == 0, "valor absurdo no teto é ignorado")
	var big := _progress()
	big.grant_xp(2000000000)
	_check(big.level == 20 and big.xp == 0, "valor absurdo chega ao teto e para (sem laço infinito)")


func _test_save_and_migration() -> void:
	var player := _player_at(Vector2.ZERO)
	var comp := player.progression
	comp.grant_xp(30 + 45 + 60 + 75 + 20)
	comp.learn("workbench")
	comp.learn("bed")
	var wire := JSON.stringify(player.to_dict())
	var json := JSON.new()
	_check(json.parse(wire) == OK, "o jogador com nível vira JSON")
	var fresh := _player_at(Vector2.ZERO)
	var heard: Array[int] = []
	fresh.progression.leveled_up.connect(func(level: int, _s: int) -> void: heard.append(level))
	_check(fresh.from_dict(json.data) and fresh.progression.level == 5 and fresh.progression.xp == 20 and fresh.progression.saber_spent == 2
			and fresh.progression.saber_free() == 4, "save e load: nível 5, XP 20 e Saber 4 livres voltam")
	_check(heard.is_empty(), "carregar não dispara `leveled_up`")
	var again := JSON.stringify(fresh.to_dict())
	_check(again == wire, "roundtrip idêntico")
	# Migração: save de antes da E6 (sem o bloco) carrega no nível 1.
	var old := player.to_dict()
	old.erase("progression")
	var legacy := _player_at(Vector2.ZERO)
	_check(legacy.from_dict(old) and legacy.progression.level == 1 and legacy.progression.xp == 0 and legacy.progression.saber_free() == 0,
			"migração: save sem `progression` carrega no nível 1, sem XP e sem Saber")
	var fixture := JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V5)) as Dictionary
	var fixture_player := _player_at(Vector2.ZERO)
	_check(fixture_player.from_dict((fixture["players"] as Array)[0]["state"]) and fixture_player.progression.level == 1,
			"fixture v5 (anterior à E6) carrega no nível 1")
	# Dado não confiável: limita ou ignora, nunca aborta.
	var hostile := _player_at(Vector2.ZERO)
	var base := player.to_dict()
	var cases := {
		"bloco em texto": "lixo",
		"nível acima do teto": {"level": 99, "xp": 5, "saber_spent": 3},
		"nível negativo e NaN": {"level": -4, "xp": NAN, "saber_spent": INF},
		"tipos errados": {"level": "dez", "xp": [], "saber_spent": {}},
		"XP gigante e Saber gasto gigante": {"level": 3, "xp": 1.0e30, "saber_spent": 1.0e30},
	}
	for label: String in cases:
		var data := base.duplicate(true)
		data["progression"] = cases[label]
		var applied := hostile.from_dict(data)
		var p := hostile.progression
		_check(applied and p.level >= 1 and p.level <= RULES.level_max and p.xp >= 0 and p.xp < maxi(p.xp_needed(), 1)
				and p.saber_spent >= 0 and p.saber_spent <= p.saber_total() and p.saber_free() >= 0, "dado hostil (%s): limitado, sem abortar" % label)
	var capped := _player_at(Vector2.ZERO)
	var over := base.duplicate(true)
	over["progression"] = {"level": 99, "xp": 5, "recipes": ["workbench", "bed", "ration_c"]}
	capped.from_dict(over)
	_check(capped.progression.level == 20 and capped.progression.xp == 0 and capped.progression.saber_spent == 3,
			"nível salvo acima do teto vira o teto, sem XP")
	# O mundo inteiro: envelope do WorldSnapshot passa por JSON.
	var envelope := WorldSnapshot.capture(player, null, "t", "agora", null, 0, 5)
	var back := JSON.parse_string(JSON.stringify(envelope)) as Dictionary
	var restored := _player_at(Vector2.ZERO)
	_check(WorldSnapshot.restore(back, restored, _dino_at(Vector2.ZERO)) and restored.progression.level == 5
			and restored.progression.saber_spent == 2,
			"o envelope do mundo leva o nível e o Saber")


func _gather_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = "progression_gather"
	main.menu_scene = ""
	_root.add_child(main)
	_track.call(main)
	main.scheduler.frozen = true
	main.wild.process_mode = Node.PROCESS_MODE_DISABLED
	main.zone.set_physics_process(false)
	main.predation.set_physics_process(false)
	return main


func _stand(main: Main, node: ResourceNode) -> void:
	main.player.position = node.position + Vector2(0, 10)
	main.player.facing = Vector2.UP
	main.player.tick(60.0)


func _test_gather_xp() -> void:
	var main := _gather_main()
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var bush: ResourceNode = null
	for candidate in main.resources.nodes():
		if candidate.def.id == "bush_baga":
			bush = candidate
			break
	var tree := main.resources.node_by_id("n316")
	_stand(main, bush)
	_check(authority.request_gather(1, authority.id_of(bush)) == RESULT.OK and player.progression.xp == 1,
			"coleta concluída (arbusto) rende 1 XP")
	_stand(main, tree)
	_check(authority.request_gather(1, authority.id_of(tree)) == RESULT.OK and tree.component.has_damage() and player.progression.xp == 1,
			"golpe intermediário na árvore não rende XP")
	for hit in 4:
		_stand(main, tree)
		authority.request_gather(1, authority.id_of(tree))
	_stand(main, tree)
	_check(authority.request_gather(1, authority.id_of(tree)) == RESULT.COOLDOWN and tree.is_available() and player.progression.xp == 1,
			"o golpe que derrubaria, barrado pelo intervalo, não rende XP")
	authority.clock.advance(2.1)
	_stand(main, tree)
	_check(authority.request_gather(1, authority.id_of(tree)) == RESULT.OK and not tree.is_available() and player.progression.xp == 2,
			"o golpe que derruba a árvore conclui a coleta: +1 (total 2)")
	var before := player.progression.xp
	authority.clock.advance(2.1)
	_stand(main, bush)
	_check(not bush.is_available() and authority.request_gather(1, authority.id_of(bush)) != RESULT.OK and player.progression.xp == before,
			"coleta recusada (nó já colhido) não rende XP")


## Coleta parcial (inventário com lugar para 1 baga, arbusto com 3): cada toque entrega 1 e NÃO rende XP; o XP vem só quando o
## arbusto esgota (uma vez).
func _test_partial_gather_xp() -> void:
	var main := _gather_main()
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var bush: ResourceNode = null
	for candidate in main.resources.nodes():
		if candidate.def.id == "bush_baga":
			bush = candidate
			break
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.inventory.capacity = 2  # a fibra extra do arbusto cabe no 2o slot
	player.inventory.add(Items.BERRY, 19)  # sobra lugar para 1 baga
	var xp_before := player.progression.xp
	var touches := 0
	while bush.is_available() and touches < 6:
		_stand(main, bush)
		authority.clock.advance(2.1)
		authority.request_gather(1, authority.id_of(bush))
		touches += 1
		if bush.is_available():
			_check(player.progression.xp == xp_before, "toque parcial %d no arbusto não rende XP" % touches)
			player.inventory.remove(Items.BERRY, 1)  # abre lugar para mais 1 baga
	_check(not bush.is_available() and touches > 1 and player.progression.xp == xp_before + 1,
			"o arbusto esgotou em %d toques e rendeu 1 XP no total" % touches)


func _test_craft_hook() -> void:
	var player := _player_at(Vector2.ZERO)
	var authority := TestWorld.arm(player, [], _track)
	authority.grant_craft_xp(authority.id_of(player))
	_check(player.progression.xp == 2, "gancho de fabricar rende 2 XP (a E7a o chama)")
	authority.grant_craft_xp(9999)
	_check(player.progression.xp == 2, "fabricar por ator desconhecido não rende")


func _test_tame_xp() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var asleep: Dino = world["asleep"]
	var berry_slot := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("id", "") == Items.BERRY:
			berry_slot = i
	authority.request_transfer_slot(1, 1, berry_slot, authority.id_of(asleep))
	_check(player.progression.xp == 0, "dar comida não rende XP, só concluir a doma")
	asleep.taming.tick(100.0)
	var expected := RULES.tame_xp(asleep.level)
	_check(asleep.state_machine.is_tamed and asleep.owner_player_id == "local" and _total_xp(player) == expected,
			"domar rende 15 + 3 x nível final (%d) ao dono" % expected)
	# Outro alimentador: o XP é de quem domou, não do jogador local.
	var other := _sleeping(_dino_at(Vector2(300, 300)))
	authority.register(other)
	var before := _total_xp(player)
	other.feeder_player_id = "outro"
	other.taming.level_finalized.emit(7)
	_check(_total_xp(player) == before, "doma de outro dono não rende ao jogador local")
	# Dois jogadores, pelo caminho real: o primeiro a dar a comida ideal RESERVA a doma e fica dono; o segundo só ajuda.
	var second := _player_at(Vector2(300, 330))
	second.player_id = "outro"
	authority.register(second)
	var pet := _sleeping(_dino_at(Vector2(300, 340)))
	authority.register(pet)
	player.position = Vector2(310, 340)
	var pet_id := authority.id_of(pet)
	player.inventory.add(Items.BERRY, 5)
	authority.request_transfer_slot(1, 1, _berry_slot(player), pet_id)  # o jogador local reserva a doma
	authority.request_transfer_slot(authority.id_of(second), authority.id_of(second), _berry_slot(second), pet_id)
	var mine := _total_xp(player)
	var theirs := _total_xp(second)
	pet.taming.tick(1000.0)  # termina a doma (a última comida foi do segundo jogador)
	_check(pet.state_machine.is_tamed and pet.owner_player_id == player.player_id and pet.feeder_player_id == player.player_id,
			"o primeiro a alimentar reservou a doma e virou dono")
	_check(_total_xp(player) == mine + RULES.tame_xp(pet.level) and _total_xp(second) == theirs,
			"dois jogadores: o dono da reserva ganha o XP; quem deu a última comida não")
	# Dono e alimentador diferentes (outro deu a última comida): o XP segue o DONO, nunca o alimentador.
	var split := _sleeping(_dino_at(Vector2(380, 340)))
	authority.register(split)
	split.owner_player_id = player.player_id
	split.feeder_player_id = second.player_id
	var owner_before := _total_xp(player)
	var feeder_before := _total_xp(second)
	authority._grant_tame_xp(split, 9)
	_check(_total_xp(player) == owner_before + RULES.tame_xp(9) and _total_xp(second) == feeder_before,
			"dono diferente de quem alimentou: o XP vai ao dono, não ao alimentador")
	var orphan := _sleeping(_dino_at(Vector2(340, 340)))
	authority.register(orphan)
	orphan.owner_player_id = ""
	orphan.feeder_player_id = "outro"
	var theirs_before := _total_xp(second)
	orphan.taming.level_finalized.emit(7)
	_check(_total_xp(second) == theirs_before + RULES.tame_xp(7), "sem dono, o XP vai a quem alimentou")


func _test_level_up_event_and_log() -> void:
	var player := _player_at(Vector2.ZERO)
	var authority := TestWorld.arm(player, [], _track)
	var events: Array[Array] = []
	authority.owner_event.connect(func(pid: String, code: String, params: Dictionary) -> void: events.append([pid, code, params]))
	player.progression.grant_xp(30)
	_check(events.size() == 1 and events[0][0] == player.player_id and events[0][1] == "player_level_up"
			and events[0][2] == {"level": 2, "saber": 1}, "subir de nível avisa só o jogador com o código `player_level_up`")
	_check(GameMessages.text_of("player_level_up", {"level": 2, "saber": 1}) == "Nível 2: +1 Saber"
			and GameMessages.kind_of("player_level_up") == GameMessages.Kind.SUCCESS, "o código tem texto e tipo no log")
	events.clear()
	player.progression.grant_xp(5)
	_check(events.is_empty(), "XP sem subir de nível não avisa")
	var log := MessageLog.new()
	log.push_event("player_level_up", {"level": 7, "saber": 2})
	_check(log.history().size() == 1 and str(log.history()[0]["text"]) == "Nível 7: +2 Saber", "o log guarda a linha do nível")


func _test_hud() -> void:
	var player := _player_at(Vector2.ZERO)
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.xp_label().text == "Nv 1" and not hud.saber_badge().visible and not hud.notice_label().visible,
			"HUD nasce em Nv 1, sem selo e sem aviso")
	player.progression.grant_xp(15)
	_check(hud.xp_bar().value() == 15.0 and hud.xp_bar().max_value() == 30.0, "a barra acompanha o XP: 15 de 30")
	player.progression.grant_xp(15)
	_check(hud.xp_label().text == "Nv 2" and hud.saber_badge().visible and hud.saber_badge().text == "Saber 1",
			"subir de nível: rótulo Nv 2 e selo de Saber")
	_check(hud.notice_label().visible and hud.notice_label().text == "Nível 2: +1 Saber", "subir de nível: aviso com o texto do log")
	_check(RULES.notice_seconds == 3.0, "o aviso dura 3 s (dado)")
	player.progression.learn("workbench")
	_check(not hud.saber_badge().visible, "o selo some quando o Saber acaba")
	# O aviso some em 3 s.
	await _root.get_tree().create_timer(2.5).timeout
	var still := hud.notice_label().visible
	await _root.get_tree().create_timer(1.0).timeout
	_check(still and not hud.notice_label().visible, "o aviso continua aos 2,5 s e some aos 3,5 s")
	# Save carregado: a HUD acompanha e não avisa.
	var saved := _player_at(Vector2.ZERO)
	saved.progression.grant_xp(30 + 45 + 60 + 75 + 20)
	hud.notice_label().visible = false
	var data := saved.to_dict()
	player.from_dict(data)
	_check(hud.xp_label().text == "Nv 5" and hud.saber_badge().visible and hud.saber_badge().text == "Saber 6"
			and not hud.notice_label().visible,
			"carregar o save: Nv 5 e Saber 6 na HUD, sem aviso")
	player.progression.grant_xp(RULES.xp_total_to_reach(20))
	_check(hud.xp_label().text == "Nv 20" and hud.xp_bar().value() == hud.xp_bar().max_value(), "no teto a HUD mostra Nv 20 com a barra cheia")


## XP total ganho (todos os níveis), para comparar a doma sem depender de onde a barra parou.
func _berry_slot(player: Player) -> int:
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("id", "") == Items.BERRY:
			return i
	return -1


func _total_xp(player: Player) -> int:
	return RULES.xp_total_to_reach(player.progression.level) + player.progression.xp
