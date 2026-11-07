# SPDX-License-Identifier: MIT
class_name AuthorityTests
extends RefCounted
## NET-01 (camada de autoridade), CRI-05 (ordens Seguir e Ficar) e MUN-01 (colisão e limites).
## Chamado por `run_tests.gd`; não é um runner: recebe a raiz da árvore, o registro de nós para liberar
## e o `_check` do runner.

const DinoScene := preload("res://src/entities/dino/Dino.tscn")
const PlayerScene := preload("res://src/entities/player/Player.tscn")
const MAIN_SCENE: PackedScene = preload("res://src/world/Main.tscn")
const RESULT := Enums.ActionResult
const ORDER_RULES: DinoOrderRules = preload("res://data/balance/dino_order_rules.tres")
const FIXTURE_V2 := "res://tests/fixtures/saves/v2.json"
const FIXTURE_V3 := "res://tests/fixtures/saves/v3.json"
const MAP_SIZE := Vector2(4096.0, 4096.0)
static var root_dir: String = SaveTests.base_dir + "/authority"

var _root: Node
var _track: Callable
var _check_fn: Callable


func _init(root: Node, track: Callable, check: Callable) -> void:
	_root = root
	_track = track
	_check_fn = check


func run() -> void:
	_test_registry()
	_test_rules_data()
	_test_denied_intents_change_nothing()
	_test_dead_actor_is_denied()
	await _test_request_move()
	_test_attack_and_interact_paths()
	_test_feeding_makes_the_owner()
	_test_command_rules()
	_test_follow_rules_pure()
	_test_follow_and_stay_in_motion()
	_test_order_save()
	_test_migration_and_fixture_v3()
	_test_hitbox_by_data()
	await _test_map_limits_and_collision()
	_release_worlds()
	await _test_follower_stays_inside()
	_release_worlds()


func _check(condition: bool, label: String) -> void:
	_check_fn.call(condition, label)


# ----------------------------------------------------------------------------- montagem

func _dino_at(position: Vector2) -> Dino:
	var dino: Dino = DinoScene.instantiate()
	_root.add_child(dino)
	_track.call(dino)
	dino.set_physics_process(false)
	dino.position = position
	return dino


func _player_at(position: Vector2) -> Player:
	var player: Player = PlayerScene.instantiate()
	_root.add_child(player)
	_track.call(player)
	player.set_physics_process(false)
	player.position = position
	return player


func _sleeping(dino: Dino) -> Dino:
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	return dino


## Domesticado, acordado, do dono `owner` (`player_id`).
func _tamed(dino: Dino, owner: String) -> Dino:
	_sleeping(dino)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = owner
	return dino


## O mundo dos testes de negação: um jogador (id 1) e criaturas em situações diferentes.
func _world() -> Dictionary:
	var world := {}
	var player := _player_at(Vector2.ZERO)
	var awake := _dino_at(Vector2(20, 0))
	var asleep := _sleeping(_dino_at(Vector2(0, 20)))
	var far := _sleeping(_dino_at(Vector2(500, 0)))
	var foreign := _tamed(_dino_at(Vector2(-20, 0)), "outro")
	var mine := _tamed(_dino_at(Vector2(0, -20)), "local")
	var far_mine := _tamed(_dino_at(Vector2(-500, 0)), "local")
	var authority := TestWorld.arm(player, [awake, asleep, far, foreign, mine, far_mine], _track)
	world.merge({"player": player, "awake": awake, "asleep": asleep, "far": far, "foreign": foreign, "mine": mine,
			"far_mine": far_mine, "authority": authority})
	return world


## Tudo o que um pedido negado não pode mexer: jogador, criaturas e a recarga do golpe.
func _snapshot(world: Dictionary) -> String:
	var parts: Array = [world["player"].to_dict(), world["player"]._attack_timer]
	for key in ["awake", "asleep", "far", "foreign", "mine", "far_mine"]:
		var dino: Dino = world[key]
		parts.append([dino.to_dict(), dino.state_machine.order, dino.position])
	return JSON.stringify(parts)


# ----------------------------------------------------------------------------- NET-01

func _test_registry() -> void:
	var authority := WorldAuthority.new()
	_track.call(authority)
	var a := _dino_at(Vector2.ZERO)
	var b := _dino_at(Vector2.ZERO)
	_check(authority.register(a, 7) == 7 and authority.id_of(a) == 7 and authority.entity(7) == a, "registro: id pedido")
	_check(authority.register(b, 7) == 0 and authority.entity(7) == a, "registro: id em uso é recusado e não troca o dono")
	var next := authority.register(b)
	_check(next == 8 and authority.id_of(b) == 8, "registro: o próximo livre vem depois do maior id")
	_check(authority.entity(0) == null and authority.entity(-3) == null and authority.entity(99) == null,
			"id inválido ou desconhecido: nulo")
	_check(authority.id_of(null) == 0 and authority.register(null) == 0, "nó nulo não registra")
	_check(a.player_locator.is_valid(), "a criatura achará o dono pelo registro")
	b.queue_free()
	_check(authority.entity(8) == null, "nó que sai do mundo deixa de ser resolvido")


