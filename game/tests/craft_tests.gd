# SPDX-License-Identifier: MIT
class_name CraftTests
extends AuthorityTests
## E7a: fabricar à mão (`request_craft`), Bancada colocada (`request_place`), save da Bancada e a Lança (CRI-13).

const RESULT_OK := Enums.ActionResult.OK
const RESPAWN: RespawnRules = preload("res://data/balance/respawn_rules.tres")
const SPEAR := Items.WOODEN_SPEAR
const TILE := 16.0
const TREE_DEF: ResourceNodeDef = preload("res://data/resources/tree.tres")


func run() -> void:
	_test_recipe_data()
	_test_missing_material()
	_test_unknown_and_locked_recipe()
	_test_unknown_actor_and_client_panel()
	_test_panel_lists_and_progress()
	_test_craft_completes_and_gives_xp()
	_test_cancel_by_walking_and_falling()
	_test_workbench_range()
	_test_inventory_full_drops()
	_test_place_rules()
	_test_place_in_safe_core_and_sea()
	_test_workbench_save()
	_test_restore_validates_saved_benches()
	_test_navigation_blocks_bench()
	_test_craft_edge_cases()
	_test_workbench_snapshot_and_old_save()
	_test_tree_gives_stick()
	_test_spear_kills_dodo_in_two_hits()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

## Jogador sem itens, ligado a uma autoridade com chão ligado e (opcional) campo de Bancadas, sem mapa.
func _setup(with_field: bool = false) -> Dictionary:
	var player := _player_at(Vector2.ZERO)
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	var authority := TestWorld.arm(player, [], _track)
	authority.drops_enabled = true
	var world := {"player": player, "authority": authority, "events": [] as Array[Dictionary]}
	authority.game_event.connect(func(code: String, params: Dictionary) -> void:
		(world["events"] as Array[Dictionary]).append({"code": code, "params": params}))
	if with_field:
		var field := WorkbenchField.new()
		_track.call(field)
		field.authority = authority
		authority.crafting.workbenches = field
		world["field"] = field
	return world


func _codes(world: Dictionary) -> Array[String]:
	var codes: Array[String] = []
	for event: Dictionary in world["events"]:
		codes.append(str(event["code"]))
	return codes


func _give_axe_materials(player: Player) -> void:
	player.inventory.add(Items.WOOD, 3)
	player.inventory.add(Items.STONE, 2)
	player.inventory.add(Items.FIBER, 1)


func _run_job(authority: WorldAuthority, seconds: float) -> void:
	authority.crafting.tick(seconds)


# ----------------------------------------------------------------------------- dados

func _test_recipe_data() -> void:
	var book := RecipeBook.with_defaults()
	var expected := {
		"wooden_spear": {Items.STICK: 2, Items.WOOD: 3},
		"axe_stone": {Items.WOOD: 3, Items.STONE: 2, Items.FIBER: 1},
		"pickaxe_stone": {Items.WOOD: 3, Items.STONE: 3, Items.FIBER: 1},
		"sleep_staff": {Items.WOOD: 3, Items.FIBER: 2},
		"workbench": {Items.WOOD: 8, Items.STONE: 2},
	}
	var ok := book.all().size() == expected.size()
	for recipe_id: String in expected:
		var recipe := book.find(recipe_id)
		ok = ok and recipe != null and recipe.is_valid() and recipe.output_id == recipe_id and recipe.station == "hand" \
				and recipe.known_at_start and recipe.inputs.size() == (expected[recipe_id] as Dictionary).size()
		if recipe != null:
			for item_id: String in expected[recipe_id]:
				ok = ok and int(recipe.inputs.get(item_id, 0)) == int(expected[recipe_id][item_id])
	_check(ok, "receitas da E7a em dados: Lança, Machado, Picareta, Bastão e Bancada com os números de receitas.md")
	_check(book.find("workbench").seconds == 4.0 and Items.durability_max(SPEAR) == 80
			and Items.weapon_of(SPEAR).damage == 12.0, "Bancada leva 4 s; Lança: dano 12 e durabilidade 80 em dados")
	var broken := RecipeDef.new()
	broken.id = "x"
	_check(not book.add(broken), "receita sem material ou saída não entra no livro")


