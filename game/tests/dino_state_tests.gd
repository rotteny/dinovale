# SPDX-License-Identifier: MIT
class_name DinoStateTests
extends TestSuite
## Vida, torpor, máquina de estados do dino, save em JSON, cena do dino, vigor e fome.


func run() -> void:
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


func _test_health() -> void:
	var health: HealthComponent = _track.call(HealthComponent.new())
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
	var health: HealthComponent = _track.call(HealthComponent.new())
	health.max_health = 250.0
	_check(health.current_health == 250.0, "vida cheia acompanha o novo máximo")
	health.take_damage(50.0)
	health.max_health = 100.0
	_check(health.current_health == 100.0, "vida é limitada ao reduzir o máximo")


func _test_torpor_knockout_and_wake() -> void:
	var torpor: TorporComponent = _track.call(TorporComponent.new())
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
	var torpor: TorporComponent = _track.call(TorporComponent.new())
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


func _stamina() -> StaminaComponent:
	return _track.call(StaminaComponent.new())


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
	var hunger: HungerComponent = _track.call(HungerComponent.new())
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
	var hunger: HungerComponent = _track.call(HungerComponent.new())
	var hits := [0]
	hunger.starved.connect(func(_damage: float) -> void: hits[0] += 1)
	hunger.tick(1000.0)
	hits[0] = 0
	hunger.eat(-5.0)
	_check(hunger.is_starving(), "comer valor negativo é ignorado")
	hunger.eat(30.0)
	hunger.tick(10.0)
	_check(hits[0] == 0 and not hunger.is_starving(), "comer interrompe o dano")
