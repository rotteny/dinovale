# SPDX-License-Identifier: MIT
class_name DayNightThreatTests
extends DenAndVigilTests
## E9: a percepção do Agressivo é x1,5 SÓ à noite (a autoridade decide), só a percepção muda, e o núcleo seguro (B6 da E3)
## segue valendo: o caçador nunca entra nele, de dia ou de noite.

const NIGHT_TIME := 560.0


func run() -> void:
	_test_perception_only_at_night()
	_test_only_the_aggressive_scales()
	_test_core_guarantee_at_night()
	_release_worlds()


func _set_time(world: Dictionary, seconds: float) -> void:
	(world["authority"] as WorldAuthority).clock.restore(seconds)


## O jogador a 10 tiles (além dos 8 do dia, dentro dos 12 da noite): de dia o caçador não o vê; de noite sim.
func _test_perception_only_at_night() -> void:
	for night in [false, true]:
		var world := _world()
		_set_time(world, NIGHT_TIME if night else 100.0)
		var hunter := _dino(world, _carnivore_stats(8.0), DEN, "c1")
		(world["player"] as Player).global_position = DEN + Vector2(10.0 * TILE, 0.0)
		_run(world, 1.0)
		var sees: bool = _target(world, hunter) == world["player"] or hunter.state_machine.is_aggressive
		_check(sees == night, "E9: jogador a 10 tiles: %s" % ("de noite o caçador o percebe" if night else "de dia o caçador não o percebe"))
		if night:
			_check(hunter.state_machine.perception_scale == 1.5, "E9: a máquina do dino recebe o multiplicador da autoridade")
	var world := _world()
	_set_time(world, NIGHT_TIME)
	var hunter := _dino(world, _carnivore_stats(8.0), DEN, "c2")
	(world["player"] as Player).global_position = DEN + Vector2(13.0 * TILE, 0.0)
	_run(world, 1.0)
	_check(_target(world, hunter) == null and not hunter.state_machine.is_aggressive, "E9: a 13 tiles nem de noite (o alcance é 12)")
	_set_time(world, 100.0)
	_check((world["authority"] as WorldAuthority).perception_scale() == 1.0, "E9: ao amanhecer a percepção volta a x1")


## Só o Agressivo cresce, e só a percepção: a velocidade e a desistência da perseguição são os mesmos dados.
func _test_only_the_aggressive_scales() -> void:
	var aggressive := _carnivore_stats(8.0)
	var passive := _herbivore_stats()
	_check(is_equal_approx(aggressive.perception_px(TILE, 1.5), 12.0 * TILE) and is_equal_approx(aggressive.perception_px(TILE), 8.0 * TILE),
			"E9: o Agressivo vê 12 tiles com x1,5 e 8 sem ele")
	_check(is_equal_approx(passive.perception_px(TILE, 1.5), 8.0 * TILE), "E9: o Passivo não ganha percepção")
	var speed := aggressive.chase_speed
	var give_up := aggressive.chase_give_up_tiles
	var seconds := aggressive.chase_max_seconds
	aggressive.perception_px(TILE, 1.5)
	_check(aggressive.chase_speed == speed and aggressive.chase_give_up_tiles == give_up and aggressive.chase_max_seconds == seconds,
			"E9: velocidade e desistência da perseguição não mudam")


## B6 à noite: mesma geometria do B6 de dia. Quem está dentro do núcleo nunca é percebido por caçador de fora e o caçador
## nunca entra, mesmo com 12 tiles de alcance contra a margem de 8. A garantia vem de `SafeCore` (alvo dentro é vedado),
## não da margem; a margem só vale na vertical (12 / 1,6 = 7,5 tiles < 8).
func _test_core_guarantee_at_night() -> void:
	var margin := (load("res://data/balance/predation_rules.tres") as PredationRules).spawn_safe_margin_tiles
	var rules := load("res://data/balance/day_cycle_rules.tres") as DayCycleRules
	var vertical_weight := _carnivore_stats().perception_vertical_weight
	var reach := 8.0 * rules.night_perception_multiplier / vertical_weight
	_check(margin >= reach, "E9: de noite a elipse vertical (%.1f tiles) cabe na margem de %.0f" % [reach, margin])
	var area := Rect2(Vector2(0.0, 288.0), Vector2(400.0, 200.0))
	var world := _world(area)
	_set_time(world, NIGHT_TIME)
	var player: Player = world["player"]
	for py in [160.0, 200.0, 400.0]:
		player.global_position = Vector2(200.0, py)
		var hunter := _dino(world, _carnivore_stats(8.0), Vector2(200.0, 152.0), "v")
		_run(world, 1.0)
		_check(_target(world, hunter) == null and not hunter.state_machine.is_aggressive,
				"E9: de noite, jogador a y = %.0f nunca é percebido por caçador a y = 152" % py)
		hunter.queue_free()
		(world["dinos"] as Array[Dino]).erase(hunter)
	# Movimento: de lado, onde o alcance de 12 tiles passa da margem de 8: o jogador dentro do núcleo, o caçador na borda.
	var edge_hunter := _dino(world, _carnivore_stats(8.0), Vector2(-190.0, 300.0), "side")
	var core: SafeCore = (world["system"] as PredationSystem).safe_core()
	edge_hunter.stats.chase_speed = 200.0
	player.global_position = Vector2(-60.0, 300.0)  # dentro do núcleo (borda em x = -128); sem a trava o caçador entraria
	var entered := false
	for _i in 300:
		_run(world, 1.0)
		entered = entered or core.contains(edge_hunter.global_position)
	_check(core.contains(player.global_position) and not entered, "E9: em 300 s de noite o caçador nunca entra no núcleo")