# ----------------------------------------------------------------------------- pedidos negados

func _test_missing_material() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.add(Items.WOOD, 2)  # falta madeira, pedra e fibra
	var before := JSON.stringify(player.inventory.to_dict())
	var result := authority.request_craft(1, "axe_stone")
	_check(result == Enums.ActionResult.REFUSED and authority.crafting.job(1).is_empty()
			and JSON.stringify(player.inventory.to_dict()) == before and "craft_started" not in _codes(world),
			"falta de material: recusa, nada começa e nada muda")
	_check(GameMessages.reason_text("missing_materials") != "" and "action_refused" in _codes(world), "a recusa vai ao log")


func _test_unknown_and_locked_recipe() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_give_axe_materials(player)
	_check(authority.request_craft(1, "nao_existe") == Enums.ActionResult.INVALID_ARGUMENT
			and authority.request_craft(1, "x".repeat(200)) == Enums.ActionResult.INVALID_ARGUMENT,
			"receita que não existe (ou id gigante) é pedido inválido")
	var locked := RecipeDef.new()
	locked.id = "secret"
	locked.inputs = {Items.WOOD: 1}
	locked.output_id = Items.FIBER
	locked.known_at_start = false
	authority.crafting.recipe_book.add(locked)
	_check(authority.request_craft(1, "secret") == Enums.ActionResult.REFUSED and authority.crafting.job(1).is_empty(),
			"receita não conhecida: recusada")
	_check(authority.request_craft(1, "axe_stone") == RESULT_OK and authority.request_craft(1, "axe_stone") == Enums.ActionResult.WRONG_STATE,
			"uma fabricação por vez")


func _test_unknown_actor_and_client_panel() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_give_axe_materials(player)
	_check(authority.request_craft(9999, "axe_stone") == Enums.ActionResult.UNKNOWN_ACTOR and authority.crafting.job(9999).is_empty(),
			"ator que a autoridade não conhece não fabrica")
	# O cliente (painel) só manda o pedido: sem a autoridade ligada, clicar não muda inventário nenhum.
	var panel := CraftPanel.new()
	_track.call(panel)
	panel.player = player
	_root.add_child(panel)
	var asked: Array[String] = []
	panel.craft_requested.connect(func(recipe_id: String) -> void: asked.append(recipe_id))
	panel.set_open(true)
	panel.refresh()  # sem autoridade: não quebra e não muda nada
	var before := JSON.stringify(player.inventory.to_dict())
	panel.craft_requested.emit("axe_stone")
	authority.crafting.tick(100.0)
	_check(asked == ["axe_stone"] and JSON.stringify(player.inventory.to_dict()) == before and player.inventory.count(Items.AXE_STONE) == 0,
			"o cliente não fabrica sem a autoridade: o pedido é só um sinal")


func _test_panel_lists_and_progress() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.add(Items.WOOD, 3)
	player.inventory.add(Items.STONE, 1)
	var panel := CraftPanel.new()
	_track.call(panel)
	panel.player = player
	panel.authority = authority
	_root.add_child(panel)
	panel.set_open(true)
	var recipe := authority.crafting.recipe_book.find("axe_stone")
	_check(panel.visible and CraftPanel.needs_text(recipe, player.inventory) == "Madeira 3/3, !Pedra 1/2, !Fibra 0/1",
			"o painel mostra o que falta de material")
	_check(panel._list.get_child_count() == authority.crafting.recipe_book.known().size(), "o painel lista as receitas conhecidas")
	player.inventory.add(Items.STONE, 1)
	player.inventory.add(Items.FIBER, 1)
	panel.refresh()
	var button := (panel._list.get_child(1) as HBoxContainer).get_child(1) as Button
	_check(not button.disabled, "com o material, o botão de fabricar fica ativo")
	var asked: Array[String] = []
	panel.craft_requested.connect(func(recipe_id: String) -> void: asked.append(recipe_id))
	button.pressed.emit()
	_check(asked == ["axe_stone"] and authority.crafting.job(1).is_empty(), "clicar só manda o pedido (a UI não muda estado)")
	authority.request_craft(1, "axe_stone")
	authority.crafting.tick(1.5)
	panel._process(0.0)
	_check(is_equal_approx(panel._progress.value, 0.5), "a barra segue o progresso da autoridade")
	TestWorld.kill(player)
	panel._process(0.0)
	_check(not panel.visible, "caído, o painel fecha")


