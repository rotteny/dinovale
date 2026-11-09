# SPDX-License-Identifier: MIT
class_name DenAndVigilTests
extends PredationTests
## E3 (toca e vigília): ronda, âncora, volta, núcleo seguro, dormindo em doma como presa. Usa a montagem de `PredationTests`.
## Os números vêm de `home_rules.tres` e `predation_rules.tres`; aqui só se prova o comportamento.

const DEN := Vector2(1000.0, 1000.0)


func run() -> void:
	_test_b1_patrol_stays_near_den()
	_test_b3_returns_to_den()
	_test_b2_b7_anchor_limits_the_hunt()
	_test_b6_safe_core_is_barred()
	_test_b9_b10_snore_radius()
	_test_b11_b12_sniff_and_provocation()
	_test_b13_b14_bites_and_death()
	_test_b15_floor_and_flags()
	_test_b17_sleeper_not_saved_as_hunt()
	_release_worlds()


func _homed(world: Dictionary, at: Vector2 = DEN, perception: float = 8.0) -> Dino:
	var stats := _carnivore_stats(perception)
	stats.home = HomeProfile.new()
	stats.predation.hears_sleepers = true
	var hunter := _dino(world, stats, at, "c1")
	hunter.state_machine.bind_home(DEN)
	return hunter


## Dormindo em doma, selvagem, com quem alimenta e comida de doma.
func _sleeper(world: Dictionary, at: Vector2, id: String = "test_herbivore") -> Dino:
	var prey := _dino(world, _herbivore_stats(id), at, "s_" + id)
	prey.taming.rules = prey.taming.rules.duplicate() as TamingRules
	prey.torpor.add_torpor(prey.torpor.max_torpor)
	prey.feeder_player_id = "owner1"  # quem alimenta (a nocaute zera o campo)
	return prey


func _tiles_from_den(dino: Dino) -> float:
	return dino.global_position.distance_to(DEN) / TILE


## B1: a ronda fica dentro do raio da ronda (10 tiles) por minutos.
func _test_b1_patrol_stays_near_den() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world)
	hunter.stats.aggressive = false  # sem alvo no mundo: só a ronda
	hunter.state_machine.idle_seconds = Vector2(0.5, 1.0)
	hunter.state_machine.transition_to(Enums.DinoStateId.WANDER)
	var rules := hunter.state_machine.home.rules
	var worst := 0.0
	for _i in 120:
		_run(world, 2.0)
		worst = maxf(worst, _tiles_from_den(hunter))
	_check(worst <= rules.patrol_tiles + 0.5 and worst > 1.0,
			"B1: a ronda anda, mas nunca passa de %.0f tiles da toca (máximo %.1f)" % [rules.patrol_tiles, worst])


func player_far(world: Dictionary) -> void:
	(world["player"] as Player).global_position = DEN + Vector2(60.0, 200.0)  # ativo, fora da percepção de 8 tiles e do círculo do ronco


## B3: fora da ronda, o caçador volta andando (60 px/s) e chega.
func _test_b3_returns_to_den() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN + Vector2(18.0 * TILE, 0.0))
	hunter.stats.aggressive = false
	_check(hunter.state_machine.wants_return(), "B3: fora da ronda ele quer voltar")
	var before := _tiles_from_den(hunter)
	_run(world, 1.0)
	var step := before - _tiles_from_den(hunter)
	_check(step > 0.0 and step * TILE <= 60.0 * 1.2, "B3: a volta anda a no máximo ~60 px/s (%.1f px em 1 s)" % (step * TILE))
	_run(world, 30.0)
	_check(hunter.state_machine.home.in_patrol(hunter.global_position), "B3: em 30 s ele volta à ronda (%.1f tiles)" % _tiles_from_den(hunter))
	var tamed := _tamed(world, _herbivore_stats("test_herbivore_tamed"), DEN + Vector2(18.0 * TILE, 0.0))
	_check(not tamed.state_machine.wants_return(), "B3: sem toca (ou domado) não há volta")