func _test_rules_data() -> void:
	var rules: ActionRules = load("res://data/balance/action_rules.tres")
	var order := ORDER_RULES
	_check(rules.reach_px() == 48.0 and rules.command_reach_px() == 48.0, "alcances vêm do dado (3 tiles de 16 px)")
	_check(order.follow_px() == 48.0 and order.arrive_px() == 40.0 and order.follow_speed_multiplier > 1.0,
			"Seguir: 3 tiles, para a 2,5 (dado)")


## Aceite do NET-01: intents inválidas são rejeitadas na camada de autoridade e nada muda.
func _test_denied_intents_change_nothing() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var ids := {}
	for key in ["awake", "asleep", "far", "foreign", "mine", "far_mine"]:
		ids[key] = authority.id_of(world[key])
	var staff_slot := -1
	for i in player.inventory.slot_count():
		if Items.is_individual(str(player.inventory.get_slot(i).get("id", ""))):
			staff_slot = i
	var food_slot := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("id", "") == Items.BERRY:
			food_slot = i
	_check(staff_slot >= 0 and food_slot >= 0, "preparo: o jogador tem o Bastão e as bagas")
	# Recarga: um golpe válido primeiro, depois o seguinte é negado sem mexer na recarga.
	_check(authority.request_attack(1, ids["awake"]) == Enums.ActionResult.OK, "preparo: o primeiro golpe passa")
	# [rótulo, pedido, argumentos (StringName = id de entidade pelo apelido), resultado esperado]
	var cases: Array = [
		["golpe longe demais", "request_attack", [1, &"far"], RESULT.OUT_OF_RANGE],
		["golpe em recarga", "request_attack", [1, &"awake"], RESULT.COOLDOWN],
		["golpe em domesticado", "request_attack", [1, &"foreign"], RESULT.INVALID_TARGET],
		["golpe em id inexistente", "request_attack", [1, 999], RESULT.UNKNOWN_TARGET],
		["golpe de ator inexistente", "request_attack", [42, &"awake"], RESULT.UNKNOWN_ACTOR],
		["golpe com id negativo", "request_attack", [-1, -1], RESULT.UNKNOWN_ACTOR],
		["golpe no próprio jogador", "request_attack", [1, 1], RESULT.UNKNOWN_TARGET],
		["alimentar dino acordado", "request_transfer_slot", [1, 1, food_slot, &"awake"], RESULT.WRONG_STATE],
		["alimentar dino domado de outro", "request_transfer_slot", [1, 1, food_slot, &"foreign"], RESULT.NOT_OWNER],
		["alimentar dino longe", "request_transfer_slot", [1, 1, food_slot, &"far"], RESULT.OUT_OF_RANGE],
		["alimentar com slot inválido", "request_transfer_slot", [1, 1, 99, &"asleep"], RESULT.INVALID_ARGUMENT],
		["alimentar com slot negativo", "request_transfer_slot", [1, 1, -1, &"asleep"], RESULT.INVALID_ARGUMENT],
		["alimentar com equipamento", "request_transfer_slot", [1, 1, staff_slot, &"asleep"], RESULT.REFUSED],
		["transferir entre terceiros", "request_transfer_slot", [1, &"asleep", 0, &"far"], RESULT.INVALID_ARGUMENT],
		["transferir de si para si", "request_transfer_slot", [1, 1, 0, 1], RESULT.INVALID_ARGUMENT],
		["interagir com dino acordado", "request_interact", [1, &"awake"], RESULT.WRONG_STATE],
		["interagir longe", "request_interact", [1, &"far"], RESULT.OUT_OF_RANGE],
		["interagir consigo", "request_interact", [1, 1], RESULT.UNKNOWN_TARGET],
		["ordenar dino selvagem", "request_command", [1, &"awake", "FOLLOW"], RESULT.WRONG_STATE],
		["ordenar dino que não é seu", "request_command", [1, &"foreign", "FOLLOW"], RESULT.NOT_OWNER],
		["ordenar dino longe", "request_command", [1, &"far_mine", "FOLLOW"], RESULT.OUT_OF_RANGE],
		["ordem desconhecida", "request_command", [1, &"mine", "FLY"], RESULT.INVALID_ARGUMENT],
		["ordem vazia", "request_command", [1, &"mine", ""], RESULT.INVALID_ARGUMENT],
		["ordem com nome gigante", "request_command", [1, &"mine", "F".repeat(5000)], RESULT.INVALID_ARGUMENT],
		["ordem por índice do enum", "request_command", [1, &"mine", "1"], RESULT.INVALID_ARGUMENT],
		["ordenar quem não existe", "request_command", [1, 999, "FOLLOW"], RESULT.UNKNOWN_TARGET],
		["ordenar o jogador", "request_command", [1, 1, "FOLLOW"], RESULT.UNKNOWN_TARGET],
		["ordem de ator inexistente", "request_command", [77, &"mine", "FOLLOW"], RESULT.UNKNOWN_ACTOR],
		["mover com NaN", "request_move", [1, Vector2(NAN, 0.0)], RESULT.INVALID_ARGUMENT],
		["mover com infinito", "request_move", [1, Vector2(0.0, INF)], RESULT.INVALID_ARGUMENT],
		["mover com menos infinito", "request_move", [1, Vector2(-INF, 0.0)], RESULT.INVALID_ARGUMENT],
		["mover com comprimento 50", "request_move", [1, Vector2(50.0, 0.0)], RESULT.INVALID_ARGUMENT],
		["mover na diagonal sem normalizar", "request_move", [1, Vector2(1.0, 1.0)], RESULT.INVALID_ARGUMENT],
		["mover ator inexistente", "request_move", [42, Vector2.RIGHT], RESULT.UNKNOWN_ACTOR],
	]
	for entry: Array in cases:
		var before := _snapshot(world)
		var denials: Array = []
		var listener := func(actor: int, action: String, result: Enums.ActionResult) -> void: denials.append([actor, action, result])
		authority.action_denied.connect(listener)
		var args: Array = []
		for arg: Variant in entry[2]:
			args.append(ids[arg] if typeof(arg) == TYPE_STRING_NAME else arg)
		var result: int = authority.callv(entry[1], args)
		authority.action_denied.disconnect(listener)
		_check(result == entry[3], "%s: negado com %s (veio %s)" % [entry[0], RESULT.find_key(entry[3]), RESULT.find_key(result)])
		_check(_snapshot(world) == before, "%s: nada mudou no estado" % entry[0])
		_check(denials.size() == 1 and denials[0][2] == entry[3], "%s: emite action_denied uma vez" % entry[0])
	# Domesticado inconsciente também não obedece.
	var mine: Dino = world["mine"]
	mine.torpor.add_torpor(mine.torpor.max_torpor)
	var before_sleep := _snapshot(world)
	_check(authority.request_command(1, ids["mine"], "FOLLOW") == Enums.ActionResult.WRONG_STATE
			and _snapshot(world) == before_sleep, "ordenar domado inconsciente: negado e nada muda")


