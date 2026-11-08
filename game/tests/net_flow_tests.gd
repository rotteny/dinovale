# SPDX-License-Identifier: MIT
class_name NetFlowTests
extends AuthorityTests
## NET-01 completo (uso de item, equipar, desequipar e colher pela autoridade), dono por `player_id`
## (ADR-003), Seguir em movimento (velocidade real do corpo, dono andando, dono morto ou ausente) e os avisos
## de recusa na `Main` de verdade. Reaproveita a montagem do `AuthorityTests`.

const SECOND_ID := "p3"
const SECOND_ENTITY := 20


func run() -> void:
	_test_new_intents_are_validated()
	_test_equip_and_unequip_validation()
	_test_player_methods_go_through_authority()
	_test_dead_actor_is_denied_everywhere()
	_test_feeder_and_owner_with_two_actors()
	_test_registry_helpers()
	_test_migration_feeder_and_restore_owner()
	_test_player_hitbox_alternative_data()
	await _test_gather_by_target_id()
	_release_worlds()
	await _test_follow_speed_and_walking_owner()
	_release_worlds()
	await _test_restored_order_moves_at_follow_speed()
	_release_worlds()
	await _test_owner_dead_or_absent()
	_release_worlds()
	await _test_main_shows_refusals()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

func _slot_of(inventory: InventoryComponent, item_id: String) -> int:
	for i in inventory.slot_count():
		if inventory.get_slot(i).get("id", "") == item_id:
			return i
	return -1


func _staff_iid(player: Player) -> String:
	var slot := _slot_of(player.inventory, Items.SLEEP_STAFF)
	return str(player.inventory.get_slot(slot).get("iid", "")) if slot >= 0 else ""


## Segundo jogador (`player_id` "p3", entity_id 3) registrado na mesma autoridade.
func _second_player(authority: WorldAuthority, position: Vector2) -> Player:
	var second := _player_at(position)
	second.player_id = SECOND_ID
	second.authority = authority
	authority.register(second, SECOND_ENTITY)
	return second


## `feeder` deposita a pilha de bagas no inventário da criatura `dino_id`.
func _feed(authority: WorldAuthority, feeder: Player, dino_id: int) -> Enums.ActionResult:
	var actor_id := authority.id_of(feeder)
	return authority.request_transfer_slot(actor_id, actor_id, _slot_of(feeder.inventory, Items.BERRY), dino_id)


func _denials(authority: WorldAuthority) -> Array:
	var log: Array = []
	authority.action_denied.connect(func(_actor: int, action: String, result: Enums.ActionResult) -> void:
		log.append([action, result]))
	return log


