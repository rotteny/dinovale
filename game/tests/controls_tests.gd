# SPDX-License-Identifier: MIT
class_name ControlsTests
extends AuthorityTests
## Regra de controles de 08/11: o E nunca dá ordem a dino (prioridade: item no chão, nó de recurso, estrutura, criatura);
## as ordens saem do menu e da tecla G; o item no chão ao lado de um domado é pego sem mudar a ordem dele.


func run() -> void:
	_test_priority_of_targets()
	_test_e_picks_item_and_keeps_order()
	_test_e_never_orders()
	_test_g_toggles_order()
	_release_worlds()


func _ground_item(authority: WorldAuthority, point: Vector2, amount: int = 3) -> GroundItem:
	var item := GroundItem.new()
	item.setup(Items.WOOD, amount)
	item.position = point
	item.due_at = 1.0e9
	_root.add_child(item)
	_track.call(item)
	authority.register(item)
	return item


func _test_priority_of_targets() -> void:
	var item := GroundItem.new()
	_track.call(item)
	var node: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	node.def = load("res://data/resources/bush_baga.tres")
	_root.add_child(node)
	_track.call(node)
	var dino := _dino_at(Vector2.ZERO)
	var structure := InteractableArea.new()  # baú, cama, fogueira ainda não existem: qualquer outro interagível
	structure.entity = Node2D.new()
	_track.call(structure)
	_track.call(structure.entity)
	var ranks := [Player.interact_priority(item.interactable), Player.interact_priority(node.interactable),
			Player.interact_priority(structure), Player.interact_priority(dino.interactable)]
	_check(ranks == [0, 1, 2, 3], "prioridade do E: item no chão, nó, estrutura, criatura (%s)" % str(ranks))


func _test_e_picks_item_and_keeps_order() -> void:
	var player := _player_at(Vector2.ZERO)
	var mine := _tamed(_dino_at(Vector2(0, 20)), "local")
	mine.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var authority := TestWorld.arm(player, [mine], _track)
	var item := _ground_item(authority, Vector2(10, 0))
	player._in_range.append(mine.interactable)
	player._in_range.append(item.interactable)
	player.update_target()
	_check(player.target == item.interactable, "com o domado mais perto, o alvo do E é o item no chão")
	var before := player.inventory.count(Items.WOOD)
	_check(player.try_interact() and player.inventory.count(Items.WOOD) == before + 3 and item.amount == 0,
			"o E pega o item (o caso do dono: domado ao lado)")
	_check(mine.state_machine.order == Enums.DinoOrder.FOLLOW, "a ordem do domado não muda")


func _test_e_never_orders() -> void:
	var player := _player_at(Vector2.ZERO)
	var mine := _tamed(_dino_at(Vector2(0, 20)), "local")
	mine.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var authority := TestWorld.arm(player, [mine], _track)
	var orders := [0]
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: orders[0] += 1 if code == "order_given" else 0)
	player._in_range.append(mine.interactable)
	player.update_target()
	player.try_interact()
	player.try_interact()
	_check(mine.state_machine.order == Enums.DinoOrder.FOLLOW and orders[0] == 0, "o E sozinho (duas vezes) nunca muda a ordem")
	_check(player.target_is_own_tamed(), "num domado meu o E abre o menu (o controlador decide)")


func _test_g_toggles_order() -> void:
	var player := _player_at(Vector2.ZERO)
	var mine := _tamed(_dino_at(Vector2(0, 20)), "local")
	mine.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var far := _tamed(_dino_at(Vector2(500, 0)), "local")
	var far_order := far.state_machine.order
	var authority := TestWorld.arm(player, [mine, far], _track)
	var lines: Array[String] = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void:
		lines.append(GameMessages.text_of(code, params)))
	_check(player.toggle_nearest_order() and mine.state_machine.order == Enums.DinoOrder.STAY, "G alterna Seguir para Ficar")
	_check(lines.back() == "%s: ficando." % mine.stats.display_name, "o log mostra '%s'" % lines.back())
	_check(player.toggle_nearest_order() and mine.state_machine.order == Enums.DinoOrder.FOLLOW
			and lines.back().ends_with("seguindo."), "G de novo volta a Seguir")
	_check(far.state_machine.order == far_order, "o distante não foi tocado")
	mine.position = Vector2(500, 500)
	_check(not player.toggle_nearest_order(), "sem domado ao alcance, a tecla não faz nada")
