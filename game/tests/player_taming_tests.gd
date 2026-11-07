# SPDX-License-Identifier: MIT
class_name PlayerTamingTests
extends TestSuite
## Cena, movimento, corrida, entrada e save do jogador; ciclo completo de domesticação.


func run() -> void:
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
