# SPDX-License-Identifier: MIT
class_name CampTests
extends BuildTests
## E12: a base. Fogueira que assa (PRO-18: tempo, combustível, fome e vida da carne assada, interrupções, Fogueira removida,
## save), a luz dela à noite (SOB-03), o Saco de dormir (1 uso), a Cama (limite 3, espera de 60 s persistida, renascer nela, Cama
## destruída ou recolhida), a tela de morte com as opções (SOB-12), o corpo com limite e marcador (SOB-13) e o ciclo completo com
## os 4 slots reais (as receitas de fibra competem por espaço). Reaproveita a montagem do `BuildTests`.

const CAMP: CampRules = preload("res://data/balance/camp_rules.tres")
const PLAYER_RULES: PlayerRules = preload("res://data/balance/player_rules.tres")
const DAY_RULES: DayCycleRules = preload("res://data/balance/day_cycle_rules.tres")
const REAL_LAYOUT: SlotRules = preload("res://data/balance/slot_rules.tres")
const MEAT := Items.MEAT
const COOKED := Items.COOKED_MEAT
const FIRE_CELL := HOME + Vector2i(1, 0)
const BAG_CELL := HOME + Vector2i(0, 1)
const BED_CELL := HOME + Vector2i(-1, 0)
const OTHER := "outro_jogador_aaaaaaaaaaaaaaaaaaaaaa"


func run() -> void:
	_test_data()
	_test_place_remove_and_limits()
	_test_cook_time_and_fuel()
	_test_cook_refusals()
	_test_cook_interruptions()
	_test_cooked_meat_food()
	_test_cook_save()
	_test_options_and_bag_single_use()
	_test_bed_wait_and_persistence()
	_test_bed_destroyed_and_removed()
	_test_hostile_choices_and_save()
	_test_corpse_limit_and_marker()
	Items.with_layout(REAL_LAYOUT, _real_layout_checks)
	await _test_main_respawn_screen()
	await _test_campfire_light()
	_release_worlds()


func _real_layout_checks() -> void:
	_test_cook_inventory_full()
	_test_full_cycle_four_slots()


# ----------------------------------------------------------------------------- montagem

## Mundo de teste sem material: o jogador só tem o que o teste dá.
func _bare() -> Dictionary:
	return _setup(true, false)


func _give(world: Dictionary, item_id: String, amount: int) -> void:
	(world["player"] as Player).inventory.add(item_id, amount)


func _place(world: Dictionary, item_id: String, cell: Vector2i) -> Enums.ActionResult:
	_give(world, item_id, 1)
	return (world["authority"] as WorldAuthority).request_place(1, item_id, BuildTests.center(cell))


func _entity_at(world: Dictionary, cell: Vector2i) -> Node:
	return (world["authority"] as WorldAuthority).entity(int(_grid(world).piece_at(cell).get("id", 0)))


## Mundo com a Fogueira posta em `FIRE_CELL`, o jogador ao lado, com `meat` de carne e `wood` de madeira.
func _with_fire(meat: int, wood: int) -> Dictionary:
	var world := _bare()
	world["place"] = _place(world, Items.CAMPFIRE, FIRE_CELL)
	_give(world, MEAT, meat)
	_give(world, WOOD, wood)
	world["fire_id"] = int(_grid(world).piece_at(FIRE_CELL).get("id", 0))
	return world


func _cook(world: Dictionary) -> Dictionary:
	var authority: WorldAuthority = world["authority"]
	var before: int = (world["events"] as Array).size()
	var result := authority.request_cook(1, int(world["fire_id"]))
	return {"result": result, "reason": _reason_since(world, before)}


func _run_cook(world: Dictionary, seconds: float) -> void:
	var camp := (world["authority"] as WorldAuthority).camp
	var left := seconds
	while left > 0.0:
		var step := minf(0.25, left)
		camp.tick(step)
		left -= step


func _now(world: Dictionary) -> float:
	return (world["authority"] as WorldAuthority).clock.now()


func _main(world_id: String) -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = world_id
	main.menu_scene = ""
	_root.add_child(main)
	_track.call(main)
	for node: Node in [main.player, main.player.hunger, main.player.stamina, main.dino, main.dino.torpor, main.dino.taming,
			main.dino.state_machine, main.scheduler]:
		node.set_physics_process(false)
	main.wild.process_mode = Node.PROCESS_MODE_DISABLED
	main.zone.set_physics_process(false)
	main.predation.set_physics_process(false)
	main.dino.process_mode = Node.PROCESS_MODE_INHERIT
	main.dino.visible = true
	main.player.inventory.weight_limit = 0.0
	return main


# ----------------------------------------------------------------------------- dados

func _test_data() -> void:
	var catalog := PieceCatalog.with_defaults()
	var book := RecipeBook.with_defaults()
	_check(catalog.find("campfire").item_id == Items.CAMPFIRE and catalog.find("sleeping_bag").item_id == Items.SLEEPING_BAG
			and catalog.find("bed").item_id == Items.BED and catalog.find("bed").blocks_body
			and not catalog.find("sleeping_bag").blocks_body, "peças: Fogueira, Saco e Cama vêm do item; a Cama é sólida e o Saco não")
	_check(catalog.find("bed").max_per_owner == 3 and catalog.find("sleeping_bag").max_per_owner == 1
			and catalog.find("campfire").max_per_owner == 0, "limites por dono em dado: Cama 3, Saco 1, Fogueira sem limite")
	_check(CAMP.cook_seconds == 2.0 and CAMP.meat_per_wood == 4 and CAMP.bed_wait_seconds == 60.0,
			"assar: 2 s por carne, 1 madeira para 4; Cama espera 60 s (dados)")
	_check(PLAYER_RULES.hunger_restore_of(COOKED) == 35.0 and PLAYER_RULES.food_regen_of(COOKED) == 10.0
			and PLAYER_RULES.food_regen_seconds == 10.0 and PLAYER_RULES.food_regen_of(MEAT) == 0.0,
			"carne assada: +35 de fome e +10 de vida em 10 s; a crua não cura")
	_check(DAY_RULES.campfire_light_radius_tiles == 4.0, "luz da Fogueira: 4 tiles (dado)")
	_check(book.all().size() == 17 and book.find("campfire").inputs == {WOOD: 4, Items.STONE: 3}
			and book.find("sleeping_bag").inputs == {Items.FIBER: 8} and book.find("bed").inputs == {Items.FIBER: 12, WOOD: 8}
			and book.find("bed").station == RecipeDef.STATION_WORKBENCH,
			"as 17 receitas seguem: Saco 8 fibra, Cama 12 fibra + 8 madeira na Bancada")
	_check(Items.has(COOKED) and Items.weight_grams(COOKED) == Items.weight_grams(MEAT) and ItemIcons.icon_of(COOKED) != null,
			"item Carne assada existe, pesa como a crua e tem ícone")


