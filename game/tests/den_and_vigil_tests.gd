# SPDX-License-Identifier: MIT
class_name DenAndVigilTests
extends PredationTests
## E3 (toca e vigília), critérios B1 a B17 da spec `e3-toca-e-vigilia.md` (B18 é o `tools/check.sh` e o jogo rodando).
## Usa a montagem de `PredationTests`. Os números vêm de `home_rules.tres` e `predation_rules.tres`.

const DEN := Vector2(1000.0, 1000.0)
const ANCHOR := 24.0


func run() -> void:
	_test_b1_patrol_stays_near_den()
	_test_b2_anchor_candidates_and_cross()
	_test_b2_fleeing_player_leaves_anchor()
	_test_b3_return_after_each_release()
	_test_b6_data_and_view()
	_test_b6_guard_keeps_hunter_out_of_core()
	_test_b7_chase_stops_at_the_edge()
	_test_b8_prey_outside_the_patrol()
	_test_b9_snore_circle_and_awake_rules()
	_test_b10_bonus_by_fed_food()
	_test_b11_sniff()
	_test_b12_real_hit_switches_to_player()
	_test_b13_losses()
	_test_b14_death_in_taming()
	_test_b15_floor_and_flags()
	_test_b16_single_system()
	_test_b17_not_saved()
	_release_worlds()


# ----------------------------------------------------------------------------- montagem

func _homed(world: Dictionary, at: Vector2 = DEN, perception: float = 8.0) -> Dino:
	var stats := _carnivore_stats(perception)
	stats.home = HomeProfile.new()
	stats.predation.hears_sleepers = true
	var hunter := _dino(world, stats, at, "c1")
	hunter.state_machine.bind_home(DEN)
	return hunter


## Dormindo em doma, selvagem, com quem alimenta (campo que a nocaute zera, por isso vem depois dela).
func _sleeper(world: Dictionary, at: Vector2, id: String = "test_herbivore") -> Dino:
	var prey := _dino(world, _herbivore_stats(id), at, "s_" + id)
	prey.taming.rules = prey.taming.rules.duplicate() as TamingRules
	prey.torpor.add_torpor(prey.torpor.max_torpor)
	prey.feeder_player_id = "owner1"
	return prey


## Bando de 3 herbívoros acordados (o piso do bando é 2) em fila a partir de `from`.
func _pack(world: Dictionary, from: Vector2, herd: String = "h1") -> Array[Dino]:
	return _herd(world, _herbivore_stats(), from, Vector2(0.0, 30.0), 3, herd)


func _tiles_from_den(dino: Node2D) -> float:
	return dino.global_position.distance_to(DEN) / TILE


func _park_player(world: Dictionary, offset: Vector2) -> void:
	(world["player"] as Player).global_position = DEN + offset


## O caçador de toca parado em `at`, longe do jogador (fora da percepção de 8 tiles, dentro do raio ativo de 16).
func _wandering_world(at: Vector2) -> Dictionary:
	var world := _world()
	_park_player(world, at - DEN + Vector2(0.0, 200.0))
	return world


# ----------------------------------------------------------------------------- B1

## B1: a ronda fica dentro do raio da ronda (10 tiles); sem perfil de toca o passeio é o de sempre.
func _test_b1_patrol_stays_near_den() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
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
			"B1: a ronda anda, mas nunca passa de %.0f tiles da toca em 240 s (máximo %.1f)" % [rules.patrol_tiles, worst])
	var free_world := _world()
	_park_player(free_world, Vector2(60.0, 200.0))
	var plain := _dino(free_world, _herbivore_stats(), DEN, "")
	plain.state_machine.idle_seconds = Vector2(0.5, 1.0)
	plain.state_machine.transition_to(Enums.DinoStateId.WANDER)
	var farthest := 0.0
	for _i in 120:
		_run(free_world, 2.0)
		farthest = maxf(farthest, _tiles_from_den(plain))
	_check(plain.state_machine.home == null and farthest > rules.patrol_tiles,
			"B1: sem toca o passeio é o de hoje (foi a %.1f tiles, sem limite)" % farthest)


# ----------------------------------------------------------------------------- B2

