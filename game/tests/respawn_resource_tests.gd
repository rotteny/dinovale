# SPDX-License-Identifier: MIT
class_name RespawnResourceTests
extends SaveTests
## SOB-01 (morte e respawn mínimos), a troca do revive provisório do save e MUN-02 (nós de recurso).
## Reaproveita `_main` e os auxiliares de `SaveTests`; todo save vai para `SaveTests.ROOT`.

const FIXTURE_V2 := "res://tests/fixtures/saves/v2.json"
const RULES: RespawnRules = preload("res://data/balance/respawn_rules.tres")
const TREE: ResourceNodeDef = preload("res://data/resources/tree.tres")
const BERRY_BUSH: ResourceNodeDef = preload("res://data/resources/berry_bush.tres")


func run() -> void:
	_test_rng_and_picker()
	_test_health_protection_and_revive()
	_test_life_dead_with_health()
	_test_dead_load_drops_protection()
	_test_node_component()
	_test_node_defs()
	await _test_death_and_respawn_flow()
	await _test_respawn_points_are_free()
	await _test_dead_save_is_not_undone()
	await _test_respawn_survives_save()
	await _test_gather_rules()
	await _test_nodes_in_save()
	_test_fixture_v2()
	await _test_death_screen_lists_data()
	await _test_targeting()
	await _test_inventory_and_death()
	await _test_respawn_save_timing()
	await _test_regions_and_points()
	await _test_death_screen_keyboard()
	await _test_two_deaths_reset_delay()


# ----------------------------------------------------------------------------- lógica pura

func _test_rng_and_picker() -> void:
	var a := SeededRng.new()
	var b := SeededRng.new()
	a.seed_from(["w", 1])
	b.seed_from(["w", 1])
	var same := true
	for i in 20:
		same = same and a.next_below(100) == b.next_below(100)
	b.seed_from(["w", 2])
	a.seed_from(["w", 1])
	var differs := false
	for i in 20:
		differs = differs or a.next_below(100) != b.next_below(100)
	_check(same and differs and a.next_below(1) == 0 and a.next_below(0) == 0, "SeededRng: mesma seed, mesma sequência; seed outra, outra")
	var region := RULES.region_by_id("campina")
	var rng := SeededRng.new()
	rng.seed_from(["picker"])
	var inside := true
	var distinct := {}
	for i in 100:
		var result := RespawnPicker.pick(region, RULES, rng, Callable(), [])
		var point: Vector2 = result["position"]
		inside = inside and region.area.has_point(point) and not result["fallback"]
		distinct[point] = true
	_check(inside and distinct.size() > 20, "o sorteio fica dentro da região e varia")
	var none := RespawnPicker.pick(region, RULES, rng, func(_p: Vector2) -> bool: return false, [])
	_check(none["fallback"] and none["position"] == region.fallback_point, "30 sorteios recusados: ponto reserva")
	var calls := [0]
	RespawnPicker.pick(region, RULES, rng, func(_p: Vector2) -> bool:
		calls[0] += 1
		return false, [])
	_check(calls[0] == RULES.max_attempts, "no máximo max_attempts sorteios (%d)" % calls[0])
	var wild: Array[Vector2] = [Vector2(320, 180)]
	var far := true
	for i in 100:
		var point: Vector2 = RespawnPicker.pick(region, RULES, rng, Callable(), wild)["position"]
		far = far and point.distance_to(wild[0]) >= RULES.min_distance_from_wild
	_check(far, "ponto sorteado respeita a distância mínima de selvagem")
	var empty := RespawnRegion.new()
	empty.fallback_point = Vector2(5, 5)
	_check(RespawnPicker.pick(empty, RULES, rng, Callable(), [])["fallback"], "região sem área: ponto reserva")