# ----------------------------------------------------------------------------- fabricar

func _test_craft_completes_and_gives_xp() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_give_axe_materials(player)
	var xp_before := player.progression.xp
	_check(authority.request_craft(1, "axe_stone") == RESULT_OK and not authority.crafting.job(1).is_empty(), "pedido aceito")
	_check(player.inventory.count(Items.WOOD) == 3, "o material só sai no fim (nada gasto no início)")
	_run_job(authority, 1.5)
	_check(is_equal_approx(authority.crafting.progress(1), 0.5) and player.inventory.count(Items.AXE_STONE) == 0,
			"na metade: 50% e nada entregue")
	_run_job(authority, 2.0)
	var axe := player.inventory.count(Items.AXE_STONE)
	_check(axe == 1 and player.inventory.count(Items.WOOD) == 0 and player.inventory.count(Items.STONE) == 0
			and player.inventory.count(Items.FIBER) == 0 and authority.crafting.job(1).is_empty(),
			"concluída: o Machado entra e o material sai")
	_check(player.progression.xp == xp_before + 2, "a fabricação concede +2 de XP")
	_check(_codes(world).filter(func(code: String) -> bool: return code.begins_with("craft_")) == ["craft_started", "craft_done"],
			"log: craft_started e craft_done")
	var slot := player.inventory.get_slot(player.inventory.index_of_iid(str(_first_iid(player, Items.AXE_STONE))))
	_check(int(slot["durab"]) == 150, "o Machado nasce com a durabilidade dos dados (150)")


func _first_iid(player: Player, item_id: String) -> String:
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		if slot.get("id", "") == item_id:
			return str(slot["iid"])
	return ""


func _test_cancel_by_walking_and_falling() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_give_axe_materials(player)
	authority.request_craft(1, "axe_stone")
	authority.request_move(1, Vector2.ZERO)  # parado não cancela
	_run_job(authority, 1.0)
	_check(not authority.crafting.job(1).is_empty(), "parado, a fabricação segue")
	authority.request_move(1, Vector2.RIGHT)
	var cancelled: Dictionary = {}
	for event: Dictionary in world["events"]:
		if event["code"] == "craft_cancelled":
			cancelled = event["params"]
	_check(authority.crafting.job(1).is_empty() and cancelled.get("reason") == "moved", "andar cancela (motivo moved)")
	_run_job(authority, 10.0)
	_check(player.inventory.count(Items.AXE_STONE) == 0 and player.inventory.count(Items.WOOD) == 3
			and player.inventory.count(Items.STONE) == 2 and player.inventory.count(Items.FIBER) == 1,
			"cancelada: nada entregue e todo o material continua com o jogador (reembolso coerente)")
	authority.request_move(1, Vector2.ZERO)
	authority.request_craft(1, "axe_stone")
	TestWorld.kill(player)  # cai
	_check(player.is_incapacitated() and authority.crafting.job(1).is_empty(), "cair cancela")
	var reasons: Array[String] = []
	for event: Dictionary in world["events"]:
		if event["code"] == "craft_cancelled":
			reasons.append(str(event["params"].get("reason")))
	_check(reasons == ["moved", "downed"], "motivos no log: moved, downed")
	var again := _setup()
	var other: Player = again["player"]
	_give_axe_materials(other)
	(again["authority"] as WorldAuthority).request_craft(1, "axe_stone")
	other.inventory.remove(Items.WOOD, 3)  # gastou o material no meio: a fabricação não conclui
	(again["authority"] as WorldAuthority).crafting.tick(5.0)
	_check(other.inventory.count(Items.AXE_STONE) == 0 and "craft_done" not in _codes(again), "sem o material no fim, cancela sem entregar")