func _test_dead_actor_is_denied() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var mine: Dino = world["mine"]
	player.health.take_damage(1000.0)
	var before := _snapshot(world)
	_check(authority.request_attack(1, authority.id_of(world["awake"])) == Enums.ActionResult.ACTOR_DEAD
			and authority.request_interact(1, authority.id_of(world["asleep"])) == Enums.ActionResult.ACTOR_DEAD
			and authority.request_command(1, authority.id_of(mine), "FOLLOW") == Enums.ActionResult.ACTOR_DEAD
			and authority.request_transfer_slot(1, 1, 0, authority.id_of(world["asleep"])) == Enums.ActionResult.ACTOR_DEAD,
			"jogador morto: golpe, interação, ordem e transferência negados")
	_check(_snapshot(world) == before, "jogador morto: nada mudou")


func _physics_frames(count: int) -> void:
	for _i in count:
		await _root.get_tree().physics_frame


## `request_move` valido anda no quadro seguinte; um pedido some depois de um quadro (sem pedido novo, para);
## morto nao anda e nao incomoda (sem `action_denied`).
func _test_request_move() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var denials := [0]
	player.set_physics_process(true)
	authority.action_denied.connect(func(_a: int, _b: String, _c: Enums.ActionResult) -> void: denials[0] += 1)
	_check(authority.request_move(1, Vector2.RIGHT, false) == RESULT.OK and authority.request_move(1, Vector2.ZERO) == RESULT.OK
			and authority.request_move(1, Vector2(0.6, 0.8)) == RESULT.OK and authority.request_move(1, Vector2.RIGHT) == RESULT.OK,
			"direção válida (zero, diagonal normalizada, eixo) é aceita")
	await _physics_frames(2)
	var after_one := player.position.x
	_check(after_one > 0.0, "pedido válido move o corpo para a direção (%s)" % player.position)
	await _physics_frames(2)
	_check(is_equal_approx(player.position.x, after_one), "sem pedido novo o corpo para")
	_check(authority.request_move(1, Vector2(NAN, 0.0)) == RESULT.INVALID_ARGUMENT, "NaN negado")
	await _physics_frames(2)
	_check(is_equal_approx(player.position.x, after_one), "pedido negado não move")
	player.health.take_damage(1000.0)
	var denied_before: int = denials[0]
	_check(authority.request_move(1, Vector2.RIGHT) == RESULT.ACTOR_DEAD and denials[0] == denied_before, "morto: negado em silêncio")
	_release_worlds()


func _test_attack_and_interact_paths() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var awake: Dino = world["awake"]
	var hits := [0]
	player.attacked.connect(func() -> void: hits[0] += 1)
	var health := awake.health.current_health
	_check(authority.request_attack(1, authority.id_of(awake)) == Enums.ActionResult.OK and awake.health.current_health < health
			and hits[0] == 1 and player._attack_timer > 0.0, "golpe válido: dano, sinal e recarga")
	var granted: Array = []
	authority.interaction_granted.connect(func(actor: int, target: int) -> void: granted.append([actor, target]))
	var asleep: Dino = world["asleep"]
	var asleep_id := authority.id_of(asleep)
	_check(authority.request_interact(1, asleep_id) == Enums.ActionResult.OK and granted == [[1, asleep_id]],
			"interação válida: concedida com os ids")
	# O corpo do jogador usa o mesmo caminho: a mira (`target`) é só sugestão.
	player.target = asleep.interactable
	player.tick(1.0)
	var unguided := _player_at(Vector2.ZERO)
	_check(not unguided.attack() and not unguided.try_interact(), "jogador sem autoridade não age no mundo")