# ----------------------------------------------------------------------------- colocar, recolher e limites

func _test_place_remove_and_limits() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	_check(_place(world, Items.CAMPFIRE, FIRE_CELL) == OK and _grid(world).def_at(FIRE_CELL).id == "campfire"
			and _count(world, Items.CAMPFIRE) == 0, "a Fogueira se coloca pelo pedido real e gasta o item")
	var fire := _entity_at(world, FIRE_CELL) as CampPiece
	var fire_id := authority.id_of(fire)
	_check(fire != null and fire.is_fire() and fire.interactable != null and fire_id > 0,
			"a Fogueira é entidade registrada, com área de interação")
	_check(_place(world, Items.SLEEPING_BAG, BAG_CELL) == OK and _entity_at(world, BAG_CELL) == null
			and _grid(world).piece_at(BAG_CELL)["owner"] == player.player_id,
			"o Saco se coloca, é do jogador e não é alvo de nada")
	_give(world, Items.SLEEPING_BAG, 1)
	var before := _state(world)
	var events_before := (world["events"] as Array).size()
	_check(authority.request_place(1, Items.SLEEPING_BAG, BuildTests.center(HOME + Vector2i(0, 2))) == Enums.ActionResult.WRONG_STATE
			and _reason_since(world, events_before) == "owner_limit", "segundo Saco do mesmo dono é recusado (limite 1)")
	_check(_count(world, Items.SLEEPING_BAG) == 1 and _state(world) == before, "recusa não gasta: o item segue no inventário e nada muda")
	# Camas: 3 por dono; a de outro jogador não conta no meu limite.
	_grid(world).add(HOME + Vector2i(5, 5), "bed", 0, OTHER)
	var placed := 0
	for cell: Vector2i in [BED_CELL, HOME + Vector2i(-1, 1), HOME + Vector2i(-1, -1), HOME + Vector2i(0, -1)]:
		placed += 1 if _place(world, Items.BED, cell) == OK else 0
	_check(placed == 3 and _grid(world).count_of("bed", player.player_id) == 3 and _count(world, Items.BED) == 1,
			"Cama: 3 colocadas por jogador; a 4ª é recusada e a de outro dono não entra na conta")
	_check(authority.request_remove_piece(1, BED_CELL) == OK and _count(world, Items.BED) == 2
			and _place(world, Items.BED, BED_CELL) == OK, "recolher uma Cama devolve o item e libera 1 do limite")
	_check(authority.request_remove_piece(1, FIRE_CELL) == OK and _count(world, Items.CAMPFIRE) == 1
			and not authority.is_registered(fire_id), "recolher a Fogueira devolve o item e a tira do registro")


# ----------------------------------------------------------------------------- assar

func _test_cook_time_and_fuel() -> void:
	var world := _with_fire(5, 3)
	var player: Player = world["player"]
	_check(world["place"] == OK and _cook(world)["result"] == OK, "preparo: Fogueira posta e o assar começa")
	_run_cook(world, 1.75)
	_check(_count(world, COOKED) == 0 and _count(world, MEAT) == 5, "antes dos 2 s nada assou e a madeira segue intacta")
	_check(_count(world, WOOD) == 3, "a madeira só sai quando a carne assa")
	_run_cook(world, 0.25)
	_check(_count(world, COOKED) == 1 and _count(world, MEAT) == 4 and _count(world, WOOD) == 2, "aos 2 s: 1 carne assada e 1 madeira gasta")
	_run_cook(world, 6.0)
	_check(_count(world, COOKED) == 4 and _count(world, WOOD) == 2, "as 4 primeiras carnes gastam 1 madeira só (1 para 4)")
	_run_cook(world, 2.0)
	_check(_count(world, COOKED) == 5 and _count(world, MEAT) == 0 and _count(world, WOOD) == 1
			and (world["authority"] as WorldAuthority).camp.job(1).is_empty(),
			"a 5ª carne pede a 2ª madeira; sem carne crua a tarefa termina na hora (sem esperar outro ciclo)")
	_check(player.inventory.count(MEAT) + player.inventory.count(COOKED) == 5, "nenhuma carne some nem se duplica")
	# Sem combustível para o 2º grupo: 5 carnes e 1 madeira assam 4 e param no fim do grupo.
	var short := _with_fire(5, 1)
	_cook(short)
	_run_cook(short, 20.0)
	_check(_count(short, COOKED) == 4 and _count(short, MEAT) == 1 and _count(short, WOOD) == 0
			and (short["authority"] as WorldAuthority).camp.job(1).is_empty() and "cook_cancelled" in _codes(short),
			"madeira acabou no meio: assou 4, a 5ª fica crua e o assar para com aviso")
	# 4 carnes e 1 madeira: termina limpo.
	var exact := _with_fire(4, 1)
	_cook(exact)
	_run_cook(exact, 8.0)
	_check(_count(exact, COOKED) == 4 and _count(exact, WOOD) == 0 and "cook_done" in _codes(exact)
			and not "cook_cancelled" in _codes(exact), "4 carnes com 1 madeira: concluído sem cancelar")