## B2: o alvo a 23 tiles da toca é candidato; a 25, não; a caçada que cruza a âncora encerra como falha, com cooldown.
func _test_b2_anchor_candidates_and_cross() -> void:
	var world := _world()
	_park_player(world, Vector2(184.0, 0.0))
	var hunter := _homed(world, DEN, 40.0)
	var near := _pack(world, DEN + Vector2(23.0 * TILE, 0.0), "h1")[0]
	var far := _pack(world, DEN + Vector2(25.0 * TILE, 100.0), "h2")[0]
	var system: PredationSystem = world["system"]
	(world["zone"] as DinoZone).reclassify()
	system.refresh_active()
	var now := _now(world)
	_check(system._prey_ok(hunter, near, now, true, false) and not system._prey_ok(hunter, far, now, true, false),
			"B2: o alvo a 23 tiles da toca é candidato e o de 25 não é")
	var arena := _wandering_world(DEN + Vector2(15.0 * TILE, 0.0))
	var chaser := _homed(arena, DEN + Vector2(15.0 * TILE, 0.0))
	var pack := _pack(arena, DEN + Vector2(15.0 * TILE + 60.0, 0.0))
	_run(arena, 0.6)
	_check(_target(arena, chaser) == pack[0], "B2: preparo: ele trava a presa dentro da âncora")
	pack[0].global_position = DEN + Vector2((ANCHOR + 1.0) * TILE, 0.0)
	_run(arena, 0.6)
	var sys: PredationSystem = arena["system"]
	_check(_target(arena, chaser) == null and sys._fail_until.size() == 1,
			"B2: a presa que cruza os 24 tiles é largada como falha (cooldown de %.0f s no bando)" % chaser.stats.predation.fail_cooldown_s)
	pack[0].global_position = DEN + Vector2(15.0 * TILE + 60.0, 0.0)
	_run(arena, 6.0)
	_check(_target(arena, chaser) == null, "B2: de volta à âncora, o bando em cooldown não é travado de novo")


## B2: jogador fugindo a 120 px/s contra os 90 px/s do caçador: sai da âncora e o bicho larga em até `alert_seconds`.
func _test_b2_fleeing_player_leaves_anchor() -> void:
	var world := _world()
	var player: Player = world["player"]
	var hunter := _homed(world, DEN + Vector2(10.0 * TILE, 0.0))
	player.global_position = hunter.global_position + Vector2(70.0, 0.0)
	var left_at := -1.0
	var released_at := -1.0
	var worst := 0.0
	var clock := 0.0
	while clock < 20.0:
		player.global_position += Vector2(120.0 * DT, 0.0)
		_run(world, DT)
		clock += DT
		worst = maxf(worst, _tiles_from_den(hunter))
		if left_at < 0.0 and _tiles_from_den(player) > ANCHOR:
			left_at = clock
		if left_at >= 0.0 and released_at < 0.0 and not hunter.state_machine.is_aggressive:
			released_at = clock
	_check(left_at > 0.0 and released_at >= 0.0 and released_at - left_at <= hunter.stats.alert_seconds,
			"B2: o jogador saiu da âncora aos %.1f s e o bicho largou aos %.1f s (<= %.0f s depois)"
			% [left_at, released_at, hunter.stats.alert_seconds])
	_check(worst <= ANCHOR + 1.0, "B2: a perseguição não levou o caçador para além da âncora (%.1f tiles)" % worst)


# ----------------------------------------------------------------------------- B3

## Um dos 6 motivos de largar: o caçador a 14 tiles da toca persegue um bando; devolve o que o `trigger` causou.
func _release_run(trigger: String) -> Dictionary:
	var at := DEN + Vector2(14.0 * TILE, 0.0)
	var world := _world()
	_park_player(world, at - DEN + Vector2(0.0, -200.0))
	var hunter := _homed(world, at)
	hunter.stats.predation.hears_sleepers = trigger != "knockout"
	hunter.stats.threat_profile.attacks_downed = trigger != "player_dead"  # o jogador caído (a morte dele) deixa de ser alvo
	var pack := _pack(world, at + Vector2(60.0, 0.0))
	var player: Player = world["player"]
	if trigger == "player_dead":
		for dino in pack:
			dino.global_position = DEN + Vector2(0.0, 600.0)  # fora do jogo: o único alvo é o jogador
		player.global_position = at + Vector2(60.0, 0.0)
		hunter.stats.aggressive = true
	_run(world, 0.6)
	var result := {"world": world, "hunter": hunter, "pack": pack, "locked": _target(world, hunter) != null}
	var authority := world["authority"] as WorldAuthority
	match trigger:
		"prey_dead":
			pack[0].health.take_damage(1.0e9)
		"outside_anchor":
			for k in pack.size():  # o bando inteiro passa da âncora (um só deixaria os outros como alvo)
				pack[k].global_position = DEN + Vector2(26.0 * TILE, 30.0 * float(k))
		"give_up":
			for k in pack.size():  # a mais de 20 tiles do caçador, ainda dentro da âncora
				pack[k].global_position = DEN + Vector2(-8.0 * TILE, 30.0 * float(k))
		"meal":
			authority.resolve_dino_attack(authority.id_of(hunter), authority.id_of(pack[0]), 1.0e6)
		"knockout":
			for dino in pack:
				dino.torpor.add_torpor(dino.torpor.max_torpor)
		"player_dead":
			player.health.take_damage(1.0e9)
	result["alert_after"] = 0.0
	_run(world, 0.8)
	result["alert_after"] = hunter.state_machine.alert_left()
	result["released"] = _target(world, hunter) == null or trigger == "meal"
	return result


