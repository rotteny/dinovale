# SPDX-License-Identifier: MIT
class_name WallLineTests
extends ChestTests
## Correções da revisão da E8b: golpe (Lança e Bastão), interação (Baú, Bancada, porta) não atravessam parede; o Baú tem dono
## (a regra de `shared_pieces`); `GridLine` não passa do destino; o teto da Bancada legada conta as postas. O golpe em área
## sem parede está em `AreaAttackTests`. Reaproveita a montagem do `BuildTests` (jogador em `HOME`, alcance de 3 tiles).

const WEST := Vector2i(8, 10)  # 3 tiles do Baú em `CHEST_CELL`
const BLOCK := Vector2i(9, 10)


func run() -> void:
	_test_grid_line_corner()
	_test_attack_through_wall()
	_test_chest_through_wall()
	_test_chest_owner()
	_test_door_and_bench_through_wall()
	_test_unplaced_cap()
	_release_worlds()


func _stand(world: Dictionary, cell: Vector2i) -> void:
	(world["player"] as Player).global_position = BuildTests.center(cell)


func _test_grid_line_corner() -> void:
	var tile := 16.0
	_check(GridLine.cells(Vector2(0, 8), Vector2(16, 0), tile) == [Vector2i(0, 0), Vector2i(1, 0)],
			"GridLine: destino exato na quina (0,8) -> (16,0) para na célula do destino")
	var tie := GridLine.cells(Vector2(0, 8), Vector2(16, 16), tile)
	_check(tie.size() == 3 and tie.front() == Vector2i(0, 0) and tie.back() == Vector2i(1, 1),
			"GridLine: empate na quina anda os dois eixos e termina no destino")
	_check(GridLine.cells(Vector2(8, 8), Vector2(24, 8), tile) == [Vector2i(0, 0), Vector2i(1, 0)]
			and GridLine.cells(Vector2(8, 8), Vector2(8, 24), tile) == [Vector2i(0, 0), Vector2i(0, 1)]
			and GridLine.cells(Vector2(8, 8), Vector2(8, 8), tile) == [Vector2i(0, 0)],
			"GridLine: pontos de meia célula")
	var long_line := GridLine.cells(Vector2(0, 0), Vector2(160, 40), tile)
	_check(long_line.back() == Vector2i(10, 2) and long_line.size() <= 14, "GridLine: nunca passa do destino (%d células)" % long_line.size())


## Jogador de um lado, raptor do outro de uma parede, a ~26 px: o golpe da Lança e o do Bastão são recusados, a vida não muda.
func _test_attack_through_wall() -> void:
	for weapon_id in [Items.WOODEN_SPEAR, Items.SLEEP_STAFF]:
		var world := _setup()
		var authority: WorldAuthority = world["authority"]
		var player: Player = world["player"]
		_stand(world, WEST)
		authority.build.grid.add(BLOCK, "wall")
		var raptor := _dino_at(player.global_position + Vector2(26.0, 0.0))
		raptor.stats = load("res://data/dino/utahraptor.tres")
		authority.register(raptor)
		player.inventory.add(weapon_id, 1)
		for index in player.inventory.slot_count():
			var slot := player.inventory.get_slot(index)
			if slot.get("id", "") == weapon_id:
				player.equipment.equip(str(slot["iid"]), EquipmentLayout.WEAPON)
		player.facing = Vector2.RIGHT
		authority.request_move(1, Vector2.RIGHT)
		var before := (world["events"] as Array).size()
		var life := raptor.health.current_health
		var result := authority.request_attack(1, authority.id_of(raptor))
		_check(result == Enums.ActionResult.OUT_OF_RANGE and _reason_since(world, before) == "blocked_line"
				and raptor.health.current_health == life, "golpe (%s) com parede no meio: recusado, vida intacta" % weapon_id)
		authority.build.grid.remove(BLOCK)
		player.tick(5.0)  # o tempo de recarga não conta como parede
		_check(authority.request_attack(1, authority.id_of(raptor)) == Enums.ActionResult.OK,
				"golpe (%s) sem a parede: acerta (a recusa era só da parede)" % weapon_id)


func _chest_beyond_wall() -> Dictionary:
	var world := _with_chest()
	_stand(world, WEST)
	_grid(world).add(BLOCK, "wall")
	return world