func _test_cook_refusals() -> void:
	var world := _with_fire(2, 1)
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var bad := authority.request_cook(1, authority.id_of(player))
	_check(bad == Enums.ActionResult.INVALID_TARGET and authority.request_cook(1, 99999) == Enums.ActionResult.INVALID_TARGET,
			"assar em algo que não é Fogueira (o jogador, id vazio) é recusado")
	_check(_cook(world)["result"] == OK and _cook(world)["reason"] == "already_cooking", "assar em dobro é recusado (já está assando)")
	authority.camp.cancel_by_player(1)
	player.global_position = BuildTests.center(HOME) + Vector2(0.0, 200.0)
	_check(_cook(world)["result"] == Enums.ActionResult.OUT_OF_RANGE, "longe da Fogueira: fora de alcance")
	player.global_position = BuildTests.center(HOME - Vector2i(1, 0))  # 2 tiles da Fogueira, com a parede no tile do meio
	_grid(world).add(HOME, "wall", 0, player.player_id)
	var through_wall := _cook(world)
	_check(through_wall["result"] == Enums.ActionResult.OUT_OF_RANGE and through_wall["reason"] == "blocked_line",
			"parede entre o jogador e a Fogueira: não assa")
	_grid(world).remove(HOME)
	player.global_position = BuildTests.center(HOME)
	var no_wood := _with_fire(2, 0)
	var no_meat := _with_fire(0, 3)
	_check(_cook(no_wood)["reason"] == "no_fuel" and _cook(no_meat)["reason"] == "no_meat", "sem madeira: no_fuel; sem carne crua: no_meat")
	_check(authority.camp.job(1).is_empty() and _count(no_wood, MEAT) == 2 and _count(no_wood, COOKED) == 0,
			"recusa não abre tarefa nem muda o inventário")
	player.perform_down(false)
	_check(authority.request_cook(1, int(world["fire_id"])) == Enums.ActionResult.ACTOR_DEAD, "caído não assa")


func _test_cook_interruptions() -> void:
	# Afastar-se.
	var away := _with_fire(4, 2)
	var away_player: Player = away["player"]
	_cook(away)
	_run_cook(away, 2.0)
	away_player.global_position = BuildTests.center(HOME) + Vector2(0.0, 200.0)
	_run_cook(away, 0.25)
	_check(_count(away, COOKED) == 1 and _count(away, MEAT) == 3 and (away["authority"] as WorldAuthority).camp.job(1).is_empty()
			and "cook_cancelled" in _codes(away), "afastar-se para o assar: o que assou fica e o resto continua cru")
	# Cair.
	var down := _with_fire(4, 2)
	_cook(down)
	_run_cook(down, 2.0)
	(down["player"] as Player).perform_down(false)
	_run_cook(down, 0.25)
	_check(_count(down, COOKED) == 1 and (down["authority"] as WorldAuthority).camp.job(1).is_empty(), "cair para o assar")
	# Cancelar a pedido.
	var asked := _with_fire(4, 2)
	_cook(asked)
	_run_cook(asked, 2.0)
	_check((asked["authority"] as WorldAuthority).request_cancel_cook(1) == OK and _count(asked, COOKED) == 1
			and (asked["authority"] as WorldAuthority).request_cancel_cook(1) == Enums.ActionResult.WRONG_STATE,
			"cancelar a pedido para; sem tarefa, cancelar é recusado")
	# A Fogueira some no meio (recolhida) e depois destruída: nada se perde.
	for how: String in ["remove", "destroy"]:
		var gone := _with_fire(4, 2)
		var authority: WorldAuthority = gone["authority"]
		_cook(gone)
		_run_cook(gone, 4.0)
		_check(_count(gone, COOKED) == 2, "preparo (%s): 2 assadas antes de a Fogueira sumir" % how)
		if how == "remove":
			authority.request_remove_piece(1, FIRE_CELL)
		else:
			authority.build.destroy(FIRE_CELL)
		_run_cook(gone, 0.25)
		_check(authority.camp.job(1).is_empty() and _count(gone, COOKED) == 2 and _count(gone, MEAT) == 2 and _count(gone, WOOD) == 1
				and "cook_cancelled" in _codes(gone), "Fogueira %s no meio: assadas ficam, cruas seguem, madeira não some" % how)
		_check(authority.request_cook(1, int(gone["fire_id"])) == Enums.ActionResult.INVALID_TARGET,
				"a Fogueira que sumiu não aceita mais pedido (%s)" % how)
	# Carregar um save na mesma sessão esquece a tarefa.
	var loaded := _with_fire(4, 2)
	_cook(loaded)
	(loaded["authority"] as WorldAuthority).camp.clear_jobs()
	_check((loaded["authority"] as WorldAuthority).camp.job(1).is_empty(), "clear_jobs (carga de save) esquece o assar")