## Mundo mínimo para os testes de corpo: dono (id 1) e dino domado (id 2) num espaço de física próprio.
func _mini_world(owner_at: Vector2, dino_at: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	_root.add_child(viewport)
	_track.call(viewport)
	var authority := WorldAuthority.new()
	viewport.add_child(authority)
	var player: Player = PlayerScene.instantiate()
	viewport.add_child(player)
	player.set_physics_process(false)  # o teste move o dono à mão
	player.position = owner_at
	var dino: Dino = DinoScene.instantiate()
	viewport.add_child(dino)
	dino.position = dino_at
	_tamed(dino, Player.LOCAL_PLAYER_ID)
	player.authority = authority
	authority.register(player, 1)
	authority.register(dino, 2)
	return {"viewport": viewport, "authority": authority, "player": player, "dino": dino}


func _physics_dt() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


# ----------------------------------------------------------------------------- NET-01 completo

func _test_new_intents_are_validated() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var denied := _denials(authority)
	player.hunger.set_ratio(0.5)
	var berries := player.inventory.count(Items.BERRY)
	_check(authority.request_use_item(1, 0) == RESULT.OK and player.inventory.count(Items.BERRY) == berries - 1,
			"usar o atalho 0 pela autoridade: come a baga")
	var before := _snapshot(world)
	_check(authority.request_use_item(1, 1) == RESULT.COOLDOWN and _snapshot(world) == before,
			"comer de novo na recarga: negado e nada muda")
	_check(authority.request_use_item(1, -1) == RESULT.INVALID_ARGUMENT and authority.request_use_item(1, 9) == RESULT.INVALID_ARGUMENT
			and _snapshot(world) == before, "atalho fora de 0 a 8: argumento inválido, nada muda")
	_check(authority.request_use_item(77, 0) == RESULT.UNKNOWN_ACTOR and authority.request_use_item(2, 0) == RESULT.UNKNOWN_ACTOR,
			"ator desconhecido, ou criatura como ator: negado")
	_check(denied.size() == 5 and denied[0] == [WorldAuthority.ACTION_USE_ITEM, RESULT.COOLDOWN],
			"cada negação emite action_denied com a ação certa")
	player.tick(1.0)
	player.hunger.set_ratio(1.0)
	var full := _snapshot(world)
	_check(authority.request_use_item(1, 0) == RESULT.REFUSED and _snapshot(world) == full, "fome cheia: recusa de regra, nada gasto")


func _test_equip_and_unequip_validation() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var iid := _staff_iid(player)
	var refusals: Array = []
	player.equip_refused.connect(func(reason: String) -> void: refusals.append(reason))
	var before := _snapshot(world)
	_check(authority.request_equip(1, "x".repeat(40), "") == RESULT.INVALID_ARGUMENT
			and authority.request_equip(1, iid, "x".repeat(40)) == RESULT.INVALID_ARGUMENT
			and authority.request_unequip(1, "x".repeat(40)) == RESULT.INVALID_ARGUMENT
			and _snapshot(world) == before and refusals.is_empty(), "iid ou vaga longos demais: argumento inválido, a regra nem roda")
	_check(authority.request_equip(1, "nao_existe", "") == RESULT.REFUSED and refusals.size() == 1 and _snapshot(world) == before,
			"iid que não existe: recusa de regra com aviso, nada muda")
	_check(authority.request_equip(1, iid, "") == RESULT.OK and player.equipped_iid == iid, "equipar pela autoridade")
	_check(authority.request_unequip(1, EquipmentLayout.WEAPON) == RESULT.COOLDOWN and player.equipped_iid == iid
			and refusals.size() == 1, "desequipar na recarga: negado, silencioso")
	player.tick(1.0)
	_check(authority.request_unequip(1, EquipmentLayout.WEAPON) == RESULT.OK and player.equipped_iid == "", "desequipar pela autoridade")
	_check(authority.request_equip(77, iid, "") == RESULT.UNKNOWN_ACTOR, "equipar com ator desconhecido: negado")
	# O corpo do jogador usa o mesmo caminho: sem autoridade, nada acontece.
	var unguided := _player_at(Vector2.ZERO)
	_check(unguided.request_equip(_staff_iid(unguided)) == Player.DENIED and unguided.request_unequip(EquipmentLayout.WEAPON) == Player.DENIED
			and unguided.request_gather() == Player.GATHER_BLOCKED and not unguided.request_use_item(0),
			"jogador sem autoridade não usa item, não equipa nem colhe")


## Pelos métodos do próprio `Player`: o pedido inválido chega à autoridade, que nega e avisa, e nada muda.
func _test_player_methods_go_through_authority() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var denied := _denials(authority)
	var before := _snapshot(world)
	_check(not player.request_use_item(99) and denied == [[WorldAuthority.ACTION_USE_ITEM, RESULT.INVALID_ARGUMENT]]
			and _snapshot(world) == before, "Player.request_use_item inválido: action_denied e nada muda")
	_check(player.request_equip("x".repeat(40)) == Player.DENIED
			and denied.back() == [WorldAuthority.ACTION_EQUIP, RESULT.INVALID_ARGUMENT]
			and _snapshot(world) == before, "Player.request_equip inválido: action_denied e nada muda")
	_check(player.request_unequip("x".repeat(40)) == Player.DENIED
			and denied.back() == [WorldAuthority.ACTION_UNEQUIP, RESULT.INVALID_ARGUMENT]
			and denied.size() == 3 and _snapshot(world) == before, "Player.request_unequip inválido: action_denied e nada muda")


func _test_dead_actor_is_denied_everywhere() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var iid := _staff_iid(player)
	player.health.take_damage(player.health.max_health * 10.0)
	var before := _snapshot(world)
	_check(authority.request_use_item(1, 0) == RESULT.ACTOR_DEAD and authority.request_equip(1, iid, "") == RESULT.ACTOR_DEAD
			and authority.request_unequip(1, EquipmentLayout.WEAPON) == RESULT.ACTOR_DEAD
			and authority.request_gather(1, 5) == RESULT.ACTOR_DEAD and _snapshot(world) == before,
			"jogador morto: uso, equipar, desequipar e colher negados, nada muda")


# ----------------------------------------------------------------------------- dono e quem alimentou

func _test_feeder_and_owner_with_two_actors() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var first: Player = world["player"]
	var second := _second_player(authority, Vector2(10, 0))
	var wild := _sleeping(_dino_at(Vector2(0, 30)))
	var other_wild := _sleeping(_dino_at(Vector2(10, 30)))
	authority.register(wild)
	authority.register(other_wild)
	first.inventory.add(Items.BERRY, 30)
	second.inventory.add(Items.BERRY, 30)
	var wild_id := authority.id_of(wild)
	var other_id := authority.id_of(other_wild)
	_check(authority.player_id_of(1) == "local" and authority.player_id_of(SECOND_ENTITY) == SECOND_ID
			and authority.player_id_of(wild_id) == "",
			"player_id sai do jogador registrado, e de mais ninguém")
	# O segundo alimenta: o candidato é ele, não o jogador 1.
	_check(_feed(authority, second, wild_id) == RESULT.OK
			and wild.feeder_player_id == SECOND_ID, "alimentador de id 3 vira o candidato a dono")
	# Recolher a comida NÃO faz de quem recolhe o alimentador.
	_check(authority.request_transfer_slot(1, wild_id, 0, 1) == RESULT.OK and wild.feeder_player_id == SECOND_ID
			and first.inventory.count(Items.BERRY) > 10 - 1, "recolher a comida ideal não muda quem alimentou")
	# O primeiro a alimentar reserva a criatura: A alimenta, B alimenta, A fica dono.
	_check(_feed(authority, first, wild_id) == RESULT.OK and wild.feeder_player_id == SECOND_ID,
			"quem alimentou depois não toma a reserva de quem alimentou primeiro")
	# Golpe de quem não reservou não derruba a Eficiência; o do dono da reserva derruba.
	var before := wild.taming.efficiency
	_check(wild.receive_hit(0.0, 0.0, TamingRules.ATTACKER_PLAYER, "local") and wild.taming.efficiency == before,
			"golpe de outro jogador não reduz a Eficiência")
	_check(wild.receive_hit(0.0, 0.0, TamingRules.ATTACKER_PLAYER, SECOND_ID) and wild.taming.efficiency < before,
			"golpe de quem reservou reduz a Eficiência")
	# Doma reiniciada (acordou selvagem) libera a reserva.
	var reset_dino := _sleeping(_dino_at(Vector2(30, 30)))
	reset_dino.feeder_player_id = "local"
	reset_dino.taming.taming_reset.emit()
	_check(reset_dino.feeder_player_id == "", "doma reiniciada limpa a reserva")
	# O mesmo vale quando o outro recolhe o que o primeiro depositou.
	var third := _sleeping(_dino_at(Vector2(20, 30)))
	authority.register(third)
	var third_id := authority.id_of(third)
	_check(_feed(authority, first, third_id) == RESULT.OK and third.feeder_player_id == "local"
			and authority.request_transfer_slot(SECOND_ENTITY, third_id, 0, SECOND_ENTITY) == RESULT.OK and third.feeder_player_id == "local",
			"recolher depois de outro depositar: quem alimentou continua o mesmo")
	# Domesticar com cada alimentador dá o dono certo (nunca um id fixo).
	wild.taming.tick(100.0)
	_check(wild.state_machine.is_tamed and wild.owner_player_id == SECOND_ID, "domesticou: dono é quem alimentou primeiro (3)")
	_check(_feed(authority, second, other_id) == RESULT.OK, "preparo: o jogador 3 deposita")
	other_wild.taming.tick(100.0)
	_check(other_wild.state_machine.is_tamed and other_wild.owner_player_id == SECOND_ID and other_wild.feeder_player_id == SECOND_ID,
			"domesticou: dono é o jogador 3, não o 1")
	# Ordens: só o dono certo manda.
	_check(authority.request_command(1, other_id, "FOLLOW") == RESULT.NOT_OWNER and other_wild.state_machine.order == Enums.DinoOrder.STAY,
			"o jogador 1 não manda no dino do 3")
	_check(authority.request_command(SECOND_ENTITY, other_id, "FOLLOW") == RESULT.OK
			and other_wild.state_machine.order == Enums.DinoOrder.FOLLOW, "o jogador 3 manda no dele")
	_check(authority.request_command(1, wild_id, "FOLLOW") == RESULT.NOT_OWNER, "e o jogador 1 não manda no que o 3 reservou primeiro")


func _test_registry_helpers() -> void:
	var authority := WorldAuthority.new()
	_track.call(authority)
	var player := _player_at(Vector2.ZERO)
	player.player_id = "alguem"
	authority.register(player, 4)
	_check(authority.player_body("alguem") == player and authority.player_body("outro") == null, "o corpo do jogador sai pelo player_id")
	_check(authority.next_entity_id() == 5, "o próximo id livre é o contador real")
	authority.ensure_next_id(40)
	authority.ensure_next_id(10)
	_check(authority.next_entity_id() == 40 and authority.register(_dino_at(Vector2.ZERO)) == 40,
			"o contador só sobe (carregar um save) e o id novo nunca é reutilizado")
	var envelope := WorldSnapshot.capture(_player_at(Vector2.ZERO), null, "t", "t", null, 0, authority.next_entity_id())
	_check(envelope["world"]["next_entity_id"] == 41 and WorldSnapshot.next_entity_id_of(envelope) == 41,
			"o save leva o contador real, não um valor fixo")


# ----------------------------------------------------------------------------- migração e carga

func _test_migration_feeder_and_restore_owner() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V2))
	raw["players"][0]["player_id"] = "p-save"
	var started := raw.duplicate(true)
	started["entities"][0]["state"]["taming"] = {"progress": 40.0, "efficiency": 80.0}
	var state: Dictionary = SaveMigrations.migrate(started)["entities"][0]["state"]
	_check(state.get("feeder_player_id") == "p-save" and not state.has("owner_player_id"),
			"v2 para v3: selvagem com progresso ganha quem alimentou (o primeiro jogador), sem dono")
	var fed := raw.duplicate(true)
	fed["entities"][0]["state"]["taming"] = {"progress": 0.0}
	fed["entities"][0]["state"]["inventory"] = {"version": 2, "slots": [{"id": "berry", "count": 3}, {}]}
	_check(SaveMigrations.migrate(fed)["entities"][0]["state"].get("feeder_player_id") == "p-save",
			"v2 para v3: selvagem com comida na criatura ganha quem alimentou")
	var idle := raw.duplicate(true)
	idle["entities"][0]["state"]["taming"] = {"progress": 0.0}
	idle["entities"][0]["state"]["inventory"] = {"version": 2, "slots": [{}, {}]}
	_check(not SaveMigrations.migrate(idle)["entities"][0]["state"].has("feeder_player_id"),
			"v2 para v3: selvagem sem andamento não ganha nada")
	var tamed := raw.duplicate(true)
	tamed["entities"][0]["state"]["state_machine"]["is_tamed"] = true
	var tamed_state: Dictionary = SaveMigrations.migrate(tamed)["entities"][0]["state"]
	_check(tamed_state["owner_player_id"] == "p-save" and tamed_state["feeder_player_id"] == "p-save",
			"v2 para v3: o domado é do primeiro jogador (player_id), como quem alimentou")
	# is_tamed que não é booleano: não aborta a migração nem vira domado.
	for odd: Variant in ["yes", 1, [], {}]:
		var weird := raw.duplicate(true)
		weird["entities"][0]["state"]["state_machine"]["is_tamed"] = odd
		var weird_state: Dictionary = SaveMigrations.migrate(weird)["entities"][0]["state"]
		_check(not weird_state.has("owner_player_id") and not weird_state["state_machine"].has("order"),
				"v2 para v3 com is_tamed %s: tratado como selvagem, sem erro" % str(odd))
	# O selvagem migrado carrega o alimentador.
	var restored_wild := _dino_at(Vector2.ZERO)
	_check(restored_wild.from_dict(SaveMigrations.migrate(started)["entities"][0]["state"]) and restored_wild.feeder_player_id == "p-save"
			and restored_wild.owner_player_id == "", "o selvagem migrado carrega quem alimentou")
	# Carga: domado sem dono válido vira do primeiro jogador do save.
	var manager := SaveManager.new(root_dir)
	var data: Dictionary = manager.read_file(FIXTURE_V3).data
	for owner: Variant in ["ghost", "", null, 7, "x".repeat(70)]:
		var broken: Dictionary = data.duplicate(true)
		if owner == null:
			broken["entities"][0]["state"].erase("owner_player_id")
		else:
			broken["entities"][0]["state"]["owner_player_id"] = owner
		var dino := _dino_at(Vector2.ZERO)
		_check(WorldSnapshot.restore(broken, _player_at(Vector2.ZERO), dino) and dino.state_machine.is_tamed
				and dino.owner_player_id == str(data["world"]["local_player_id"]) and dino.can_command(),
				"domado sem dono válido (%s): vira do primeiro jogador do save" % str(owner))
	var kept := _dino_at(Vector2.ZERO)
	var other_owner: Dictionary = data.duplicate(true)
	other_owner["players"].append({"player_id": "amigo", "entity_id": 3, "life": "alive", "state": {}})
	other_owner["entities"][0]["state"]["owner_player_id"] = "amigo"
	_check(WorldSnapshot.restore(other_owner, _player_at(Vector2.ZERO), kept) and kept.owner_player_id == "amigo",
			"dono que está no save é respeitado (offline também)")