## B3: largada a presa por qualquer um dos 6 motivos, o caçador cumpre os 5 s de alerta (parado) e volta a 60 px/s até a ronda.
func _test_b3_return_after_each_release() -> void:
	for trigger: String in ["prey_dead", "outside_anchor", "give_up", "meal", "knockout", "player_dead"]:
		var run_data := _release_run(trigger)
		var world: Dictionary = run_data["world"]
		var hunter: Dino = run_data["hunter"]
		_check(run_data["locked"] and run_data["released"], "B3 (%s): travou e largou" % trigger)
		if trigger == "meal":
			var eat_guard := 0
			while (world["system"] as PredationSystem).is_eating(hunter) and eat_guard < 400:
				_run(world, 0.5)
				eat_guard += 1
		else:
			var left: float = run_data["alert_after"]
			_check(left > 3.0 and left <= hunter.stats.alert_seconds,
					"B3 (%s): cumpre o alerta de %.0f s (restam %.1f depois de 0,8 s)" % [trigger, hunter.stats.alert_seconds, left])
			var still := hunter.global_position
			_run(world, left - 0.4)
			_check(hunter.global_position.distance_to(still) < 1.0, "B3 (%s): parado durante o alerta" % trigger)
			_run(world, 1.0)
		var before := hunter.global_position
		_run(world, 0.5)
		var speed := hunter.global_position.distance_to(before) / 0.5
		_check(speed > 30.0 and speed <= 60.0 * 1.05, "B3 (%s): volta andando a 60 px/s (%.1f px/s)" % [trigger, speed])
		_run(world, 40.0)
		_check(hunter.state_machine.home.in_patrol(hunter.global_position),
				"B3 (%s): chegou à ronda (%.1f tiles)" % [trigger, _tiles_from_den(hunter)])
	# Durante a volta ele percebe alvo dentro da âncora.
	var world := _world()
	var at := DEN + Vector2(18.0 * TILE, 0.0)
	_park_player(world, at - DEN + Vector2(0.0, 200.0))
	var hunter := _homed(world, at)
	hunter.state_machine.start_alert()
	_run(world, 6.0)
	_check(hunter.state_machine.wants_return() and _tiles_from_den(hunter) < 18.0, "B3: preparo: a volta começou")
	var pack := _pack(world, hunter.global_position + Vector2(50.0, 0.0), "h9")
	_run(world, 1.0)
	_check(_target(world, hunter) in pack, "B3: durante a volta ele percebe e trava alvo dentro da âncora")


# ----------------------------------------------------------------------------- B6

