# SPDX-License-Identifier: MIT
class_name BuildTests
extends AuthorityTests
## E8a: grade de construção (CON-01), fundação, parede e porta (CON-02 parte 1), modo construção (CON-03), save e Bancada no grid.

const OK := Enums.ActionResult.OK
const RESPAWN: RespawnRules = preload("res://data/balance/respawn_rules.tres")
const TILE := 16.0
const WOOD := Items.WOOD
## O jogador fica na célula (10, 10): a fundação em (11, 10) e a porta em (12, 10) estão ao alcance.
const HOME := Vector2i(10, 10)
const BASE_RULES: BuildRules = preload("res://data/balance/build_rules.tres")
const TREE_DEF: ResourceNodeDef = preload("res://data/resources/tree.tres")


func run() -> void:
	_test_data()
	_test_refusals()
	_test_terrain_core_resource_and_limit()
	_test_support_and_dependents()
	_test_remove_and_refund()
	_test_door()
	_test_door_owner_rules()
	_test_navigation_door()
	await _test_bodies_block_dino()
	_test_grid_save_roundtrip()
	_test_grid_save_garbage()
	_test_minimal_shelter_exact_cost()
	_test_bench_in_grid()
	_test_craft_panel_hides_pieces()
	_test_build_mode_ui()
	await _test_main_wiring_and_save()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

## Jogador em `HOME`, material de sobra, receitas do abrigo aprendidas, ocupação e campo ligados. Sem mapa (terreno livre).
func _setup(learn: bool = true, materials: bool = true) -> Dictionary:
	var player := _player_at(BuildTests.center(HOME))
	player.inventory.weight_limit = 0.0  # a obra pede mais que 50 kg de material; o Peso tem os testes dele (carry_tests)
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	if materials:
		player.inventory.add(WOOD, 100)
		player.inventory.add(Items.STONE, 20)
		player.inventory.add(Items.FIBER, 5)
	var authority := TestWorld.arm(player, [], _track)
	authority.drops_enabled = true
	var occupancy := TileOccupancy.new()
	var bodies: Array = [player]
	occupancy.add_source(func() -> Array: return bodies)
	var field := BuildField.new()
	_root.add_child(field)
	_track.call(field)
	field.authority = authority
	authority.build.setup(null, occupancy, null, null)
	field.attach(authority.build.grid, TILE)
	authority.crafting.workbenches = field
	var world := {"player": player, "authority": authority, "field": field, "bodies": bodies, "occupancy": occupancy,
			"events": [] as Array[Dictionary], "dropped": [] as Array}
	authority.game_event.connect(func(code: String, params: Dictionary) -> void:
		(world["events"] as Array[Dictionary]).append({"code": code, "params": params}))
	authority.items_dropped.connect(func(item_id: String, amount: int, _at: Vector2, _who: String) -> void:
		(world["dropped"] as Array).append([item_id, amount]))
	if learn:
		player.progression.grant_xp(1000000)
		authority.request_learn_recipe(1, "foundation")
	return world


static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Pede construir e devolve `{result, reason}` (o motivo vem do log; "" se aceitou).
func _ask(world: Dictionary, piece_id: String, cell: Vector2i, rotation: int = 0) -> Dictionary:
	var authority: WorldAuthority = world["authority"]
	var before: int = (world["events"] as Array).size()
	var result := authority.request_build(1, piece_id, cell, rotation)
	return {"result": result, "reason": _reason_since(world, before)}


func _reason_since(world: Dictionary, before: int) -> String:
	var events: Array = world["events"]
	for index in range(before, events.size()):
		if events[index]["code"] == "action_refused":
			return str(events[index]["params"]["reason"])
	return ""


## O estado que um pedido recusado não pode mudar: inventário e grade.
func _state(world: Dictionary) -> String:
	var inventory := JSON.stringify((world["player"] as Player).inventory.to_dict())
	return inventory + JSON.stringify((world["authority"] as WorldAuthority).build.grid.to_dict())


func _refused(world: Dictionary, piece_id: String, cell: Vector2i, rotation: int, expected: Enums.ActionResult, reason: String,
		label: String) -> void:
	var before := _state(world)
	var answer := _ask(world, piece_id, cell, rotation)
	_check(answer["result"] == expected and (answer["reason"] == reason or reason == "?") and _state(world) == before,
			"%s (%s): recusa e nada muda" % [label, answer["reason"]])


func _grid(world: Dictionary) -> BuildGrid:
	return (world["authority"] as WorldAuthority).build.grid


func _count(world: Dictionary, item_id: String) -> int:
	return (world["player"] as Player).inventory.count(item_id)


func _codes(world: Dictionary) -> Array[String]:
	var codes: Array[String] = []
	for event: Dictionary in world["events"]:
		codes.append(str(event["code"]))
	return codes


# ----------------------------------------------------------------------------- dados

