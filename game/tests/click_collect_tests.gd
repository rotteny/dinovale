# SPDX-License-Identifier: MIT
class_name ClickCollectTests
extends AuthorityTests
## Clique esquerdo que colhe (moita, nó de coleta direta) e pega (item no chão), com a criatura sob o cursor em primeiro
## lugar, e a ação do cursor contextual (`PlayerController.cursor_state`): qual ação existe sob o ponteiro e se o jogador
## a alcança. Reaproveita a montagem de `AuthorityTests`.

const BUSH_DEF: ResourceNodeDef = preload("res://data/resources/bush_baga.tres")
const TREE: ResourceNodeDef = preload("res://data/resources/tree.tres")
const ROCK: ResourceNodeDef = preload("res://data/resources/rock.tres")
const IRON: ResourceNodeDef = preload("res://data/resources/iron_seam.tres")
const ResourceScene := preload("res://src/entities/resource/ResourceNode.tscn")
const LEFT := MOUSE_BUTTON_LEFT


func run() -> void:
	_test_click_bush_in_reach()
	_test_click_bush_out_of_reach()
	_test_click_ground_item()
	_test_creature_has_priority()
	_test_cursor_actions()
	_test_cursor_reach_and_ui()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

## Jogador em (0,0) com a autoridade e o controlador (como a `Main`), sem nada mais. `events` junta `[código, motivo]`.
func _world() -> Dictionary:
	var player := _player_at(Vector2.ZERO)
	var authority := TestWorld.arm(player, [], _track)
	var controller: PlayerController = _track.call(PlayerController.new())
	controller.player = player
	controller.authority = authority
	var events: Array = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void: events.append([code, params.get("reason", "")]))
	var granted: Array[int] = []
	authority.interaction_granted.connect(func(_actor: int, target_id: int) -> void: granted.append(target_id))
	return {"player": player, "authority": authority, "controller": controller, "events": events, "granted": granted}


func _node(def: ResourceNodeDef, at: Vector2, authority: WorldAuthority) -> ResourceNode:
	var node: ResourceNode = ResourceScene.instantiate()
	node.def = def
	_root.add_child(node)
	_track.call(node)
	node.position = at
	authority.register(node)
	return node


func _click(world: Dictionary, point: Vector2) -> bool:
	var controller: PlayerController = world["controller"]
	return controller.world_click(LEFT, point, Vector2.ZERO, false)


# ----------------------------------------------------------------------------- testes

func _test_click_bush_in_reach() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var bush := _node(BUSH_DEF, Vector2(10.0, 0.0), authority)
	var player: Player = world["player"]
	var life := player.health.current_health
	_check(_click(world, Vector2(10.0, 0.0)), "clique esquerdo na moita ao alcance: a autoridade aceita")
	_check((world["granted"] as Array[int]) == [authority.id_of(bush)], "o pedido é o do E (`request_interact`): a coleta é concedida")
	_check(is_equal_approx(player.health.current_health, life) and player.gather_cooldown_left() >= 0.0, "não vira golpe no vazio")


func _test_click_bush_out_of_reach() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	_node(BUSH_DEF, Vector2(200.0, 0.0), authority)
	var player: Player = world["player"]
	var timer_before := player._attack_timer
	_check(not _click(world, Vector2(200.0, 0.0)), "moita fora do alcance: recusada")
	_check((world["granted"] as Array[int]).is_empty(), "nada é concedido")
	_check((world["events"] as Array).has(["action_refused", "out_of_range"]), "o log explica a recusa (fora de alcance)")
	_check(player._attack_timer == timer_before, "e não vira golpe (sem recarga de ataque)")


func _test_click_ground_item() -> void:
	var player := _player_at(Vector2.ZERO)
	var clock := TestWorld.TestClock.new()
	var authority := TestWorld.arm(player, [], _track)
	var field: GroundItemField = _track.call(GroundItemField.new())
	_root.add_child(field)
	field.set_physics_process(false)
	field.authority = authority
	field.clock = clock.now
	field.world_seed = 7
	var controller: PlayerController = _track.call(PlayerController.new())
	controller.player = player
	controller.authority = authority
	var piles := field.spawn_scatter(Items.WOOD, 1, Vector2(12.0, 0.0))
	var before := player.inventory.count(Items.WOOD)
	var at := piles[0].global_position
	_check(controller.world_click(LEFT, at, Vector2.ZERO, false), "clique esquerdo no item no chão ao alcance: recolhido")
	_check(player.inventory.count(Items.WOOD) == before + 1 and field.total_of(Items.WOOD) == 0, "foi para o inventário e saiu do chão")