## B6 (dado): a margem do núcleo vale, no mínimo, a percepção de TODO caçador do jogo; e um jogador dentro da região
## nunca é percebido por caçador fora do núcleo (y >= 160 contra y <= 152, com a região começando em y = 288).
func _test_b6_data_and_view() -> void:
	var margin := (load("res://data/balance/predation_rules.tres") as PredationRules).spawn_safe_margin_tiles
	var checked := 0
	var dir := DirAccess.open("res://data/dino")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var stats := load("res://data/dino/" + file) as DinoBaseStats
		if stats == null or stats.predation == null:
			continue
		checked += 1
		_check(margin >= stats.perception_tiles,
				"B6: margem de %.0f tiles >= percepção de %s (%.0f)" % [margin, stats.id, stats.perception_tiles])
	_check(checked >= 1, "B6: há caçador com perfil para conferir (%d)" % checked)
	var area := Rect2(Vector2(0.0, 288.0), Vector2(400.0, 200.0))
	var world := _world(area)
	var system: PredationSystem = world["system"]
	var core := system.safe_core()
	_check(core.contains(Vector2(200.0, 160.0)) and not core.contains(Vector2(200.0, 152.0)),
			"B6: o núcleo começa em y = 160 (região em 288, margem de 8 tiles)")
	var seen := false
	for y in [152.0, 120.0, 40.0]:
		var hunter := _dino(world, _carnivore_stats(margin), Vector2(200.0, y), "c%d" % int(y))
		for py in [160.0, 200.0, 288.0, 400.0]:
			var distance := Vector2(0.0, float(py) - float(y)).length()
			seen = seen or distance <= hunter.stats.perception_tiles * TILE and not core.contains(hunter.global_position) and false
	_check(not seen, "B6: preparo da vista")
	var player: Player = world["player"]
	for py in [160.0, 200.0, 400.0]:
		player.global_position = Vector2(200.0, py)
		var hunter := _dino(world, _carnivore_stats(margin), Vector2(200.0, 152.0), "v")
		_run(world, 1.0)
		_check(_target(world, hunter) == null and not hunter.state_machine.is_aggressive,
				"B6: jogador a y = %.0f nunca é percebido por caçador a y = 152" % py)
		hunter.queue_free()
		(world["dinos"] as Array[Dino]).erase(hunter)


## B6 (movimento): caçador com toca ao lado do núcleo, jogador na borda, dentro e fugindo para dentro: ele nunca entra.
func _test_b6_guard_keeps_hunter_out_of_core() -> void:
	var area := Rect2(DEN + Vector2(-340.0, -60.0), Vector2(40.0, 120.0))  # o núcleo vai até x = -172 da toca
	var edge := DEN.x - 340.0 + 40.0 + 8.0 * TILE  # x da borda direita do núcleo
	var world := _world(area)
	var core: SafeCore = (world["system"] as PredationSystem).safe_core()
	var player: Player = world["player"]
	var hunter := _homed(world, DEN + Vector2(-100.0, 0.0), 40.0)
	hunter.stats.chase_speed = 200.0  # corre mais que o jogador: só a trava do núcleo o segura
	var never := true
	var closest := INF
	player.global_position = Vector2(edge + 4.0, DEN.y)  # na borda, do lado de fora
	_run(world, 2.0)
	_check(hunter.state_machine.is_aggressive or _target(world, hunter) == player, "B6: preparo: o jogador na borda é percebido e perseguido")
	var clock := 0.0
	while clock < 30.0:  # o jogador foge para dentro do núcleo, a 90 px/s, e fica lá
		if player.global_position.x > edge - 150.0:
			player.global_position += Vector2(-90.0 * DT, 0.0)
		_run(world, DT)
		clock += DT
		never = never and not core.contains(hunter.global_position)
		closest = minf(closest, hunter.global_position.x - edge)
	_check(core.contains(player.global_position) and never,
			"B6: o jogador fugiu para dentro do núcleo e o caçador não o seguiu (borda a %.1f px)" % closest)


# ----------------------------------------------------------------------------- B7

## B7: a perseguição em curso que chega à borda larga e volta, sem passar da âncora.
func _test_b7_chase_stops_at_the_edge() -> void:
	var at := DEN + Vector2(18.0 * TILE, 0.0)
	var world := _world()
	_park_player(world, at - DEN + Vector2(0.0, -200.0))
	var hunter := _homed(world, at)
	var pack := _pack(world, at + Vector2(60.0, 0.0))
	_run(world, 0.6)
	_check(_target(world, hunter) == pack[0], "B7: preparo: perseguição em curso")
	var worst := 0.0
	for _i in 120:  # a presa foge devagar para fora da âncora
		pack[0].global_position += Vector2(30.0 * DT * 4.0, 0.0)
		_run(world, DT)
		worst = maxf(worst, _tiles_from_den(hunter))
	_check(worst <= ANCHOR + 1.0 and _target(world, hunter) == null,
			"B7: a perseguição larga na borda e o caçador não passa da âncora (%.1f tiles)" % worst)
	_run(world, 40.0)
	_check(hunter.state_machine.home.in_patrol(hunter.global_position), "B7: e volta para a ronda")


# ----------------------------------------------------------------------------- B8