func _test_data() -> void:
	var catalog := PieceCatalog.with_defaults()
	var book := RecipeBook.with_defaults()
	var ok := catalog.all().size() == 5
	for piece in catalog.all():
		ok = ok and piece.is_valid()
	_check(ok and catalog.find("wall").needs_support and catalog.find("door").toggleable and catalog.find("foundation").gives_support
			and catalog.find("workbench").item_id == Items.WORKBENCH, "o catálogo tem fundação, parede, porta e Bancada, válidos")
	_check(book.find("foundation").inputs == {WOOD: 3, Items.STONE: 1} and book.find("wall").inputs == {WOOD: 2}
			and book.find("door").inputs == {WOOD: 4, Items.FIBER: 1},
					"custos em dados: fundação 3 madeira + 1 pedra, parede 2, porta 4 + 1 fibra")
	var wood_total: int = 4 * 3 + 8 * 2 + 4
	_check(wood_total == 32 and 4 * 1 == 4 and book.find("foundation").places_in_world and book.find("wall").places_in_world
			and book.find("door").places_in_world and not book.find("workbench").places_in_world,
			"abrigo mínimo (4 fundações, 8 paredes, 1 porta) = 32 madeira, 4 pedra, 1 fibra; as peças se constroem no mundo")
	_check(book.find("chest").places_in_world and book.find("chest").is_known_at_start() and book.find("chest").inputs == {WOOD: 6}
			and catalog.find("chest").recipe_id == "chest" and catalog.find("chest").container_slots > 0,
			"Baú: receita conhecida (Saber 0), 6 madeira, vira peça do mundo e guarda")
	_check(BASE_RULES.tile_px == float(IslandMap.default_map().tile) and BASE_RULES.tile_px == 16.0
			and BASE_RULES.refund_percent == 100
			and BASE_RULES.support_radius == 1, "a grade usa o tile de 16 px do GDD e do mapa")
	var both := PieceDef.new()
	both.id = "x"
	both.display_name = "X"
	both.recipe_id = "wall"
	both.item_id = "workbench"
	var neither := PieceDef.new()
	neither.id = "y"
	neither.display_name = "Y"
	_check(not catalog.add(both) and not catalog.add(neither) and not catalog.add(null),
			"peça sem fonte de custo (ou com duas) não entra")


# ----------------------------------------------------------------------------- recusas

func _test_refusals() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var near := HOME + Vector2i(1, 0)
	_check(_ask(world, "foundation", near)["result"] == OK and _grid(world).has_piece(near), "preparo: a fundação em (11, 10) entra")
	_check(_count(world, WOOD) == 97 and _count(world, Items.STONE) == 19, "e gasta 3 madeira e 1 pedra")
	_check(authority.request_build(99, "foundation", near, 0) == Enums.ActionResult.UNKNOWN_ACTOR, "ator que não existe")
	_refused(world, "nope", near, 0, Enums.ActionResult.INVALID_ARGUMENT, "unknown_piece", "peça desconhecida")
	_refused(world, "x".repeat(200), near, 0, Enums.ActionResult.INVALID_ARGUMENT, "unknown_piece", "id gigante")
	_refused(world, "foundation", near + Vector2i(0, 1), 4, Enums.ActionResult.INVALID_ARGUMENT, "?", "rotação 4")
	_refused(world, "foundation", near + Vector2i(0, 1), -1, Enums.ActionResult.INVALID_ARGUMENT, "?", "rotação -1")
	_refused(world, "foundation", Vector2i(1 << 30, 0), 0, Enums.ActionResult.INVALID_ARGUMENT, "?", "célula absurda")
	_refused(world, "foundation", HOME + Vector2i(30, 0), 0, Enums.ActionResult.OUT_OF_RANGE, "out_of_range", "longe demais")
	_refused(world, "foundation", near, 0, Enums.ActionResult.WRONG_STATE, "occupied", "célula ocupada")
	_refused(world, "wall", HOME + Vector2i(3, 0), 0, Enums.ActionResult.WRONG_STATE, "no_support", "parede sem fundação por perto")
	_refused(world, "door", HOME + Vector2i(3, 0), 0, Enums.ActionResult.WRONG_STATE, "no_support", "porta sem fundação por perto")
	_refused(world, "wall", HOME, 0, Enums.ActionResult.WRONG_STATE, "body_in_way", "parede sobre o jogador")
	var dino := _dino_at(BuildTests.center(HOME + Vector2i(0, 1)))
	(world["bodies"] as Array).append(dino)
	_refused(world, "wall", HOME + Vector2i(0, 1), 0, Enums.ActionResult.WRONG_STATE, "body_in_way", "parede sobre um dino")
	(world["bodies"] as Array).erase(dino)
	_check(_ask(world, "wall", HOME + Vector2i(0, 1))["result"] == OK, "sem o dino, a mesma parede entra")
	player.inventory.remove(WOOD, 9999)
	player.inventory.add(WOOD, 1)
	_refused(world, "wall", HOME + Vector2i(1, 1), 0, Enums.ActionResult.REFUSED, "missing_materials", "falta madeira")
	_check("action_refused" in _codes(world) and GameMessages.reason_text("no_support") != ""
			and GameMessages.reason_text("body_in_way") != "",
			"as recusas vão ao log com texto")
	var locked := _setup(false)
	_refused(locked, "foundation", near, 0, Enums.ActionResult.REFUSED, "recipe_locked", "receita não aprendida")
	var down := _setup()
	TestWorld.kill(down["player"])
	_check((down["authority"] as WorldAuthority).request_build(1, "foundation", near, 0) == Enums.ActionResult.ACTOR_DEAD
			and _grid(down).count() == 0, "jogador caído não constrói")