## B2 e B7: a presa fora da âncora (24 tiles) não é travada; a que sai dela é solta.
func _test_b2_b7_anchor_limits_the_hunt() -> void:
	var world := _world()
	(world["player"] as Player).global_position = DEN + Vector2(200.0, 100.0)  # a presa fica no raio ativo
	var hunter := _homed(world, DEN, 40.0)
	hunter.stats.aggressive = false  # o jogador não é alvo: só a presa
	var inside := _dino(world, _herbivore_stats(), DEN + Vector2(100.0, 0.0), "h1")
	var outside := _dino(world, _herbivore_stats("test_herbivore_b"), DEN + Vector2(25.0 * TILE, 0.0), "h2")
	for k in 2:
		_dino(world, _herbivore_stats(), DEN + Vector2(100.0, 30.0 * float(k + 1)), "h1")
		_dino(world, _herbivore_stats("test_herbivore_b"), DEN + Vector2(25.0 * TILE, 30.0 * float(k + 1)), "h2")
	_run(world, 0.5)
	_check(_target(world, hunter) == inside, "B2: trava a presa dentro da âncora")
	inside.global_position = DEN + Vector2(26.0 * TILE, 10.0)
	_run(world, 0.6)
	_check(not (_target(world, hunter) is Dino) and outside != null,
			"B2/B7: presa fora da âncora (25 tiles) não é travada; a que passa dela é solta")
	_run(world, 6.0)
	_check(hunter.state_machine.home.in_anchor(hunter.global_position), "B7: o caçador não passa da âncora (%.1f)" % _tiles_from_den(hunter))


## B6: o núcleo seguro (região + margem) veda a presa: dentro dele nunca é travada.
func _test_b6_safe_core_is_barred() -> void:
	var area := Rect2(DEN + Vector2(-340.0, -10.0), Vector2(20.0, 20.0))
	var world := _world(area)
	(world["player"] as Player).global_position = DEN + Vector2(-150.0, 100.0)
	var hunter := _dino(world, _carnivore_stats(40.0), DEN, "c1")
	var core: SafeCore = (world["system"] as PredationSystem).safe_core()
	_check(core.contains(area.get_center()) and core.contains(DEN + Vector2(-200.0, 0.0)) and not core.contains(DEN + Vector2(-100.0, 0.0)),
			"B6: o núcleo é a região mais a margem de 8 tiles")
	var prey := _dino(world, _herbivore_stats(), DEN + Vector2(-100.0, 0.0), "h1")
	for k in 2:
		_dino(world, _herbivore_stats(), DEN + Vector2(-100.0, 30.0 * float(k + 1)), "h1")
	_run(world, 1.0)
	_check(_target(world, hunter) == prey, "B6: fora do núcleo a presa é travada")
	prey.global_position = DEN + Vector2(-200.0, 0.0)
	_run(world, 1.0)
	_check(_target(world, hunter) != prey, "B6: a presa dentro do núcleo é solta e não volta a ser travada")
	var never_inside := true
	for _i in 120:
		_run(world, 1.0)
		never_inside = never_inside and not core.contains(hunter.global_position)
	_check(never_inside, "B6: o caçador nunca entra no núcleo em 120 s")


## B9 e B10: o círculo do ronco (8 tiles), o teto da espécie e o bônus por comida.
func _test_b9_b10_snore_radius() -> void:
	for case: Array in [[7.9, 0.0, true], [8.1, 0.0, false], [3.9, 4.0, true], [5.0, 4.0, false]]:
		var world := _world()
		player_far(world)
		var hunter := _homed(world, DEN, 40.0)
		hunter.stats.predation.sleeper_range_cap_tiles = case[1]
		var prey := _sleeper(world, DEN + Vector2(float(case[0]) * TILE, 0.0))
		_run(world, 1.0)
		_check((_target(world, hunter) == prey) == case[2], "B9: dormindo a %.1f tiles, teto %.0f: %s" % [case[0], case[1], str(case[2])])
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(10.0 * TILE, 0.0))
	_run(world, 1.0)
	_check(_target(world, hunter) != prey, "B10: a 10 tiles ele não escuta (ronco 8)")
	prey.taming.rules.snore_bonus_by_food = {prey.taming.ideal_food: 3.0}
	_run(world, 1.0)
	_check(_target(world, hunter) == prey, "B10: o bônus da comida de doma amplia o ronco (8 + 3)")


