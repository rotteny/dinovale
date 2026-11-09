# SPDX-License-Identifier: MIT
class_name BuildReviewTests
extends BuildTests
## Correções da revisão da E8a (LEVI): versão do bloco, reembolso ao dono da peça, Bancada legada que não coube e carga em lote
## da navegação com 4096 peças. Reaproveita a montagem do `BuildTests`.

const WALL_CELL := HOME + Vector2i(1, 0)
const BIG_SIDE := 64


func run() -> void:
	_test_version_is_refused()
	_test_refund_goes_to_the_owner()
	_test_legacy_bench_that_does_not_fit()
	_test_big_load_is_batched()
	await _test_snapshot_refuses_bad_version_and_returns_benches()
	_release_worlds()


func _test_version_is_refused() -> void:
	var grid := BuildGrid.new()
	grid.add(Vector2i(1, 1), "foundation")
	var before := JSON.stringify(grid.to_dict())
	var block := {"pieces": [{"piece": "foundation", "x": 5, "y": 5}]}
	for bad: Variant in [99, 2, 0, -1, "x", 1.5, null, [1], NAN]:
		var versioned := block.duplicate()
		versioned["version"] = bad
		_check(not grid.from_dict(versioned) and JSON.stringify(grid.to_dict()) == before,
				"bloco da grade com versão `%s` é recusado e a grade fica como estava" % str(bad))
	var ok := block.duplicate()
	ok["version"] = BuildGrid.FORMAT_VERSION
	_check(grid.from_dict(ok) and grid.has_piece(Vector2i(5, 5)) and grid.from_dict(block) and grid.has_piece(Vector2i(5, 5)),
			"versão atual e bloco sem versão (migração) entram")


## Dono e quem remove diferem (peças compartilhadas): o material vai ao dono; offline ou sem espaço, cai junto da peça.
func _test_refund_goes_to_the_owner() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var grid := _grid(world)
	var drops: Array = []
	authority.items_dropped.connect(func(item_id: String, amount: int, at: Vector2, who: String) -> void:
		drops.append({"item": item_id, "amount": amount, "at": at, "who": who}))
	var bob := _player_at(BuildTests.center(HOME + Vector2i(0, 6)))
	bob.player_id = "bob"
	authority.register(bob)
	for item_id: String in Items.all_ids():
		bob.inventory.remove(item_id, 9999)
	grid.add(HOME + Vector2i(2, 0), "foundation", 0, "bob")
	grid.add(WALL_CELL, "wall", 0, "bob")
	var mine := _count(world, WOOD)
	_check(authority.request_remove_piece(1, WALL_CELL) == OK and bob.inventory.count(WOOD) == 2 and _count(world, WOOD) == mine
			and drops.is_empty(), "dono online: o reembolso vai ao dono, não a quem removeu")
	grid.add(WALL_CELL, "wall", 0, "bob")
	bob.inventory.remove(WOOD, 100)
	for index in bob.inventory.slot_count():
		bob.inventory.add_entry({"id": Items.STONE, "count": bob.inventory.max_stack})
	var second := authority.request_remove_piece(1, WALL_CELL)
	_check(second == OK and _count(world, WOOD) == mine and drops.size() == 1
			and drops[0]["item"] == WOOD and drops[0]["amount"] == 2 and drops[0]["who"] == "bob"
			and (drops[0]["at"] as Vector2).is_equal_approx(BuildTests.center(WALL_CELL)),
			"dono sem espaço: o que não cabe cai junto da peça, com a preferência dele")
	grid.add(WALL_CELL, "wall", 0, "ghost")
	drops.clear()
	_check(authority.request_remove_piece(1, WALL_CELL) == OK and _count(world, WOOD) == mine and drops.size() == 1
			and drops[0]["who"] == "ghost" and (drops[0]["at"] as Vector2).is_equal_approx(BuildTests.center(WALL_CELL)),
			"dono fora do mundo: o material cai no chão junto da peça")
	grid.add(WALL_CELL, "wall", 0, player.player_id)
	_check(authority.request_remove_piece(1, WALL_CELL) == OK and _count(world, WOOD) == mine + 2,
			"peça do próprio jogador: o reembolso volta a ele")
	authority.drops_enabled = false
	grid.add(WALL_CELL, "wall", 0, "ghost")
	var state := _state(world)
	_check(authority.request_remove_piece(1, WALL_CELL) == Enums.ActionResult.REFUSED and grid.has_piece(WALL_CELL)
			and _state(world) == state, "sem chão e com o dono fora, a remoção é recusada (o material não some)")