func _test_terrain_core_resource_and_limit() -> void:
	var map := IslandMap.default_map()
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var core := SafeCore.new(RESPAWN, 8.0, TILE)
	authority.build.setup(map, world["occupancy"], core, null)
	player.position = BuildTests.center(Vector2i(-1, -1))
	_refused(world, "foundation", Vector2i(-1, -1), 0, Enums.ActionResult.WRONG_STATE, "bad_terrain", "no mar")
	var core_cell := authority.build.cell_of(RESPAWN.available_regions()[0].area.get_center())
	player.position = BuildTests.center(core_cell)
	_refused(world, "foundation", core_cell + Vector2i(1, 0), 0, Enums.ActionResult.WRONG_STATE, "safe_core",
			"dentro do núcleo seguro")
	var free := _land_cell(map, core)
	player.position = BuildTests.center(free)
	_check(_ask(world, "foundation", free + Vector2i(1, 0))["result"] == OK, "em terra firme e fora do núcleo: constrói")
	# Nó de recurso na célula.
	var resources := ResourceField.new()
	_root.add_child(resources)
	_track.call(resources)
	var tree: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	tree.node_id = "t1"
	tree.def = TREE_DEF
	var tree_cell := free + Vector2i(0, 1)
	tree.position = BuildTests.center(tree_cell)
	resources.add_node(tree)
	authority.build.resources = resources
	_refused(world, "foundation", tree_cell, 0, Enums.ActionResult.WRONG_STATE, "occupied", "sobre um nó de recurso")
	# Teto de peças.
	var capped := _setup()
	var rules: BuildRules = BASE_RULES.duplicate()  # o recurso é compartilhado: copia
	rules.max_pieces = 1
	(capped["authority"] as WorldAuthority).build.rules = rules
	_check(_ask(capped, "foundation", HOME + Vector2i(1, 0))["result"] == OK, "preparo: a primeira peça cabe")
	_refused(capped, "foundation", HOME + Vector2i(2, 0), 0, Enums.ActionResult.WRONG_STATE, "place_limit", "teto de peças")
	var in_core := BASE_RULES.duplicate()
	in_core.build_in_safe_core = true
	authority.build.rules = in_core
	player.position = BuildTests.center(core_cell)
	_check(_ask(world, "foundation", core_cell + Vector2i(1, 0))["result"] == OK,
			"com a regra `build_in_safe_core`, o núcleo deixa de recusar")


func _land_cell(map: IslandMap, core: SafeCore) -> Vector2i:
	for y in range(40, map.size - 40, 12):
		for x in range(40, map.size - 40, 12):
			var cell := Vector2i(x, y)
			if map.is_land(cell) and map.is_land(cell + Vector2i(1, 1)) and map.is_land(cell + Vector2i(1, 0)) \
					and map.is_land(cell + Vector2i(0, 1)) and not core.contains(map.center_of(cell + Vector2i(1, 1))):
				return cell
	return Vector2i.ZERO


# ----------------------------------------------------------------------------- apoio

func _test_support_and_dependents() -> void:
	var world := _setup()
	var grid := _grid(world)
	var first := HOME + Vector2i(1, 0)
	_ask(world, "foundation", first)
	_check(_ask(world, "wall", HOME + Vector2i(2, 1))["result"] == OK, "parede na diagonal da fundação: apoiada")
	_check(_ask(world, "door", HOME + Vector2i(2, 0))["result"] == OK, "porta ao lado da fundação: apoiada")
	_refused(world, "wall", HOME + Vector2i(3, 0), 0, Enums.ActionResult.WRONG_STATE, "no_support",
			"a 2 células da fundação, só com parede ao lado")
	_refused_remove(world, first, Enums.ActionResult.WRONG_STATE, "has_dependents",
			"a fundação que ainda apoia a porta e a parede fica")
	_check(_ask(world, "foundation", HOME + Vector2i(1, 1))["result"] == OK, "a fundação pode ficar em qualquer lugar livre")
	var authority: WorldAuthority = world["authority"]
	_check(authority.request_remove_piece(1, first) == OK and not grid.has_piece(first) and grid.has_piece(HOME + Vector2i(2, 0)),
			"com outra fundação que também apoia, a primeira pode sair")
	_refused_remove(world, HOME + Vector2i(1, 1), Enums.ActionResult.WRONG_STATE, "has_dependents",
			"a que sobrou agora segura a porta e a parede")
	authority.request_remove_piece(1, HOME + Vector2i(2, 1))
	authority.request_remove_piece(1, HOME + Vector2i(2, 0))
	_check(authority.request_remove_piece(1, HOME + Vector2i(1, 1)) == OK and grid.count() == 0, "sem ninguém apoiado, a fundação sai")


func _refused_remove(world: Dictionary, cell: Vector2i, expected: Enums.ActionResult, reason: String, label: String) -> void:
	var before := _state(world)
	var events_before: int = (world["events"] as Array).size()
	var result := (world["authority"] as WorldAuthority).request_remove_piece(1, cell)
	var got := _reason_since(world, events_before)
	_check(result == expected and got == reason and _state(world) == before, "%s (%s): recusa e nada muda" % [label, got])


# ----------------------------------------------------------------------------- remover e reembolso