func _test_player_hitbox_alternative_data() -> void:
	var custom: Player = PlayerScene.instantiate()
	custom.rules = custom.rules.duplicate()
	custom.rules.hitbox_size = Vector2(14, 12)
	_root.add_child(custom)
	_track.call(custom)
	_check((custom.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(14, 12), "outro dado do jogador, outra caixa")


# ----------------------------------------------------------------------------- colher pelo id do alvo

func _test_gather_by_target_id() -> void:
	var tree := _root.get_tree()
	var main := _main_with_physics()
	await tree.physics_frame
	var player := main.player
	player.set_physics_process(false)
	var authority := main.authority
	var bush := main.resources.node_by_id("n1")
	var wood := main.resources.node_by_id("n316")
	var denied := _denials(authority)
	player.position = bush.position + Vector2(0, 10)
	player.target = wood.interactable  # a mira local aponta para OUTRO nó
	var berries := player.inventory.count(Items.BERRY)
	_check(authority.request_gather(1, authority.id_of(bush)) == RESULT.OK and not bush.is_available() and wood.is_available()
			and player.inventory.count(Items.BERRY) > berries, "colher usa o id do alvo, não a mira local")
	_check(authority.request_gather(1, authority.id_of(main.dino)) == RESULT.UNKNOWN_TARGET
			and authority.request_gather(1, 99999999) == RESULT.UNKNOWN_TARGET,
			"alvo que não é nó de recurso, ou que não existe: negado")
	player.tick(20.0)
	var before := player.to_dict()
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OUT_OF_RANGE and wood.is_available() and player.to_dict() == before,
			"nó longe: negado pela distância real, o nó não gasta")
	_check(authority.request_gather(1, authority.id_of(bush)) == RESULT.WRONG_STATE
			and denied.back() == [WorldAuthority.ACTION_GATHER, RESULT.WRONG_STATE],
			"nó esgotado: negado (%s)" % str(denied.back()))
	player.position = wood.position + Vector2(0, 10)
	player.facing = Vector2.UP
	player.tick(10.0)
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK and wood.component.has_damage(),
			"perto do nó certo, de frente: o golpe conta")
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.COOLDOWN, "a recarga do golpe vale")
	main.get_parent().queue_free()
	await tree.process_frame


