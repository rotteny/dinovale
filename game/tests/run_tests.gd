# SPDX-License-Identifier: MIT
extends SceneTree
## Testes da lógica, sem janela nem GPU:
##   godot --headless --path . --script res://tests/run_tests.gd

const DinoScene := preload("res://src/entities/dino/Dino.tscn")
const PlayerScene := preload("res://src/entities/player/Player.tscn")
const SaveableTable := preload("res://tests/saveable_table.gd")


## Erro de runtime em GDScript só aborta a função atual: sem isto, um teste
## quebrado no meio passaria como verde.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		count += 1


var _checks := 0
var _failures := 0
var _nodes: Array[Node] = []
var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# Nenhum teste grava em user://saves: tudo vai para uma pasta descartável.
	GameSession.save_root = SaveTests.ROOT
	SaveTests.remove_tree("user://test_saves")
	_test_health()
	_test_health_scene_override()
	_test_torpor_knockout_and_wake()
	_test_torpor_is_independent_of_health()
	_test_torpor_restore_is_silent()
	_test_idle_wander_cycle()
	_test_knockout_from_wander_stops_movement()
	_test_wild_wakes_to_idle()
	_test_mark_tamed()
	_test_tamed_knockout_returns_to_tamed()
	_test_save_roundtrip_through_json()
	_test_inconsistent_save_is_repaired()
	_test_dino_scene()
	_test_stamina_drain_and_regen()
	_test_stamina_exhaustion()
	_test_hunger_decay_and_starvation()
	_test_hunger_eat_stops_damage()
	_test_player_scene_wiring()
	_test_player_movement_speed()
	_test_player_sprint_uses_stamina()
	_test_player_input_actions()
	_test_player_starves_to_death()
	_test_player_save_roundtrip_through_json()
	_test_taming_full_cycle()
	_test_taming_wrong_food_ignored()
	_test_taming_no_food_stalls()
	_test_taming_wake_resets_progress()
	_test_taming_only_wild_and_unconscious()
	_test_taming_restore_is_validated()
	_test_dino_save_with_taming_through_json()
	_test_inventory_stacks_and_capacity()
	_test_inventory_remove_and_count()
	_test_inventory_transfer()
	_test_inventory_signals()
	_test_inventory_save_is_validated()
	_test_inventory_capacity_setter()
	_test_taming_without_inventory()
	_test_can_interact_rule()
	_test_input_actions_for_interaction()
	_test_attack_rules()
	_test_player_inventory_and_save()
	await _test_target_is_nearest()
	_test_screen_closes_when_dino_wakes()
	_test_screen_closes_when_tamed()
	_test_screen_closes_when_dino_removed()
	_test_hud_reacts_to_signals()
	_test_dino_status_bars()
	DinoLevelTests.new(root, _track, _check).run()
	DinoReviewTests.new(root, _track, _check).run()
	HudHotbarTests.new(root, _track, _check).run()
	InventoryModelTests.new(root, _track, _check).run()
	EquipmentFlowTests.new(root, _track, _check).run()
	await MenuTests.new(root, _track, _check).run()
	await SaveTests.new(root, _track, _check).run()
	await _test_full_taming_integration()
	_test_saveable_roundtrip_table()
	GameSession.save_root = GameSession.DEFAULT_SAVE_ROOT
	SaveTests.remove_tree("user://test_saves")
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	print("%d verificações, %d falhas, %d erros de script" % [_checks, _failures, _errors.count])
	quit(1 if _failures > 0 or _errors.count > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _track(node: Node) -> Node:
	_nodes.append(node)
	return node


func _make_machine() -> DinoStateMachine:
	var machine: DinoStateMachine = _track(DinoStateMachine.new())
	machine.torpor = _track(TorporComponent.new())
	machine.rng.seed = 42
	machine.start()
	return machine


func _test_health() -> void:
	var health: HealthComponent = _track(HealthComponent.new())
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.take_damage(-10.0)
	_check(health.current_health == 100.0, "dano negativo é ignorado")
	health.take_damage(30.0)
	health.heal(500.0)
	_check(health.current_health == 100.0, "cura não passa do máximo")
	health.take_damage(150.0)
	_check(health.current_health == 0.0 and health.is_dead(), "vida para em zero")
	health.take_damage(10.0)
	health.heal(10.0)
	_check(deaths[0] == 1, "morre uma vez só")
	_check(health.is_dead(), "morto não é curado")


func _test_health_scene_override() -> void:
	var health: HealthComponent = _track(HealthComponent.new())
	health.max_health = 250.0
	_check(health.current_health == 250.0, "vida cheia acompanha o novo máximo")
	health.take_damage(50.0)
	health.max_health = 100.0
	_check(health.current_health == 100.0, "vida é limitada ao reduzir o máximo")


func _test_torpor_knockout_and_wake() -> void:
	var torpor: TorporComponent = _track(TorporComponent.new())
	var events := {"out": 0, "up": 0}
	torpor.knocked_out.connect(func() -> void: events.out += 1)
	torpor.woke_up.connect(func() -> void: events.up += 1)
	torpor.add_torpor(99.0)
	_check(not torpor.is_unconscious, "abaixo do máximo continua consciente")
	torpor.add_torpor(1.0)
	_check(torpor.is_unconscious, "torpor >= máximo desmaia")
	torpor.add_torpor(50.0)
	_check(events.out == 1, "knocked_out emite uma vez")
	torpor.tick(50.0)
	_check(torpor.is_unconscious and is_equal_approx(torpor.current_torpor, 50.0),
			"inconsciente usa a queda própria")
	torpor.tick(50.0)
	_check(not torpor.is_unconscious and events.up == 1, "acorda ao chegar no limiar")


func _test_torpor_is_independent_of_health() -> void:
	var dino: Dino = _spawn_dino()
	dino.torpor.add_torpor(100.0)
	_check(dino.health.current_health == 100.0, "torpor não afeta a vida")
	dino.torpor.reset()
	dino.health.take_damage(40.0)
	_check(dino.torpor.current_torpor == 0.0, "dano não afeta o torpor")


func _test_torpor_restore_is_silent() -> void:
	var torpor: TorporComponent = _track(TorporComponent.new())
	var events := [0]
	torpor.knocked_out.connect(func() -> void: events[0] += 1)
	torpor.from_dict({"current": 80.0, "max": 80.0, "is_unconscious": true})
	_check(torpor.is_unconscious and events[0] == 0, "carregar não dispara knocked_out")


func _test_idle_wander_cycle() -> void:
	var machine := _make_machine()
	_check(machine.current_id == Enums.DinoStateId.IDLE, "começa parado")
	machine.tick(3.1)
	_check(machine.current_id == Enums.DinoStateId.WANDER, "idle vira wander")
	_check(is_equal_approx(machine.desired_direction.length(), 1.0), "wander tem direção")
	machine.tick(4.1)
	_check(machine.current_id == Enums.DinoStateId.IDLE, "wander vira idle")
	_check(machine.desired_direction == Vector2.ZERO, "idle fica parado")


func _test_knockout_from_wander_stops_movement() -> void:
	var machine := _make_machine()
	machine.tick(3.1)
	machine.torpor.add_torpor(100.0)
	_check(machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "wander desmaia")
	_check(machine.desired_direction == Vector2.ZERO, "desmaiado não anda")
	machine.tick(100.0)
	_check(machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "só o torpor o acorda")


func _test_wild_wakes_to_idle() -> void:
	var machine := _make_machine()
	machine.torpor.add_torpor(100.0)
	machine.torpor.tick(100.0)
	_check(machine.current_id == Enums.DinoStateId.IDLE, "selvagem acorda em idle")


func _test_mark_tamed() -> void:
	var machine := _make_machine()
	_check(not machine.mark_tamed(), "consciente não é domesticado")
	machine.torpor.add_torpor(100.0)
	_check(machine.mark_tamed(), "desmaiado é domesticado")
	_check(machine.current_id == Enums.DinoStateId.TAMED, "vira tamed")
	_check(not machine.torpor.is_unconscious, "domesticar acorda")
	machine.tick(100.0)
	_check(machine.current_id == Enums.DinoStateId.TAMED, "tamed não passeia sozinho")


func _test_tamed_knockout_returns_to_tamed() -> void:
	var machine := _make_machine()
	machine.torpor.add_torpor(100.0)
	machine.mark_tamed()
	machine.torpor.add_torpor(100.0)
	_check(machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "domesticado pode desmaiar")
	machine.torpor.tick(100.0)
	_check(machine.current_id == Enums.DinoStateId.TAMED, "acorda ainda domesticado")


func _test_save_roundtrip_through_json() -> void:
	var original: Dino = _spawn_dino()
	original.position = Vector2(48.0, 96.0)
	original.health.take_damage(25.0)
	original.torpor.add_torpor(100.0)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var copy: Dino = _spawn_dino()
	copy.from_dict(parsed)
	_check(copy.position == Vector2(48.0, 96.0), "posição restaurada")
	_check(copy.health.current_health == 75.0, "vida restaurada")
	_check(copy.torpor.is_unconscious, "torpor restaurado")
	_check(copy.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "estado restaurado")
	_check(copy.to_dict() == original.to_dict(), "save idêntico depois do JSON")


func _test_inconsistent_save_is_repaired() -> void:
	var machine := _make_machine()
	machine.from_dict({"state": "UNCONSCIOUS", "is_tamed": false})
	_check(machine.current_id == Enums.DinoStateId.IDLE, "torpor é a fonte da verdade")
	machine.from_dict({"state": "NAO_EXISTE", "is_tamed": true})
	_check(machine.current_id == Enums.DinoStateId.TAMED, "estado inválido cai no padrão")


func _test_dino_scene() -> void:
	var dino: Dino = _spawn_dino()
	_check(dino.state_machine.torpor == dino.torpor, "cena liga a máquina ao torpor")


func _spawn_dino() -> Dino:
	var dino: Dino = DinoScene.instantiate()
	root.add_child(dino)
	_nodes.append(dino)
	return dino


func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	root.add_child(player)
	_nodes.append(player)
	return player


func _stamina() -> StaminaComponent:
	return _track(StaminaComponent.new())


func _test_stamina_drain_and_regen() -> void:
	var stamina := _stamina()
	stamina.tick(2.0, true)
	_check(is_equal_approx(stamina.current_stamina, 50.0), "correr gasta stamina")
	stamina.tick(2.0, false)
	_check(is_equal_approx(stamina.current_stamina, 80.0), "parado regenera")
	stamina.tick(100.0, false)
	_check(stamina.current_stamina == 100.0, "regeneração para no máximo")


func _test_stamina_exhaustion() -> void:
	var stamina := _stamina()
	var events := {"out": 0, "back": 0}
	stamina.exhausted.connect(func() -> void: events.out += 1)
	stamina.recovered.connect(func() -> void: events.back += 1)
	stamina.tick(10.0, true)
	_check(stamina.current_stamina == 0.0 and not stamina.can_sprint(), "sem stamina não corre")
	_check(events.out == 1, "exausto emite uma vez")
	stamina.tick(0.5, false)
	_check(not stamina.can_sprint(), "ainda exausto abaixo do limiar de retomada")
	stamina.tick(1.0, false)
	_check(stamina.can_sprint() and events.back == 1, "volta a correr no limiar")


func _test_hunger_decay_and_starvation() -> void:
	var hunger: HungerComponent = _track(HungerComponent.new())
	var hits: Array[float] = []
	hunger.starved.connect(func(damage: float) -> void: hits.append(damage))
	hunger.tick(10.0)
	_check(is_equal_approx(hunger.current_hunger, 95.0), "fome cai com o tempo")
	_check(hits.is_empty(), "sem dano enquanto há comida")
	hunger.tick(1000.0)
	_check(hunger.is_starving(), "fome zera e para em zero")
	_check(hits.size() == 500, "tick grande aplica um dano por intervalo (%d)" % hits.size())
	hits.clear()
	hunger.tick(1.0)
	_check(hits.is_empty(), "meio intervalo não causa dano")
	hunger.tick(1.0)
	_check(hits.size() == 1 and hits[0] == 5.0, "dano periódico a cada intervalo")


func _test_hunger_eat_stops_damage() -> void:
	var hunger: HungerComponent = _track(HungerComponent.new())
	var hits := [0]
	hunger.starved.connect(func(_damage: float) -> void: hits[0] += 1)
	hunger.tick(1000.0)
	hits[0] = 0
	hunger.eat(-5.0)
	_check(hunger.is_starving(), "comer valor negativo é ignorado")
	hunger.eat(30.0)
	hunger.tick(10.0)
	_check(hits[0] == 0 and not hunger.is_starving(), "comer interrompe o dano")


func _test_player_scene_wiring() -> void:
	var player := _spawn_player()
	_check(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "player é top-down floating")
	_check(player.health != null and player.stamina != null and player.hunger != null,
			"player tem os três atributos")


func _test_player_movement_speed() -> void:
	var player := _spawn_player()
	var diagonal := player.apply_input(Vector2(1, 1), false, 0.1)
	_check(is_equal_approx(diagonal.length(), player.walk_speed), "diagonal sem ganho de velocidade")
	var axis := player.apply_input(Vector2.LEFT, false, 0.1)
	_check(axis == Vector2.LEFT * player.walk_speed, "eixo anda na velocidade base")
	_check(player.apply_input(Vector2.ZERO, true, 0.1) == Vector2.ZERO, "sem direção fica parado")
	var oversize := player.apply_input(Vector2(5, 0), false, 0.1)
	_check(is_equal_approx(oversize.length(), player.walk_speed), "direção maior que 1 é limitada")


func _test_player_sprint_uses_stamina() -> void:
	var player := _spawn_player()
	var run := player.apply_input(Vector2.RIGHT, true, 1.0)
	_check(run.length() == player.sprint_speed, "shift corre mais")
	_check(is_equal_approx(player.stamina.current_stamina, 75.0), "correr gasta stamina")
	player.apply_input(Vector2.ZERO, true, 1.0)
	_check(player.stamina.current_stamina > 75.0, "parado com shift não gasta, regenera")
	for i in 4:
		player.apply_input(Vector2.RIGHT, true, 1.0)
	_check(player.stamina.current_stamina == 0.0, "stamina chega a zero")
	var tired := player.apply_input(Vector2.RIGHT, true, 0.1)
	_check(tired.length() == player.walk_speed, "sem stamina anda, não corre")
	var diagonal_run := _spawn_player().apply_input(Vector2(1, 1), true, 0.1)
	_check(is_equal_approx(diagonal_run.length(), 120.0), "diagonal correndo sem ganho")


func _test_player_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		_check(InputMap.has_action(action), "ação %s existe" % action)
		_check(InputMap.action_get_events(action).size() >= 1, "ação %s tem tecla" % action)
	_check(InputMap.action_get_events("move_up").size() == 2, "move_up tem WASD e seta")
	var player := _spawn_player()
	Input.action_press("move_right")
	Input.action_press("move_down")
	var direction := player.read_direction()
	Input.action_release("move_right")
	Input.action_release("move_down")
	_check(direction.x > 0.0 and direction.y > 0.0, "read_direction lê as ações")
	_check(is_equal_approx(direction.length(), 1.0), "diagonal lida tem comprimento 1")


func _test_player_starves_to_death() -> void:
	var player := _spawn_player()
	player.hunger.current_hunger = 0.0
	player.hunger.tick(2.0)
	_check(player.health.current_health == 95.0, "fome zerada machuca o player")
	player.hunger.tick(38.0)
	_check(player.health.is_dead(), "fome mata depois de muito tempo")
	_check(player.apply_input(Vector2.RIGHT, false, 0.1) == Vector2.ZERO, "morto não anda")


func _test_player_save_roundtrip_through_json() -> void:
	var original := _spawn_player()
	original.position = Vector2(12.0, 34.0)
	original.health.take_damage(30.0)
	original.apply_input(Vector2.RIGHT, true, 2.0)
	original.hunger.tick(20.0)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var copy := _spawn_player()
	copy.from_dict(parsed)
	_check(copy.position == Vector2(12.0, 34.0), "posição do player restaurada")
	_check(copy.health.current_health == 70.0, "vida do player restaurada")
	_check(is_equal_approx(copy.stamina.current_stamina, 50.0), "stamina restaurada")
	_check(is_equal_approx(copy.hunger.current_hunger, 96.0), "fome restaurada (queda de 0,2/s)")
	_check(copy.to_dict() == original.to_dict(), "save do player idêntico depois do JSON")
	var starving := _spawn_player()
	var hits := [0]
	starving.health.damaged.connect(func(_amount: float) -> void: hits[0] += 1)
	starving.from_dict({"hunger": {"current": 0.0, "starvation_timer": 1.9}})
	_check(hits[0] == 0, "carregar save com fome zerada não causa dano")


## Dino selvagem já inconsciente, com comida ideal no estoque.
func _make_sleeping_dino(berries: int) -> Dino:
	var dino := _spawn_dino()
	dino.torpor.add_torpor(100.0)
	dino.inventory.add("berry", berries)
	return dino


func _test_taming_full_cycle() -> void:
	var dino := _make_sleeping_dino(7)
	var tamed := [0]
	dino.state_machine.state_changed.connect(func(_p: int, c: int) -> void:
		if c == Enums.DinoStateId.TAMED: tamed[0] += 1)
	dino.taming.tick(4.9)
	_check(dino.taming.taming_progress == 0.0, "antes do intervalo não come")
	dino.taming.tick(0.2)
	_check(is_equal_approx(dino.taming.taming_progress, 20.0), "primeira refeição preenche 20%")
	_check(dino.inventory.count("berry") == 6, "refeição consome 1 comida")
	dino.taming.tick(15.0)
	_check(is_equal_approx(dino.taming.taming_progress, 80.0), "três refeições a mais")
	_check(dino.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "80% ainda inconsciente")
	dino.taming.tick(5.0)
	_check(dino.taming.taming_progress == 100.0, "100% de progresso")
	_check(dino.state_machine.is_tamed, "100% chama mark_tamed")
	_check(dino.state_machine.current_id == Enums.DinoStateId.TAMED, "vira TAMED")
	_check(tamed[0] == 1, "domesticou uma vez só")
	_check(dino.inventory.count("berry") == 2, "sobrou a comida não usada")
	dino.taming.tick(100.0)
	_check(dino.inventory.count("berry") == 2, "domesticado não consome mais")
	_check(dino.taming.taming_progress == 100.0, "domesticado mantém 100%")


func _test_taming_wrong_food_ignored() -> void:
	var dino := _spawn_dino()
	dino.torpor.add_torpor(100.0)
	dino.inventory.add("meat", 5)
	dino.taming.tick(100.0)
	_check(dino.taming.taming_progress == 0.0, "comida errada não preenche")
	_check(dino.inventory.count("meat") == 5, "comida errada não é consumida")
	dino.inventory.add("berry", 1)
	dino.taming.tick(5.0)
	_check(dino.inventory.count("meat") == 5 and dino.inventory.count("berry") == 0,
			"só a ideal é consumida")
	_check(dino.inventory.add("", 3) == 3 and dino.inventory.add("berry", -2) == 0,
			"id vazio é rejeitado e quantidade negativa é ignorada")
	_check(dino.inventory.count("meat") == 5 and dino.inventory.room_for("berry") > 0,
			"inventário continua íntegro")


func _test_taming_no_food_stalls() -> void:
	var dino := _make_sleeping_dino(2)
	dino.taming.tick(10.0)
	_check(is_equal_approx(dino.taming.taming_progress, 40.0), "gastou a comida disponível")
	dino.taming.tick(100.0)
	_check(is_equal_approx(dino.taming.taming_progress, 40.0), "sem comida o progresso para")
	_check(dino.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "continua inconsciente")
	dino.inventory.add("berry", 1)
	dino.taming.tick(5.0)
	_check(is_equal_approx(dino.taming.taming_progress, 60.0), "retoma de onde parou")


func _test_taming_wake_resets_progress() -> void:
	var dino := _make_sleeping_dino(5)
	dino.taming.tick(10.0)
	_check(is_equal_approx(dino.taming.taming_progress, 40.0), "progresso parcial")
	dino.torpor.tick(100.0)
	_check(dino.state_machine.current_id == Enums.DinoStateId.IDLE, "acordou selvagem")
	_check(dino.taming.taming_progress == 0.0, "acordar zera o progresso")
	_check(dino.inventory.count("berry") == 3, "comida que sobrou permanece")
	dino.taming.tick(100.0)
	_check(dino.taming.taming_progress == 0.0 and dino.inventory.count("berry") == 3,
			"acordado não consome")


func _test_taming_only_wild_and_unconscious() -> void:
	var awake := _spawn_dino()
	awake.inventory.add("berry", 5)
	awake.taming.tick(100.0)
	_check(awake.taming.taming_progress == 0.0 and awake.inventory.count("berry") == 5,
			"consciente não é domesticado")
	var tamed := _make_sleeping_dino(10)
	tamed.state_machine.mark_tamed()
	tamed.torpor.add_torpor(100.0)
	tamed.taming.tick(100.0)
	_check(tamed.inventory.count("berry") == 10, "já domesticado não consome comida")


func _test_taming_restore_is_validated() -> void:
	var dino := _spawn_dino()
	var events := [0]
	dino.taming.food_consumed.connect(func(_id: String) -> void: events[0] += 1)
	dino.taming.from_dict({"progress": 999.0, "meal_timer": 1e9, "food_stock": {"berry": 5}})
	_check(dino.taming.taming_progress == 100.0, "progresso do save é limitado")
	_check(dino.taming.to_dict()["meal_timer"] <= dino.taming.seconds_per_meal, "relógio da refeição é limitado")
	_check(dino.inventory.is_empty(), "food_stock antigo é ignorado (jogo não publicado)")
	_check(not dino.state_machine.is_tamed and events[0] == 0, "restaurar não domestica nem dispara evento")
	var wake := _spawn_dino()
	wake.from_dict({"taming": {"progress": 60.0}, "torpor": {"current": 0.0}})
	_check(wake.taming.taming_progress == 0.0, "progresso de criatura acordada no save é zerado")


func _test_dino_save_with_taming_through_json() -> void:
	var original := _make_sleeping_dino(5)
	original.inventory.add("meat", 2)
	original.taming.tick(7.0)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var copy := _spawn_dino()
	copy.from_dict(parsed)
	_check(is_equal_approx(copy.taming.taming_progress, 20.0), "progresso restaurado")
	_check(copy.inventory.count("berry") == 4 and copy.inventory.count("meat") == 2,
			"inventário restaurado")
	_check(copy.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "continua inconsciente")
	_check(copy.to_dict() == original.to_dict(), "save com domesticação idêntico depois do JSON")
	copy.taming.tick(3.0)
	original.taming.tick(3.0)
	_check(is_equal_approx(copy.taming.taming_progress, original.taming.taming_progress)
			and copy.taming.taming_progress == 40.0, "relógio da refeição também é restaurado")


# --- Inventário ---

func _make_inventory(slots: int, stack: int = 99) -> InventoryComponent:
	var inventory: InventoryComponent = _track(InventoryComponent.new())
	inventory.capacity = slots
	inventory.max_stack = stack
	return inventory


func _test_inventory_stacks_and_capacity() -> void:
	var inv := _make_inventory(3, 20)
	_check(inv.add("berry", 25) == 0, "25 baga cabem em 3 slots de 20")
	_check(inv.get_slot(0) == {"id": "berry", "count": 20, "expira_em": 0.0}
			and inv.get_slot(1) == {"id": "berry", "count": 5, "expira_em": 0.0},
			"pilha enche e transborda para o próximo slot")
	_check(inv.add("berry", 10) == 0 and inv.get_slot(1)["count"] == 15, "completa a pilha existente antes de abrir slot")
	_check(inv.add("meat", 3) == 0 and inv.get_slot(2) == {"id": "meat", "count": 3, "expira_em": 0.0}, "item diferente usa slot livre")
	_check(inv.add("berry", 10) == 5 and inv.count("berry") == 40, "cheio: devolve o que não coube e guarda o resto")
	_check(inv.add("fern", 1) == 1, "sem slot livre, outro item não entra")
	_check(inv.add("pedra", 5) == 5 and inv.count("pedra") == 0, "item desconhecido é rejeitado")
	_check(inv.add("berry", 0) == 0 and inv.add("berry", -3) == 0, "quantidade <= 0 não faz nada")
	var small := _make_inventory(2, 4)
	_check(small.add("fern", 10) == 2 and small.count("fern") == 8, "max_stack do inventário limita a pilha")
	_check(Items.max_stack("meat") == 10, "pilha máxima do item também vale")
	var meat := _make_inventory(2, 99)
	_check(meat.add("meat", 25) == 5, "pilha máxima do item (10) limita o inventário")
	_check(inv.get_slot(99).is_empty() and inv.get_slot(-1).is_empty(), "slot fora do intervalo é vazio")
	var copy := inv.get_slot(0)
	copy["count"] = 1
	_check(inv.get_slot(0)["count"] == 20, "get_slot devolve cópia")


func _test_inventory_remove_and_count() -> void:
	var inv := _make_inventory(4, 10)
	inv.add("berry", 25)
	_check(inv.count("berry") == 25, "count soma as pilhas")
	_check(inv.remove("berry", 12) == 12 and inv.count("berry") == 13, "remove atravessa pilhas")
	_check(inv.remove("berry", 100) == 13 and inv.is_empty(), "remove devolve só o que existia")
	_check(inv.remove("berry", 1) == 0 and inv.remove("berry", -1) == 0, "remover o que não há ou negativo é 0")
	inv.add("berry", 3)
	inv.add("meat", 2)
	inv.remove("berry", 3)
	_check(inv.get_slot(0).is_empty() and inv.count("meat") == 2, "slot esvaziado fica livre e o outro item permanece")


func _test_inventory_transfer() -> void:
	var a := _make_inventory(4, 10)
	var b := _make_inventory(2, 10)
	a.add("berry", 25)
	a.add("meat", 5)
	var total := a.count("berry") + b.count("berry")
	_check(a.transfer(b, "berry", 8) == 8, "transfere a quantidade pedida")
	_check(a.count("berry") == 17 and b.count("berry") == 8, "origem perdeu e destino ganhou o mesmo")
	_check(a.transfer(b, "berry", 100) == 12, "só move o que o destino comporta (12 de espaço)")
	_check(a.count("berry") == 5 and b.count("berry") == 20, "destino cheio, sobra na origem")
	_check(a.count("berry") + b.count("berry") == total, "nada some nem duplica")
	_check(a.transfer(b, "meat", 5) == 0 and a.count("meat") == 5, "destino sem slot livre: nada se perde")
	_check(a.transfer(a, "berry", 1) == 0 and a.count("berry") == 5, "transferir para si mesmo não faz nada")
	_check(a.transfer(null, "berry", 1) == 0, "sem destino não faz nada")
	_check(a.transfer(b, "berry", 0) == 0 and a.transfer(b, "fern", 3) == 0, "zero e item ausente")
	b.remove("berry", 20)
	var first := 0
	while a.get_slot(first).is_empty():
		first += 1
	var in_slot: int = a.get_slot(first)["count"]
	_check(a.transfer_slot(first, b) == in_slot and a.transfer_slot(99, b) == 0,
			"transfer_slot move o slot inteiro; slot inexistente é 0")
	_check(a.count("berry") + b.count("berry") == 5, "conservação depois de transfer_slot")


func _test_inventory_signals() -> void:
	var a := _make_inventory(2, 10)
	var b := _make_inventory(2, 10)
	var hits := [0, 0]
	a.changed.connect(func() -> void: hits[0] += 1)
	b.changed.connect(func() -> void: hits[1] += 1)
	a.add("berry", 5)
	_check(hits[0] == 1, "add emite changed uma vez")
	a.add("berry", 0)
	a.remove("meat", 1)
	a.add("pedra", 1)
	_check(hits[0] == 1, "operação sem efeito não emite")
	a.transfer(b, "berry", 3)
	_check(hits[0] == 2 and hits[1] == 1, "transfer emite uma vez em cada lado")
	var full := _make_inventory(1, 1)
	full.add("berry", 1)
	a.transfer(full, "berry", 1)
	_check(hits[0] == 2, "transfer bloqueada não emite")
	a.from_dict(a.to_dict())
	_check(hits[0] == 3, "from_dict emite changed (a UI redesenha)")


func _test_inventory_save_is_validated() -> void:
	var inv := _make_inventory(4, 20)
	inv.add("berry", 25)
	inv.add("meat", 3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	var copy := _make_inventory(4, 20)
	copy.from_dict(parsed)
	_check(copy.to_dict() == inv.to_dict(), "inventário idêntico depois do JSON")
	_check(copy.count("berry") == 25 and copy.get_slot(2).get("id") == "meat", "posições dos slots preservadas")
	var hostile := _make_inventory(2, 20)
	hostile.add("meat", 1)
	_check(not hostile.from_dict({"slots": [{"id": "berry", "count": 99999999}]}) and hostile.count("meat") == 1
			and hostile.count("berry") == 0, "contagem absurda que não cabe: carga recusada, nada muda")
	hostile.from_dict({"slots": [{"id": "berry", "count": 30}]})
	_check(hostile.get_slot(0)["count"] == 20 and hostile.get_slot(1)["count"] == 10, "pilha acima do teto é dividida, não cortada")
	hostile.from_dict({"slots": [{"id": "pedra", "count": 5}, {"id": "meat", "count": 1}]})
	_check(hostile.get_slot(0).is_empty() and hostile.count("meat") == 1, "id desconhecido é descartado")
	_check(not hostile.from_dict({"slots": [{"id": "meat", "count": 1}, {"id": "fern", "count": 1}, {"id": "berry", "count": 3}]})
			and hostile.count("fern") == 0 and hostile.count("meat") == 1, "item válido além da capacidade: recusa a carga inteira")
	hostile.from_dict({"slots": []})
	for bad: Variant in [{"slots": "lixo"}, {"slots": [null, 3, "x", [], {"id": 7, "count": 1}]},
			{"slots": [{"id": "berry", "count": -4}]}, {"slots": [{"id": "berry", "count": "9"}]},
			{"slots": [{"id": "berry", "count": INF}]}, {"slots": [{"id": "berry", "count": NAN}]}, {}]:
		hostile.from_dict(bad)
		_check(hostile.is_empty(), "save inválido vira inventário vazio: %s" % str(bad))


func _test_inventory_capacity_setter() -> void:
	var inv := _make_inventory(6, 10)
	inv.add("berry", 25)
	inv.capacity = 2
	_check(inv.capacity == 3 and inv.count("berry") == 25, "reduzir capacidade não descarta itens")
	inv.capacity = 500
	_check(inv.capacity == InventoryComponent.MAX_CAPACITY and inv.slot_count() == inv.capacity, "capacidade é limitada")
	inv.capacity = 0
	_check(inv.capacity == 3, "capacidade mínima respeita o que está ocupado")


func _test_taming_without_inventory() -> void:
	var machine := _make_machine()
	var taming: TamingComponent = _track(TamingComponent.new())
	taming.state_machine = machine
	machine.torpor.add_torpor(100.0)
	taming.tick(100.0)
	_check(taming.taming_progress == 0.0 and taming.food_available() == 0, "sem inventário não domestica nem quebra")


# --- Interação ---

func _test_can_interact_rule() -> void:
	var dino := _spawn_dino()
	_check(not dino.can_interact(), "selvagem acordado não pode ser aberto")
	_check(not dino.interactable.can_interact(), "a área reflete a regra da entidade")
	dino.torpor.add_torpor(100.0)
	_check(dino.can_interact() and dino.interactable.can_interact(), "selvagem inconsciente pode ser aberto")
	dino.state_machine.mark_tamed()
	_check(not dino.can_interact(), "domesticado não pode ser aberto")
	dino.torpor.add_torpor(100.0)
	_check(not dino.can_interact(), "domesticado inconsciente também não")
	var area: InteractableArea = _track(InteractableArea.new())
	_check(area.can_interact(), "sem regra, a área está sempre disponível")
	var events: Array[bool] = []
	var wild := _spawn_dino()
	wild.interactable.availability_changed.connect(func(v: bool) -> void: events.append(v))
	wild.torpor.add_torpor(100.0)
	wild.torpor.tick(1000.0)
	wild.interactable.refresh()
	_check(events == [true, false], "availability_changed só emite quando muda")


func _test_input_actions_for_interaction() -> void:
	for action in ["interact", "attack", "inventory"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
				"ação %s existe no projeto" % action)


func _test_attack_rules() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	_check(not player.attack(), "sem alvo não ataca")
	player.target = dino.interactable
	player._in_range.append(dino.interactable)
	_check(player.attack(), "golpe acerta o alvo")
	_check(is_equal_approx(dino.torpor.current_torpor, player.current_weapon().torpor), "aplica o torpor da arma")
	_check(not player.attack(), "recarga impede golpe seguido")
	player.tick(player.current_weapon().cooldown)
	_check(player.attack(), "depois da recarga ataca de novo")
	player.tick(1.0)
	player.input_locked = true
	_check(not player.attack() and not player.try_interact(), "com a tela aberta não ataca nem interage")
	player.input_locked = false
	dino.torpor.add_torpor(100.0)
	dino.state_machine.mark_tamed()
	_check(dino.state_machine.is_tamed and not dino.apply_torpor(10.0), "domesticado não recebe torpor")
	player.tick(1.0)
	_check(not player.attack(), "ataque não afeta domesticado")
	player.health.take_damage(1000.0)
	_check(not player.attack() and not player.try_interact(), "jogador morto não age")


func _test_player_inventory_and_save() -> void:
	var player := _spawn_player()
	_check(player.inventory.count("berry") == 10 and player.inventory.count("meat") == 4,
			"jogador começa com comida")
	player.inventory.remove("berry", 3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var copy := _spawn_player()
	copy.from_dict(parsed)
	_check(copy.inventory.count("berry") == 7, "inventário do jogador restaurado")
	_check(copy.to_dict() == player.to_dict(), "save do jogador idêntico depois do JSON")


## Dois dinos reais, detecção por física: o mais próximo vira alvo.
func _test_target_is_nearest() -> void:
	var player := _spawn_player()
	var far := _spawn_dino()
	var near := _spawn_dino()
	for dino in [far, near]:
		dino.set_physics_process(false)
	player.global_position = Vector2(5000, 5000)
	far.global_position = player.global_position + Vector2(30, 0)
	near.global_position = player.global_position + Vector2(-12, 0)
	var seen: Array[InteractableArea] = []
	player.target_changed.connect(func(t: InteractableArea) -> void: seen.append(t))
	for i in 4:
		await physics_frame
	player.tick(0.0)
	_check(player.target == near.interactable, "alvo é o interagível mais próximo")
	near.global_position = player.global_position + Vector2(200, 0)
	for i in 4:
		await physics_frame
	player.tick(0.0)
	_check(player.target == far.interactable, "o outro assume quando o primeiro sai do alcance")
	far.global_position = player.global_position + Vector2(300, 0)
	for i in 4:
		await physics_frame
	player.tick(0.0)
	_check(player.target == null and seen.back() == null, "sem ninguém no alcance, sem alvo")


# --- UI ---

func _spawn_screen(player: Player) -> InventoryScreen:
	var screen := InventoryScreen.new()
	screen.player_inventory = player.inventory
	root.add_child(screen)
	_nodes.append(screen)
	return screen


func _test_screen_closes_when_dino_wakes() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.torpor.add_torpor(100.0)
	var screen := _spawn_screen(player)
	var closed := [0]
	screen.closed.connect(func() -> void: closed[0] += 1)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	_check(screen.is_open and screen.visible, "tela abre")
	_check(screen.slot_button(true, 0) != null and screen.slot_button(false, 7) != null
			and screen.slot_button(false, 8) == null, "grade tem um botão por slot")
	dino.torpor.tick(1000.0)
	_check(not screen.is_open and not screen.visible and closed[0] == 1, "acordar fecha o painel")
	screen.close()
	_check(closed[0] == 1, "fechar duas vezes não repete o sinal")
	var own_hits := [0]
	player.inventory.changed.connect(func() -> void: own_hits[0] += 1)
	player.inventory.add("berry", 1)
	_check(own_hits[0] == 1, "fechada, a tela não se pendura nos sinais")
	screen.open_own()
	_check(screen.is_open and not screen.slot_button(false, 0), "inventário próprio abre sozinho")
	screen.close()


func _test_screen_closes_when_tamed() -> void:
	var player := _spawn_player()
	var dino := _make_sleeping_dino(0)
	var screen := _spawn_screen(player)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	dino.state_machine.mark_tamed()
	_check(not screen.is_open, "domesticar fecha o painel")


func _test_screen_closes_when_dino_removed() -> void:
	var player := _spawn_player()
	var dino := _make_sleeping_dino(0)
	var screen := _spawn_screen(player)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	root.remove_child(dino)
	_check(not screen.is_open, "dino removido da árvore fecha o painel")
	dino.free()


func _test_hud_reacts_to_signals() -> void:
	var player := _spawn_player()
	var hud := PlayerHud.new()
	hud.player = player
	root.add_child(hud)
	_nodes.append(hud)
	_check(hud.health_bar().value() == 100.0 and hud.hunger_bar().max_value() == 100.0, "HUD começa com os valores do jogador")
	player.health.take_damage(30.0)
	player.hunger.eat(0.0)
	_check(hud.health_bar().value() == 70.0, "barra de vida acompanha")
	player.hunger.tick(10.0)
	_check(hud.hunger_bar().value() == player.hunger.current_hunger, "barra de fome acompanha")
	_check(not hud.prompt_label().visible, "sem alvo: sem prompt")
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	player.target = dino.interactable
	player.target_changed.emit(dino.interactable)
	_check(not hud.prompt_label().visible, "criatura acordada: sem prompt")
	dino.torpor.add_torpor(100.0)
	_check(hud.prompt_label().visible and hud.prompt_label().text == "E para interagir", "inconsciente: prompt aparece")
	player.input_locked = true
	_check(not hud.prompt_label().visible, "tela aberta esconde o prompt")
	player.input_locked = false
	player.target = null
	player.target_changed.emit(null)
	_check(not hud.prompt_label().visible, "perder o alvo esconde o prompt")


func _spawn_bars(dino: Dino) -> DinoStatusBars:
	var bars := DinoStatusBars.new()
	bars.dino = dino
	root.add_child(bars)
	_nodes.append(bars)
	return bars


func _test_dino_status_bars() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var bars := _spawn_bars(dino)
	_check(not bars.visible, "dino acordado: nenhuma barra")
	dino.torpor.add_torpor(100.0)
	_check(bars.visible and bars.torpor_bar().visible and bars.taming_bar().visible, "dormindo: torpor e domesticação")
	_check(bars.torpor_bar().value() == 100.0, "barra de torpor reflete o valor")
	dino.inventory.add("berry", 5)
	dino.taming.tick(5.0)
	_check(is_equal_approx(bars.taming_bar().value(), 20.0), "barra de domesticação reflete o progresso")
	dino.global_position = Vector2(500, 40)
	bars.follow()
	_check(bars.global_position == Vector2(500, 40), "acompanha a posição do dino")
	var far := _spawn_player()
	far.global_position = Vector2(-5000, -5000)
	_check(bars.visible, "visível a qualquer distância do jogador")
	dino.torpor.reduce_torpor(100.0)
	_check(not dino.torpor.is_unconscious and not bars.visible, "acordou: nenhuma barra")
	_check(bars.torpor_bar().value() == 0.0, "barra de torpor zera ao acordar")
	var tamed := _make_sleeping_dino(10)
	var tamed_bars := _spawn_bars(tamed)
	_check(tamed_bars.visible and tamed_bars.taming_bar().visible, "barras criadas depois: refletem o estado")
	for i in 60:
		tamed.taming.tick(1.0)
		if tamed.state_machine.is_tamed:
			break
	_check(tamed.state_machine.is_tamed, "dino domesticado no teste")
	_check(not tamed_bars.visible, "domesticado acordado: nenhuma barra")
	tamed.torpor.add_torpor(tamed.torpor.max_torpor)
	_check(tamed.torpor.is_unconscious and tamed_bars.visible, "domesticado desmaiado: barras aparecem")
	_check(tamed_bars.torpor_bar().visible and not tamed_bars.taming_bar().visible,
			"domesticado desmaiado: só torpor")
	# Restaurar save: a barra reflete o estado restaurado, sem evento de jogo.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_make_sleeping_dino(0).to_dict()))
	var restored := _spawn_dino()
	restored.set_physics_process(false)
	var restored_bars := _spawn_bars(restored)
	restored.from_dict(saved)
	_check(restored_bars.visible and restored_bars.taming_bar().visible
			and restored_bars.torpor_bar().value() == 100.0, "from_dict de dormindo: barras visíveis")
	var awake: Dictionary = JSON.parse_string(JSON.stringify(_spawn_dino().to_dict()))
	restored.from_dict(awake)
	_check(not restored_bars.visible, "from_dict de acordado: barras escondidas")
	var tamed_save: Dictionary = JSON.parse_string(JSON.stringify(tamed.to_dict()))
	restored.from_dict(tamed_save)
	_check(restored_bars.visible and restored_bars.torpor_bar().visible and not restored_bars.taming_bar().visible,
			"from_dict de domesticado desmaiado: só torpor")


## Ponta a ponta sem teclado, na Main real: derruba, transfere, avança o tempo e domestica.
func _test_full_taming_integration() -> void:
	var main: Main = load("res://src/world/Main.tscn").instantiate()
	root.add_child(main)
	_nodes.append(main)
	var player: Player = main.player
	var screen: InventoryScreen = main.screen
	var dino: Dino = main.get_node("Dino")
	var hud: PlayerHud = main.get_node("UI/PlayerHud")
	# Tempo manual e determinístico: o relógio real não mexe no dino nem no jogador.
	for node: Node in [dino, dino.torpor, dino.taming, dino.state_machine, player, player.hunger, player.stamina]:
		node.set_physics_process(false)
	var starting_total := player.inventory.count("berry") + player.inventory.count("meat") \
			+ player.inventory.count("fern")
	dino.global_position = player.global_position + Vector2(30, 0)
	for i in 4:
		await physics_frame
	player.tick(0.0)
	_check(player.target == dino.interactable, "jogador detecta o dino no alcance")
	_check(not player.try_interact() and not screen.is_open, "dino acordado: E não abre nada")
	_check(dino.level == 20 and main.dino_level == 20, "a Main fixa o nível do dino")
	_check(player.request_use_item(3) and player.current_weapon().id == "sleep_staff", "tecla 4 põe o Bastão em mãos")
	for i in 12:
		player.attack()
		player.tick(0.7)
		dino.torpor.tick(0.7)
		if dino.torpor.is_unconscious:
			break
	_check(dino.torpor.is_unconscious, "golpes do bastão derrubam o dino")
	_check(dino.health.current_health < dino.health.max_health, "os golpes tiraram um pouco de vida")
	_check(hud.prompt_label().visible, "prompt aparece com o dino inconsciente")
	_check(player.try_interact() and screen.is_open and player.input_locked, "E abre a tela e trava o jogador")
	var before := player.global_position
	player.velocity = player.apply_input(Vector2.RIGHT, false, 0.1) * 0.0
	_check(player.input_locked, "jogador segue travado com a tela aberta")
	var button := screen.slot_button(true, 0)
	_check("Baga" in button.text.split("\n")[0], "slot 0 do jogador mostra a baga")
	button.pressed.emit()
	_check(dino.inventory.count("berry") == 10 and player.inventory.count("berry") == 0, "clique transferiu as bagas")
	for i in 40:
		dino.torpor.tick(1.0)
		dino.taming.tick(1.0)
		if dino.state_machine.is_tamed:
			break
	_check(dino.state_machine.current_id == Enums.DinoStateId.TAMED, "dino chegou a TAMED")
	_check(is_equal_approx(dino.taming.taming_progress, 100.0), "progresso em 100%")
	_check(dino.level == 28, "nível final 28 (20 com Eficiência 79%%: %d)" % dino.level)
	_check(not screen.is_open and not player.input_locked, "domesticar fechou a tela e liberou o jogador")
	var bars: DinoStatusBars = main.get_node("DinoStatusBars")
	_check(bars.health_bar_visible(), "dano recente: a barra de vida ainda aparece")
	bars.tick(DinoStatusBars.HEALTH_VISIBLE_SECONDS + 0.1)
	_check(not bars.visible, "domesticado, acordado e sem dano recente: sem barras sobre ele")
	_check(not hud.prompt_label().visible, "sem prompt para domesticado")
	var total := 0
	for inv: InventoryComponent in [player.inventory, dino.inventory]:
		total += inv.count("meat") + inv.count("fern") + inv.count("berry")
	_check(total + 6 == starting_total, "conservação: o que sumiu foi só o consumido (6 bagas no nível 20)")
	_check(player.global_position == before, "jogador não se moveu")


## Todo saveable da tabela volta idêntico depois do JSON. A cobertura da tabela
## (nenhum `to_dict` esquecido) é do tools/checks.d/10-arquitetura.sh.
func _test_saveable_roundtrip_table() -> void:
	var table := SaveableTable.new(root, _track)
	for script_path in SaveableTable.SCRIPTS:
		var pair := table.build(script_path)
		_check(pair.size() == 2, "saveable tem caso na tabela: %s" % script_path)
		if pair.size() != 2:
			continue
		var original: Object = pair[0]
		var restored: Object = pair[1]
		var expected: Dictionary = original.to_dict()
		_check(restored.to_dict() != expected, "caso exercita estado fora do padrão: %s" % script_path)
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(expected))
		restored.from_dict(parsed)
		_check(restored.to_dict() == expected, "roundtrip por JSON idêntico: %s" % script_path)