func _test_remove_and_refund() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var cell := HOME + Vector2i(1, 0)
	_ask(world, "foundation", cell)
	_ask(world, "wall", HOME + Vector2i(2, 0))
	_ask(world, "door", HOME + Vector2i(2, 1))
	_check(_count(world, WOOD) == 100 - 3 - 2 - 4 and _count(world, Items.STONE) == 19 and _count(world, Items.FIBER) == 4,
			"preparo: material gasto")
	for piece_cell in [HOME + Vector2i(2, 1), HOME + Vector2i(2, 0)]:
		authority.request_remove_piece(1, piece_cell)
	_check(_count(world, WOOD) == 100 - 3 and _count(world, Items.FIBER) == 5, "parede e porta devolvem tudo (100%)")
	_check(authority.request_remove_piece(1, cell) == OK and _count(world, WOOD) == 100 and _count(world, Items.STONE) == 20
			and _grid(world).count() == 0, "a fundação devolve 3 madeira e 1 pedra: o inventário volta ao que era")
	_check("piece_removed" in _codes(world), "remover vai ao log (piece_removed)")
	_refused_remove(world, cell, Enums.ActionResult.INVALID_TARGET, "no_piece", "remover onde não há peça")
	_ask(world, "foundation", cell)
	player.position = BuildTests.center(HOME + Vector2i(20, 0))
	_refused_remove(world, cell, Enums.ActionResult.OUT_OF_RANGE, "out_of_range", "remover de longe")
	player.position = BuildTests.center(HOME)
	# Reembolso parcial por dado: floor(2 x 50%) = 1 e floor(1 x 50%) = 0.
	var half := _setup()
	var half_rules: BuildRules = BASE_RULES.duplicate()
	half_rules.refund_percent = 50
	(half["authority"] as WorldAuthority).build.rules = half_rules
	_ask(half, "foundation", cell)
	_ask(half, "door", HOME + Vector2i(2, 0))
	var wood_before := _count(half, WOOD)
	(half["authority"] as WorldAuthority).request_remove_piece(1, HOME + Vector2i(2, 0))
	_check(_count(half, WOOD) == wood_before + 2 and _count(half, Items.FIBER) == 4,
			"a 50%: porta devolve 2 de 4 madeira e 0 de 1 fibra")
	# O que não cabe cai no chão (com chão ligado); sem chão, a remoção é recusada e nada se perde.
	var full := _setup()
	_ask(full, "foundation", cell)
	var full_player: Player = full["player"]
	full_player.inventory.capacity = 1
	for item_id: String in [Items.STONE, Items.FIBER]:
		full_player.inventory.remove(item_id, 9999)
	full_player.inventory.add(WOOD, 9999)
	_check(full_player.inventory.room_for(WOOD) == 0, "preparo: o inventário não comporta mais madeira nem pedra")
	(full["authority"] as WorldAuthority).request_remove_piece(1, cell)
	_check((full["dropped"] as Array).size() == 2 and _grid(full).count() == 0,
			"inventário cheio: o reembolso cai no chão e a peça sai")
	var closed := _setup()
	_ask(closed, "foundation", cell)
	(closed["authority"] as WorldAuthority).drops_enabled = false
	var closed_player: Player = closed["player"]
	closed_player.inventory.capacity = 1
	closed_player.inventory.remove(Items.STONE, 9999)
	closed_player.inventory.add(WOOD, 9999)
	_refused_remove(closed, cell, Enums.ActionResult.REFUSED, "inventory_full", "sem chão e sem lugar")


# ----------------------------------------------------------------------------- porta

func _test_door() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var grid := _grid(world)
	var door := HOME + Vector2i(2, 0)
	_ask(world, "foundation", HOME + Vector2i(1, 0))
	_ask(world, "door", door)
	_check(grid.blocks(door) and not grid.is_open(door), "a porta nasce fechada e bloqueia")
	_check(authority.request_toggle_door(1, door) == OK and grid.is_open(door) and not grid.blocks(door), "abrir libera")
	_check(authority.request_toggle_door(1, door) == OK and not grid.is_open(door) and grid.blocks(door), "fechar bloqueia de novo")
	var toggled: Array[String] = []
	for event: Dictionary in world["events"]:
		if event["code"] == "door_toggled":
			toggled.append(GameMessages.text_of("door_toggled", event["params"]))
	_check(toggled == ["Porta de madeira: aberta.", "Porta de madeira: fechada."] and "piece_built" in _codes(world),
			"o log tem piece_built e door_toggled com o estado")
	authority.request_toggle_door(1, door)  # aberta
	var dino := _dino_at(BuildTests.center(door))
	(world["bodies"] as Array).append(dino)
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_toggle_door(1, door) == Enums.ActionResult.WRONG_STATE and grid.is_open(door)
			and _reason_since(world, events_before) == "body_in_way", "fechar com alguém na porta é recusado: ninguém fica preso")
	(world["bodies"] as Array).erase(dino)
	_check(authority.request_toggle_door(1, HOME + Vector2i(1, 0)) == Enums.ActionResult.INVALID_TARGET
			and authority.request_toggle_door(1, HOME + Vector2i(1, 5)) == Enums.ActionResult.INVALID_TARGET,
					"só porta abre: fundação e vazio não")
	(world["player"] as Player).position = BuildTests.center(HOME + Vector2i(15, 0))
	_check(authority.request_toggle_door(1, door) == Enums.ActionResult.OUT_OF_RANGE, "porta longe: fora de alcance")
	var piece_nodes := 0
	for child in (world["field"] as BuildField).get_children():
		piece_nodes += 1 if child is BuildPiece else 0
	_check(piece_nodes == 2, "o campo tem um nó por peça (fundação e porta)")


## [premissa] Sem trava de dono por padrão (solo e cooperativo livre); com `shared_pieces` falso só o dono abre e remove.
func _test_door_owner_rules() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var grid := _grid(world)
	grid.add(HOME + Vector2i(1, 0), "foundation", 0, "outro")
	grid.add(HOME + Vector2i(2, 0), "door", 0, "outro")
	_check(authority.request_toggle_door(1, HOME + Vector2i(2, 0)) == OK,
			"[premissa] porta de outro abre por padrão: peças compartilhadas")
	var strict: BuildRules = BASE_RULES.duplicate()
	strict.shared_pieces = false
	authority.build.rules = strict
	_check(authority.request_toggle_door(1, HOME + Vector2i(2, 0)) == Enums.ActionResult.NOT_OWNER
			and authority.request_remove_piece(1, HOME + Vector2i(2, 0)) == Enums.ActionResult.NOT_OWNER
			and grid.has_piece(HOME + Vector2i(2, 0)), "sem `shared_pieces`: porta e remoção de outro dono são recusadas")
	_check(_ask(world, "foundation", HOME + Vector2i(1, 1))["result"] == OK
			and authority.request_remove_piece(1, HOME + Vector2i(1, 1)) == OK, "as peças do próprio jogador seguem livres")