func _test_feeding_makes_the_owner() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var asleep: Dino = world["asleep"]
	var asleep_id := authority.id_of(asleep)
	var berry_slot := -1
	var fern_slot := -1
	for i in player.inventory.slot_count():
		match player.inventory.get_slot(i).get("id", ""):
			Items.BERRY: berry_slot = i
			Items.FERN: fern_slot = i
	_check(authority.request_transfer_slot(1, 1, fern_slot, asleep_id) == Enums.ActionResult.OK and asleep.feeder_player_id == "",
			"comida que não é a ideal passa, mas não faz do jogador o candidato a dono")
	_check(authority.request_transfer_slot(1, 1, berry_slot, asleep_id) == Enums.ActionResult.OK and asleep.feeder_player_id == "local"
			and asleep.inventory.count(Items.BERRY) == 10, "a comida ideal passa e registra quem alimentou")
	_check(authority.request_transfer_slot(1, asleep_id, 0, 1) == Enums.ActionResult.OK,
			"recolher da criatura dormindo também passa pela autoridade")
	asleep.taming.tick(100.0)
	_check(asleep.state_machine.is_tamed and asleep.owner_player_id == "local", "domesticou: o último a alimentar é o dono")
	_check(asleep.can_command() and asleep.interactable.prompt == "mandar Paquicéfalo seguir" and asleep.interactable.can_prompt()
			and not asleep.interactable.can_interact(), "domado seu: prompt de ordem, sem tela")
	_check(authority.request_transfer_slot(1, 1, 0, asleep_id) == Enums.ActionResult.WRONG_STATE,
			"domado acordado não recebe alimento pela tela")


func _test_command_rules() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var mine: Dino = world["mine"]
	var mine_id := authority.id_of(mine)
	var changes: Array = []
	mine.state_machine.order_changed.connect(func(order: Enums.DinoOrder) -> void: changes.append(order))
	_check(mine.state_machine.order == Enums.DinoOrder.STAY, "recém-domado fica")
	_check(authority.request_command(1, mine_id, "FOLLOW") == Enums.ActionResult.OK and mine.state_machine.order == Enums.DinoOrder.FOLLOW
			and changes == [Enums.DinoOrder.FOLLOW], "Seguir: aceito e avisado")
	_check(authority.request_command(1, mine_id, "FOLLOW") == Enums.ActionResult.OK and changes.size() == 1,
			"repetir a ordem não repete o aviso")
	# A tecla de interação alterna pelo mesmo caminho (mira real do jogador).
	player.target = mine.interactable
	_check(player.try_interact() and mine.state_machine.order == Enums.DinoOrder.STAY and changes.size() == 2,
			"interagir com o domado seu alterna para Ficar")
	_check(player.try_interact() and mine.state_machine.order == Enums.DinoOrder.FOLLOW, "e de volta para Seguir")
	var foreign: Dino = world["foreign"]
	player.target = foreign.interactable
	_check(not player.try_interact() and foreign.state_machine.order == Enums.DinoOrder.STAY, "no domado de outro a tecla não ordena")
	# Ordem não passa em selvagem nem nasce de save.
	var wild := _dino_at(Vector2.ZERO)
	_check(not wild.state_machine.set_order(Enums.DinoOrder.FOLLOW) and wild.state_machine.order == Enums.DinoOrder.STAY,
			"selvagem não obedece")


func _test_follow_rules_pure() -> void:
	var rules := ORDER_RULES
	var origin := Vector2.ZERO
	_check(rules.follow_direction(origin, Vector2(48, 0), false) == Vector2.ZERO, "parado a 3 tiles exatos: não anda")
	_check(rules.follow_direction(origin, Vector2(49, 0), false) == Vector2.RIGHT, "parado a mais de 3 tiles: anda até o dono")
	_check(rules.follow_direction(origin, Vector2(45, 0), true) == Vector2.RIGHT, "andando: continua até 2,5 tiles")
	_check(rules.follow_direction(origin, Vector2(40, 0), true) == Vector2.ZERO, "andando: para ao chegar a 2,5 tiles")
	_check(rules.follow_direction(origin, origin, true) == Vector2.ZERO, "sobreposto: sem direção (sem NaN)")
	_check(is_equal_approx(rules.follow_direction(origin, Vector2(300, 400), false).length(), 1.0), "direção unitária na diagonal")