func _test_workbench_range() -> void:
	var world := _setup(true)
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var field: WorkbenchField = world["field"]
	var bench_recipe := RecipeDef.new()
	bench_recipe.id = "bench_only"
	bench_recipe.inputs = {Items.WOOD: 1}
	bench_recipe.output_id = Items.FIBER
	bench_recipe.station = RecipeDef.STATION_WORKBENCH
	bench_recipe.seconds = 4.0
	authority.crafting.recipe_book.add(bench_recipe)
	player.inventory.add(Items.WOOD, 5)
	_check(authority.request_craft(1, "bench_only") == Enums.ActionResult.OUT_OF_RANGE and authority.crafting.job(1).is_empty(),
			"receita de Bancada sem Bancada por perto: recusada")
	field.place(Vector2(40.0, 8.0))  # centro (40, 8): a 40 px do jogador em (0,0): 2,5 tiles
	_check(authority.request_craft(1, "bench_only") == Enums.ActionResult.OUT_OF_RANGE, "a 2,5 tiles: longe demais")
	field.place(Vector2(24.0, 8.0))  # centro (24, 8): ~25,3 px = 1,58 tile
	_check(authority.request_craft(1, "bench_only") == RESULT_OK, "a menos de 2 tiles: aceita")
	_run_job(authority, 3.9)
	_check(player.inventory.count(Items.FIBER) == 0, "a 4 s de trabalho, ainda não acabou")
	_run_job(authority, 0.2)
	_check(player.inventory.count(Items.FIBER) == 1 and player.inventory.count(Items.WOOD) == 4, "na Bancada leva 4 s")
	authority.request_craft(1, "bench_only")
	player.position = Vector2(200.0, 0.0)  # empurrado para longe (sem andar por pedido)
	authority.crafting.tick(0.1)
	_check(authority.crafting.job(1).is_empty() and "craft_cancelled" in _codes(world), "afastar-se da Bancada cancela")


func _test_inventory_full_drops() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var entries: Array[Dictionary] = []
	authority.crafting.entry_dropped.connect(func(entry: Dictionary, _at: Vector2, _who: String) -> void: entries.append(entry))
	player.inventory.add(Items.WOOD, 10)
	player.inventory.add(Items.STONE, 10)
	player.inventory.add(Items.FIBER, 10)
	player.inventory.capacity = 3  # as três pilhas continuam cheias de sobra depois do gasto: sem lugar para o Machado
	_check(player.inventory.room_for(Items.AXE_STONE) == 0, "inventário sem lugar para o Machado")
	authority.request_craft(1, "axe_stone")
	_run_job(authority, 3.5)
	_check(player.inventory.count(Items.AXE_STONE) == 0 and entries.size() == 1 and entries[0]["id"] == Items.AXE_STONE
			and int(entries[0]["durab"]) == 150 and str(entries[0]["iid"]) != "", "inventário cheio: o Machado cai no chão, com a durabilidade")
	_check(player.inventory.count(Items.WOOD) == 7 and "craft_done" in _codes(world), "o material foi gasto e a fabricação concluiu")
	# sem chão ligado e sem lugar, o pedido é recusado para não perder item
	var closed := _setup()
	var other: Player = closed["player"]
	var closed_authority: WorldAuthority = closed["authority"]
	closed_authority.drops_enabled = false
	other.inventory.add(Items.WOOD, 10)
	other.inventory.add(Items.STONE, 10)
	other.inventory.add(Items.FIBER, 10)
	other.inventory.capacity = 3
	_check(closed_authority.request_craft(1, "axe_stone") == Enums.ActionResult.REFUSED, "sem chão e sem lugar: recusa (nada se perde)")


# ----------------------------------------------------------------------------- colocar