# ----------------------------------------------------------------------------- navegação e corpo

## Pedido de caminho num quadro novo (o teto de pedidos por quadro não pode virar `DEFERRED` no meio do teste).
func _path(navigation: NavigationWorld, from: Vector2i, to: Vector2i) -> PathResult:
	navigation.tick(1.0)
	return navigation.provider.request_path(from, to, Enums.DinoSize.SMALL)


func _test_navigation_door() -> void:
	var map := IslandMap.default_map()
	var core := SafeCore.new(RESPAWN, 8.0, TILE)
	var grid := BuildGrid.new()
	var navigation := NavigationWorld.new()
	_track.call(navigation)
	navigation.setup(map, preload("res://data/world/world_rules.tres"), preload("res://data/balance/navigation_rules.tres"), null)
	navigation.watch_build(grid, TILE)
	var center := _open_land(map, core)
	grid.add(center, "foundation")
	var door := center + Vector2i(1, 0)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := center + Vector2i(dx, dy)
			if cell != center and cell != door:
				grid.add(cell, "wall")
	grid.add(door, "door")
	var outside := center + Vector2i(4, 0)
	var closed := _path(navigation, outside, center)
	_check(navigation.provider.is_blocked(door) and navigation.provider.is_blocked(center + Vector2i(0, 1))
			and closed.status == PathResult.Status.NO_PATH,
			"anel de 8 peças com a porta fechada: sem caminho para dentro")
	grid.set_open(door, true)
	var opened := _path(navigation, outside, center)
	_check(not navigation.provider.is_blocked(door) and opened.is_ok() and opened.touches(door),
			"porta aberta libera a célula e o caminho passa por ela")
	grid.set_open(door, false)
	_check(navigation.provider.is_blocked(door) and _path(navigation, outside, center).status == PathResult.Status.NO_PATH,
			"fechar a porta bloqueia de novo")
	grid.remove(center + Vector2i(0, 1))
	_check(_path(navigation, outside, center).is_ok(), "remover uma parede abre um vão")
	grid.from_dict({})
	_check(not navigation.provider.is_blocked(door) and not navigation.provider.is_blocked(center + Vector2i(-1, 0)),
			"carregar um save sem as peças libera as células")


## Uma célula de terra firme com a vizinhança de 5x5 toda andável e fora do núcleo seguro.
func _open_land(map: IslandMap, core: SafeCore) -> Vector2i:
	for y in range(40, map.size - 40, 7):
		for x in range(40, map.size - 40, 7):
			var ok := true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var cell := Vector2i(x + dx, y + dy)
					ok = ok and map.is_land(cell) and not core.contains(map.center_of(cell))
			if ok:
				return Vector2i(x, y)
	return Vector2i.ZERO


func _test_bodies_block_dino() -> void:
	var world := _setup()
	var grid := _grid(world)
	var far := Vector2i(40, 40)
	grid.add(far, "foundation")
	grid.add(far + Vector2i(1, 0), "wall")
	grid.add(far + Vector2i(1, 2), "door")
	await _root.get_tree().physics_frame
	await _root.get_tree().physics_frame
	var wall_dino := _dino_at(BuildTests.center(far) + Vector2(-8.0, 0.0))
	var hit := wall_dino.move_and_collide(Vector2(40.0, 0.0))
	_check(hit != null and wall_dino.position.x < BuildTests.center(far + Vector2i(1, 0)).x - TILE * 0.5 + 0.5,
			"o dino não atravessa a parede (colisão real, não só a grade)")
	var door_dino := _dino_at(BuildTests.center(far + Vector2i(0, 2)))
	_check(door_dino.move_and_collide(Vector2(40.0, 0.0)) != null, "nem a porta fechada")
	door_dino.position = BuildTests.center(far + Vector2i(0, 2))
	grid.set_open(far + Vector2i(1, 2), true)
	await _root.get_tree().physics_frame
	await _root.get_tree().physics_frame
	var passed := door_dino.move_and_collide(Vector2(40.0, 0.0))
	_check(passed == null and door_dino.position.x > BuildTests.center(far + Vector2i(1, 2)).x, "a porta aberta deixa passar")
	var player: Player = world["player"]
	player.position = BuildTests.center(far) + Vector2(-8.0, 0.0)
	_check(player.move_and_collide(Vector2(40.0, 0.0)) != null, "o jogador também não atravessa a parede")


# ----------------------------------------------------------------------------- save

func _test_grid_save_roundtrip() -> void:
	var world := _setup()
	var grid := _grid(world)
	_ask(world, "foundation", HOME + Vector2i(1, 0))
	_ask(world, "wall", HOME + Vector2i(2, 1), 3)
	_ask(world, "door", HOME + Vector2i(2, 0), 1)
	(world["authority"] as WorldAuthority).request_toggle_door(1, HOME + Vector2i(2, 0))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(grid.to_dict()))
	var other := _setup()
	var restored := _grid(other)
	restored.add(Vector2i(0, 0), "foundation")  # o que havia some
	var changed: Array[String] = []
	restored.piece_removed.connect(func(_cell: Vector2i, _piece: Dictionary) -> void: changed.append("removed"))
	_check(restored.from_dict(saved) and JSON.stringify(JSON.parse_string(JSON.stringify(restored.to_dict()))) == JSON.stringify(saved)
			and changed.size() == 1,
			"to_dict e from_dict fazem o roundtrip por JSON (e a grade antiga sai)")
	_check(restored.is_open(HOME + Vector2i(2, 0)) and int(restored.piece_at(HOME + Vector2i(2, 1))["rot"]) == 3
			and str(restored.piece_at(HOME + Vector2i(2, 0))["owner"]) == (world["player"] as Player).player_id,
			"porta aberta, rotação e dono voltam")
	_check(not (other["events"] as Array).any(func(event: Dictionary) -> bool: return event["code"] in ["piece_built",
			"door_toggled"]),
			"restaurar não dispara evento de jogo")