func _test_follow_and_stay_in_motion() -> void:
	var dino := _tamed(_dino_at(Vector2(100, 100)), "local")
	var owner_at := Vector2(300, 100)
	var machine := dino.state_machine
	var rules := machine.order_rules
	machine.observe(dino.position, owner_at, true)
	machine.tick(0.1)
	_check(machine.desired_direction == Vector2.ZERO and machine.speed_multiplier == 1.0, "Ficar (padrão): parado e velocidade normal")
	machine.set_order(Enums.DinoOrder.FOLLOW)
	_check(machine.desired_direction == Vector2.RIGHT and machine.speed_multiplier == rules.follow_speed_multiplier,
			"Seguir: vai na direção do dono já ao receber a ordem, com a velocidade do dado")
	for i in 400:
		machine.observe(dino.position, owner_at, true)
		machine.tick(0.1)
		dino.position += machine.desired_direction * dino.move_speed * machine.speed_multiplier * 0.1
	var gap := dino.position.distance_to(owner_at)
	_check(gap <= rules.follow_px() and gap >= rules.arrive_px() - 7.0 and machine.desired_direction == Vector2.ZERO,
			"Seguir: chega a até 3 tiles do dono e para (distância %.1f)" % gap)
	owner_at = Vector2(300, 400)
	for i in 600:
		machine.observe(dino.position, owner_at, true)
		machine.tick(0.1)
		dino.position += machine.desired_direction * dino.move_speed * machine.speed_multiplier * 0.1
	_check(dino.position.distance_to(owner_at) <= rules.follow_px(), "o dono andou: o dino alcança e volta a ficar a 3 tiles")
	machine.set_order(Enums.DinoOrder.STAY)
	owner_at = Vector2(0, 0)
	var stopped_at := dino.position
	for i in 100:
		machine.observe(dino.position, owner_at, true)
		machine.tick(0.1)
		dino.position += machine.desired_direction * dino.move_speed * machine.speed_multiplier * 0.1
	_check(dino.position == stopped_at and machine.speed_multiplier == 1.0, "Ficar: o dono se afasta e o dino não sai do lugar")
	machine.set_order(Enums.DinoOrder.FOLLOW)
	machine.observe(dino.position, owner_at, false)
	machine.tick(0.1)
	_check(machine.desired_direction == Vector2.ZERO, "Seguir sem dono no mundo: fica parado")
	# Desmaiar suspende a ordem; acordar a retoma sem perdê-la.
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	_check(machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not machine.set_order(Enums.DinoOrder.STAY),
			"inconsciente não recebe ordem")
	dino.torpor.reset()
	_check(machine.current_id == Enums.DinoStateId.TAMED and machine.order == Enums.DinoOrder.FOLLOW, "acordou: a ordem continua")


func _test_order_save() -> void:
	var dino := _tamed(_dino_at(Vector2(10, 20)), "amigo")
	dino.feeder_player_id = "amigo"
	dino.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(dino.to_dict()))
	_check(saved["state_machine"]["order"] == "FOLLOW" and saved["owner_player_id"] == "amigo", "a ordem vai ao save pelo nome, com o dono")
	var copy := _dino_at(Vector2.ZERO)
	var events := [0]
	copy.state_machine.order_changed.connect(func(_o: Enums.DinoOrder) -> void: events[0] += 1)
	_check(copy.from_dict(saved) and copy.state_machine.order == Enums.DinoOrder.FOLLOW and copy.owner_player_id == "amigo"
			and copy.feeder_player_id == "amigo" and copy.state_machine.is_tamed, "roundtrip: ordem, dono e quem alimentou")
	_check(events[0] == 0 and copy.state_machine.speed_multiplier == copy.state_machine.order_rules.follow_speed_multiplier,
			"restaurar não emite evento e já vale a velocidade do Seguir")
	_check(copy.interactable.prompt == "mandar Paquicéfalo ficar", "o prompt acompanha a ordem restaurada")
	# Dado ruim não vira ordem nem dono.
	var wild_data := _dino_at(Vector2.ZERO).to_dict()
	wild_data["state_machine"]["order"] = "FOLLOW"
	wild_data["owner_player_id"] = "x"
	var wild := _dino_at(Vector2.ZERO)
	_check(wild.from_dict(wild_data) and wild.state_machine.order == Enums.DinoOrder.STAY and wild.owner_player_id == "",
			"selvagem com ordem e dono no arquivo: ignorados")
	for bad: Variant in ["FLY", 1, null, [], "follow", {}]:
		var data := saved.duplicate(true)
		data["state_machine"]["order"] = bad
		var other := _dino_at(Vector2.ZERO)
		_check(other.from_dict(data) and other.state_machine.order == Enums.DinoOrder.STAY,
				"ordem inválida no arquivo (%s): Ficar" % str(bad))
	for bad: Variant in [-1, 1.5, 7, null, NAN, [2], {}, "x".repeat(65)]:
		var data := saved.duplicate(true)
		data["owner_player_id"] = bad
		var other := _dino_at(Vector2.ZERO)
		_check(other.from_dict(data) and other.owner_player_id == "", "dono inválido no arquivo (%s): sem dono" % str(bad))


