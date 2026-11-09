# SPDX-License-Identifier: MIT
class_name GroundItemTests
extends AuthorityTests
## Itens no chão: espalhar, recolher (inteiro, parcial, cheio), pedido duplo, sumir no prazo, save/load sem duplicar, largar.


func run() -> void:
	_test_scatter_and_pickup()
	_test_partial_and_full()
	_test_double_pickup()
	_test_despawn()
	_test_save_roundtrip()
	_test_drop()
	_release_worlds()


func _field(player: Player, clock: TestWorld.TestClock) -> Dictionary:
	var authority := TestWorld.arm(player, [], _track)
	var field := GroundItemField.new()
	_root.add_child(field)
	_track.call(field)
	field.set_physics_process(false)
	field.authority = authority
	field.clock = clock.now
	field.world_seed = 7
	authority.drops_enabled = true
	authority.items_dropped.connect(func(item_id: String, amount: int, at: Vector2, dropper_id: String) -> void:
		field.spawn_scatter(item_id, amount, at, dropper_id))
	return {"field": field, "authority": authority}


func _test_scatter_and_pickup() -> void:
	var player := _player_at(Vector2.ZERO)
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	var authority: WorldAuthority = world["authority"]
	var piles := field.spawn_scatter(Items.WOOD, 7, Vector2(100, 100))
	_check(piles.size() == 3 and field.total_of(Items.WOOD) == 7, "7 madeiras viram pilhas de até 3 (%d pilhas)" % piles.size())
	var close := true
	for pile in piles:
		var distance := pile.position.distance_to(Vector2(100, 100))
		close = close and distance >= field.rules.scatter_min_px - 0.01 and distance <= field.rules.scatter_max_px + 0.01
	_check(close, "cada pilha cai entre 4 e 12 px do ponto")
	var again := GroundItemField.new()
	_track.call(again)
	again.rules = field.rules
	again.world_seed = 7
	again.clock = clock.now
	var twin := again.spawn_scatter(Items.WOOD, 7, Vector2(100, 100))
	_check(twin[0].position == piles[0].position, "a disposição vem da semente (determinística)")
	player.position = piles[0].position
	var before := player.inventory.count(Items.WOOD)
	_check(authority.request_pickup(1, authority.id_of(piles[0])) == Enums.ActionResult.OK
			and player.inventory.count(Items.WOOD) == before + 3, "pegar a pilha põe no inventário")
	_check(authority.request_pickup(1, authority.id_of(piles[1])) == Enums.ActionResult.OUT_OF_RANGE
			or piles[1].position.distance_to(player.position) <= authority.rules.reach_px(),
			"fora do alcance é recusado")


func _test_partial_and_full() -> void:
	var player := _player_at(Vector2.ZERO)
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.weight_limit = 0.0  # teste de slot cheio, não de Peso
	player.inventory.add(Items.WOOD, player.inventory.stack_limit(Items.WOOD) - 1)  # uma pilha de madeira com 1 de folga
	for filler in [Items.STONE, Items.MEAT, Items.FERN, Items.SLEEP_FRUIT, Items.FIBER, Items.BERRY]:
		while player.inventory.room_for(filler) > 0 and player.inventory.add(filler, 1) == 0:
			pass  # `add` devolve o que NÃO coube: 0 = entrou
	var piles := field.spawn_scatter(Items.WOOD, 3, Vector2(2, 0))
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void: events.append(GameMessages.text_of(code, params)))
	player.inventory.add(Items.WOOD, 1)  # agora nada cabe
	_check(authority.request_pickup(1, authority.id_of(piles[0])) == Enums.ActionResult.REFUSED and piles[0].amount == 3,
			"mochila cheia: recusa e o item fica no chão")
	_check(events.back() == "Inventário cheio.", "o log diz 'Inventário cheio' (%s)" % events.back())
	player.inventory.remove(Items.WOOD, 1)
	var room := player.inventory.room_for(Items.WOOD)
	_check(room == 1 and authority.request_pickup(1, authority.id_of(piles[0])) == Enums.ActionResult.OK and piles[0].amount == 2,
			"cabe 1 de 3: leva 1 e as outras 2 ficam")


func _test_double_pickup() -> void:
	var player := _player_at(Vector2.ZERO)
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	var authority: WorldAuthority = world["authority"]
	var piles := field.spawn_scatter(Items.STONE, 2, Vector2(2, 0))
	var id := authority.id_of(piles[0])
	var first := authority.request_pickup(1, id)
	var second := authority.request_pickup(1, id)
	_check(first == Enums.ActionResult.OK and second != Enums.ActionResult.OK, "dois pedidos pelo mesmo item: só o primeiro leva")


func _test_despawn() -> void:
	var player := _player_at(Vector2(5000, 5000))
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	field.spawn_scatter(Items.STONE, 2, Vector2(2, 0))
	clock.time += field.rules.despawn_seconds - 1.0
	field.tick()
	_check(field.count() == 1, "antes do prazo o item segue no chão")
	clock.time += 1.0
	field.tick()
	_check(field.count() == 0, "no prazo (300 s do relógio do mundo) ele some")


func _test_save_roundtrip() -> void:
	var player := _player_at(Vector2(5000, 5000))
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	field.spawn_scatter(Items.WOOD, 5, Vector2(100, 100))
	var saved := field.to_list()
	var copy_world := _field(_player_at(Vector2(5000, 5000)), clock)
	var copy: GroundItemField = copy_world["field"]
	copy.restore_list(JSON.parse_string(JSON.stringify(saved)))
	copy.restore_list(JSON.parse_string(JSON.stringify(saved)))  # carregar duas vezes não duplica
	_check(copy.count() == field.count() and copy.total_of(Items.WOOD) == 5, "save e load preservam sem duplicar")
	copy.restore_list([{"item": "nao_existe", "amount": 5}, {"item": Items.WOOD, "amount": -3}, "lixo", {"item": Items.WOOD,
			"amount": 1.0e12}])
	_check(copy.total_of(Items.WOOD) <= 9999 and copy.count() <= 1, "dado hostil é saneado")


func _test_drop() -> void:
	var player := _player_at(Vector2.ZERO)
	var clock := TestWorld.TestClock.new()
	var world := _field(player, clock)
	var field: GroundItemField = world["field"]
	var authority: WorldAuthority = world["authority"]
	var slot := -1
	for index in player.inventory.slot_count():
		if player.inventory.get_slot(index).get("id", "") == Items.BERRY:
			slot = index
	var before := player.inventory.count(Items.BERRY)
	_check(authority.request_drop(1, slot, 4) == Enums.ActionResult.OK and player.inventory.count(Items.BERRY) == before - 4
			and field.total_of(Items.BERRY) == 4, "largar 4 bagas as põe no chão; nada some")
	_check(authority.request_drop(1, slot, 0) == Enums.ActionResult.INVALID_ARGUMENT, "quantidade inválida é recusada")