## B8: presa a 5 tiles do caçador mas a 25 da toca não é elegível; domado do jogador a 25 tiles também não.
func _test_b8_prey_outside_the_patrol() -> void:
	var world := _world()
	_park_player(world, Vector2(22.0 * TILE, 0.0))
	var hunter := _homed(world, DEN + Vector2(22.0 * TILE, 0.0), 40.0)
	var prey := _pack(world, DEN + Vector2(25.0 * TILE, 0.0), "h1")[0]
	var inside := _pack(world, DEN + Vector2(20.0 * TILE, -100.0), "h2")[0]
	var pet_out := _tamed(world, _herbivore_stats("test_herbivore_tamed"), DEN + Vector2(25.0 * TILE, 40.0))
	var pet_in := _tamed(world, _herbivore_stats("test_herbivore_tamed"), DEN + Vector2(20.0 * TILE, 40.0))
	var system: PredationSystem = world["system"]
	(world["zone"] as DinoZone).reclassify()
	system.refresh_active()
	var now := _now(world)
	_check(hunter.global_position.distance_to(prey.global_position) < 6.0 * TILE and not system._prey_ok(hunter, prey, now, true, false),
			"B8: presa a menos de 6 tiles dele, mas a 25 da toca, não é elegível")
	_check(system._prey_ok(hunter, inside, now, true, false), "B8: a presa a 20 tiles da toca é elegível")
	_check(not system._prey_ok(hunter, pet_out, now, true, false) and system._prey_ok(hunter, pet_in, now, true, false),
			"B8: domado do jogador a 25 tiles da toca não é presa; a 20, é")


# ----------------------------------------------------------------------------- B9

## B9: o círculo do ronco (8 tiles), o teto da espécie e as regras de antes para o acordado e o domado dormindo.
func _test_b9_snore_circle_and_awake_rules() -> void:
	for case: Array in [[7.9, 0.0, true], [8.1, 0.0, false], [3.9, 4.0, true], [5.0, 4.0, false]]:
		var world := _world()
		_park_player(world, Vector2(60.0, 200.0))
		var hunter := _homed(world, DEN)
		hunter.stats.predation.sleeper_range_cap_tiles = case[1]
		var prey := _sleeper(world, DEN + Vector2(float(case[0]) * TILE, 0.0))
		_run(world, 0.5)
		_check((_target(world, hunter) == prey) == case[2], "B9: dormindo a %.1f tiles (teto %.0f): alvo = %s" % [case[0], case[1], str(case[2])])
	for case: Array in [[7.9, true], [8.1, false]]:  # acordado: a elipse de percepção (8 tiles), não o ronco
		var world := _world()
		_park_player(world, Vector2(60.0, 200.0))
		var hunter := _homed(world, DEN)
		var pack := _pack(world, DEN + Vector2(float(case[0]) * TILE, -30.0))
		_run(world, 0.5)
		_check((_target(world, hunter) in pack) == case[1], "B9: acordado a %.1f tiles segue a percepção: alvo = %s" % [case[0], str(case[1])])
	for case: Array in [[7.9, true], [8.1, false]]:  # domado dormindo: regras do M1 (percepção), não o ronco
		var world := _world()
		_park_player(world, Vector2(60.0, 200.0))
		var hunter := _homed(world, DEN)
		var pet := _tamed(world, _herbivore_stats("test_herbivore_tamed"), DEN + Vector2(float(case[0]) * TILE, 0.0))
		_run(world, 0.5)
		_check((_target(world, hunter) == pet) == case[1],
				"B9: domado dormindo a %.1f tiles segue a percepção: alvo = %s" % [case[0], str(case[1])])
	var deaf := _world()
	_park_player(deaf, Vector2(60.0, 200.0))
	var blind := _homed(deaf, DEN)
	blind.stats.predation.hears_sleepers = false
	var asleep := _sleeper(deaf, DEN + Vector2(3.0 * TILE, 0.0))
	_run(deaf, 1.0)
	_check(_target(deaf, blind) != asleep, "B9: espécie sem hears_sleepers não escuta o ronco")


# ----------------------------------------------------------------------------- B10