func _test_grid_save_garbage() -> void:
	var grid := BuildGrid.new()
	var junk := {"pieces": [
		{"piece": "wall", "x": 6, "y": 5, "rot": 7},  # parede ANTES da fundação que a apoia: a ordem do arquivo não importa
		{"piece": "foundation", "x": 5, "y": 5},
		{"piece": "wall", "x": 50, "y": 50},  # sem apoio: cai
		{"piece": "nope", "x": 1, "y": 1}, 5, "texto", null, [], {},
		{"piece": "foundation", "x": 1e30, "y": 0}, {"piece": "foundation", "x": "7", "y": 0}, {"piece": "foundation", "x": 2.5,
				"y": 0},
		{"piece": "foundation", "x": NAN, "y": 0}, {"piece": "foundation", "x": 5},
		{"piece": "foundation", "x": 5, "y": 5},  # célula repetida
		{"piece": "wall", "x": 4, "y": 5, "open": true, "owner": "o".repeat(500), "id": 1 << 40},  # open em parede, dono gigante, id alto
		{"piece": "door", "x": 4, "y": 4, "open": true, "id": -3},
	]}
	_check(grid.from_dict(junk), "from_dict com lixo não recusa nem aborta")
	var kept := grid.to_dict()["pieces"] as Array
	_check(grid.count() == 4 and grid.has_piece(Vector2i(5, 5)) and grid.has_piece(Vector2i(6, 5)) and grid.has_piece(Vector2i(4, 5))
			and grid.has_piece(Vector2i(4, 4)) and not grid.has_piece(Vector2i(50, 50)) and not grid.has_piece(Vector2i(1, 1)),
			"fica só o que vale: lixo, desconhecida, fora da faixa, repetida e sem apoio caem (%d peças)" % kept.size())
	_check(int(grid.piece_at(Vector2i(6, 5))["rot"]) == 3 and not grid.is_open(Vector2i(4, 5)) and grid.is_open(Vector2i(4, 4))
			and str(grid.piece_at(Vector2i(4, 5))["owner"]).length() == BuildGrid.MAX_OWNER_LENGTH
			and int(grid.piece_at(Vector2i(4, 5))["id"]) == 0 and int(grid.piece_at(Vector2i(4, 4))["id"]) == 0,
			"saneado: rotação em módulo 4, só porta abre, dono limitado e id ruim vira 0")
	for bad: Variant in [null, 5, "x", [1], {"pieces": "texto"}, {"pieces": 3}]:
		var again := BuildGrid.new()
		again.add(Vector2i(0, 0), "foundation")
		again.from_dict(SafeRead.dict(bad))
		_check(again.count() == 0, "bloco `%s` não derruba: a grade sai vazia" % str(bad))
	var capped := BuildGrid.new()
	var rules: BuildRules = BASE_RULES.duplicate()
	rules.max_pieces = 3
	capped.rules = rules
	var many: Array = []
	for x in 10:
		many.append({"piece": "foundation", "x": x, "y": 0})
	capped.from_dict({"pieces": many})
	_check(capped.count() == 3, "o teto de peças vale também ao carregar")
	var filtered := BuildGrid.new()
	filtered.fixed_check = func(cell: Vector2i) -> String: return "bad_terrain" if cell.x < 0 else ""
	filtered.from_dict({"pieces": [{"piece": "foundation", "x": -1, "y": 0}, {"piece": "foundation", "x": 1, "y": 0}]})
	_check(filtered.count() == 1 and filtered.has_piece(Vector2i(1, 0)), "terreno ou núcleo que não servem descartam a peça do save")
	_check(BuildGrid.pieces_from_legacy_benches([{"x": 33.0, "y": 17.0, "id": 4}, {"x": 1e30, "y": 0}, {"x": INF, "y": 0}, "x",
			{"x": 1}], 16.0)
			== [{"piece": "workbench", "x": 2, "y": 1, "id": 4}], "a migração da Bancada converte pixel em célula e ignora lixo")


# ----------------------------------------------------------------------------- abrigo mínimo