func _test_legacy_bench_that_does_not_fit() -> void:
	var legacy := BuildGrid.pieces_from_legacy_benches([{"x": 40.0, "y": 40.0, "id": 3}, {"x": 41.0, "y": 41.0, "id": 4},
			{"x": -50.0, "y": 8.0, "id": 5}, {"x": 120.0, "y": 8.0, "id": 6}], 16.0)
	var grid := BuildGrid.new()
	grid.fixed_check = func(cell: Vector2i) -> String: return "bad_terrain" if cell.x < 0 else ""
	grid.from_dict({"pieces": legacy, "legacy_benches": true})
	_check(grid.count() == 2 and grid.unplaced_items == {Items.WORKBENCH: 2},
			"migração: a Bancada em célula repetida e a em terreno que não serve voltam como item (2), não somem")
	grid.from_dict({"pieces": legacy})
	_check(grid.unplaced_items.is_empty(), "um bloco sem a marca da migração não rende Bancada nenhuma")
	var save_block := WorldSnapshot.build_block_of({"world": {"build": {"pieces": [], "legacy_benches": true}}}, 16.0)
	_check(not save_block.has("legacy_benches") and WorldSnapshot.build_block_of({"world": {"workbenches": []}}, 16.0)["legacy_benches"],
			"a marca é só da migração: um `world.build` de save novo não a traz")


## `watch_build` em lote: 4096 peças entram no A* com as grades refeitas uma vez, e quem seguia um caminho é avisado.
func _test_big_load_is_batched() -> void:
	var grid := BuildGrid.new()
	var provider := GridPathProvider.new()
	provider.setup(256, PackedByteArray())  # o tamanho do mapa de verdade
	provider.end_bulk()
	var navigation := NavigationWorld.new()
	_track.call(navigation)
	navigation.provider = provider
	navigation.watch_build(grid, TILE)
	var invalidated: Array[Vector2i] = []
	provider.cell_invalidated.connect(func(cell: Vector2i) -> void: invalidated.append(cell))
	var pieces: Array = []
	for y in BIG_SIDE:
		for x in BIG_SIDE:
			pieces.append({"piece": "foundation" if (x + y) % 2 == 0 else "wall", "x": x, "y": y})
	var started := Time.get_ticks_usec()
	grid.from_dict({"pieces": pieces})
	var millis := float(Time.get_ticks_usec() - started) / 1000.0
	var walls := 0
	for cell in grid.cells():
		walls += 1 if provider.is_blocked(cell) else 0
	_check(grid.count() == BIG_SIDE * BIG_SIDE and walls == grid.count_of("wall") and provider.is_blocked(Vector2i(1, 0))
			and not provider.is_blocked(Vector2i(0, 0)),
			"carga de 4096 peças: o A* ficou com as 2048 paredes (e as fundações livres)")
	_check(invalidated.size() == grid.count_of("wall") and millis < 4000.0,
			"carga de 4096 peças em %.0f ms, com os caminhos avisados das células que mudaram (%d)" % [millis, invalidated.size()])
	started = Time.get_ticks_usec()
	grid.from_dict({})
	millis = float(Time.get_ticks_usec() - started) / 1000.0
	_check(not provider.is_blocked(Vector2i(1, 0)), "esvaziar a grade (4096 peças) libera tudo, em %.0f ms" % millis)


## Na `Main`: bloco com versão desconhecida recusa a carga inteira; Bancada legada em terreno ruim volta ao inventário (ou ao chão).
func _test_snapshot_refuses_bad_version_and_returns_benches() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var authority := main.authority
	var player := main.player
	var envelope := WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0, authority.next_entity_id(), null,
			main.carcasses, 0.0, main.ground, main.corpses, authority.build.grid)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	var bad: Dictionary = parsed.duplicate(true)
	(bad["world"]["build"] as Dictionary)["version"] = 99
	var before := JSON.stringify(player.to_dict())
	_check(not WorldSnapshot.restore(bad, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid) and JSON.stringify(player.to_dict()) == before,
			"save com o bloco da grade em versão 99: a carga é recusada e nada muda")
	var old: Dictionary = parsed.duplicate(true)
	(old["world"] as Dictionary).erase("build")
	var sea := Vector2i(0, 0)
	(old["world"] as Dictionary)["workbenches"] = [{"id": 5, "x": 4.0, "y": 4.0}]
	_check(not main.map.is_land(sea), "preparo: a célula (0, 0) é mar")
	var had := player.inventory.count(Items.WORKBENCH)
	_check(WorldSnapshot.restore(old, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid) and authority.build.grid.count() == 0 and player.inventory.count(Items.WORKBENCH) == had + 1,
			"Bancada legada em terreno inválido: a migração a devolve como item no inventário")
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	for index in player.inventory.slot_count():
		player.inventory.add_entry({"id": Items.STONE, "count": player.inventory.max_stack})
	var dropped: Array = []
	authority.items_dropped.connect(func(item_id: String, amount: int, _at: Vector2, _who: String) -> void:
		dropped.append([item_id, amount]))
	var grid := BuildGrid.new()
	grid.unplaced_items = {Items.WORKBENCH: 1}
	WorldSnapshot.return_unplaced(grid, player, authority)
	_check(dropped == [[Items.WORKBENCH, 1]], "e com o inventário cheio, cai no chão perto do jogador")