## B11 e B12: farejar 1,5 s sem morder, "!" no sinal, e a pancada do jogador troca o alvo no mesmo quadro.
func _test_b11_b12_sniff_and_provocation() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(5.0 * TILE, 0.0))
	var alerts := [0]
	(world["system"] as PredationSystem).sleeper_alerted.connect(func(_h: Dino, _p: Dino) -> void: alerts[0] += 1)
	_run(world, 0.5)
	_check(_target(world, hunter) == prey and hunter.is_sniffing() and alerts[0] == 1, "B11: trava o dormindo e fareja (um aviso)")
	_run(world, 0.7)
	_check(hunter.is_sniffing() and prey.bite_count == 0, "B11: aos 1,2 s ainda fareja, sem mordida")
	_run(world, 1.0)
	_check(not hunter.is_sniffing() and alerts[0] == 1, "B11: passado 1,5 s o farejo acaba, e o aviso não repete")
	_run(world, 6.0)
	_check(prey.bite_count > 0, "B11: depois do farejo ele morde")
	var other := _world()
	player_far(other)
	var raptor := _homed(other, DEN)
	var sleeper := _sleeper(other, DEN + Vector2(5.0 * TILE, 0.0))
	_run(other, 0.5)
	raptor.player_damage_count += 1
	(other["system"] as PredationSystem).tick(0.0)
	_check(_target(other, raptor) != sleeper and sleeper.bite_count == 0, "B12: a pancada do jogador solta o dormindo no mesmo quadro")


## B13 e B14: cada mordida custa eficiência; a morte falha a doma, avisa e solta a comida no chão.
func _test_b13_b14_bites_and_death() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(2.0 * TILE, 0.0))
	prey.inventory.add("berry", 5)
	var ground: GroundItemField = world["ground"]
	var codes: Array[String] = []
	(world["authority"] as WorldAuthority).owner_event.connect(func(_o: String, code: String, _p: Dictionary) -> void: codes.append(code))
	var rules := prey.taming.rules
	var before := prey.taming.efficiency
	var hp := prey.health.current_health
	_check(prey.be_bitten(hunter.attack_damage, hunter), "B13: o dormindo leva a mordida")
	var expected := rules.attack_loss("carnivore", (hp - prey.health.current_health) / prey.health.max_health * 100.0)
	_check(absf((before - prey.taming.efficiency) - expected) < 0.01 and expected > 8.0,
			"B13: a eficiência cai o fixo mais o por cento de vida (%.1f)" % (before - prey.taming.efficiency))
	_check(prey.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not prey.state_machine.is_aggressive,
			"B13: não acorda nem vira bravo")
	prey.health.current_health = 1.0
	_run(world, 12.0)
	_check(prey.health.is_dead() and prey.taming.has_failed, "B14: morto, a doma falha")
	_check(ground.total_of("berry") == 5, "B14: a comida do inventário cai no chão (%d)" % ground.total_of("berry"))
	_check("taming_killed" in codes, "B14: o alimentador é avisado da morte")
	_check("taming_attacked" in codes or prey.bite_count > 0, "B14: houve mordida registrada")


## B15: o piso do bando não protege o dormindo; as flags desligam o comportamento; domado ignora o dormindo.
func _test_b15_floor_and_flags() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(3.0 * TILE, 0.0))
	_run(world, 1.0)
	_check(_target(world, hunter) == prey, "B15: sozinho no bando, o dormindo ainda é presa (piso ignorado)")
	var system: PredationSystem = world["system"]
	system.rules = system.rules.duplicate() as PredationRules
	system.rules.sleeper_is_prey = false
	_run(world, 1.0)
	_check(_target(world, hunter) != prey, "B15: sleeper_is_prey = false volta ao D15 (dormindo não é presa)")
	var deaf := _world()
	player_far(deaf)
	var blind := _homed(deaf, DEN)
	blind.stats.predation.hears_sleepers = false
	var asleep := _sleeper(deaf, DEN + Vector2(3.0 * TILE, 0.0))
	_run(deaf, 1.0)
	_check(_target(deaf, blind) != asleep, "B15: espécie sem hears_sleepers não escuta")


## B17: nada da caça (nem do farejo) vai para o save do dormindo.
func _test_b17_sleeper_not_saved_as_hunt() -> void:
	var world := _world()
	player_far(world)
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(4.0 * TILE, 0.0))
	_run(world, 0.5)
	var text := JSON.stringify(hunter.to_dict()) + JSON.stringify(prey.to_dict())
	_check(hunter.is_sniffing() and not text.contains("sniff") and not text.contains("alert"), "B17: o farejo não é salvo")
