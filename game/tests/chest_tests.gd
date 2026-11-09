# SPDX-License-Identifier: MIT
class_name ChestTests
extends BuildTests
## E8b: o Baú (PRO-06, CON-02 parte 2). Peça do grid que guarda: receita conhecida, construir, abrir e mover pela autoridade
## (alcance, índice, espaço), save com lixo e remover o Baú cheio. Reaproveita a montagem do `BuildTests`.

const CHEST_CELL := HOME + Vector2i(1, 0)


func run() -> void:
	_test_build_and_open()
	_test_store_and_take()
	_test_refusals_change_nothing()
	_test_save_roundtrip()
	_test_save_garbage()
	_test_remove_full_chest()
	_test_remove_without_ground()
	await _test_main_ui_and_save()
	_release_worlds()


## Mundo de teste com um Baú já construído em `CHEST_CELL` (pelo pedido real) e o id dele.
func _with_chest() -> Dictionary:
	var world := _setup()
	var answer := _ask(world, "chest", CHEST_CELL)
	var grid := _grid(world)
	world["chest_id"] = int(grid.piece_at(CHEST_CELL).get("id", 0))
	world["answer"] = answer
	return world


func _chest(world: Dictionary) -> Chest:
	return (world["authority"] as WorldAuthority).entity(int(world["chest_id"])) as Chest


## O índice do primeiro slot de `inventory` com `item_id`, ou -1.
func _slot_of(inventory: InventoryComponent, item_id: String) -> int:
	for index in inventory.slot_count():
		if inventory.get_slot(index).get("id", "") == item_id:
			return index
	return -1


func _test_build_and_open() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var chest := _chest(world)
	_check(world["answer"]["result"] == OK and chest != null and _count(world, WOOD) == 94 and _grid(world).blocks(CHEST_CELL),
			"Baú: construído pelo pedido real, 6 madeira, sólido na grade")
	_check(chest != null and chest.inventory == _grid(world).container_at(CHEST_CELL) and chest.interactable != null
			and chest.inventory.slot_count() == _grid(world).def_at(CHEST_CELL).container_slots,
			"o nó do Baú aponta para o inventário da grade, com os slots que o dado manda")
	var granted: Array = []
	authority.interaction_granted.connect(func(actor: int, target: int) -> void: granted.append([actor, target]))
	_check(authority.request_interact(1, int(world["chest_id"])) == OK and granted == [[1, int(world["chest_id"])]],
			"abrir o Baú ao alcance é concedido")
	player.global_position = BuildTests.center(HOME) + Vector2(0.0, 200.0)
	granted.clear()
	_check(authority.request_interact(1, int(world["chest_id"])) == Enums.ActionResult.OUT_OF_RANGE and granted.is_empty(),
			"o Baú longe é recusado: não abre")


func _test_store_and_take() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var chest := _chest(world)
	var id := int(world["chest_id"])
	var before_wood := _count(world, WOOD)
	var slot := _slot_of(player.inventory, WOOD)
	_check(authority.request_transfer_slot(1, 1, slot, id, 10) == OK and chest.inventory.count(WOOD) == 10
			and _count(world, WOOD) == before_wood - 10, "guardar 10 de madeira: sai do jogador e entra no Baú")
	_check(authority.request_transfer_slot(1, id, _slot_of(chest.inventory, WOOD), 1, 4) == OK and chest.inventory.count(WOOD) == 6
			and _count(world, WOOD) == before_wood - 6, "retirar 4 devolve ao jogador, nos dois sentidos")
	player.inventory.add(Items.WOODEN_SPEAR, 1)
	var spear := _slot_of(player.inventory, Items.WOODEN_SPEAR)
	var iid := str(player.inventory.get_slot(spear)["iid"])
	_check(authority.request_transfer_slot(1, 1, spear, id) == OK and chest.inventory.has_iid(iid) and not player.inventory.has_iid(iid),
			"o equipamento individual também vai para o Baú, com o mesmo iid")
	_check(authority.request_transfer_slot(1, id, _slot_of(chest.inventory, Items.WOODEN_SPEAR), 1) == OK
			and player.inventory.has_iid(iid), "e volta com o mesmo iid")
	# Baú cheio: o que não cabe fica onde estava.
	var tight := _with_chest()
	var tight_chest := _chest(tight)
	for fill in tight_chest.inventory.slot_count():
		tight_chest.inventory.add_entry({"id": Items.STONE, "count": tight_chest.inventory.max_stack})
	(tight["player"] as Player).inventory.add(Items.BERRY, 3)
	var state := _state(tight) + JSON.stringify(tight_chest.inventory.to_dict())
	var tight_authority: WorldAuthority = tight["authority"]
	var refused := tight_authority.request_transfer_slot(1, 1, _slot_of((tight["player"] as Player).inventory, Items.BERRY),
			int(tight["chest_id"]))
	_check(refused == Enums.ActionResult.REFUSED and _state(tight) + JSON.stringify(tight_chest.inventory.to_dict()) == state,
			"Baú cheio recusa e nada se perde nem se duplica")