func _test_creature_has_priority() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var bush := _node(BUSH_DEF, Vector2(14.0, 0.0), authority)
	var dino := _dino_at(Vector2(14.0, 0.0))
	authority.register(dino)
	player._in_range.append(dino.interactable)
	player.facing = Vector2.RIGHT
	var controller: PlayerController = world["controller"]
	_check(controller.cursor_action(Vector2(14.0, 0.0)) == PlayerController.CURSOR_ATTACK, "cursor: a criatura sob o ponteiro vence a moita")
	_click(world, Vector2(14.0, 0.0))
	_check(dino.health.current_health < dino.health.max_health or dino.torpor.current_torpor > 0.0, "o clique golpeia a criatura")
	_check(not (world["granted"] as Array[int]).has(authority.id_of(bush)), "e não colhe a moita que está por baixo")


func _test_cursor_actions() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var controller: PlayerController = world["controller"]
	_node(TREE, Vector2(10.0, 0.0), authority)
	_node(ROCK, Vector2(10.0, 60.0), authority)
	_node(IRON, Vector2(10.0, 120.0), authority)
	_node(BUSH_DEF, Vector2(10.0, 180.0), authority)
	var wild := _dino_at(Vector2(10.0, 240.0))
	authority.register(wild)
	var mine := _tamed(_dino_at(Vector2(10.0, 300.0)), player.player_id)
	authority.register(mine)
	var foreign := _tamed(_dino_at(Vector2(10.0, 360.0)), "outro_jogador")
	authority.register(foreign)
	var field: GroundItemField = _track.call(GroundItemField.new())
	_root.add_child(field)
	field.set_physics_process(false)
	field.authority = authority
	field.clock = TestWorld.TestClock.new().now
	field.world_seed = 7
	var item_at := field.spawn_scatter(Items.WOOD, 1, Vector2(10.0, 420.0))[0].global_position
	_check(controller.cursor_action(Vector2(10.0, 0.0)) == PlayerController.CURSOR_AXE, "árvore: machado")
	_check(controller.cursor_action(Vector2(10.0, 60.0)) == PlayerController.CURSOR_PICKAXE, "rocha: picareta")
	_check(controller.cursor_action(Vector2(10.0, 120.0)) == PlayerController.CURSOR_PICKAXE, "minério: picareta")
	_check(controller.cursor_action(Vector2(10.0, 180.0)) == PlayerController.CURSOR_HAND, "moita: mão")
	_check(controller.cursor_action(item_at) == PlayerController.CURSOR_HAND, "item no chão: mão")
	_check(controller.cursor_action(Vector2(10.0, 240.0)) == PlayerController.CURSOR_ATTACK, "selvagem vivo: ataque")
	_check(controller.cursor_action(Vector2(10.0, 300.0)) == PlayerController.CURSOR_INTERACT, "domado meu: interagir")
	_check(controller.cursor_action(Vector2(10.0, 360.0)) == PlayerController.CURSOR_DEFAULT, "domado de outro: padrão")
	_check(controller.cursor_action(Vector2(900.0, 900.0)) == PlayerController.CURSOR_DEFAULT, "nada sob o ponteiro: padrão")
	wild.health.take_damage(wild.health.max_health)
	_check(controller.cursor_action(Vector2(10.0, 240.0)) == PlayerController.CURSOR_DEFAULT, "selvagem morto: padrão")


func _test_cursor_reach_and_ui() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var controller: PlayerController = world["controller"]
	_node(BUSH_DEF, Vector2(10.0, 0.0), authority)
	_node(BUSH_DEF, Vector2(300.0, 0.0), authority)
	_node(TREE, Vector2(0.0, 300.0), authority)
	_check(controller.cursor_state(Vector2(10.0, 0.0))["in_reach"] == true, "moita perto: ao alcance")
	var far := controller.cursor_state(Vector2(300.0, 0.0))
	_check(far["action"] == PlayerController.CURSOR_HAND and far["in_reach"] == false, "moita longe: mão, fora de alcance (variante apagada)")
	var tree := controller.cursor_state(Vector2(0.0, 300.0))
	_check(tree["action"] == PlayerController.CURSOR_AXE and tree["in_reach"] == false, "árvore longe: machado, fora de alcance")
	_check(controller.cursor_action(Vector2(10.0, 0.0), true) == PlayerController.CURSOR_DEFAULT, "sobre a UI: padrão")
	_check(controller.cursor_in_reach(Vector2(10.0, 0.0), true), "sobre a UI não há alvo: sem variante apagada")
	_check(controller.current_cursor()["action"] == PlayerController.CURSOR_DEFAULT, "com o teclado em uso (mouse parado): padrão")
	controller.player = null
	_check(controller.cursor_action(Vector2(10.0, 0.0)) == PlayerController.CURSOR_DEFAULT, "sem jogador: padrão")


func _tamed(dino: Dino, owner: String) -> Dino:
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = owner
	return dino