func _test_place_rules() -> void:
	var world := _setup(true)
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var field: WorkbenchField = world["field"]
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(24, 0)) == Enums.ActionResult.REFUSED and field.count() == 0,
			"sem o item, não coloca")
	player.inventory.add(Items.WORKBENCH, 2)
	_check(authority.request_place(1, Items.WOOD, Vector2(24, 0)) == Enums.ActionResult.INVALID_ARGUMENT
			and authority.request_place(1, Items.WORKBENCH, Vector2(INF, 0)) == Enums.ActionResult.INVALID_ARGUMENT
			and authority.request_place(1, Items.WORKBENCH, Vector2(NAN, 0)) == Enums.ActionResult.INVALID_ARGUMENT,
			"item que não se coloca e número não finito são pedido inválido")
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(400, 0)) == Enums.ActionResult.OUT_OF_RANGE, "longe demais do ponto")
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(24, 0)) == RESULT_OK and field.count() == 1
			and player.inventory.count(Items.WORKBENCH) == 1, "coloca e gasta 1 do inventário")
	var bench := field.bench_at(Vector2(24, 0))
	_check(bench != null and bench.position == Vector2(24, 8) and authority.id_of(bench) > 0, "no centro do tile, registrada na autoridade")
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(26, 3)) == Enums.ActionResult.WRONG_STATE and field.count() == 1
			and player.inventory.count(Items.WORKBENCH) == 1, "sobrepor outra Bancada (mesmo tile) é recusado e nada se gasta")
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(8, 8)) == Enums.ActionResult.OK, "tile vizinho serve")
	var occupied := ((world["field"] as WorkbenchField).problem_at(Vector2(24, 0)))
	_check(occupied == WorkbenchField.REASON_OCCUPIED, "o motivo é 'occupied'")
	var capped := _setup(true)
	var capped_field: WorkbenchField = capped["field"]
	capped_field.rules = CraftRules.new()
	capped_field.rules.max_workbenches = 1
	(capped["player"] as Player).inventory.add(Items.WORKBENCH, 1)
	capped_field.place(Vector2(100, 100))
	_check((capped["authority"] as WorldAuthority).request_place(1, Items.WORKBENCH, Vector2(24, 0)) == Enums.ActionResult.WRONG_STATE,
			"teto de peças no mundo")


func _test_place_in_safe_core_and_sea() -> void:
	var map := IslandMap.default_map()
	var world := _setup(true)
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var field: WorkbenchField = world["field"]
	field.map = map
	field.safe_core = SafeCore.new(RESPAWN, 8.0, TILE)
	player.inventory.add(Items.WORKBENCH, 3)
	var core_point := RESPAWN.available_regions()[0].area.get_center()
	player.position = core_point
	_check(field.problem_at(core_point + Vector2(TILE, 0)) == WorkbenchField.REASON_SAFE_CORE
			and authority.request_place(1, Items.WORKBENCH, core_point + Vector2(TILE, 0)) == Enums.ActionResult.WRONG_STATE,
			"dentro do núcleo seguro: recusado")
	var sea := Vector2(-TILE, -TILE)  # fora do mapa: nem terra nem andável
	player.position = sea
	_check(field.problem_at(sea) == WorkbenchField.REASON_TERRAIN
			and authority.request_place(1, Items.WORKBENCH, sea) == Enums.ActionResult.WRONG_STATE and field.count() == 0,
			"terreno não andável: recusado")
	var free_point := Vector2.ZERO
	var found := false
	for y in range(40, map.size - 40, 12):
		for x in range(40, map.size - 40, 12):
			var point := map.center_of(Vector2i(x, y))
			if map.is_land(Vector2i(x, y)) and not field.safe_core.contains(point):
				free_point = point
				found = true
				break
		if found:
			break
	player.position = free_point
	_check(found and field.problem_at(free_point) == "" and authority.request_place(1, Items.WORKBENCH, free_point) == RESULT_OK,
			"em terra firme e fora do núcleo: coloca")