func _test_minimal_shelter_exact_cost() -> void:
	var world := _setup(true, false)
	var player: Player = world["player"]
	player.inventory.add(WOOD, 32)
	player.inventory.add(Items.STONE, 4)
	player.inventory.add(Items.FIBER, 1)
	var grid := _grid(world)
	player.position = BuildTests.center(Vector2i(11, 11))  # no meio das fundações
	var origin := Vector2i(10, 10)
	var floor_cells: Array[Vector2i] = [origin, origin + Vector2i(1, 0), origin + Vector2i(0, 1), origin + Vector2i(1, 1)]
	# 8 paredes: 7 nas bordas e a oitava no canto (9, 9); a porta ocupa a borda (12, 10). Porta em canto não passa ninguém
	# (a navegação não corta quina), então o abrigo nunca teria entrada.
	var ring: Array[Vector2i] = [Vector2i(9, 10), Vector2i(9, 11), Vector2i(12, 11), Vector2i(10, 9), Vector2i(11, 9),
			Vector2i(10, 12), Vector2i(11, 12), Vector2i(9, 9)]
	var door_cell := Vector2i(12, 10)
	var ok := true
	for cell in floor_cells:
		ok = ok and _ask(world, "foundation", cell)["result"] == OK
	for cell in ring:
		ok = ok and _ask(world, "wall", cell)["result"] == OK
	var last_wood := _count(world, WOOD)
	_check(ok and last_wood == 4 and _count(world, Items.STONE) == 0 and _count(world, Items.FIBER) == 1,
			"4 fundações e 8 paredes custam 28 madeira e 4 pedra; sobram 4 madeira e 1 fibra")
	_check(_ask(world, "door", door_cell)["result"] == OK and _count(world, WOOD) == 0 and _count(world, Items.FIBER) == 0
			and grid.count() == 13 and grid.count_of("wall") == 8 and grid.count_of("foundation") == 4 and grid.count_of("door") == 1,
			"com a porta, o abrigo gasta exatamente 32 madeira, 4 pedra e 1 fibra e fica de pé")
	var provider := GridPathProvider.new()
	provider.setup(64, PackedByteArray())
	provider.end_bulk()
	var navigation := NavigationWorld.new()
	_track.call(navigation)
	navigation.provider = provider
	navigation.watch_build(grid, TILE)
	var outside := Vector2i(16, 10)
	var inside := Vector2i(11, 10)
	_check(grid.blocks(door_cell) and _path(navigation, outside, inside).status == PathResult.Status.NO_PATH,
			"abrigo mínimo com a porta fechada: sem rota até dentro")
	grid.set_open(door_cell, true)
	var through := _path(navigation, outside, inside)
	_check(through.is_ok() and through.touches(door_cell), "e com a porta aberta há rota até dentro, pela porta")
	# Um a menos de madeira: a última peça é recusada e o inventário fica inteiro.
	var short := _setup(true, false)
	var short_player: Player = short["player"]
	short_player.inventory.add(WOOD, 31)
	short_player.inventory.add(Items.STONE, 4)
	short_player.inventory.add(Items.FIBER, 1)
	short_player.position = BuildTests.center(Vector2i(11, 11))
	for cell in floor_cells:
		_ask(short, "foundation", cell)
	for cell in ring:
		_ask(short, "wall", cell)
	_refused(short, "door", door_cell, 0, Enums.ActionResult.REFUSED, "missing_materials", "31 madeira não fecha o abrigo")


# ----------------------------------------------------------------------------- Bancada no grid

func _test_bench_in_grid() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var field: BuildField = world["field"]
	player.inventory.add(Items.WORKBENCH, 1)
	var point := BuildTests.center(HOME + Vector2i(1, 0))
	_check(authority.request_place(1, Items.WORKBENCH, point) == OK and _grid(world).count_of("workbench") == 1
			and field.nearest_workbench(player.position, 40.0) != null, "a Bancada colocada vira peça do grid, com o nó na autoridade")
	var entry := _grid(world).piece_at(HOME + Vector2i(1, 0))
	_check(int(entry["id"]) == authority.id_of(field.bench_in(HOME + Vector2i(1, 0))) and _grid(world).blocks(HOME + Vector2i(1, 0)),
			"o id da entidade vai para a grade (o save o devolve) e a Bancada bloqueia")
	_check(authority.request_remove_piece(1, HOME + Vector2i(1, 0)) == OK and player.inventory.count(Items.WORKBENCH) == 1
			and field.count_benches() == 0, "remover a Bancada devolve o item e tira o nó")


func _test_craft_panel_hides_pieces() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	_check(authority.request_craft(1, "wall") == Enums.ActionResult.WRONG_STATE and authority.crafting.job(1).is_empty(),
			"fundação, parede e porta não se fabricam em item: constroem-se no mundo")
	var panel := CraftPanel.new()
	_track.call(panel)
	panel.player = player
	panel.authority = authority
	_root.add_child(panel)
	panel.set_open(true)
	var expected := 0
	for recipe in authority.crafting.recipe_book.known_by(player.progression):
		expected += 0 if recipe.places_in_world else 1
	_check(panel._list.get_child_count() == expected and expected > 0, "o painel de fabricação não lista as peças de construção")


# ----------------------------------------------------------------------------- modo construção (UI)