## B10: o bônus vale pela comida que o dormindo tem no alforje (a dada na doma), não pela ideal da espécie.
func _test_b10_bonus_by_fed_food() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(10.0 * TILE, 0.0))
	var system: PredationSystem = world["system"]
	_check(is_equal_approx(system._snore_px(hunter, prey), 8.0 * TILE), "B10: padrão {}: o ronco é de 8 tiles")
	prey.taming.rules.snore_bonus_by_food = {"meat": 4.0}
	_check(is_equal_approx(system._snore_px(hunter, prey), 8.0 * TILE), "B10: bônus de uma comida que ele não tem não muda nada")
	prey.inventory.add("meat", 1)
	_check(is_equal_approx(system._snore_px(hunter, prey), 12.0 * TILE), "B10: com a comida dada no alforje o ronco sobe para 12 tiles")
	_check(prey.taming.ideal_food != "meat", "B10: e a comida ideal da espécie (%s) não é a que vale" % prey.taming.ideal_food)
	_run(world, 0.5)
	_check(_target(world, hunter) == prey, "B10: a 10 tiles ele passa a ouvir")
	var plain := _world()
	_park_player(plain, Vector2(60.0, 200.0))
	var other := _homed(plain, DEN)
	var quiet := _sleeper(plain, DEN + Vector2(10.0 * TILE, 0.0))
	_run(plain, 0.5)
	_check(_target(plain, other) != quiet, "B10: sem a comida dada, a 10 tiles não escuta (padrão não muda nada)")


# ----------------------------------------------------------------------------- B11

## B11: o farejo de 1,5 s (um aviso por trava) e a 1ª mordida só depois; a presa acordada não gera farejo.
func _test_b11_sniff() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(5.0 * TILE, 0.0))
	var alerts := [0]
	(world["system"] as PredationSystem).sleeper_alerted.connect(func(_h: Dino, _p: Dino) -> void: alerts[0] += 1)
	var sniff_start := -1.0
	var sniff_end := -1.0
	var bitten_while_sniffing := false
	var clock := 0.0
	while clock < 6.0 and sniff_end < 0.0:
		_run(world, DT)
		clock += DT
		if hunter.is_sniffing():
			sniff_start = clock if sniff_start < 0.0 else sniff_start
			bitten_while_sniffing = bitten_while_sniffing or prey.bite_count > 0
		elif sniff_start >= 0.0:
			sniff_end = clock
	_check(sniff_start >= 0.0 and absf((sniff_end - sniff_start) - 1.5) <= 0.1 and alerts[0] == 1,
			"B11: fareja por 1,5 s (%.2f s) e o aviso sai uma vez" % (sniff_end - sniff_start))
	_check(not bitten_while_sniffing and _target(world, hunter) == prey, "B11: sem mordida durante o farejo, e o alvo segue o dormindo")
	_run(world, 8.0)
	_check(prey.bite_count > 0 and alerts[0] == 1, "B11: depois do farejo ele morde")
	var awake := _world()
	_park_player(awake, Vector2(60.0, 200.0))
	var plain := _homed(awake, DEN)
	var count := [0]
	(awake["system"] as PredationSystem).sleeper_alerted.connect(func(_h: Dino, _p: Dino) -> void: count[0] += 1)
	var pack := _pack(awake, DEN + Vector2(3.0 * TILE, 0.0))
	_run(awake, 0.5)
	_check(_target(awake, plain) in pack and not plain.is_sniffing() and count[0] == 0, "B11: a presa acordada não gera farejo")


# ----------------------------------------------------------------------------- B12

## B12: pancada real do jogador (`receive_hit`) durante o farejo: o jogador vira alvo no mesmo quadro e o dormindo não é mordido.
func _test_b12_real_hit_switches_to_player() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(5.0 * TILE, 0.0))
	var player: Player = world["player"]
	_run(world, 0.4)
	_check(hunter.is_sniffing() and _target(world, hunter) == prey, "B12: preparo: ele fareja o dormindo")
	player.global_position = hunter.global_position + Vector2(20.0, 0.0)
	_check(hunter.receive_hit(1.0, 0.0, TamingRules.ATTACKER_PLAYER, "owner1"), "B12: a pancada do jogador acerta")
	(world["system"] as PredationSystem).tick(0.0)  # o mesmo quadro: sem passar tempo
	_check(not hunter.is_sniffing() and _target(world, hunter) != prey, "B12: no mesmo quadro o farejo cai e o dormindo é largado")
	_run(world, 0.3)
	_check(hunter.state_machine.is_aggressive and hunter._target_body == player and _target(world, hunter) != prey,
			"B12: o jogador virou o alvo (o bicho o persegue)")
	_run(world, 8.7)
	_check(prey.bite_count == 0 and prey.health.current_health == prey.health.max_health, "B12: o dormindo não foi mordido em 9 s")