# ----------------------------------------------------------------------------- Seguir em movimento

func _test_follow_speed_and_walking_owner() -> void:
	var tree := _root.get_tree()
	var rules := ORDER_RULES
	var walk := 70.0
	_check(rules.follow_speed_multiplier >= 1.75 and 40.0 * rules.follow_speed_multiplier > walk,
			"Seguir: o multiplicador do dado põe o dino acima do andar do jogador")
	var world := _mini_world(Vector2(200, 100), Vector2(170, 100))
	var player: Player = world["player"]
	var dino: Dino = world["dino"]
	var authority: WorldAuthority = world["authority"]
	await tree.physics_frame
	_check(authority.request_command(1, 2, "FOLLOW") == RESULT.OK, "preparo: o dono manda Seguir")
	# Velocidade real do corpo: o multiplicador chega à física.
	player.position = Vector2(600, 100)
	await tree.physics_frame
	await tree.physics_frame
	var expected: float = dino.move_speed * rules.follow_speed_multiplier
	_check(is_equal_approx(dino.velocity.length(), expected) and dino.velocity.length() > walk,
			"Seguir: o corpo anda a %.1f px/s (esperado %.1f)" % [dino.velocity.length(), expected])
	# O dono anda (70 px/s): o dino acompanha a até 3 tiles.
	player.position = dino.position + Vector2(30, 0)
	await tree.physics_frame
	var farthest := 0.0
	var started_at := dino.position
	for i in 150:
		player.position += Vector2.RIGHT * walk * _physics_dt()
		await tree.physics_frame
		farthest = maxf(farthest, dino.position.distance_to(player.position))
	_check(dino.position.distance_to(started_at) > 100.0, "o dino saiu do lugar e andou atrás do dono")
	_check(farthest <= rules.follow_px() + 4.0, "dono andando: o dino fica a até 3 tiles (maior distância %.1f px)" % farthest)
	# O dono corre e abre distância; ao parar, o dino alcança.
	for i in 60:
		player.position += Vector2.RIGHT * 120.0 * _physics_dt()
		await tree.physics_frame
	var opened := dino.position.distance_to(player.position)
	for i in 150:
		await tree.physics_frame
	var closed := dino.position.distance_to(player.position)
	_check(opened > rules.follow_px() and closed <= rules.follow_px() + 1.0,
			"dono correndo abre distância (%.1f px); parado, o dino alcança (%.1f px)" % [opened, closed])
	world["viewport"].queue_free()
	await tree.process_frame