func _test_migration_and_fixture_v3() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V2))
	_check(raw["format_version"] == 2 and SaveMigrations.CURRENT_VERSION == 5, "preparo: a fixture v2 segue v2 e o formato atual é o 5")
	var migrated := SaveMigrations.migrate(raw)
	var wild_machine: Dictionary = migrated["entities"][0]["state"]["state_machine"]
	_check(migrated["format_version"] == SaveMigrations.CURRENT_VERSION and not wild_machine.has("order")
		and not migrated["entities"][0]["state"].has("owner_player_id"),
			"v2 para v3: selvagem fica como estava")
	var tamed := raw.duplicate(true)
	tamed["entities"][0]["state"]["state_machine"]["is_tamed"] = true
	tamed["players"][0]["player_id"] = "p-save"
	var out := SaveMigrations.migrate(tamed)
	var state: Dictionary = out["entities"][0]["state"]
	_check(state["owner_player_id"] == "p-save" and state["state_machine"]["order"] == "STAY",
			"v2 para v3: o domado vira do jogador do save e fica")
	_check(SaveMigrations.migrate(out) == out and tamed["entities"][0]["state"].has("owner_player_id") == false,
			"a migração é pura e não repete")
	for junk: Variant in [null, "x", [], 5]:
		var odd := raw.duplicate(true)
		odd["entities"] = junk
		odd["players"] = junk
		_check(SaveMigrations.v2_to_v3(odd).get("entities") == junk, "v2 para v3 com lista inválida (%s): não aborta" % str(junk))
	# Fixture v3: carrega pelo gerenciador e restaura o domado seguindo.
	var manager := SaveManager.new(root_dir)
	var outcome := manager.read_file(FIXTURE_V3)
	_check(outcome.status == SaveManager.Status.OK and outcome.data.get("format_version") == SaveMigrations.CURRENT_VERSION
		and (outcome.data.get("world", {}) as Dictionary).get("map_id") == "lunata", "fixture v3 carrega e é migrada para a versão atual")
	var player := _player_at(Vector2.ZERO)
	var dino := _dino_at(Vector2.ZERO)
	_check(WorldSnapshot.restore(outcome.data, player, dino), "fixture v3 é aplicada ao mundo")
	_check(dino.state_machine.is_tamed and dino.state_machine.order == Enums.DinoOrder.FOLLOW
			and dino.owner_player_id == str(outcome.data["world"]["local_player_id"])
			and dino.state_machine.current_id == Enums.DinoStateId.TAMED
			and dino.level == 28, "fixture v3: domado, Seguir, dono local, nível 28")