func _test_workbench_save() -> void:
	var world := _setup(true)
	var authority: WorldAuthority = world["authority"]
	var field: WorkbenchField = world["field"]
	var first := field.place(Vector2(40, 40))
	field.place(Vector2(100, 56))
	var first_id := authority.id_of(first)
	var saved: Array = JSON.parse_string(JSON.stringify(field.to_list()))
	var other := _setup(true)
	var other_field: WorkbenchField = other["field"]
	other_field.place(Vector2(5, 5))  # o que havia some: a lista salva manda
	other_field.restore_list(saved)
	var restored := other_field.bench_at(Vector2(40, 40))
	_check(other_field.count() == 2 and restored != null and restored.position == first.position
			and (other["authority"] as WorldAuthority).id_of(restored) == first_id and other_field.bench_at(Vector2(100, 56)) != null
			and other_field.bench_at(Vector2(5, 5)) == null, "save e load da Bancada: posições e ids voltam, o resto sai")
	other_field.restore_list([{"x": "lixo", "y": 3}, 5, {"x": 1e30, "y": 0}, {"x": 8, "y": 8}, {"x": 8, "y": 8}, {}])
	_check(other_field.count() == 2 and other_field.bench_at(Vector2(8, 8)) != null,
			"dado ruim: entrada inválida cai fora, coordenada gigante é limitada e o tile repetido vale uma vez")
	_check(not (other["events"] as Array).any(func(event: Dictionary) -> bool: return str(event["code"]).begins_with("craft_") \
			or event["code"] == "item_placed"), "restaurar não dispara evento de jogo")


## Save editado: Bancada no mar ou no núcleo seguro é descartada e id no teto não empurra o contador (o próximo load seria recusado).
func _test_restore_validates_saved_benches() -> void:
	var map := IslandMap.default_map()
	var world := _setup(true)
	var authority: WorldAuthority = world["authority"]
	var field: WorkbenchField = world["field"]
	field.map = map
	field.safe_core = SafeCore.new(RESPAWN, 8.0, TILE)
	var core_point := RESPAWN.available_regions()[0].area.get_center()
	var land := _land_point(map, field)
	field.restore_list([{"id": 0, "x": -TILE, "y": -TILE}, {"id": 0, "x": core_point.x, "y": core_point.y},
			{"id": 1 << 30, "x": land.x, "y": land.y}])
	_check(field.count() == 1 and field.bench_at(land) != null, "restaurar descarta Bancada no mar e no núcleo seguro, e guarda a boa")
	_check(authority.id_of(field.bench_at(land)) < SaveMigrations.MAX_ENTITY_ID - 1
			and authority.next_entity_id() < SaveMigrations.MAX_ENTITY_ID, "id no teto vira o próximo livre: o contador não dispara")
	var ground := GroundItemField.new()
	_track.call(ground)
	ground.authority = authority
	ground.clock = func() -> float: return 0.0
	ground.restore_list([{"id": 1 << 30, "item": Items.WOOD, "amount": 2, "x": 5, "y": 5, "due_at": 10.0}])
	_check(ground.count() == 1 and authority.next_entity_id() < SaveMigrations.MAX_ENTITY_ID,
			"chão: id no teto também não empurra o contador")


## Um ponto de terra firme fora do núcleo seguro.
func _land_point(map: IslandMap, field: WorkbenchField) -> Vector2:
	for y in range(40, map.size - 40, 12):
		for x in range(40, map.size - 40, 12):
			var point := map.center_of(Vector2i(x, y))
			if map.is_land(Vector2i(x, y)) and not field.safe_core.contains(point):
				return point
	return Vector2.ZERO