func _test_cooked_meat_food() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	_give(world, COOKED, 3)
	_give(world, MEAT, 1)
	player.hotbar.assign(0, COOKED)
	player.hotbar.assign(1, MEAT)
	player.hunger.set_ratio(0.2)
	player.health.take_damage(60.0)
	var life := player.health.current_health
	var hunger := player.hunger.current_hunger
	_check(authority.request_use_item(1, 0) == OK and _count(world, COOKED) == 2 and is_equal_approx(player.hunger.pending, 35.0),
			"comer a assada: gasta 1 e põe +35 de fome na fila")
	player.hunger.tick(20.0)
	_check(player.hunger.current_hunger > hunger + 34.0 - player.hunger.decay_per_second * 20.0 - 0.01, "a fome subiu os 35 pontos")
	_check(player.health.regen_left == 10.0 and is_equal_approx(player.health.regen_rate, 1.0),
			"e a cura abre uma janela de 10 s a 1 por segundo")
	player.health.tick(4.0)
	_check(is_equal_approx(player.health.current_health, life + 4.0), "depois de 4 s: +4 de vida")
	player._eat_timer = 0.0  # recarga de comer
	player.health.tick(1.0)
	_check(authority.request_use_item(1, 0) == OK and player.health.regen_left == 10.0 and is_equal_approx(player.health.regen_rate, 1.0),
			"comer de novo RENOVA a janela (10 s, 1 por segundo; a taxa não soma)")
	player.health.tick(10.0)
	_check(is_equal_approx(player.health.current_health, life + 4.0 + 1.0 + 10.0) and player.health.regen_left == 0.0,
			"a cura termina em 10 s e para")
	# A crua não cura.
	var raw_life := player.health.current_health
	player._eat_timer = 0.0
	player.hunger.set_ratio(0.2)
	authority.request_use_item(1, 1)
	player.health.tick(10.0)
	_check(player.health.regen_left == 0.0 and player.health.current_health == raw_life, "a carne crua alimenta mas não cura")
	# Morrer cancela a cura.
	player.health.start_regen(10.0, 10.0)
	player.perform_death()
	_check(player.health.regen_left == 0.0, "a morte cancela a cura em andamento")


func _test_cook_save() -> void:
	var world := _with_fire(4, 2)
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	_cook(world)
	_run_cook(world, 4.0)
	var envelope := WorldSnapshot.capture(player, null, "t", "now", null, 0, authority.next_entity_id(), null, null,
			_now(world), null, null, _grid(world))
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	_check(SaveManager.validate_envelope(parsed) == "" and _grid(world).count() == 1, "o save com Fogueira e carne assada é válido")
	# Carrega num mundo novo: a Fogueira volta com o mesmo id, a carne assada vem no inventário e a tarefa NÃO volta.
	var fresh := _bare()
	var fresh_authority: WorldAuthority = fresh["authority"]
	var fresh_player: Player = fresh["player"]
	_check(WorldSnapshot.restore(parsed, fresh_player, null, null, null, null, fresh_authority, null, null, _grid(fresh)),
			"a carga do save aceita")
	var restored := _entity_at(fresh, FIRE_CELL) as CampPiece
	_check(restored != null and restored.is_fire() and fresh_authority.id_of(restored) == int(world["fire_id"])
			and _count(fresh, COOKED) == 2 and _count(fresh, MEAT) == 2 and fresh_authority.camp.job(1).is_empty(),
			"depois da carga: Fogueira com o mesmo id, 2 assadas, 2 cruas e nenhuma tarefa em andamento")
	fresh["fire_id"] = fresh_authority.id_of(restored)
	_check(_cook(fresh)["result"] == OK, "e a Fogueira carregada assa de novo")
	_check(not authority.camp.job(1).is_empty(), "preparo: o mundo original ainda está assando")
	_check(WorldSnapshot.restore(parsed, player, null, null, null, null, authority, null, null, _grid(world))
			and authority.camp.job(1).is_empty(), "carregar na mesma sessão esquece o assar em curso")


func _test_cook_inventory_full() -> void:
	# 4 slots cheios e a carne crua com 2: tirar 1 não libera o slot, então a assada não cabe: a crua volta e a tarefa para.
	var tight := _with_fire(0, 0)
	var tight_player: Player = tight["player"]
	_fill_four(tight_player, 2)
	_check(_cook(tight)["result"] == OK, "preparo: 4 slots cheios e a tarefa começa")
	_run_cook(tight, 2.0)
	_check(_count(tight, COOKED) == 0 and _count(tight, MEAT) == 2 and _count(tight, WOOD) == 1
			and (tight["authority"] as WorldAuthority).camp.job(1).is_empty() and "cook_cancelled" in _codes(tight),
			"sem lugar para a assada: a crua volta, a madeira fica e o assar para")
	# Com 1 carne só, tirá-la libera o slot e a assada entra no lugar dela.
	var swap := _with_fire(0, 0)
	_fill_four(swap["player"], 1)
	_cook(swap)
	_run_cook(swap, 2.0)
	_check(_count(swap, COOKED) == 1 and _count(swap, MEAT) == 0 and "cook_done" in _codes(swap),
			"a última crua libera o slot: a assada ocupa o lugar dela")


## Esvazia o inventário e o deixa com 4 pilhas: `meat` de carne, 1 madeira, 1 pedra e 1 fibra.
func _fill_four(player: Player, meat: int) -> void:
	player.inventory.from_dict({"version": InventoryComponent.FORMAT_VERSION, "next_iid": 1, "slots": []})
	player.inventory.add(MEAT, meat)
	player.inventory.add(WOOD, 1)
	player.inventory.add(Items.STONE, 1)
	player.inventory.add(Items.FIBER, 1)


# ----------------------------------------------------------------------------- Saco e Cama (serviço)