func _test_restored_order_moves_at_follow_speed() -> void:
	var tree := _root.get_tree()
	var rules := ORDER_RULES
	var world := _mini_world(Vector2(400, 100), Vector2(100, 100))
	var dino: Dino = world["dino"]
	await tree.physics_frame
	dino.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(dino.to_dict()))
	var viewport: SubViewport = world["viewport"]
	var copy: Dino = DinoScene.instantiate()
	viewport.add_child(copy)
	copy.position = Vector2(100, 200)
	_tamed(copy, "local")  # já domado e em Ficar: a carga cai no mesmo estado e precisa reaplicar a ordem
	var authority: WorldAuthority = world["authority"]
	authority.register(copy, 5)
	_check(copy.from_dict(saved) and copy.state_machine.order == Enums.DinoOrder.FOLLOW, "preparo: a ordem volta do save")
	await tree.physics_frame
	await tree.physics_frame
	_check(is_equal_approx(copy.velocity.length(), copy.move_speed * rules.follow_speed_multiplier),
			"ordem restaurada: o corpo já anda na velocidade do Seguir (%.1f px/s)" % copy.velocity.length())
	viewport.queue_free()
	await tree.process_frame


func _test_owner_dead_or_absent() -> void:
	var tree := _root.get_tree()
	var world := _mini_world(Vector2(400, 100), Vector2(100, 100))
	var player: Player = world["player"]
	var dino: Dino = world["dino"]
	var authority: WorldAuthority = world["authority"]
	await tree.physics_frame
	dino.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	for i in 5:
		await tree.physics_frame
	_check(dino.velocity.length() > 0.0 and dino.position.x > 100.0, "dono vivo e longe: o dino vai até ele")
	# Dono morto conta como ausente: o dino fica onde está e a ordem se mantém.
	TestWorld.kill(player)
	await tree.physics_frame
	await tree.physics_frame
	var stopped_at := dino.position
	for i in 20:
		await tree.physics_frame
	_check(player.health.is_dead() and dino.velocity == Vector2.ZERO and dino.position == stopped_at
			and dino.state_machine.order == Enums.DinoOrder.FOLLOW, "dono morto: o dino fica parado e a ordem Seguir se mantém")
	# Renasceu: volta a seguir sozinho.
	player.respawn_at(Vector2(500, 100), load("res://data/balance/respawn_rules.tres"))
	for i in 20:
		await tree.physics_frame
	_check(not player.health.is_dead() and dino.position.x > stopped_at.x + 5.0, "dono renasceu: o dino volta a seguir")
	# Dono fora do mundo: também fica parado (não vai a um ponto qualquer).
	authority.unregister(1)
	await tree.physics_frame
	await tree.physics_frame
	var absent_at := dino.position
	for i in 20:
		await tree.physics_frame
	_check(dino.velocity == Vector2.ZERO and dino.position == absent_at, "dono ausente do mundo: o dino fica parado")
	world["viewport"].queue_free()
	await tree.process_frame