func _test_navigation_blocks_bench() -> void:
	var map := IslandMap.default_map()
	var world := _setup(true)
	var field: WorkbenchField = world["field"]
	field.map = map
	field.safe_core = SafeCore.new(RESPAWN, 8.0, TILE)
	var navigation := NavigationWorld.new()
	_track.call(navigation)
	navigation.setup(map, preload("res://data/world/world_rules.tres"), preload("res://data/balance/navigation_rules.tres"), null)
	navigation.watch_workbenches(field)
	var point := _land_point(map, field)
	var cell := map.cell_of(point)
	_check(not navigation.provider.is_blocked(cell), "preparo: o tile está livre na grade")
	var bench := field.place(point)
	_check(navigation.provider.is_blocked(cell), "colocar a Bancada bloqueia o tile na grade dos dinos")
	field.remove(bench)
	_check(not navigation.provider.is_blocked(cell), "remover libera o tile")
	field.place(point)
	field.restore_list([])  # carregar um save sem a Bancada
	_check(not navigation.provider.is_blocked(cell), "carregar um save que troca as Bancadas libera o tile")


## Alcance de colocar até o centro do tile, saída que cabe depois de gastar o material, desconexão e load no meio da fabricação.
func _test_craft_edge_cases() -> void:
	var world := _setup(true)
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.add(Items.WORKBENCH, 1)
	# Ponto a 48 px (3 tiles, cabia) mas o centro do tile fica a 56 px: pelo centro não alcança.
	_check(authority.request_place(1, Items.WORKBENCH, Vector2(48.0, 0.0)) == Enums.ActionResult.OUT_OF_RANGE,
			"o alcance de colocar vai até o centro do tile, não até o ponto pedido")
	# Sem chão: material 1 pilha só, o resultado entra no lugar que ela libera.
	var closed := _setup()
	var other: Player = closed["player"]
	var closed_authority: WorldAuthority = closed["authority"]
	closed_authority.drops_enabled = false
	other.inventory.add(Items.WOOD, 3)
	other.inventory.add(Items.STONE, 2)
	other.inventory.add(Items.FIBER, 1)
	other.inventory.capacity = 3  # cheio, mas as três pilhas somem ao gastar o material
	_check(closed_authority.request_craft(1, "axe_stone") == RESULT_OK, "cheio, mas o material libera o lugar: aceita")
	closed_authority.crafting.tick(3.5)
	_check(other.inventory.count(Items.AXE_STONE) == 1, "e o Machado entra no lugar que o material liberou")
	# Desconectar no meio.
	var dropped := _setup()
	var leaver: Player = dropped["player"]
	var drop_authority: WorldAuthority = dropped["authority"]
	_give_axe_materials(leaver)
	drop_authority.request_craft(1, "axe_stone")
	drop_authority.unregister(1)
	drop_authority.crafting.tick(0.1)
	var reasons: Array[String] = []
	for event: Dictionary in dropped["events"]:
		if event["code"] == "craft_cancelled":
			reasons.append(str(event["params"].get("reason")))
	_check(reasons == ["disconnected"] and drop_authority.crafting.job(1).is_empty(),
			"desconectar no meio cancela com o motivo `disconnected`")
	# Load na mesma sessão.
	var loaded := _setup()
	var loader: Player = loaded["player"]
	var load_authority: WorldAuthority = loaded["authority"]
	_give_axe_materials(loader)
	var envelope := WorldSnapshot.capture(loader, null, "t", "now", null, 0, 10)
	load_authority.request_craft(1, "axe_stone")
	_check(WorldSnapshot.restore(JSON.parse_string(JSON.stringify(envelope)), loader, null, null, null, null, load_authority)
			and load_authority.crafting.job(1).is_empty(), "carregar um save na mesma sessão cancela a fabricação em curso")
	var panel := CraftPanel.new()  # painel fechado não reconstrói; aberto, só quando a lista muda
	_track.call(panel)
	panel.player = loader
	panel.authority = load_authority
	_root.add_child(panel)
	panel.refresh()
	_check(panel._list.get_child_count() == 0, "painel fechado não reconstrói os botões")
	panel.set_open(true)
	var first := panel._list.get_child(0)
	panel.refresh()
	_check(panel._list.get_child(0) == first, "painel aberto com a lista igual mantém os botões")
	loader.inventory.add(Items.FIBER, 1)
	panel.refresh()
	_check(panel._list.get_child(0) != first, "a lista mudou: reconstrói")