func _test_hitbox_by_data() -> void:
	var dino := _dino_at(Vector2.ZERO)
	var shape := dino.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(shape.size == dino.stats.hitbox_size and shape.size == Vector2(24, 16), "caixa do dino vem do dado")
	var custom: Dino = DinoScene.instantiate()
	custom.stats = custom.stats.duplicate()
	custom.stats.hitbox_size = Vector2(30, 20)
	_root.add_child(custom)
	_track.call(custom)
	_check((custom.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(30, 20), "outro dado, outra caixa")
	var other_dino := _dino_at(Vector2.ZERO)
	_check((other_dino.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(24, 16),
			"a caixa nova não vaza para outras criaturas")
	var player := _player_at(Vector2.ZERO)
	_check((player.get_node("CollisionShape2D").shape as RectangleShape2D).size == player.rules.hitbox_size
			and player.rules.hitbox_size == Vector2(12, 8), "caixa do jogador vem do dado")
	_check(player.get_node("CollisionShape2D").position == player.rules.hitbox_offset
			and player.rules.hitbox_offset == Vector2(0, -4), "caixa do jogador apoiada nos pés (offset do dado)")


# ----------------------------------------------------------------------------- MUN-01

## A física roda no relógio de parede (1 s de jogo = 1 s de teste): os cenários são curtos de propósito, e o
## corpo anda pelo `_physics_process` de verdade, lendo o input como no jogo. A `Main` vai num SubViewport,
## que tem o próprio espaço de física: os outros testes deixam mundos na raiz, e eles se atropelariam.
func _main_with_physics() -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = "authority_physics"
	main.menu_scene = ""
	var viewport := SubViewport.new()
	_root.add_child(viewport)
	_track.call(viewport)
	viewport.add_child(main)
	main.scheduler.frozen = true  # o teste de colisão não grava save
	main.dino.set_physics_process(false)
	main.dino.state_machine.set_physics_process(false)
	main.wild.process_mode = Node.PROCESS_MODE_DISABLED  # os selvagens do mapa não passeiam sobre a colisão testada
	main.zone.set_physics_process(false)  # e a zona não liga nem desliga o dino do teste (ele fica ativo, com colisão)
	main.dino.process_mode = Node.PROCESS_MODE_INHERIT
	main.dino.visible = true
	return main


## O corpo está dentro de algo sólido (mapa, casa, árvore)? Encostar não conta: a caixa de teste é 1 px
## menor, então só penetração de verdade acusa. Os outros corpos ficam de fora (`ignore`).
func _inside_solid(body: CharacterBody2D, ignore: Array[RID]) -> bool:
	var probe := RectangleShape2D.new()
	probe.size = ((body.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size - Vector2.ONE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = (body.get_node("CollisionShape2D") as CollisionShape2D).global_transform  # a caixa dos pés, não a origem
	query.collision_mask = 1
	query.exclude = ignore + [body.get_rid()]
	return not body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## O corpo inteiro (a caixa, não só o centro) está dentro do mapa?
func _inside_map(body: CharacterBody2D) -> bool:
	var box := body.get_node("CollisionShape2D") as CollisionShape2D
	var size := (box.shape as RectangleShape2D).size
	return Rect2(Vector2.ZERO, MAP_SIZE).grow(0.01).encloses(Rect2(box.global_position - size / 2.0, size))


## Passa `frames` quadros de física e devolve se `body` saiu do mapa ou entrou em sólido em algum deles.
func _watch(body: CharacterBody2D, frames: int, ignore: Array[RID]) -> bool:
	var bad := false
	for i in frames:
		await _root.get_tree().physics_frame
		if not _inside_map(body) or _inside_solid(body, ignore):
			bad = true
			break
	return bad


## O jogador corre (Shift) `frames` quadros apertando `action`.
func _run_player(main: Main, action: String, frames: int) -> bool:
	main.player.stamina.from_dict({"current": main.player.stamina.max_stamina, "is_exhausted": false})
	Input.action_press("sprint")
	Input.action_press(action)
	var ignore: Array[RID] = [main.dino.get_rid()]
	var bad: bool = await _watch(main.player, frames, ignore)
	Input.action_release(action)
	Input.action_release("sprint")
	return bad


## Retângulo dos pés da rocha (a colisão que o corpo encontra).
func _rock_rect(rock: ResourceNode) -> Rect2:
	var foot := rock.def.foot_size
	return Rect2(rock.global_position + Vector2(-foot.x / 2.0, -foot.y), foot)


## As `count` rochas mais próximas do início, de colisão ligada, em ordem de distância (determinístico).
func _rock_rects(main: Main, count: int) -> Array[Rect2]:
	var rocks: Array[ResourceNode] = []
	for node in main.resources.nodes():
		if node.def.id == "rock" and node.blocks_movement():
			rocks.append(node)
	var start := main.map.start_point()
	rocks.sort_custom(func(a: ResourceNode, b: ResourceNode) -> bool:
		return a.position.distance_squared_to(start) < b.position.distance_squared_to(start))
	var rects: Array[Rect2] = []
	for i in mini(count, rocks.size()):
		rects.append(_rock_rect(rocks[i]))
	return rects


## Pontos de praia de frente para o mar fundo, um por direção de corrida: `{ação: ponto}`. O ponto fica a 3 tiles
## da água funda com colisão, com o caminho até ela só de terra e raso.
func _shore_points(map: IslandMap) -> Dictionary:
	var dirs := {"move_right": Vector2i(1, 0), "move_left": Vector2i(-1, 0), "move_down": Vector2i(0, 1), "move_up": Vector2i(0, -1)}
	var found := {}
	for y in range(8, map.size - 8):
		for x in range(8, map.size - 8):
			var cell := Vector2i(x, y)
			if not map.has_ring_collision(cell):
				continue
			for action: String in dirs:
				if found.has(action):
					continue
				var step: Vector2i = dirs[action]
				var clear := true
				for k in range(1, 5):
					clear = clear and map.is_walkable(cell - step * k)
				if clear and not map.has_ring_collision(cell - step):
					found[action] = map.center_of(cell - step * 4)
	return found


func _test_map_limits_and_collision() -> void:
	var main := _main_with_physics()
	await _root.get_tree().physics_frame
	var player := main.player
	var ignore: Array[RID] = [main.dino.get_rid()]
	# Mar: correndo da praia contra a água funda de cada lado, o corpo para no anel de colisão (nunca entra).
	var shores := _shore_points(main.map)
	_check(shores.size() == 4, "a ilha tem costa virada para as 4 direções (%d achadas)" % shores.size())
	for action: String in shores:
		player.position = shores[action]
		var bad: bool = await _run_player(main, action, 90)
		_check(not bad, "correndo para o mar (%s): não atravessa a água funda (%s)" % [action, str(player.position)])
		_check(main.map.is_walkable_at(player.position), "correndo para o mar (%s): continua em chão caminhável" % action)
	# Rochas: de cada lado, nunca entra.
	var obstacles: Array[Rect2] = _rock_rects(main, 8)
	_check(obstacles.size() == 8, "o mapa tem rochas sólidas perto do início (%d obstáculos)" % obstacles.size())
	var approaches := {"move_right": Vector2(-1, 0), "move_left": Vector2(1, 0), "move_down": Vector2(0, -1), "move_up": Vector2(0, 1)}
	var tried := 0
	var stopped := 0
	for index in obstacles.size():
		var rect := obstacles[index]
		for action: String in approaches:
			if index > 0 and action != "move_right" and action != "move_down":
				continue  # a primeira rocha é atacada dos quatro lados e as outras de dois, para o teste ser curto
			var side: Vector2 = approaches[action]
			player.position = rect.get_center() + side * (rect.size / 2.0 + Vector2(24, 24))
			player.velocity = Vector2.ZERO
			if _inside_solid(player, ignore) or not _inside_map(player):
				continue  # largada inválida (colada em outro sólido): não conta
			tried += 1
			var bad: bool = await _run_player(main, action, 30)
			_check(not bad, "obstáculo %s, correndo %s: não atravessa nem sai do mapa" % [str(rect.position), action])
			var box := player.get_node("CollisionShape2D") as CollisionShape2D
			var box_size := (box.shape as RectangleShape2D).size
			if rect.grow(3.0).intersects(Rect2(box.global_position - box_size / 2.0, box_size)):  # parou encostado (folga de 3 px)
				stopped += 1
	_check(tried >= 10 and stopped == tried, "o teste exerceu %d combinações e o corpo parou junto do obstáculo em %d" % [tried, stopped])
	# Corpo contra corpo: o jogador não atravessa o dino.
	var open_spot: Vector2 = shores["move_up"] + Vector2(0, 32)
	main.dino.position = open_spot + Vector2(30, 0)
	player.position = open_spot
	await _run_player(main, "move_right", 30)
	_check(player.position.x < main.dino.position.x, "o jogador não atravessa o dino")
	# O selvagem empurrando contra cada lado do mapa: o corpo não sai.
	main.dino.set_physics_process(true)
	var dino_bad := false
	var pushes := {Vector2.LEFT: shores["move_left"], Vector2.RIGHT: shores["move_right"],
			Vector2.UP: shores["move_up"], Vector2.DOWN: shores["move_down"]}
	for direction: Vector2 in pushes:
		main.dino.position = pushes[direction]
		for i in 40:
			main.dino.state_machine.desired_direction = direction
			await _root.get_tree().physics_frame
			if not _inside_map(main.dino) or _inside_solid(main.dino, [player.get_rid()] as Array[RID]):
				dino_bad = true
	_check(not dino_bad, "dino empurrando contra o mar fundo nas quatro direções: não atravessa")
	main.get_parent().queue_free()
	await _root.get_tree().process_frame


## Aceite do CRI-05 com o MUN-01: o domado que segue o dono não atravessa a rocha nem a água funda.
func _test_follower_stays_inside() -> void:
	var tree := _root.get_tree()
	var main := _main_with_physics()
	await tree.physics_frame
	var player := main.player
	var dino := main.dino
	var authority := main.authority
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = player.player_id
	var shore: Vector2 = _shore_points(main.map)["move_left"]
	player.position = shore
	dino.position = shore + Vector2(30, 0)
	_check(authority.request_command(1, authority.id_of(dino), "FOLLOW") == Enums.ActionResult.OK, "pela Main: o dono manda Seguir")
	dino.set_physics_process(true)
	dino.state_machine.set_physics_process(true)
	var ignore_player: Array[RID] = [player.get_rid()]
	# O dono corre para o mar fundo a oeste; o dino vem atrás e para a até 3 tiles.
	Input.action_press("sprint")
	Input.action_press("move_left")
	var bad: bool = await _watch(dino, 40, ignore_player)
	Input.action_release("move_left")
	Input.action_release("sprint")
	bad = (await _watch(dino, 150, ignore_player)) or bad
	var rules := dino.state_machine.order_rules
	var gap := dino.position.distance_to(player.position)
	_check(not bad and gap <= rules.follow_px() + 1.0 and gap > 0.0,
			"domado seguindo o dono até o mar: em chão, fora de sólido, a até 3 tiles (%.1f px)" % gap)
	# O dono passa para o outro lado de uma rocha: o dino empurra nela e não a atravessa.
	var wall := _rock_rects(main, 1)[0]
	dino.position = Vector2(wall.position.x - 40.0, wall.get_center().y)
	var crossed := false
	for i in 120:
		player.position = Vector2(wall.end.x + 40.0, wall.get_center().y)
		await tree.physics_frame
		if wall.has_point(dino.global_position) or _inside_solid(dino, ignore_player):
			crossed = true
	_check(not crossed and dino.position.x < wall.position.x, "dono do outro lado da rocha: o dino fica contra ela, sem atravessá-la")
	# Ficar: o dono manda parar e se afasta; o dino não se mexe mais.
	player.position = dino.position + Vector2(-20, 0)
	_check(authority.request_command(1, authority.id_of(dino), "STAY") == Enums.ActionResult.OK, "pela Main: o dono manda Ficar")
	await tree.physics_frame
	var parked := dino.position
	player.position = dino.position + Vector2(600, 0)
	for i in 60:
		await tree.physics_frame
	_check(dino.position.distance_to(parked) < 0.5, "Ficar: com o dono do outro lado do mapa, o dino não sai do lugar")
	main.get_parent().queue_free()
	await _root.get_tree().process_frame


## Libera os mundos (`Main`) do teste anterior: cada um vivo custa física a cada quadro (ver `DinoLevelTests`).
func _release_worlds() -> void:
	for child in _root.get_children():
		if child is Main:
			child.free()