# ----------------------------------------------------------------------------- avisos na Main

func _test_main_shows_refusals() -> void:
	var tree := _root.get_tree()
	var main := _main_with_physics()
	await tree.physics_frame
	var player := main.player
	player.set_physics_process(false)
	var dino := main.dino
	var hud: PlayerHud = main.hud
	# Domado de outro: a tecla de interação avisa que não é seu.
	_tamed(dino, "outro")
	dino.global_position = player.global_position + Vector2(24, 0)
	player.target = dino.interactable
	_check(not player.try_interact() and hud.notice_label().visible and hud.notice_label().text == "Esse dino não é seu.",
			"Main: ordenar o dino de outro avisa 'não é seu'")
	# Transferência recusada pela regra (equipamento não vai para a criatura) avisa na tela.
	main.get_parent().queue_free()
	await tree.process_frame
	main = _main_with_physics()
	await tree.physics_frame
	player = main.player
	player.set_physics_process(false)
	dino = main.dino
	_sleeping(dino)
	dino.global_position = player.global_position + Vector2(24, 0)
	player.target = dino.interactable
	_check(player.try_interact() and main.screen.is_open, "Main: a interação abre a tela da criatura dormindo")
	var staff_slot := _slot_of(player.inventory, Items.SLEEP_STAFF)
	main.screen.slot_button(true, staff_slot).pressed.emit()
	_check(main.screen.notice_text().contains("não vai para a criatura") and player.inventory.count(Items.SLEEP_STAFF) == 1,
			"Main: equipamento recusado avisa na tela e o item fica")
	# Longe demais: a negação da autoridade vira o texto certo.
	dino.global_position = player.global_position + Vector2(400, 0)
	main.screen.slot_button(true, _slot_of(player.inventory, Items.BERRY)).pressed.emit()
	_check(main.screen.notice_text() == "Longe demais." and dino.inventory.count(Items.BERRY) == 0,
			"Main: transferir longe avisa 'Longe demais.' e nada passa")
	# Cada negação tem o seu texto.
	var texts := {}
	for result: Enums.ActionResult in [RESULT.OUT_OF_RANGE, RESULT.NOT_OWNER, RESULT.WRONG_STATE, RESULT.ACTOR_DEAD]:
		main.screen.show_transfer_refusal(result)
		texts[main.screen.notice_text()] = true
	_check(texts.size() == 4, "a tela tem um texto para cada tipo de negação (%d textos)" % texts.size())
	# O contador de ids do save é o da autoridade, não um valor fixo.
	_check(main.scheduler.authority == main.authority and main.authority.next_entity_id() > WorldSnapshot.DINO_ENTITY_ID + 1,
			"Main: o save recebe o contador real de ids (%d)" % main.authority.next_entity_id())
	main.get_parent().queue_free()
	await tree.process_frame