func _test_chest_through_wall() -> void:
	var world := _chest_beyond_wall()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var chest := _chest(world)
	var id := int(world["chest_id"])
	var before := (world["events"] as Array).size()
	var opened := authority.request_interact(1, id)
	_check(opened == Enums.ActionResult.OUT_OF_RANGE and _reason_since(world, before) == "blocked_line",
			"Baú atrás da parede: abrir é recusado (linha)")
	var state := _state(world) + JSON.stringify(chest.inventory.to_dict())
	var slot := _slot_of(player.inventory, WOOD)
	_check(authority.request_transfer_slot(1, 1, slot, id, 5) == Enums.ActionResult.OUT_OF_RANGE,
			"Baú atrás da parede: guardar é recusado")
	chest.inventory.add(Items.BERRY, 4)
	state = _state(world) + JSON.stringify(chest.inventory.to_dict())
	_check(authority.request_transfer_slot(1, id, _slot_of(chest.inventory, Items.BERRY), 1, 2) == Enums.ActionResult.OUT_OF_RANGE
			and _state(world) + JSON.stringify(chest.inventory.to_dict()) == state, "Baú atrás da parede: tirar é recusado e nada muda")
	_grid(world).remove(BLOCK)
	_check(authority.request_interact(1, id) == OK, "sem a parede o mesmo Baú abre")


func _test_chest_owner() -> void:
	var world := _with_chest()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var grid := _grid(world)
	var stranger_cell := HOME + Vector2i(-1, 0)
	grid.add(stranger_cell, "chest", 0, "outro_jogador")
	var stranger := authority.entity(int(grid.piece_at(stranger_cell).get("id", 0))) as Chest
	_check(stranger != null and authority.request_interact(1, authority.id_of(stranger)) == OK,
			"com peças compartilhadas (padrão) o Baú de outro jogador abre")
	var rules := authority.build.rules.duplicate() as BuildRules
	rules.shared_pieces = false
	authority.build.rules = rules
	var before := (world["events"] as Array).size()
	var denied := authority.request_interact(1, authority.id_of(stranger))
	_check(denied == Enums.ActionResult.NOT_OWNER and _reason_since(world, before) == "not_yours",
			"shared_pieces=false: o Baú de outro jogador não abre")
	stranger.inventory.add(Items.BERRY, 4)
	player.inventory.add(Items.BERRY, 2)
	var state := _state(world) + JSON.stringify(stranger.inventory.to_dict())
	var put := authority.request_transfer_slot(1, 1, _slot_of(player.inventory, Items.BERRY), authority.id_of(stranger))
	var take := authority.request_transfer_slot(1, authority.id_of(stranger), _slot_of(stranger.inventory, Items.BERRY), 1)
	_check(put == Enums.ActionResult.NOT_OWNER and take == Enums.ActionResult.NOT_OWNER
			and _state(world) + JSON.stringify(stranger.inventory.to_dict()) == state,
			"shared_pieces=false: nem guarda nem tira no Baú de outro jogador, e nada muda")
	var own := _chest(world)
	_check(authority.request_interact(1, authority.id_of(own)) == OK,
			"shared_pieces=false: o Baú do próprio dono abre")


func _test_door_and_bench_through_wall() -> void:
	var world := _setup()
	var authority: WorldAuthority = world["authority"]
	var grid := _grid(world)
	_stand(world, WEST)
	grid.add(BLOCK, "wall")
	grid.add(HOME, "door")  # a porta de 2 tiles, com a parede no meio
	var before := (world["events"] as Array).size()
	var shut := authority.request_toggle_door(1, HOME)
	_check(shut == Enums.ActionResult.OUT_OF_RANGE and _reason_since(world, before) == "blocked_line" and not grid.is_open(HOME),
			"porta atrás da parede: não abre")
	grid.remove(BLOCK)
	_check(authority.request_toggle_door(1, HOME) == OK and grid.is_open(HOME), "sem a parede a porta abre")
	grid.remove(HOME)
	grid.add(BLOCK, "wall")
	grid.add(HOME, "workbench")  # a 2 tiles (o alcance da Bancada), com a parede no meio
	var bench := authority.entity(int(grid.piece_at(HOME).get("id", 0))) as Workbench
	var player: Player = world["player"]
	_check(bench != null and authority.crafting._bench_near(player) == null, "Bancada atrás da parede não serve para fabricar")
	grid.remove(BLOCK)
	_check(authority.crafting._bench_near(player) == bench, "sem a parede a Bancada serve")


## O teto da Bancada legada conta postas + devolvidas: um save não rende mais Bancadas do que o mundo comporta.
func _test_unplaced_cap() -> void:
	var grid := BuildGrid.new()
	var limit := grid.catalog.find("workbench").max_count
	var pieces: Array = []
	for index in limit - 1:
		pieces.append({"piece": "workbench", "x": index, "y": 0, "id": index + 1})
	for index in 5:  # a mesma célula repetida: caem como não postas, e só cabe 1 pelo teto
		pieces.append({"piece": "workbench", "x": 0, "y": 0, "id": 900 + index})
	var loaded := grid.from_dict({"version": BuildGrid.FORMAT_VERSION, "legacy_benches": true, "pieces": pieces})
	var returned := int(grid.unplaced_items.get(Items.WORKBENCH, 0))
	_check(loaded and grid.count_of("workbench") == limit - 1 and returned == 1,
			"Bancada legada: %d postas + %d devolvida cabem no teto de %d" % [grid.count_of("workbench"), returned, limit])