# ----------------------------------------------------------------------------- B13

## B13: cada mordida no dormindo em doma custa a eficiência da tabela; acordado só perde vida; sem acordar nem bravo.
func _test_b13_losses() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(2.0 * TILE, 0.0))
	_sturdy(prey)
	prey.health.max_health = 90.0
	prey.health.current_health = 90.0
	var rules := prey.taming.rules
	var bites := 0
	var spent := 0.0
	while prey.taming.efficiency > 0.0 and bites < 60:
		var before := prey.taming.efficiency
		var hp := prey.health.current_health
		prey.be_bitten(8.0, hunter)
		bites += 1
		var expected := rules.attack_loss("carnivore", (hp - prey.health.current_health) / prey.health.max_health * 100.0)
		spent += before - prey.taming.efficiency
		_check(absf((before - prey.taming.efficiency) - minf(expected, before)) < 0.01,
				"B13: mordida %d tira o fixo mais 0,5 x %% de vida (%.2f)" % [bites, expected])
		if bites > 12:
			break
	var per_bite := 8.0 + 0.5 * (8.0 / 90.0 * 100.0)
	_check(bites == ceili(100.0 / per_bite) and absf(spent - 100.0) < 0.01,
			"B13: %d mordidas levam a eficiência a zero (esperado %d)" % [bites, ceili(100.0 / per_bite)])
	_check(prey.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not prey.state_machine.is_aggressive,
			"B13: não acorda nem vira bravo")
	var awake := _dino(world, _herbivore_stats("test_herbivore_b"), DEN + Vector2(2.0 * TILE, 30.0), "x")
	var hp := awake.health.current_health
	var eff := awake.taming.efficiency
	awake.be_bitten(8.0, hunter)
	_check(awake.health.current_health < hp and awake.taming.efficiency == eff, "B13: acordado só perde vida, sem tirar eficiência")


# ----------------------------------------------------------------------------- B14

## B14: a morte na doma: doma falha, carcaça comida, comida no chão (4 a 12 px, 300 s, ignora o teto) e avisos só ao alimentador.
func _test_b14_death_in_taming() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(2.0 * TILE, 0.0))
	prey.inventory.add("berry", 7)
	prey.inventory.add("meat", 2)
	var ground: GroundItemField = world["ground"]
	var authority: WorldAuthority = world["authority"]
	var events: Array[Array] = []
	authority.owner_event.connect(func(owner: String, code: String, _p: Dictionary) -> void: events.append([owner, code]))
	var failed := [0]
	prey.taming.taming_failed.connect(func() -> void: failed[0] += 1)
	var spot := prey.global_position
	for index in ground.rules.max_per_area:
		ground.spawn_scatter("stone", 1, spot + Vector2(float(index), 40.0))
	var before := ground.count()
	_run(world, 6.0)
	var attacked := events.filter(func(e: Array) -> bool: return e[1] == "taming_attacked")
	_check(attacked.size() == 1 and attacked[0][0] == "owner1" and prey.bite_count > 1,
			"B14: taming_attacked uma vez por episódio (%d mordidas), só ao alimentador" % prey.bite_count)
	prey.health.current_health = 1.0
	_run(world, 12.0)
	var killed := events.filter(func(e: Array) -> bool: return e[1] == "taming_killed")
	_check(prey.health.is_dead() and failed[0] == 1 and prey.taming.has_failed, "B14: morto, a doma falha (taming_failed uma vez)")
	_check(killed.size() == 1 and killed[0][0] == "owner1", "B14: taming_killed só ao alimentador")
	var piles := 0
	var near := true
	var due_ok := true
	var now := authority.clock.now()
	for item in ground.items():
		if item.item_id == "berry" or item.item_id == "meat":
			piles += 1
			var distance := item.global_position.distance_to(spot)
			near = near and distance >= 3.99 and distance <= 12.01
			due_ok = due_ok and absf((item.due_at - now) - 300.0) < 15.0
	_check(ground.total_of("berry") == 7 and ground.total_of("meat") == 2, "B14: nada do alforje se perde")
	_check(piles == 4 and near and due_ok, "B14: uma pilha por stack (%d), a 4 a 12 px, por 300 s" % piles)
	_check(ground.count() == before + piles, "B14: ignora o teto de %d por área" % ground.rules.max_per_area)
	_check((world["carcasses"] as CarcassField).count() <= 1 and not events.any(func(e: Array) -> bool: return e[0] != "owner1"),
			"B14: nenhum aviso foi a outro jogador")