func _test_refusals_change_nothing() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var chest := _chest(world)
	var id := int(world["chest_id"])
	chest.inventory.add(Items.BERRY, 5)
	var state := _state(world) + JSON.stringify(chest.inventory.to_dict())
	var slot := _slot_of(player.inventory, WOOD)
	var cases := {
		"índice negativo": authority.request_transfer_slot(1, 1, -1, id),
		"índice grande": authority.request_transfer_slot(1, 1, 999, id),
		"quantidade zero": authority.request_transfer_slot(1, 1, slot, id, 0),
		"quantidade acima da pilha": authority.request_transfer_slot(1, 1, slot, id, 100000),
		"retirar de slot vazio fora do índice": authority.request_transfer_slot(1, id, 99, 1),
		"Baú para Baú": authority.request_transfer_slot(1, id, 0, id),
		"ator desconhecido": authority.request_transfer_slot(99, 99, 0, id),
	}
	for label: String in cases:
		_check(cases[label] != OK, "%s é recusado" % label)
	_check(_state(world) + JSON.stringify(chest.inventory.to_dict()) == state, "e nenhuma recusa mexeu no estado")
	player.global_position = BuildTests.center(HOME) + Vector2(0.0, 200.0)
	_check(authority.request_transfer_slot(1, 1, slot, id) == Enums.ActionResult.OUT_OF_RANGE
			and authority.request_transfer_slot(1, id, _slot_of(chest.inventory, Items.BERRY), 1) == Enums.ActionResult.OUT_OF_RANGE
			and _state(world) + JSON.stringify(chest.inventory.to_dict()) == state,
			"Baú longe: guardar e retirar são recusados, nada muda")
	TestWorld.kill(player)
	player.global_position = BuildTests.center(HOME)
	_check(authority.request_transfer_slot(1, id, _slot_of(chest.inventory, Items.BERRY), 1) != OK, "jogador caído não mexe no Baú")


func _test_save_roundtrip() -> void:
	var world := _with_chest()
	var grid := _grid(world)
	var chest := _chest(world)
	chest.inventory.add(WOOD, 30)
	chest.inventory.add(Items.BERRY, 7)
	chest.inventory.add(Items.WOODEN_SPEAR, 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(grid.to_dict()))
	var other := BuildGrid.new()
	_check(other.from_dict(saved) and other.has_piece(CHEST_CELL) and other.container_at(CHEST_CELL) != null
			and other.container_at(CHEST_CELL).count(WOOD) == 30 and other.container_at(CHEST_CELL).count(Items.BERRY) == 7
			and other.container_at(CHEST_CELL).count(Items.WOODEN_SPEAR) == 1
			and JSON.stringify(other.to_dict()) == JSON.stringify(grid.to_dict()),
			"save e load do Baú: o conteúdo vai e volta igual, junto da peça")
	var empty := BuildGrid.new()
	empty.add(CHEST_CELL, "chest")
	_check(not (empty.to_dict()["pieces"][0] as Dictionary).has("items"), "Baú vazio não grava conteúdo")


func _test_save_garbage() -> void:
	var bad_items: Array = [null, 5, "texto", [1, 2], {}, {"slots": "x"}, {"version": 99, "slots": []}, {"version": 2, "slots": 7},
			{"slots": [{"id": "nope", "count": 3}, {"id": "wood", "count": -4}, {"id": "wood", "count": 1e30}, 9, "x", null]},
			{"slots": [{"id": "wood", "count": 5}, {"id": "wood", "count": 5}]},
			{"version": 2, "slots": range(2000)},
			{"version": 2, "slots": [{"id": "wooden_spear", "iid": "x".repeat(500), "durab": NAN}]}]
	for items: Variant in bad_items:
		var grid := BuildGrid.new()
		grid.from_dict({"pieces": [{"piece": "chest", "x": 5, "y": 5, "items": items}, {"piece": "foundation", "x": 7, "y": 5},
				{"piece": "wall", "x": 6, "y": 5, "items": {"slots": []}}]})
		var box := grid.container_at(Vector2i(5, 5))
		var sane := box != null and grid.has_piece(Vector2i(6, 5)) and grid.container_at(Vector2i(6, 5)) == null
		for index in (box.slot_count() if box != null else 0):
			var slot := box.get_slot(index)
			sane = sane and (slot.is_empty() or (Items.has(str(slot["id"])) and int(slot.get("count", 1)) >= 1
					and int(slot.get("count", 1)) <= box.max_stack))
		_check(sane, "Baú com conteúdo lixo (%s): a peça fica e o conteúdo é saneado ou vazio" % str(items).left(40))
	var overflow := BuildGrid.new()
	var many: Array = []
	for index in 40:
		many.append({"id": Items.STONE, "count": 99})
	overflow.from_dict({"pieces": [{"piece": "chest", "x": 5, "y": 5, "items": {"version": 2, "slots": many}}]})
	_check(overflow.has_piece(Vector2i(5, 5)) and overflow.container_at(Vector2i(5, 5)).slot_count() == 12,
			"conteúdo maior que o Baú: a peça fica e a capacidade vem do dado, não do save")