func _test_options_and_bag_single_use() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	_place(world, Items.BED, BED_CELL)
	_place(world, Items.SLEEPING_BAG, BAG_CELL)
	_grid(world).add(HOME + Vector2i(6, 6), "bed", 0, OTHER)
	var body := BuildTests.center(HOME) + Vector2(160.0, 0.0)
	var options := authority.respawn_points.options(player.player_id, body)
	_check(options.size() == 2 and options[0]["kind"] == "bed" and options[0]["name"] == "Cama 1" and options[1]["kind"] == "bag"
			and options[1]["name"] == "Saco de dormir" and options[0]["id"] == RespawnPointService.option_id("bed", BED_CELL),
			"a lista do jogador: Cama 1 e o Saco, nessa ordem; a Cama de outro dono não aparece")
	_check(options[0]["distance_tiles"] == 11 and options[0]["enabled"] and options[1]["enabled"],
			"cada linha traz a distância ao corpo e vem habilitada")
	var landing: Vector2 = options[0]["position"]
	var landing_cell := authority.build.cell_of(landing)
	_check(landing_cell != BED_CELL and maxi(absi(landing_cell.x - BED_CELL.x), absi(landing_cell.y - BED_CELL.y)) == 1
			and not _grid(world).has_piece(landing_cell), "quem renasce na Cama nasce num tile livre ao lado dela, não nela")
	_check(authority.build.cell_of(options[1]["position"]) == BAG_CELL, "o Saco não tem corpo: nasce no próprio tile")
	var bag := options[1]
	var resolved := authority.respawn_points.resolve(player.player_id, str(bag["id"]), body)
	_check(resolved["ok"] and _grid(world).has_piece(BAG_CELL), "resolver a escolha não consome o Saco")
	authority.respawn_points.commit(bag)
	_check(not _grid(world).has_piece(BAG_CELL) and authority.respawn_points.options(player.player_id, body).size() == 1
			and _entity_at(world, BAG_CELL) == null, "usar o Saco (commit) o tira do mundo: 1 uso")
	_check(not authority.respawn_points.resolve(player.player_id, str(bag["id"]), body)["ok"], "e ele não vale uma segunda vez")
	# Cama murada (sem tile livre em volta): desabilitada, com motivo.
	var boxed := _bare()
	_place(boxed, Items.BED, BED_CELL)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := BED_CELL + Vector2i(dx, dy)
			if cell != BED_CELL and not _grid(boxed).has_piece(cell):
				_grid(boxed).add(cell, "wall", 0, (boxed["player"] as Player).player_id)
	var walled := (boxed["authority"] as WorldAuthority).respawn_points.options((boxed["player"] as Player).player_id, body)
	_check(walled.size() == 1 and not walled[0]["enabled"] and walled[0]["reason"] == "point_blocked",
			"Cama sem lugar ao lado: opção desabilitada (point_blocked)")


func _test_bed_wait_and_persistence() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var points := authority.respawn_points
	_place(world, Items.BED, BED_CELL)
	_place(world, Items.BED, HOME + Vector2i(-1, 1))
	var body := BuildTests.center(HOME)
	var first := points.options(player.player_id, body)[0]
	points.commit(first)
	var waiting := points.options(player.player_id, body)
	_check(not waiting[0]["enabled"] and waiting[0]["reason"] == "point_waiting" and is_equal_approx(float(waiting[0]["wait_left"]), 60.0),
			"renascer na Cama a põe em espera de 60 s")
	_check(waiting[1]["enabled"], "a espera é POR Cama: a outra segue pronta")
	authority.clock.advance(59.0)
	_check(not points.options(player.player_id, body)[0]["enabled"] and is_equal_approx(points.wait_left(BED_CELL), 1.0),
			"aos 59 s ainda espera 1 s")
	authority.clock.advance(1.0)
	_check(points.options(player.player_id, body)[0]["enabled"] and points.wait_left(BED_CELL) == 0.0, "aos 60 s a Cama volta")
	# O mundo parado não conta: sem avanço do relógio a espera não desce.
	points.commit(first)
	_check(is_equal_approx(points.wait_left(BED_CELL), 60.0), "sem o relógio do mundo andar (pausa, jogo fechado) a espera não desce")
	# Persistida: ida e volta pelo JSON, num mundo novo cujo relógio foi reposto do save.
	authority.clock.advance(25.0)
	var block: Dictionary = JSON.parse_string(JSON.stringify(_grid(world).to_dict()))
	var saved_time := _now(world)
	var fresh := _bare()
	var fresh_authority: WorldAuthority = fresh["authority"]
	fresh_authority.clock.restore(saved_time)
	_check(_grid(fresh).from_dict(block) and is_equal_approx(fresh_authority.respawn_points.wait_left(BED_CELL), 35.0),
			"a espera vai ao save e volta com o que faltava (35 s), não zera nem estende")
	fresh_authority.clock.advance(35.0)
	_check(fresh_authority.respawn_points.wait_left(BED_CELL) == 0.0, "e acaba no tempo certo depois da carga")
	_check((block["pieces"][0] as Dictionary).has("ready_at") and not (block["pieces"][1] as Dictionary).has("ready_at"),
			"só a Cama em espera leva `ready_at` ao save; a pronta não grava o campo")


func _test_bed_destroyed_and_removed() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var points := authority.respawn_points
	var body := BuildTests.center(HOME)
	_place(world, Items.BED, BED_CELL)
	points.commit(points.options(player.player_id, body)[0])
	_check(authority.build.destroy(BED_CELL) and points.options(player.player_id, body).is_empty()
			and _count(world, Items.BED) == 0 and "piece_destroyed" in _codes(world),
			"Cama destruída: sai da lista na hora e NÃO devolve o item")
	_check(not authority.build.destroy(BED_CELL), "destruir onde não há peça não faz nada")
	_check(_place(world, Items.BED, BED_CELL) == OK and points.wait_left(BED_CELL) == 0.0
			and points.options(player.player_id, body)[0]["enabled"], "uma Cama nova no mesmo lugar nasce pronta (a espera sumiu junto)")
	points.commit(points.options(player.player_id, body)[0])
	_check(authority.request_remove_piece(1, BED_CELL) == OK and _count(world, Items.BED) == 1
			and points.options(player.player_id, body).is_empty(), "Cama recolhida pelo dono: o item volta inteiro e ela sai da lista")
	_check(_place(world, Items.BED, BED_CELL) == OK and points.wait_left(BED_CELL) == 0.0,
			"recolher zera a espera e libera 1 do limite")