func _test_workbench_snapshot_and_old_save() -> void:
	var world := _setup(true)
	var player: Player = world["player"]
	var field: WorkbenchField = world["field"]
	field.place(Vector2(72, 72))
	var envelope := WorldSnapshot.capture(player, null, "t", "now", null, 0, 10, null, null, 0.0, null, null, field)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	_check(parsed["world"]["workbenches"].size() == 1 and SaveManager.validate_envelope(parsed) == "",
			"o envelope leva as Bancadas e segue válido")
	var other := _setup(true)
	var other_field: WorkbenchField = other["field"]
	other_field.place(Vector2(1, 1))
	_check(WorldSnapshot.restore(parsed, other["player"], null, null, null, null, other["authority"], null, null, other_field)
			and other_field.count() == 1 and other_field.bench_at(Vector2(72, 72)) != null, "WorldSnapshot.restore recoloca a Bancada")
	var old: Dictionary = parsed.duplicate(true)
	(old["world"] as Dictionary).erase("workbenches")  # save anterior à E7a
	_check(WorldSnapshot.restore(old, other["player"], null, null, null, null, other["authority"], null, null, other_field)
			and other_field.count() == 0, "save sem a lista (anterior à E7a) carrega, sem Bancada")


# ----------------------------------------------------------------------------- Lança

## Fonte de graveto (provisória): a árvore rende 1 graveto a cada 2 de madeira, em dado e sem sorteio.
func _test_tree_gives_stick() -> void:
	_check(TREE_DEF.extra_yields.get(Items.STICK, 0) == TREE_DEF.yield_amount / 2, "dado: a árvore dá 1 graveto a cada 2 de madeira")
	var component := ResourceNodeComponent.new()
	_track.call(component)
	component.def = TREE_DEF
	var yields := component.full_yields()
	_check(yields.get(Items.WOOD) == 3 and yields.get(Items.STICK) == 1 and component.full_yields() == yields,
			"a colheita da árvore entrega 3 madeira e 1 graveto, sempre igual")
	var world := _setup()
	var player: Player = world["player"]
	player.inventory.add(Items.WOOD, 3 * 2)
	for _tree in 2:  # duas árvores: os 2 gravetos da Lança
		player.inventory.add(Items.STICK, int(yields[Items.STICK]))
	var authority: WorldAuthority = world["authority"]
	authority.crafting.begin_craft(1, "wooden_spear")
	authority.crafting.tick(3.5)
	_check(player.inventory.count(SPEAR) == 1, "a Lança sai com a madeira e os gravetos de duas árvores")


func _test_spear_kills_dodo_in_two_hits() -> void:
	var player := _player_at(Vector2.ZERO)
	var dino := _dino_at(Vector2(0, 20))
	dino.health.max_health = 24.0  # vida do Dodo (GDD 6.1): a espécie ainda não existe nos dados do jogo
	var authority := TestWorld.arm(player, [dino], _track)
	player.facing = Vector2.DOWN
	player.inventory.add(SPEAR, 1)
	player.equipment.equip(_first_iid(player, SPEAR), EquipmentLayout.WEAPON)
	player.tick(1.0)
	var first := authority.request_attack(1, authority.id_of(dino))
	_check(first == RESULT_OK and not dino.health.is_dead() and is_equal_approx(dino.health.current_health, 12.0),
			"1o golpe: 12 de dano, o Dodo vive")
	player.tick(1.0)
	var second := authority.request_attack(1, authority.id_of(dino))
	_check(second == RESULT_OK and dino.health.is_dead(), "2o golpe: o Dodo (vida 24) morre em 2 golpes")
	var crafted := _setup()
	var maker: Player = crafted["player"]
	maker.inventory.add(Items.STICK, 2)
	maker.inventory.add(Items.WOOD, 3)
	var maker_authority: WorldAuthority = crafted["authority"]
	maker_authority.request_craft(1, "wooden_spear")
	maker_authority.crafting.tick(3.5)
	_check(maker.inventory.count(SPEAR) == 1 and maker.inventory.count(Items.STICK) == 0, "a Lança sai da receita (2 graveto + 3 madeira)")