func _test_build_mode_ui() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var grid := _grid(world)
	var menu := BuildMenu.new()
	_root.add_child(menu)
	_track.call(menu)
	menu.catalog = grid.catalog
	menu.recipe_book = authority.crafting.recipe_book
	menu.player = player
	var mode := BuildMode.new()
	mode.authority = authority
	mode.player = player
	mode.menu = menu
	mode.follow_mouse = false
	_root.add_child(mode)
	_track.call(mode)
	BuildMode.ensure_actions()
	_check(InputMap.has_action(BuildMode.TOGGLE_MODE) and InputMap.has_action(BuildMode.ROTATE)
			and InputMap.has_action(BuildMode.TOGGLE_DOOR),
			"as ações B, R e T são criadas por código")
	var built: Array = []
	var removed: Array[Vector2i] = []
	var doors: Array[Vector2i] = []
	mode.build_requested.connect(func(piece_id: String, cell: Vector2i, rotation: int) -> void: built.append([piece_id, cell,
			rotation]))
	mode.remove_requested.connect(func(cell: Vector2i) -> void: removed.append(cell))
	mode.door_requested.connect(func(cell: Vector2i) -> void: doors.append(cell))
	_check(not mode.click(MOUSE_BUTTON_LEFT, Vector2.ZERO) and built.is_empty(), "com o modo desligado, o clique não faz nada")
	mode.set_active(true)
	_check(mode.active and menu.visible and menu._list.get_child_count() == 4,
			"B liga o modo e abre o menu com as 4 peças (fundação, parede, porta e Baú)")
	_check(menu.cost_text(grid.catalog.find("foundation")) == "Madeira 3/3, Pedra 1/1"
			and menu.cost_text(grid.catalog.find("door")) == "Madeira 4/4, Fibra 1/1", "o menu mostra o custo")
	mode.select("nope")
	_check(mode.selected == "", "peça desconhecida é ignorada")
	mode.select("foundation")
	mode.mouse_world = BuildTests.center(HOME + Vector2i(1, 0))
	mode._process(0.0)
	_check(mode.selected == "foundation" and mode.ghost_color() == BuildMode.OK_COLOR, "ghost verde onde a autoridade aceitaria")
	mode.select("wall")
	mode._process(0.0)
	_check(mode.ghost_color() == BuildMode.NO_COLOR, "ghost vermelho sem fundação por perto")
	mode.rotate_ghost()
	mode.rotate_ghost()
	_check(mode.rotation_steps == 2, "R gira o ghost")
	_check(mode.click(MOUSE_BUTTON_LEFT, BuildTests.center(HOME + Vector2i(1, 0)) + Vector2(3.0, -4.0))
			and built == [["wall", HOME + Vector2i(1, 0), 2]], "clique esquerdo pede a construção na célula do mouse, com a rotação")
	_check(grid.count() == 0 and _count(world, WOOD) == 100, "a UI só pede: sem a Main ligando o pedido, nada muda no mundo")
	grid.add(HOME + Vector2i(1, 0), "foundation")
	grid.add(HOME + Vector2i(2, 0), "door")
	mode.select("wall")  # desliga a escolha
	_check(mode.selected == "" and mode.click(MOUSE_BUTTON_LEFT, BuildTests.center(HOME + Vector2i(2, 0))) and doors == [HOME +
			Vector2i(2, 0)],
			"sem peça escolhida, o clique esquerdo numa porta pede abrir")
	_check(mode.click(MOUSE_BUTTON_RIGHT, BuildTests.center(HOME + Vector2i(1, 0))) and removed == [HOME + Vector2i(1, 0)]
			and not mode.click(MOUSE_BUTTON_RIGHT, BuildTests.center(HOME + Vector2i(5, 5))),
					"clique direito pede remover só onde há peça")
	_check(mode.door_near(Vector2.ZERO) == HOME + Vector2i(2, 0), "T acha a porta ao alcance")
	player.position = BuildTests.center(HOME + Vector2i(10, 0))
	_check(mode.door_near(Vector2.ZERO) == BuildMode.NO_CELL, "porta fora do alcance de porta não vale")
	mode.set_active(false)
	_check(not mode.active and not menu.visible, "B desliga")
	TestWorld.kill(player)
	mode.set_active(true)
	_check(not mode.active, "caído não entra no modo construção")


# ----------------------------------------------------------------------------- Main

func _test_main_wiring_and_save() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var authority := main.authority
	var player := main.player
	_check(main.workbenches is BuildField and main.build_mode != null and main.build_menu != null
			and authority.build.map == main.map and authority.build.grid.catalog.all().size() == 5,
					"a Main liga a grade, o campo e o modo construção")
	var map := main.map
	var core := SafeCore.new(main.respawn_rules, main.predation_rules.spawn_safe_margin_tiles, float(map.tile))
	var spot := _land_cell(map, core) + Vector2i(1, 1)
	player.global_position = BuildTests.center(spot)
	player.progression.grant_xp(1000000)
	authority.request_learn_recipe(1, "foundation")
	player.inventory.add(WOOD, 20)
	player.inventory.add(Items.STONE, 4)
	player.inventory.add(Items.FIBER, 2)
	main.build_mode.set_active(true)
	main.build_mode.follow_mouse = false
	main.build_mode.select("foundation")
	main.build_mode.mouse_world = BuildTests.center(spot + Vector2i(1, 0))
	_check(main.build_mode.click(MOUSE_BUTTON_LEFT, main.build_mode.mouse_world) and authority.build.grid.has_piece(spot + Vector2i(1,
			0)),
			"clique no modo construção: o pedido chega à autoridade e a peça entra")
	main.build_mode.select("wall")
	main.build_mode.click(MOUSE_BUTTON_LEFT, BuildTests.center(spot + Vector2i(1, 1)))
	var nodes := 0
	for child in main.workbenches.get_children():
		nodes += 1 if child is BuildPiece else 0
	_check(authority.build.grid.count() == 2 and nodes == 2, "fundação e parede viram nós no mundo")
	var envelope := WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0, authority.next_entity_id(), null,
			main.carcasses,
			0.0, main.ground, main.corpses, authority.build.grid)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	_check(SaveManager.validate_envelope(parsed) == "" and (parsed["world"]["build"]["pieces"] as Array).size() == 2,
			"o save da Main leva a grade e segue válido")
	authority.request_remove_piece(1, spot + Vector2i(1, 1))
	authority.request_remove_piece(1, spot + Vector2i(1, 0))
	_check(authority.build.grid.count() == 0, "preparo: tudo removido")
	_check(WorldSnapshot.restore(parsed, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid) and authority.build.grid.count() == 2 and authority.build.grid.blocks(spot + Vector2i(1, 1)),
			"carregar devolve as peças ao grid")
	await _root.get_tree().process_frame
	nodes = 0
	for child in main.workbenches.get_children():
		nodes += 1 if child is BuildPiece else 0
	_check(nodes == 2 and main.navigation.provider.is_blocked(spot + Vector2i(1, 1)), "e o campo e a navegação os refazem")