func _test_hostile_choices_and_save() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var points := authority.respawn_points
	_place(world, Items.BED, BED_CELL)
	_grid(world).add(HOME + Vector2i(1, 1), "bed", 0, OTHER)
	var body := BuildTests.center(HOME)
	var bad_ids: Array[String] = ["", "bed", "bed:abc:1", "bed:1:1", "bag:%d:%d" % [BED_CELL.x, BED_CELL.y], "x".repeat(200),
			RespawnPointService.option_id("bed", HOME + Vector2i(1, 1)), "bed:99999999999999999999:1"]
	var all_refused := true
	for choice in bad_ids:
		all_refused = all_refused and not bool(points.resolve(player.player_id, choice, body)["ok"])
	_check(all_refused, "ids de fora (vazio, mal formado, sem peça, tipo trocado, enorme, Cama de outro dono) são recusados")
	# Save hostil: instante absurdo, texto, negativo e ausente.
	var pieces: Array = []
	for index in 4:
		var entry := {"piece": "bed", "x": 20 + index * 2, "y": 20, "owner": player.player_id}
		match index:
			0:
				entry["ready_at"] = 1.0e30
			1:
				entry["ready_at"] = "amanhã"
			2:
				entry["ready_at"] = -50.0
		pieces.append(entry)
	_check(_grid(world).from_dict({"version": 1, "pieces": pieces}), "save com ready_at hostil carrega (só sanea)")
	_check(points.wait_left(Vector2i(20, 20)) <= 60.0 and _grid(world).ready_at(Vector2i(22, 20)) == 0.0
			and _grid(world).ready_at(Vector2i(24, 20)) == 0.0 and _grid(world).ready_at(Vector2i(26, 20)) == 0.0,
			"instante gigante vira no máximo uma espera cheia; texto, negativo e ausente (save antigo) = pronta")


# ----------------------------------------------------------------------------- corpo

func _test_corpse_limit_and_marker() -> void:
	var world := _bare()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var corpses := CorpseField.new()
	_root.add_child(corpses)
	_track.call(corpses)
	corpses.clock = authority.clock.now
	corpses.attach(authority)
	var mine := player.player_id
	player.player_id = OTHER  # um corpo de outro jogador, que o limite do meu não toca
	_give(world, WOOD, 1)
	player.global_position = Vector2(-3000.0, 0.0)
	corpses.deposit(player)
	player.player_id = mine
	var spots: Array[Vector2] = [Vector2(2000.0, 0.0), Vector2(0.0, 2000.0), Vector2(-2000.0, 0.0), Vector2(0.0, -2000.0)]
	for spot in spots:
		_give(world, WOOD, 1)
		player.global_position = spot
		corpses.deposit(player)
	var kept: Array[Vector2] = []
	for corpse in corpses.corpses():
		if corpse.owner_player_id == mine:
			kept.append(corpse.position)
	_check(kept.size() == 3 and not kept.has(spots[0]) and kept.has(spots[3]) and corpses.count() == 4,
			"limite de 3 corpos por jogador: o 4º apaga o mais antigo dele; o de outro dono fica")
	_check("corpse_expired" in _codes(world), "e o jogador é avisado de que o corpo antigo (e o que ele guardava) se perdeu")
	var marker := CorpseMarker.new()
	marker.corpses = corpses
	marker.viewer = player
	var arrows := marker.markers(Vector2(320.0, 180.0), Transform2D.IDENTITY)
	_check(arrows.size() == 3, "o marcador mostra os 3 corpos do jogador local fora da tela (o de outro dono, não)")
	var left: Dictionary = {}
	for arrow in arrows:
		if (arrow["position"] as Vector2).x < 20.0:
			left = arrow
	_check(not left.is_empty() and is_equal_approx((left["position"] as Vector2).x, 8.0) and absf(float(left["angle"])) > 3.0,
			"o do corpo à esquerda fica na borda esquerda (a 8 px) apontando para a esquerda")
	player.global_position = Vector2(0.0, 0.0)
	var near := marker.markers(Vector2(320.0, 180.0), Transform2D(0.0, Vector2(160.0, 90.0) - spots[1]))  # câmera sobre o corpo de baixo
	_check(near.size() == 2, "corpo dentro da tela não ganha seta")
	marker.free()
	# Carga de save com excesso: no máximo 3 por dono.
	var list: Array = []
	for index in 5:
		list.append({"player_id": mine, "x": float(index), "y": 0.0, "due_at": 1.0e6, "items": [{"id": WOOD, "count": 1}]})
	corpses.restore_list(list)
	_check(corpses.count() == 3, "o save com 5 corpos do mesmo dono carrega só 3 (o limite vale também na carga)")
	# Geometria pura.
	var inside := EdgeMarker.place(Vector2(160.0, 90.0), Vector2(320.0, 180.0), 8.0)
	var corner := EdgeMarker.place(Vector2(5.0, 5.0), Vector2(320.0, 180.0), 8.0)
	var up := EdgeMarker.place(Vector2(160.0, -500.0), Vector2(320.0, 180.0), 8.0)
	_check(not inside["visible"] and corner["visible"] and is_equal_approx((corner["position"] as Vector2).y, 8.0)
			and is_equal_approx((up["position"] as Vector2).y, 8.0) and is_equal_approx((up["position"] as Vector2).x, 160.0)
			and is_equal_approx(float(up["angle"]), -PI * 0.5), "EdgeMarker: dentro não marca; fora cai na borda interna, na reta do centro")


# ----------------------------------------------------------------------------- ciclo completo com 4 slots