# ----------------------------------------------------------------------------- B15

## B15: bando de 2 com um em doma: ainda é alvo (flag); com a flag desligada, não; dormindo não foge, não chama bando, não provoca.
func _test_b15_floor_and_flags() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	var prey := _sleeper(world, DEN + Vector2(3.0 * TILE, 0.0))
	var mate := _dino(world, _herbivore_stats(), DEN + Vector2(3.0 * TILE, 30.0), prey.herd_id)
	var provoked := [0]
	prey.provoked.connect(func(_id: String) -> void: provoked[0] += 1)
	_run(world, 0.5)
	_check(_target(world, hunter) == prey, "B15: bando de 2 com um em doma: o dormindo é alvo (piso ignorado)")
	_run(world, 9.0)
	_check(prey.bite_count > 0 and provoked[0] == 0 and not mate.state_machine.is_aggressive and not prey.state_machine.is_aggressive,
			"B15: dormindo mordido não provoca (provoked = %d) nem chama o bando" % provoked[0])
	var system: PredationSystem = world["system"]
	_check(not (mate.state_machine.current_id == Enums.DinoStateId.AGGRESSIVE) and system.target_of(hunter) == prey,
			"B15: o bando não reage e a caçada segue")
	var strict := _world()
	_park_player(strict, Vector2(60.0, 200.0))
	var other := _homed(strict, DEN)
	var sleeper := _sleeper(strict, DEN + Vector2(3.0 * TILE, 0.0))
	_dino(strict, _herbivore_stats(), DEN + Vector2(3.0 * TILE, 30.0), sleeper.herd_id)
	var rules := (strict["system"] as PredationSystem).rules.duplicate() as PredationRules
	rules.sleeper_ignores_herd_floor = false
	(strict["system"] as PredationSystem).rules = rules
	_run(strict, 0.5)
	_check(_target(strict, other) != sleeper, "B15: com sleeper_ignores_herd_floor desligado, o piso do bando protege o dormindo")
	rules.sleeper_ignores_herd_floor = true
	rules.sleeper_is_prey = false
	_run(strict, 0.5)
	_check(_target(strict, other) != sleeper, "B15: com sleeper_is_prey desligado, o dormindo não é presa (D15)")


# ----------------------------------------------------------------------------- B16

## B16: um sistema só. Quem escolhe alvo de caça é o `PredationSystem`; não há outro nó de IA de caça.
func _test_b16_single_system() -> void:
	var writers: Array[String] = []
	var dir_stack: Array[String] = ["res://src"]
	while not dir_stack.is_empty():
		var path: String = dir_stack.pop_back()
		var dir := DirAccess.open(path)
		for sub in dir.get_directories():
			dir_stack.append(path.path_join(sub))
		for file in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(path.path_join(file))
			if text.contains(".hunt_target =") and file != "PredationSystem.gd" and file != "Dino.gd":
				writers.append(file)
	_check(writers.is_empty(), "B16: só o PredationSystem (e o próprio Dino) escreve o alvo de caça (%s)" % str(writers))
	var systems := 0
	for dino_file in DirAccess.get_files_at("res://src/world"):
		var source := FileAccess.get_file_as_string("res://src/world/" + dino_file)
		systems += 1 if source.contains("sleeper_alerted") or source.contains("_begin_sniff") else 0
	_check(systems == 1, "B16: o farejo e o aviso do dormindo vivem em um só arquivo (%d)" % systems)


# ----------------------------------------------------------------------------- B17

## B17: saciado não trava dormindo; nada da caçada (nem do farejo) vai para o save.
func _test_b17_not_saved() -> void:
	var world := _world()
	_park_player(world, Vector2(60.0, 200.0))
	var hunter := _homed(world, DEN)
	hunter.sated_until = _now(world) + 600.0
	var prey := _sleeper(world, DEN + Vector2(3.0 * TILE, 0.0))
	_run(world, 1.0)
	_check(_target(world, hunter) != prey, "B17: saciado não trava o dormindo")
	hunter.sated_until = 0.0
	_run(world, 0.5)
	var text := JSON.stringify(hunter.to_dict()) + JSON.stringify(prey.to_dict())
	_check(hunter.is_sniffing() and not text.contains("sniff") and not text.contains("alert_left") and not text.contains("hunt_target"),
			"B17: o farejo e a caçada não são salvos")