func _test_remove_full_chest() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var chest := _chest(world)
	var id := int(world["chest_id"])
	chest.inventory.add(WOOD, 40)
	chest.inventory.add(Items.BERRY, 7)
	chest.inventory.add(Items.WOODEN_SPEAR, 1)
	var singles: Array[Dictionary] = []
	authority.build.entry_dropped.connect(func(entry: Dictionary, _at: Vector2, _who: String) -> void: singles.append(entry))
	var wood_before := _count(world, WOOD)
	_check(authority.request_remove_piece(1, CHEST_CELL) == OK and not _grid(world).has_piece(CHEST_CELL)
			and _grid(world).container_at(CHEST_CELL) == null, "remover o Baú cheio é aceito")
	var dropped: Array = world["dropped"]
	var on_floor := {}
	for pair: Array in dropped:
		on_floor[pair[0]] = int(on_floor.get(pair[0], 0)) + int(pair[1])
	_check(on_floor.get(WOOD, 0) == 40 and on_floor.get(Items.BERRY, 0) == 7 and singles.size() == 1
			and singles[0]["id"] == Items.WOODEN_SPEAR and singles[0].has("iid"),
			"o conteúdo cai no chão: empilháveis inteiros e o individual com iid")
	_check(_count(world, WOOD) == wood_before + 6 and authority.entity(id) == null and not authority.is_registered(id),
			"a madeira da receita volta ao jogador e o Baú sai do registro")
	_check(authority.request_interact(1, id) != OK and authority.request_transfer_slot(1, 1, 0, id) != OK,
			"o id do Baú removido não abre nem recebe")


func _test_remove_without_ground() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	authority.drops_enabled = false
	var chest := _chest(world)
	chest.inventory.add(WOOD, 10)
	var state := _state(world) + JSON.stringify(chest.inventory.to_dict())
	var answer := authority.request_remove_piece(1, CHEST_CELL)
	_check(answer == Enums.ActionResult.REFUSED and _grid(world).has_piece(CHEST_CELL)
			and _state(world) + JSON.stringify(chest.inventory.to_dict()) == state,
			"sem chão para largar, o Baú com conteúdo não sai (nada some)")
	chest.inventory.remove(WOOD, 10)
	_check(authority.request_remove_piece(1, CHEST_CELL) == OK, "vazio, sai normalmente")


## Na `Main` de verdade: abrir o Baú abre a tela com os dois lados, a tela transfere nos dois sentidos pela autoridade, e o
## conteúdo atravessa um save e um load completos (a peça e os nós voltam com o conteúdo e o mesmo id).
func _test_main_ui_and_save() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var authority := main.authority
	var player := main.player
	var core := SafeCore.new(main.respawn_rules, main.predation_rules.spawn_safe_margin_tiles, float(main.map.tile))
	var spot := _land_cell(main.map, core) + Vector2i(1, 1)
	player.global_position = BuildTests.center(spot)
	player.inventory.add(WOOD, 20)
	var cell := spot + Vector2i(1, 0)
	_check(authority.request_build(1, "chest", cell, 0) == OK, "Main: o Baú se constrói sem aprender nada (Saber 0)")
	var chest_id := int(authority.build.grid.piece_at(cell)["id"])
	var chest := authority.entity(chest_id) as Chest
	_check(chest != null and authority.request_interact(1, chest_id) == OK and main.screen.is_open,
			"Main: abrir o Baú abre a tela do inventário com o conteúdo dele")
	main.screen.transfer_requested.emit(true, _first_wood(player), 5)
	_check(chest.inventory.count(WOOD) == 5, "a tela guarda no Baú (pedido da UI chega à autoridade)")
	main.screen.transfer_requested.emit(false, 0, WorldAuthority.TRANSFER_ALL)
	_check(chest.inventory.count(WOOD) == 0, "e retira do Baú, no sentido contrário")
	main.screen.transfer_requested.emit(true, _first_wood(player), 7)
	main.screen.close()
	var envelope := WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0, authority.next_entity_id(), null,
			main.carcasses, 0.0, main.ground, main.corpses, authority.build.grid)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	_check(SaveManager.validate_envelope(parsed) == "", "o save com o Baú cheio é válido")
	authority.request_remove_piece(1, cell)  # esvazia o mundo: o conteúdo cai no chão
	_check(not authority.build.grid.has_piece(cell) and authority.entity(chest_id) == null, "preparo: Baú removido")
	_check(WorldSnapshot.restore(parsed, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid), "carregar o save aceita")
	await _root.get_tree().process_frame
	var again := authority.entity(chest_id) as Chest
	_check(again != null and again.inventory.count(WOOD) == 7 and authority.build.grid.blocks(cell)
			and main.navigation.provider.is_blocked(cell), "o Baú volta do save com o conteúdo, o mesmo id e na navegação")


func _first_wood(player: Player) -> int:
	return _slot_of(player.inventory, WOOD)