func _test_full_cycle_four_slots() -> void:
	# Com chão (como no jogo), a fabricação sem lugar NÃO perde nada: o item cai aos pés.
	var ground := _four_slot_world()
	var ground_authority: WorldAuthority = ground["authority"]
	_check(ground_authority.request_craft(1, "sleeping_bag") == OK, "preparo: 4 pilhas cheias e fibra de sobra")
	ground_authority.crafting.tick(3.0)
	_check(_count(ground, Items.SLEEPING_BAG) == 0 and (ground["dropped"] as Array).has([Items.SLEEPING_BAG, 1])
			and _count(ground, Items.FIBER) == 12, "com o inventário cheio o Saco cai no chão (nada se perde) e a fibra já foi gasta")
	# Sem chão, a ordem importa: cada receita só cabe se a anterior liberou um slot.
	var world := _four_slot_world()
	var authority: WorldAuthority = world["authority"]
	authority.drops_enabled = false
	var player: Player = world["player"]
	var before := (world["events"] as Array).size()
	_check(authority.request_craft(1, "sleeping_bag") == Enums.ActionResult.REFUSED and _reason_since(world, before) == "inventory_full"
			and _count(world, Items.FIBER) == 20, "Saco com 4 pilhas e fibra de sobra: recusado, sem gastar (a fibra compete por espaço)")
	_check(authority.request_craft(1, "campfire") == OK, "a Fogueira gasta toda a pedra e libera o slot")
	authority.crafting.tick(3.0)
	_check(_count(world, Items.CAMPFIRE) == 1 and _count(world, Items.STONE) == 0, "Fogueira fabricada; a pedra acabou")
	_check(authority.request_place(1, Items.CAMPFIRE, BuildTests.center(FIRE_CELL)) == OK, "e posta no mundo: o slot volta")
	_check(authority.request_craft(1, "sleeping_bag") == OK, "agora o Saco cabe")
	authority.crafting.tick(3.0)
	_check(authority.request_place(1, Items.SLEEPING_BAG, BuildTests.center(BAG_CELL)) == OK and _count(world, Items.FIBER) == 12,
			"Saco posto; sobram 12 fibra")
	_grid(world).add(HOME + Vector2i(0, -1), "workbench", 0, player.player_id)
	_check(authority.request_craft(1, "bed") == OK, "a Cama (12 fibra + 8 madeira) na Bancada: gasta duas pilhas inteiras e cabe")
	authority.crafting.tick(4.0)
	_check(authority.request_place(1, Items.BED, BuildTests.center(BED_CELL)) == OK and _count(world, WOOD) == 0
			and _count(world, Items.FIBER) == 0, "Cama posta; a madeira e a fibra acabaram")
	world["fire_id"] = int(_grid(world).piece_at(FIRE_CELL).get("id", 0))
	_check(_cook(world)["reason"] == "no_fuel", "sem madeira (a Cama levou tudo): a Fogueira não assa")
	_give(world, WOOD, 1)
	_check(_cook(world)["result"] == OK, "com 1 madeira (um slot novo) assa")
	_run_cook(world, 4.0)
	_check(_count(world, COOKED) == 2 and _count(world, MEAT) == 0 and _count(world, WOOD) == 0
			and _grid(world).def_at(FIRE_CELL).id == "campfire" and _grid(world).def_at(BAG_CELL).id == "sleeping_bag"
			and _grid(world).def_at(BED_CELL).id == "bed" and player.inventory.grid_used() <= 4,
			"ciclo fechado: Fogueira, Saco e Cama no mundo, 2 carnes assadas, sem item perdido nem a grade estourada")


## Mundo com o dado real de 4 slots, receitas de Saco e Cama aprendidas e 4 pilhas: 20 fibra, 12 madeira, 3 pedra, 2 carne.
func _four_slot_world() -> Dictionary:
	var world := _bare()
	var player: Player = world["player"]
	player.inventory.from_dict({"version": InventoryComponent.FORMAT_VERSION, "next_iid": 1, "slots": []})
	_check(player.inventory.capacity == 4, "preparo: o dado real, 4 slots")
	for pair: Array in [[Items.FIBER, 20], [WOOD, 12], [Items.STONE, 3], [MEAT, 2]]:
		player.inventory.add(pair[0], pair[1])
	var authority: WorldAuthority = world["authority"]
	authority.request_learn_recipe(1, "sleeping_bag")
	authority.request_learn_recipe(1, "bed")
	return world


# ----------------------------------------------------------------------------- Main: tela de morte e luz

## Uma célula no meio de um quadrado 5x5 de chão livre (terra, andável, fora do refúgio, sem recurso).
func _open_ground(main: Main) -> Vector2i:
	for y in range(44, main.map.size - 44, 7):
		for x in range(44, main.map.size - 44, 7):
			var free := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					free = free and main.authority.build.is_free_cell(Vector2i(x + dx, y + dy))
			if free:
				return Vector2i(x, y)
	return Vector2i.ZERO