func _test_health_protection_and_revive() -> void:
	var health: HealthComponent = _track.call(HealthComponent.new())
	health.grant_protection(3.0)
	health.take_damage(50.0)
	_check(health.current_health == 100.0, "proteção: dano ignorado")
	health.tick(3.0)
	health.take_damage(50.0)
	_check(health.current_health == 50.0 and not health.is_protected(), "proteção acaba com o tempo")
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.take_damage(500.0)
	health.revive(1.0)
	_check(not health.is_dead() and health.current_health == 100.0 and deaths[0] == 1, "revive: vida cheia, sem novo died")
	health.revive(1.0)
	var dino := _spawn_dino()
	dino.health.from_dict({"current": 10.0, "protection": 50.0})
	dino.health.take_damage(500.0)
	_check(dino.health.is_dead() and dino.health.protection_left == 0.0, "proteção de save não torna dino imortal (só o jogador a restaura)")
	var player := _spawn_player()
	player.health.grant_protection(2.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var restored := _spawn_player()
	restored.from_dict(saved)
	_check(is_equal_approx(restored.health.protection_left, 2.0), "a proteção do jogador vai no save")
	saved["protection"] = 1.0e30
	restored.from_dict(saved)
	_check(restored.health.protection_left == HealthComponent.MAX_PROTECTION, "proteção de save é limitada")
	saved.erase("protection")
	restored.from_dict(saved)
	_check(restored.health.protection_left == 0.0, "sem campo: sem proteção")


func _test_life_dead_with_health() -> void:
	var pair := _fresh_pair()
	var data := SaveManager.make_envelope({}, [{"player_id": "local", "entity_id": 1, "life": WorldSnapshot.LIFE_DEAD_PENDING_CHOICE,
			"state": {"health": {"current": 50.0}}}], [], "0.1.0", "x")
	_check(WorldSnapshot.restore(data, pair[0], pair[1]) and (pair[0] as Player).health.is_dead(),
			"life morto com vida > 0 no estado: carrega morto")


func _test_dead_load_drops_protection() -> void:
	var pair := _fresh_pair()
	var data := SaveManager.make_envelope({}, [{"player_id": "local", "entity_id": 1, "life": WorldSnapshot.LIFE_DEAD_PENDING_CHOICE,
			"state": {"health": {"current": 0.0}, "protection": 60.0}}], [], "0.1.0", "x")
	_check(WorldSnapshot.restore(data, pair[0], pair[1]) and (pair[0] as Player).health.protection_left == 0.0,
			"carregar morto zera a proteção salva")


func _test_node_component() -> void:
	var node: ResourceNodeComponent = _track.call(ResourceNodeComponent.new())
	_check(not node.is_available() and node.harvest() == 0, "sem def: nada a colher")
	node.def = TREE
	_check(node.is_available() and node.harvest() == TREE.yield_amount and not node.is_available(), "colher entrega e esgota")
	_check(node.harvest() == 0, "esgotado não entrega de novo")
	var returned := [0]
	node.changed.connect(func() -> void: returned[0] += 1)
	node.tick(TREE.respawn_seconds - 1.0)
	_check(not node.is_available() and returned[0] == 0, "antes do tempo continua esgotado")
	node.tick(1.0)
	_check(node.is_available() and returned[0] == 1, "no tempo, volta cheio")
	node.harvest()
	node.tick(100.0)
	var copy: ResourceNodeComponent = _track.call(ResourceNodeComponent.new())
	copy.def = TREE
	copy.from_dict(JSON.parse_string(JSON.stringify(node.to_dict())))
	_check(not copy.is_available() and is_equal_approx(copy.respawn_left, TREE.respawn_seconds - 100.0),
			"estado esgotado e tempo restante vão no save")
	copy.from_dict({"def": "rock", "depleted": false})
	_check(not copy.is_available(), "dado de outro tipo de nó é ignorado")
	copy.from_dict({"def": "tree", "depleted": true, "respawn_left": 1.0e30})
	_check(copy.respawn_left == TREE.respawn_seconds, "tempo de save é limitado")


func _test_node_defs() -> void:
	var items := {}
	for path in ["tree", "rock", "berry_bush", "fiber_plant"]:
		var def: ResourceNodeDef = load("res://data/resources/%s.tres" % path)
		_check(def.id == path and Items.has(def.item_id) and def.yield_amount > 0 and def.respawn_seconds > 0.0, "def %s completa" % path)
		items[def.item_id] = true
	_check(items.has("wood") and items.has("stone") and items.has("berry") and items.has("fiber"), "árvore, pedra, baga e fibra")
	_check(BERRY_BUSH.respawn_seconds == 240.0 and BERRY_BUSH.yield_amount == 3, "arbusto de baga: 3 por coleta, volta em 4 min (GDD)")


# ----------------------------------------------------------------------------- morte e respawn

func _test_death_and_respawn_flow() -> void:
	var tree := _root.get_tree()
	var main := _main("death_flow")
	await tree.physics_frame
	main.player.inventory.add(Items.WOOD, 5)
	var berries := main.player.inventory.count(Items.BERRY)
	main.player.hunger.set_ratio(0.2)
	main.player.health.take_damage(10000.0)
	_check(main.pending_death_choice and main.death_screen.is_open and main.player.health.is_dead(), "vida 0 abre a tela de morte")
	_check(main.death_screen.column().selected_id() == "campina", "Campina vem pré-selecionada")
	_check(main.request_respawn("nao_existe") == "unknown_region" and main.player.health.is_dead(), "região desconhecida é recusada")
	_check(main.player.respawn_at(Vector2.ZERO, RULES) and main.player.health.is_dead() == false, "respawn_at renasce quem morreu")
	main.player.health.take_damage(1000.0)  # protegido: ignorado
	_check(not main.player.health.is_dead(), "respawn_at direto também protege")
	main.player.health.protection_left = 0.0
	main.player.health.take_damage(10000.0)
	_check(main.player.health.is_dead(), "morreu de novo")
	_check(main.request_respawn("campina") == "", "respawn na Campina")
	var player := main.player
	_check(not main.pending_death_choice and not main.death_screen.is_open and not player.health.is_dead(), "escolhido: tela fecha, vivo")
	_check(player.health.current_health == player.health.max_health, "vida 100%")
	_check(is_equal_approx(player.hunger.current_hunger, player.hunger.max_hunger * 0.5), "fome 50%")
	_check(is_equal_approx(player.health.protection_left, RULES.protection_seconds), "proteção de 3 s")
	_check(RULES.region_by_id("campina").area.has_point(player.position), "renasceu dentro da região")
	player.health.take_damage(50.0)
	_check(player.health.current_health == player.health.max_health, "dano durante a proteção é ignorado")
	player.tick(RULES.protection_seconds + 0.1)
	player.health.take_damage(50.0)
	_check(player.health.current_health == player.health.max_health - 50.0, "depois dos 3 s o dano volta")
	_check(player.inventory.count(Items.WOOD) == 5 and player.inventory.count(Items.BERRY) == berries,
			"M1: o inventário fica com o jogador (o corpo com itens é SOB-02, M2)")
	_check(main.request_respawn("campina") == "not_dead", "vivo não renasce de novo")


func _test_respawn_points_are_free() -> void:
	var tree := _root.get_tree()
	var main := _main("free_points", 20, true)
	await tree.physics_frame
	await tree.physics_frame
	_check(not main._is_free_point(Vector2(424, 92)), "parede da casa não é ponto livre")
	_check(not main._is_free_point(main.resources.node_by_id("berry_1").global_position), "em cima de nó de recurso não é ponto livre")
	_check(main._is_free_point(RULES.region_by_id("campina").fallback_point), "o ponto reserva da Campina é livre")
	var all_free := true
	var far := true
	for i in 60:
		main._respawn_count = i
		main.player.health.protection_left = 0.0
		main.player.health.take_damage(10000.0)
		_check(main.request_respawn("campina") == "", "respawn %d" % i)
		var point := main.player.position
		all_free = all_free and main._is_free_point(point)
		far = far and point.distance_to(main.dino.global_position) >= RULES.min_distance_from_wild
	_check(all_free and far, "60 respawns: sempre livre e longe do selvagem")


func _test_dead_save_is_not_undone() -> void:
	var tree := _root.get_tree()
	var main := _main("dead_roundtrip")
	main.player.health.take_damage(10000.0)
	await tree.process_frame
	var dead_file := _read_raw(main.save_manager.main_path())
	_check(main.scheduler.saves_done == 1 and dead_file.contains("dead_pending_choice"), "a morte salva o estado de morto")
	main.save_game(R.EXIT_MENU)  # o caminho de "Voltar ao menu"
	dead_file = _read_raw(main.save_manager.main_path())
	# Continuar várias vezes sem escolher: segue morto, e carregar nunca regrava o arquivo.
	for i in 3:
		GameSession.continue_requested = true
		var again := _main("dead_roundtrip", 20, true)
		await tree.process_frame
		_check(again.pending_death_choice and again.player.health.is_dead() and again.death_screen.is_open,
				"Continuar %d: continua morto, com a tela de morte aberta" % (i + 1))
		_check(again.player.inventory.count(Items.BERRY) == 10, "inventário do morto intacto")
		_check(_read_raw(again.save_manager.main_path()) == dead_file, "carregar não mexe no arquivo")
	# A escolha tira do estado de morto, e só ela.
	GameSession.continue_requested = true
	var chooser := _main("dead_roundtrip", 20, true)
	_check(chooser.request_respawn("campina") == "" and not chooser.player.health.is_dead(), "a escolha renasce")
	chooser.save_game(R.EXIT_MENU)
	GameSession.continue_requested = true
	var alive := _main("dead_roundtrip", 20, true)
	_check(not alive.pending_death_choice and not alive.player.health.is_dead() and not alive.death_screen.is_open,
			"depois da escolha e do save, Continuar abre vivo")


func _test_respawn_survives_save() -> void:
	var tree := _root.get_tree()
	var main := _main("respawn_save")
	main.player.health.take_damage(10000.0)
	main.request_respawn("campina")
	var position := main.player.position
	main.save_game(R.EXIT_MENU)
	var file_text := _read_raw(main.save_manager.main_path())
	_check(file_text.contains('"life": "alive"') or file_text.contains('"life":"alive"'), "depois da escolha o save é de vivo")
	GameSession.continue_requested = true
	var again := _main("respawn_save", 20, true)
	await tree.process_frame
	_check(not again.pending_death_choice and not again.death_screen.is_open and not again.player.health.is_dead(),
			"Continuar: vivo, sem tela")
	_check(again.player.position == position and is_equal_approx(again.player.health.protection_left, RULES.protection_seconds),
			"posição e proteção restauradas")
	_check(again._respawn_count == 1 and again.scheduler.respawn_count == 1, "o contador de respawns vai no save")


# ----------------------------------------------------------------------------- nós de recurso

func _test_gather_rules() -> void:
	var tree := _root.get_tree()
	var main := _main("gather")
	await tree.physics_frame
	var player := main.player
	var bush := main.resources.node_by_id("berry_1")
	var wood := main.resources.node_by_id("tree_1")
	_check(player.request_gather() == Player.GATHER_NO_TARGET, "sem alvo: recusa")
	player.target = bush.interactable
	_check(player.request_gather() == Player.GATHER_TOO_FAR and bush.is_available(), "longe do nó: recusa e o nó não gasta")
	player.position = bush.position + Vector2(0, 10)
	var before := player.inventory.count(Items.BERRY)
	var notices: Array[String] = []
	player.gathered.connect(func(item_id: String, amount: int) -> void: notices.append("%s%d" % [item_id, amount]))
	_check(player.try_interact(), "colher é interagir com o alvo")
	_check(player.inventory.count(Items.BERRY) == before + 3 and not bush.is_available() and notices == ["berry3"],
			"colheu 3 bagas e esgotou o nó")
	_check(main.hud.notice_label().text.contains("+3 Baga"), "a HUD avisa o ganho")
	_check(not bush.interactable.can_interact() and not player.try_interact(), "esgotado não é interagível")
	_check(player.request_gather() == Player.COOLDOWN, "ação de colher tem tempo (recarga)")
	player.tick(BERRY_BUSH.gather_seconds)
	player.target = bush.interactable  # o tick reavalia o alvo pelo detector (vazio no teste)
	_check(player.request_gather() == Player.GATHER_DEPLETED, "nó esgotado: recusa")
	# Espaço: sem espaço o nó NÃO é gasto.
	player.position = wood.position + Vector2(0, 10)
	player.target = wood.interactable
	var guard := 0
	while player.inventory.room_for(Items.WOOD) >= TREE.yield_amount and guard < 1000:
		player.inventory.add(Items.STONE, 1)
		guard += 1
	var room := player.inventory.room_for(Items.WOOD)
	_check(room < TREE.yield_amount, "preparo: inventário sem espaço para 3 madeiras (sobra %d)" % room)
	var wood_before := player.inventory.count(Items.WOOD)
	_check(player.request_gather() == Player.GATHER_FULL and wood.is_available() and player.inventory.count(Items.WOOD) == wood_before,
			"inventário cheio: recusa e o nó não gasta")
	_check(main.hud.notice_label().text.contains("cheio"), "a HUD avisa inventário cheio")
	# Parcial: cabe 1 de 3. Não gasta o nó e não perde o excedente.
	player.inventory.remove(Items.STONE, player.inventory.count(Items.STONE))
	player.inventory.remove(Items.STONE, player.inventory.count(Items.STONE))
	player.inventory.add(Items.WOOD, 19)
	while player.inventory.room_for(Items.STONE) > 0:
		player.inventory.add(Items.STONE, 1)
	_check(player.inventory.room_for(Items.WOOD) == 1, "preparo: cabe exatamente 1 madeira")
	var partial_before := player.inventory.count(Items.WOOD)
	_check(player.request_gather() == Player.GATHER_FULL and wood.is_available() and player.inventory.count(Items.WOOD) == partial_before,
			"espaço parcial (1 de 3): recusa, o nó não gasta e nada se perde")
	# Morto não colhe.
	player.inventory.remove(Items.WOOD, player.inventory.count(Items.WOOD))
	player.health.take_damage(10000.0)
	_check(player.request_gather() == Player.GATHER_BLOCKED and wood.is_available(), "morto não colhe")
	# Respawn do nó pelo relógio do jogo.
	bush.component.tick(BERRY_BUSH.respawn_seconds)
	_check(bush.is_available() and bush.interactable.can_interact(), "o nó volta no tempo e fica interagível")


func _test_nodes_in_save() -> void:
	var tree := _root.get_tree()
	var main := _main("nodes_save")
	await tree.physics_frame
	var bush := main.resources.node_by_id("berry_2")
	main.player.position = bush.position + Vector2(0, 10)
	main.player.target = bush.interactable
	main.player.request_gather()
	bush.component.tick(60.0)
	main.save_game()
	GameSession.continue_requested = true
	var again := _main("nodes_save", 20, true)
	var restored := again.resources.node_by_id("berry_2")
	_check(not restored.is_available() and is_equal_approx(restored.component.respawn_left, BERRY_BUSH.respawn_seconds - 60.0),
			"nó colhido continua esgotado depois de salvar e continuar, com o tempo restante")
	_check(again.resources.node_by_id("berry_1").is_available(), "os outros nós seguem cheios")
	again.resources.restore_list([5, "x", {"id": 7}, {"id": "tree_1", "def": "tree", "depleted": true, "respawn_left": 9.0}])
	_check(not again.resources.node_by_id("tree_1").is_available(), "lista com lixo não aborta e aplica o que serve")
	var junk: Array = []
	for i in 15:
		junk.append(i)
	junk.append({"id": "tree_2", "def": "tree", "depleted": true, "respawn_left": 9.0})
	again.resources.restore_list(junk)
	_check(not again.resources.node_by_id("tree_2").is_available(), "lixo no início da lista não esconde um nó válido")
	var ids: Array = []
	for entry: Dictionary in again.resources.to_list():
		ids.append(entry["id"])
	_check(ids.size() == 11 and ids[0] == "berry_1", "to_list leva todos os nós em ordem de id")


func _test_fixture_v2() -> void:
	var manager := SaveManager.new(ROOT)
	var outcome := manager.read_file(FIXTURE_V2)
	_check(outcome.status == SaveManager.Status.OK and outcome.data.get("format_version") == 2, "fixture v2 carrega")
	var main := _main("fixture_v2", 20, true)
	var pair := [main.player, main.dino]
	_check(WorldSnapshot.restore(outcome.data, pair[0], pair[1], main.resources), "fixture v2 é aplicada ao mundo")
	var bush := main.resources.node_by_id("berry_1")
	_check(not bush.is_available() and bush.component.respawn_left == 100.0 and main.resources.node_by_id("tree_1").is_available(),
			"fixture v2: nó esgotado com tempo; id desconhecido e tipo trocado são ignorados")
	_check(main.resources.node_by_id("rock_1").is_available(), "fixture v2: nó com tipo diferente do da cena fica como está")
	_check(WorldSnapshot.respawn_count_of(outcome.data) == 3, "fixture v2: contador de respawns")


func _test_death_screen_lists_data() -> void:
	var rules: RespawnRules = RULES.duplicate()
	var extra := RespawnRegion.new()
	extra.id = "mata_baixa"
	extra.display_name = "Mata-baixa"
	extra.area = Rect2(32, 32, 160, 160)
	extra.fallback_point = Vector2(100, 100)
	rules.regions = [RULES.regions[0], extra]
	var screen := DeathScreen.new()
	screen.rules = rules
	_root.add_child(screen)
	_track.call(screen)
	var chosen: Array[String] = []
	screen.region_chosen.connect(func(id: String) -> void: chosen.append(id))
	screen.open(Vector2(100, 100))
	_check(screen.column().button_of("campina") != null and screen.column().button_of("mata_baixa") != null
			and screen.column().selected_id() == "campina", "a tela lista as regiões dos dados; a primeira vem selecionada")
	_check(screen.column().label_of("mata_baixa").contains("Mata-baixa") and screen.column().label_of("mata_baixa").contains("tiles"),
			"cada linha mostra nome e distância")
	screen.column().button_of("mata_baixa").pressed.emit()
	_check(chosen.is_empty(), "antes do atraso, a escolha é ignorada")
	screen._process(rules.accept_delay)
	screen.column().button_of("mata_baixa").pressed.emit()
	_check(chosen == ["mata_baixa"], "clicar numa região pede o respawn nela")
	screen.close()
	_check(not screen.is_open and not screen.visible, "fecha")


# ----------------------------------------------------------------------------- revisão (LEVI)

func _area_range(player: Player, areas: Array[InteractableArea]) -> void:
	player._in_range.clear()
	for area in areas:
		player._in_range.append(area)
	player.update_target()


func _test_targeting() -> void:
	var tree := _root.get_tree()
	var main := _main("targeting")
	await tree.physics_frame
	var player := main.player
	var bush := main.resources.node_by_id("berry_1")
	var other := main.resources.node_by_id("berry_2")
	var dino := main.dino
	player.position = Vector2(200, 180)
	dino.position = Vector2(226, 180)
	bush.position = Vector2(210, 180)
	var areas: Array[InteractableArea] = [bush.interactable, dino.interactable]
	_area_range(player, areas)
	_check(player.target == bush.interactable, "preparo: o arbusto é o alvo mais perto")
	var health := dino.health.current_health
	_check(player.attack() and dino.health.current_health < health, "o golpe acerta o dino mesmo com o arbusto mais perto")
	# Esgotado não rouba o alvo.
	other.position = Vector2(215, 180)
	bush.harvest()
	areas = [bush.interactable, other.interactable]
	_area_range(player, areas)
	_check(player.target == other.interactable and player.try_interact(), "arbusto esgotado é ignorado: o cheio ao lado é o alvo")
	# E em dino dormindo perto de arbusto esgotado abre a criatura.
	dino.torpor.add_torpor(100000.0)
	other.harvest()
	areas = [bush.interactable, other.interactable, dino.interactable]
	_area_range(player, areas)
	var opened: Array[Node] = []
	player.interacted.connect(func(area: InteractableArea) -> void: opened.append(area.entity))
	_check(player.target == dino.interactable and player.try_interact() and opened == [dino], "E no dino dormindo ignora arbustos esgotados")
	# Renascer limpa alvo e alcance.
	player.health.take_damage(10000.0)
	_check(main.request_respawn("campina") == "" and player.target == null, "renascer zera o alvo")
	# Renascer ao lado de um nó: o que continua sobreposto continua alcançável.
	player.health.protection_left = 0.0
	player.health.take_damage(10000.0)
	player._in_range.clear()
	player._in_range.append(other.interactable)
	other.component.depleted = false
	other.component.respawn_left = 0.0
	player.respawn_at(other.position + Vector2(28, 0), main.respawn_rules)
	player.update_target()
	_check(player.target == other.interactable and player.try_interact(), "renascendo a 28 px do nó, interagir funciona de imediato")
	player.health.protection_left = 0.0
	player.health.take_damage(10000.0)
	main.request_respawn("campina")
	player.target = other.interactable
	other.component.depleted = false
	player._gather_timer = 0.0
	_check(player.request_gather() == Player.GATHER_TOO_FAR, "depois de renascer longe, não colhe à distância")
	main.queue_free()  # a criatura e o jogador ficaram perto de onde as outras suítes põem os deles
	await tree.process_frame


func _test_inventory_and_death() -> void:
	var tree := _root.get_tree()
	var main := _main("inv_death")
	await tree.physics_frame
	main.screen.open_own()
	_check(main.screen.is_open and main.player.input_locked, "preparo: inventário aberto trava o jogador")
	main.player.health.take_damage(10000.0)
	_check(not main.screen.is_open and not main.player.input_locked, "morrer fecha o inventário e destrava o corpo")
	main.screen.open_own()
	main.screen.open_with(main.player.inventory, main.dino.inventory, main.dino.interactable, "Criatura")
	_check(not main.screen.is_open, "morto não abre o inventário (nem o da criatura)")
	main.screen.locked = false  # força a abertura para provar que o respawn também fecha
	main.screen.open_own()
	_check(main.screen.is_open, "preparo: aberta à força")
	main.screen.locked = true
	_check(main.request_respawn("campina") == "" and not main.screen.is_open and not main.player.input_locked, "respawn fecha e destrava")
	_check(not main.screen.locked, "o respawn desbloqueia a tela de inventário")
	main.screen.open_own()  # sem forçar nada
	_check(main.screen.is_open, "vivo de novo, o inventário abre")


func _test_respawn_save_timing() -> void:
	var tree := _root.get_tree()
	# Morte, save de morto e respawn: o save do respawn espera o prazo e só então grava o vivo.
	var main := _main("timing")
	main.player.health.take_damage(10000.0)
	await tree.process_frame
	_check(main.scheduler.saves_done == 1 and _read_raw(main.save_manager.main_path()).contains("dead_pending_choice"), "morte gravada")
	main.request_respawn("campina")
	_check(main.scheduler.pending_count() == 1, "o respawn pede um save (RESPAWN)")
	await tree.process_frame
	_check(main.scheduler.saves_done == 1 and _read_raw(main.save_manager.main_path()).contains("dead_pending_choice"),
			"dentro do prazo de 10 s o arquivo ainda é o de morto")
	main.scheduler.tick(main.scheduler.rules.min_seconds_between_saves)
	_check(main.scheduler.saves_done == 2 and _read_raw(main.save_manager.main_path()).contains('"alive"'), "passado o prazo, grava o vivo")
	# Morte e respawn dentro do prazo do save anterior: só o save de vivo existe.
	var burst := _main("timing_burst")
	burst.save_game()
	burst.player.health.take_damage(10000.0)
	burst.request_respawn("campina")
	await tree.process_frame
	burst.scheduler.tick(burst.scheduler.rules.min_seconds_between_saves)
	var file := _read_raw(burst.save_manager.main_path())
	_check(burst.scheduler.saves_done == 2 and file.contains('"alive"') and not file.contains("dead_pending_choice"),
			"morte e respawn dentro do prazo geram um save só, de vivo")
	_check(not _read_raw(burst.save_manager.backup_path()).contains("dead_pending_choice"), "e o .bak nunca viu o morto")


func _test_regions_and_points() -> void:
	var tree := _root.get_tree()
	var main := _main("regions", 20, true)
	await tree.physics_frame
	await tree.physics_frame
	var rules := main.respawn_rules
	_check(not rules.available_regions().is_empty(), "a lista de regiões nunca é vazia")
	for region in rules.available_regions():
		_check(main._is_free_point(region.fallback_point), "ponto reserva de %s é livre" % region.id)
		var wanted := region.id
		main.player.health.protection_left = 0.0
		main.player.health.take_damage(10000.0)
		_check(main.request_respawn(wanted) == "" and not main.player.health.is_dead(), "renasce em %s" % wanted)
	# Sem regiões nos dados: a tela e o respawn continuam possíveis.
	var empty: RespawnRules = rules.duplicate()
	empty.regions = []
	main.respawn_rules = empty
	main.death_screen.rules = empty
	main.player.health.protection_left = 0.0
	main.player.health.take_damage(10000.0)
	_check(main.death_screen.column().selected_id() == "inicio", "sem regiões nos dados a tela oferece o ponto de emergência")
	_check(main.request_respawn("inicio") == "" and main.player.position == empty.default_fallback_point, "e o respawn usa o ponto reserva")
	# A seed depende do contador: pontos diferentes a cada respawn, mesmo mundo.
	main.respawn_rules = rules
	main.death_screen.rules = rules
	main._respawn_count = 0
	var points := {}
	for i in 12:
		main.player.health.protection_left = 0.0
		main.player.health.take_damage(10000.0)
		main.request_respawn("campina")
		points[main.player.position] = true
	_check(points.size() >= 8, "respawns seguidos sorteiam pontos diferentes (%d de 12)" % points.size())
	# Selvagem conta, domado não.
	_check(main._wild_positions().size() == 1, "dino selvagem conta para a distância")
	main.dino.torpor.add_torpor(100000.0)
	main.dino.state_machine.mark_tamed()
	_check(main._wild_positions().is_empty(), "dino domado não conta")


func _test_death_screen_keyboard() -> void:
	var tree := _root.get_tree()
	var main := _main("keyboard")
	await tree.physics_frame
	main.player.health.take_damage(10000.0)
	var screen := main.death_screen
	var column := screen.column()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	# Duas regiões para a seta mover a seleção.
	var rules: RespawnRules = main.respawn_rules.duplicate()
	var extra := RespawnRegion.new()
	extra.id = "mata_baixa"
	extra.display_name = "Mata-baixa"
	extra.area = Rect2(32, 32, 160, 160)
	extra.fallback_point = Vector2(100, 100)
	rules.regions = [main.respawn_rules.regions[0], extra]
	screen.rules = rules
	main.respawn_rules = rules
	screen.open(main.player.position)
	screen._input(down)
	_check(column.selected_id() == "mata_baixa", "a seta move a seleção pelo teclado")
	screen._input(accept)
	_check(main.player.health.is_dead(), "Espaço/Enter logo ao abrir não escolhe nada (atraso)")
	screen._process(rules.accept_delay)
	screen._input(accept)
	_check(not main.player.health.is_dead() and not screen.is_open
			and rules.region_by_id("mata_baixa").area.has_point(main.player.position),
			"depois do atraso o teclado escolhe a região selecionada e o jogador renasce")


func _test_two_deaths_reset_delay() -> void:
	var tree := _root.get_tree()
	var main := _main("two_deaths")
	await tree.physics_frame
	main.player.health.take_damage(10000.0)
	main.death_screen._process(10.0)
	_check(main.death_screen.open_seconds >= 10.0, "preparo: atraso cumprido na primeira morte")
	main.request_respawn("campina")
	main.player.health.protection_left = 0.0
	main.player.health.take_damage(10000.0)
	_check(main.death_screen.open_seconds == 0.0 and main.death_screen.is_open, "a segunda morte zera o atraso")
	main.death_screen.column().button_of("campina").pressed.emit()
	_check(main.player.health.is_dead(), "e a escolha logo ao abrir de novo é ignorada")
	var label := ""
	var screen := DeathScreen.new()
	var rules: RespawnRules = main.respawn_rules.duplicate()
	rules.regions = []
	screen.rules = rules
	_root.add_child(screen)
	_track.call(screen)
	screen.open(Vector2(160, 300))
	label = screen.column().label_of("inicio")
	_check(label.contains("(0 tiles)"), "a distância da região de emergência mede até o ponto reserva (%s)" % label)