func _test_main_respawn_screen() -> void:
	var main := _main("camp_screen")
	await _root.get_tree().physics_frame
	var authority := main.authority
	var player := main.player
	var base := _open_ground(main)
	var bed_cell := base + Vector2i(1, 0)
	var bag_cell := base + Vector2i(0, 1)
	player.global_position = BuildTests.center(base)
	player.inventory.add(Items.BED, 1)
	player.inventory.add(Items.SLEEPING_BAG, 1)
	var id := authority.id_of(player)
	_check(authority.request_place(id, Items.BED, BuildTests.center(bed_cell)) == OK
			and authority.request_place(id, Items.SLEEPING_BAG, BuildTests.center(bag_cell)) == OK, "preparo: Cama e Saco postos na Main")
	authority.build.grid.add(base + Vector2i(2, 2), "bed", 0, OTHER)
	var bed_id := RespawnPointService.option_id("bed", bed_cell)
	var bag_id := RespawnPointService.option_id("bag", bag_cell)
	_check(main.request_respawn(bag_id) == "not_dead" and authority.build.grid.has_piece(bag_cell), "vivo não usa o Saco: ele fica")
	player.health.protection_left = 0.0
	TestWorld.kill(player)
	var column := main.death_screen.column()
	_check(main.pending_death_choice and column.button_of(bed_id) != null and column.button_of(bag_id) != null
			and column.button_of("campina") != null and column.button_of(RespawnPointService.option_id("bed", base + Vector2i(2, 2))) == null,
			"tela de morte: Cama, Saco e Local aleatório; a Cama de outro dono não")
	_check(column.selected_id() == bed_id and column.label_of(bed_id).begins_with("Cama 1 (") and "tiles" in column.label_of(bed_id)
			and column.label_of(bag_id).begins_with("Saco de dormir (") and column.label_of("campina").begins_with("Local aleatório"),
			"a Cama pronta vem pré-selecionada; cada linha tem nome e distância")
	_check(main.request_respawn(RespawnPointService.option_id("bed", base + Vector2i(2, 2))) == "point_gone" and player.health.is_dead()
			and main.request_respawn("x".repeat(100) + ":1:1") == "point_gone", "escolha de peça alheia ou inventada é recusada: segue morto")
	var wait_start := authority.clock.now()
	_check(main.request_respawn(bed_id) == "" and not player.health.is_dead(), "renascer na Cama")
	var landed := authority.build.cell_of(player.global_position)
	_check(maxi(absi(landed.x - bed_cell.x), absi(landed.y - bed_cell.y)) == 1 and authority.build.grid.has_piece(bag_cell)
			and is_equal_approx(authority.build.grid.ready_at(bed_cell), wait_start + 60.0) and player.health.is_protected(),
			"nasce ao lado da Cama, com proteção, o Saco intacto e a Cama em espera de 60 s")
	# Morre de novo: a Cama espera (cinza, com o tempo), o Saco vem pré-selecionado.
	player.health.protection_left = 0.0
	TestWorld.kill(player)
	_check(column.button_of(bed_id).disabled and "espera 60 s" in column.label_of(bed_id) and column.selected_id() == bag_id,
			"2ª morte: a Cama fica cinza com o tempo restante e o Saco é o pré-selecionado")
	authority.clock.advance(25.0)
	main.death_screen._process(0.0)
	_check("espera 35 s" in column.label_of(bed_id) and column.button_of(bed_id).disabled and column.selected_id() == bag_id,
			"a tela aberta acompanha a espera (35 s) sem perder a seleção")
	_check(main.request_respawn(bed_id) == "point_waiting" and player.health.is_dead(), "escolher a Cama em espera é recusado")
	authority.build.destroy(bed_cell)
	main.death_screen._process(0.0)
	_check(column.button_of(bed_id) == null and column.selected_id() == bag_id,
			"Cama destruída com a tela aberta: sai da lista na hora e a seleção fica")
	_check(main.request_respawn(bag_id) == "" and not authority.build.grid.has_piece(bag_cell)
			and authority.build.cell_of(player.global_position) == bag_cell, "renascer no Saco: nasce nele e ele some (1 uso)")
	player.health.protection_left = 0.0
	TestWorld.kill(player)
	_check(column.button_of(bag_id) == null and column.selected_id() == "campina" and main.request_respawn(bag_id) == "point_gone",
			"3ª morte: sem Cama nem Saco só resta o Local aleatório, pré-selecionado; o Saco usado não volta")
	_check(main.request_respawn("campina") == "", "o Local aleatório sempre funciona")
	# O Saco é consumido só com o jogador no mundo: fechar a tela de morte (save) não o consome.
	player.inventory.add(Items.SLEEPING_BAG, 1)
	authority.request_place(id, Items.SLEEPING_BAG, BuildTests.center(bag_cell))
	player.health.protection_left = 0.0
	TestWorld.kill(player)
	var saved := WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0, authority.next_entity_id(), null, main.carcasses,
			authority.clock.now(), main.ground, main.corpses, authority.build.grid)
	_check(JSON.stringify(saved).contains("sleeping_bag") and WorldSnapshot.was_dead_pending_choice(saved),
			"fechar na tela de morte: o save guarda o Saco e a morte pendente")


func _test_campfire_light() -> void:
	var main := _main("camp_light")
	await _root.get_tree().physics_frame
	var authority := main.authority
	var view: DayNightView = null
	for child in main.get_children():
		if child is DayNightView:
			view = child
	_check(view != null and view.fire_lights().is_empty(), "preparo: a vista do dia e da noite, sem Fogueira, sem luz de Fogueira")
	if view == null:
		return
	var base := _open_ground(main)
	var cell := base + Vector2i(1, 0)
	main.player.global_position = BuildTests.center(base)
	main.player.inventory.add(Items.CAMPFIRE, 1)
	_check(authority.request_place(authority.id_of(main.player), Items.CAMPFIRE, BuildTests.center(cell)) == OK
			and view.fire_lights().size() == 1, "pôr a Fogueira acende uma luz no tile dela")
	var rules := authority.day_cycle.rules
	authority.clock.restore(200.0)
	view.tick(0.0)
	_check(not view.fire_lights()[cell].visible, "de dia a luz da Fogueira não aparece")
	authority.clock.restore(560.0)
	view.tick(0.0)
	var light := view.fire_lights()[cell]
	var radius_tiles: float = light.texture.get_width() * light.texture_scale / 2.0 / view.tile_px
	_check(light.visible and light.color.is_equal_approx(view.light_node().color) and is_equal_approx(radius_tiles, 4.0)
			and rules.campfire_light_radius_tiles == 4.0 and light.position.is_equal_approx(BuildTests.center(cell)),
			"de noite a luz aparece, no centro da Fogueira, com 4 tiles de raio e a cor da luz do jogador (%.2f)" % radius_tiles)
	var block := authority.build.grid.to_dict()
	authority.build.grid.from_dict(block)
	_check(view.fire_lights().size() == 1 and view.fire_lights().has(cell), "carregar o save refaz a luz (uma só, sem duplicar)")
	_check(authority.request_remove_piece(authority.id_of(main.player), cell) == OK and view.fire_lights().is_empty(),
			"recolher a Fogueira apaga a luz")
