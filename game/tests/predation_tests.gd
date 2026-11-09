# SPDX-License-Identifier: MIT
class_name PredationTests
extends WildGroupsTests
## M1, etapa 5b: predação (`m1-ameaca-e-corpo.md` seção 10, aceite A20 a A37). Os testes usam ESPÉCIES DE TESTE feitas aqui
## (um carnívoro e herbívoros de portes diferentes): a regra nunca depende do id de uma espécie do jogo.
## Montagem: autoridade + `DinoZone` + `PredationSystem` + carcaças + chão, sem a `Main`. Os dinos não têm física: `_run`
## aplica `desired_direction` à posição, como o corpo faria.

const DT := 0.05
const TILE := 16.0
const FAR := 1.0e6
## Onde o jogador espera: a ~9 tiles da origem (ativo, pois o raio é 16), mas fora da elipse de 8 x 5 de quem está na origem.
const PARKED := Vector2(0.0, 150.0)

var _fail_events: Array[String] = []


func run() -> void:
	_stage("_test_data_and_species")
	_test_data_and_species()
	_stage("_test_a20_hunts_only_with_profile")
	_test_a20_hunts_only_with_profile()
	_stage("_test_a21_range_is_the_species_perception")
	_test_a21_range_is_the_species_perception()
	_stage("_test_a22_closest_with_hysteresis")
	_test_a22_closest_with_hysteresis()
	_stage("_test_a23_combat_ignores_the_player")
	_test_a23_combat_ignores_the_player()
	_stage("_test_a24_prey_dies_picks_another")
	_test_a24_prey_dies_picks_another()
	_stage("_test_a25_size_and_pack_bonus")
	_test_a25_size_and_pack_bonus()
	_stage("_test_a26_carnivore_vs_carnivore_and_may_strike")
	_test_a26_carnivore_vs_carnivore_and_may_strike()
	_stage("_test_a27_kill_eat_and_sated")
	_test_a27_kill_eat_and_sated()
	_stage("_test_a27_interrupted_meal")
	_test_a27_interrupted_meal()
	_stage("_test_a27_sated_final_blow")
	_test_a27_sated_final_blow()
	_stage("_test_a28_helpers_retreat_and_pack")
	_test_a28_helpers_retreat_and_pack()
	_stage("_test_a29_floor_never_below_two")
	_test_a29_floor_never_below_two()
	_stage("_test_a29_far_from_player_no_kill_and_safe_zone")
	_test_a29_far_from_player_no_kill_and_safe_zone()
	_stage("_test_a30_performance")
	_test_a30_performance()
	_stage("_test_a29_regen_and_a31_save")
	await _test_a29_regen_and_a31_save()
	_release_worlds()
	_stage("_test_a31_hunt_not_saved")
	_test_a31_hunt_not_saved()


# ----------------------------------------------------------------------------- montagem

## Com `PREDATION_TRACE=1` mostra cada teste ao começar (para achar o lento).
func _stage(name: String) -> void:
	if OS.get_environment("PREDATION_TRACE") != "":
		print("[predação] ", name, " t=", Time.get_ticks_msec())


## Espécie de teste. `kind` = tipo de atacante da doma ("carnivore" ou "herbivore").
func _species(id: String, kind: String, size: Enums.DinoSize, perception: float = 8.0) -> DinoBaseStats:
	var stats := DinoBaseStats.new()
	stats.id = id
	stats.display_name = id
	stats.attacker_kind = kind
	stats.size = size
	stats.perception_tiles = perception
	stats.carcass_meat = 4
	var threat := ThreatProfile.new()
	if kind == TamingRules.ATTACKER_CARNIVORE:
		stats.aggressive = true
		stats.base_damage = 8.0
		stats.chase_speed = 90.0
		stats.predation = PredationProfile.new()
		threat.cooldown_s = 1.5
		threat.attack_reach_px = 30.0
	else:
		stats.base_damage = 6.0
		stats.chase_speed = 80.0
		threat.cooldown_s = 1.6
		threat.windup_s = 0.5
		threat.attack_reach_px = 26.0
		threat.attacks_downed = false
	stats.threat_profile = threat
	return stats


func _carnivore_stats(perception: float = 8.0) -> DinoBaseStats:
	return _species("test_carnivore", TamingRules.ATTACKER_CARNIVORE, Enums.DinoSize.MEDIUM, perception)


func _herbivore_stats(id: String = "test_herbivore", size: Enums.DinoSize = Enums.DinoSize.MEDIUM) -> DinoBaseStats:
	return _species(id, TamingRules.ATTACKER_HERBIVORE, size)


## Mundo de teste: jogador (vida folgada), zona, caça, carcaças e chão. A região de nascimento fica longe de tudo,
## salvo `safe_area` (em pixels).
func _world(safe_area: Rect2 = Rect2(FAR, FAR, 10.0, 10.0)) -> Dictionary:
	var player := _spawn_player()
	player.set_physics_process(false)
	player.global_position = PARKED  # dentro do raio ativo, fora do alcance de qualquer caçador de teste
	player.player_id = "owner1"
	player.health.max_health = 100000.0
	player.health.current_health = 100000.0
	var authority: WorldAuthority = player.authority
	var zone := DinoZone.new()
	zone.foci = [player]
	_root.add_child(zone)
	_track.call(zone)
	zone.set_physics_process(false)
	var carcasses := CarcassField.new()
	carcasses.authority = authority
	carcasses.clock = authority.clock.now
	carcasses.set_physics_process(false)
	_root.add_child(carcasses)
	_track.call(carcasses)
	var ground := GroundItemField.new()
	ground.authority = authority
	ground.clock = authority.clock.now
	ground.set_physics_process(false)
	_root.add_child(ground)
	_track.call(ground)
	var region := RespawnRegion.new()
	region.id = "teste"
	region.area = safe_area
	var respawn := RespawnRules.new()
	respawn.regions = [region] as Array[RespawnRegion]
	var system := PredationSystem.new()
	system.respawn_rules = respawn
	system.zone = zone
	system.carcasses = carcasses
	system.ground = ground
	system.authority = authority
	system.set_physics_process(false)
	_root.add_child(system)
	_track.call(system)
	var world := {"player": player, "authority": authority, "zone": zone, "system": system, "carcasses": carcasses,
			"ground": ground, "dinos": [] as Array[Dino], "frozen": false}
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: _fail_events.append(code))
	return world


## Dino de teste no ponto `at`: sem física, no registro da autoridade e na zona; parado se `idle` (não passeia sozinho).
func _dino(world: Dictionary, stats: DinoBaseStats, at: Vector2, herd: String = "") -> Dino:
	var dino: Dino = DinoScene.instantiate()
	dino.stats = stats
	_root.add_child(dino)
	_track.call(dino)
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	dino.global_position = at
	dino.herd_id = herd
	dino.state_machine.rng.seed = 7
	dino.state_machine.idle_seconds = Vector2(FAR, FAR)  # sem passeio: o teste decide quem anda
	dino.state_machine.transition_to(Enums.DinoStateId.WANDER)  # força reentrar em IDLE já com o prazo infinito
	dino.state_machine.transition_to(Enums.DinoStateId.IDLE)
	var player: Player = world["player"]
	dino.target_locator = func() -> Array: return [player]
	var authority: WorldAuthority = world["authority"]
	authority.register(dino)
	var zone: DinoZone = world["zone"]
	zone.register(dino, false)
	var carcasses: CarcassField = world["carcasses"]
	carcasses.extra_species[stats.id] = stats
	dino.health.died.connect(func() -> void: carcasses.spawn_from(dino))
	(world["dinos"] as Array[Dino]).append(dino)
	return dino


## Bando de herbívoros em fila, a partir de `from`, de `step` em `step`.
func _herd(world: Dictionary, stats: DinoBaseStats, from: Vector2, step: Vector2, count: int, herd: String = "h1") -> Array[Dino]:
	var list: Array[Dino] = []
	for i in count:
		list.append(_dino(world, stats, from + step * float(i), herd))
	return list


## Domado do jogador `owner1`: passa pelo caminho real (nocaute e `mark_tamed`).
func _tamed(world: Dictionary, stats: DinoBaseStats, at: Vector2) -> Dino:
	var dino := _dino(world, stats, at, "")
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = (world["player"] as Player).player_id
	return dino


func _sturdy(dino: Dino) -> void:
	dino.health.max_health = 100000.0
	dino.health.current_health = 100000.0


## Passa `seconds` de jogo: relógio, zona, caça e cada dino (como os quadros fariam).
func _run(world: Dictionary, seconds: float, step: float = DT) -> void:
	var authority: WorldAuthority = world["authority"]
	var zone: DinoZone = world["zone"]
	var system: PredationSystem = world["system"]
	var dinos: Array[Dino] = []
	dinos.assign(world["dinos"])
	for _i in roundi(seconds / step):
		authority.clock.advance(step)
		authority.tick_herd(step)
		zone.reclassify()
		system.tick(step)
		for dino in dinos:
			if not is_instance_valid(dino) or dino.is_queued_for_deletion():
				continue
			dino.observe_owner()
			dino.observe_targets()
			dino.state_machine.tick(step)
			if not world["frozen"]:
				var speed := dino.move_speed * dino.state_machine.speed_multiplier * dino.state_machine.wound_multiplier()
				dino.global_position += dino.state_machine.desired_direction * speed * step


func _target(world: Dictionary, hunter: Dino) -> Node2D:
	return (world["system"] as PredationSystem).target_of(hunter)


func _now(world: Dictionary) -> float:
	return (world["authority"] as WorldAuthority).clock.now()


# ----------------------------------------------------------------------------- dados

func _test_data_and_species() -> void:
	var rules: PredationRules = load("res://data/balance/predation_rules.tres")
	_check(rules.herd_floor_alive == 2 and is_equal_approx(rules.member_regen_seconds, 600.0) \
			and is_equal_approx(rules.spawn_safe_margin_tiles, 8.0) and is_equal_approx(rules.prey_alarm_tiles, 6.0) \
			and is_equal_approx(rules.owner_shield_tiles, 4.0), "piso 2, reposição 600 s, zona segura 8, alarme 6 e escudo 4 vêm do .tres")
	var raptor: DinoBaseStats = load("res://data/dino/utahraptor.tres")
	var profile := raptor.predation
	_check(profile != null and is_equal_approx(profile.reevaluate_s, 0.5) and is_equal_approx(profile.lock_min_seconds, 2.0) \
			and is_equal_approx(profile.switch_ratio, 0.7) and is_equal_approx(profile.engage_tiles, 4.0) \
			and is_equal_approx(profile.hunt_max_seconds, 40.0) and is_equal_approx(profile.fail_cooldown_s, 60.0) \
			and is_equal_approx(profile.eat_seconds_per_meat, 2.0) and is_equal_approx(profile.sated_seconds_per_meat, 60.0) \
			and is_equal_approx(profile.retreat_health_ratio, 0.25), "o perfil da espécie caçadora vem do .tres com os números da seção 10")
	var paqui: DinoBaseStats = load("res://data/dino/placeholder_dino.tres")
	_check(paqui.predation == null, "o herbívoro não tem perfil de predação (não caça)")
	_check(is_equal_approx(profile.eat_seconds(4.0), 8.0) and is_equal_approx(profile.sated_seconds(4.0), 240.0) \
			and is_equal_approx(profile.eat_seconds(99.0), 20.0) and is_equal_approx(profile.sated_seconds(99.0), 600.0),
			"comer 2 s por carne (teto 20) e saciedade 60 s por carne (teto 600)")


# ----------------------------------------------------------------------------- A20 a A25

## A20: com perfil caça herbívoro dentro da percepção; sem perfil não caça.
func _test_a20_hunts_only_with_profile() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 300.0), 3)
	_run(world, 2.0)
	_check(_target(world, hunter) == prey[0] and hunter.hunt_target == prey[0] and hunter.state_machine.is_aggressive,
			"A20: o carnívoro com perfil trava o herbívoro dentro da percepção")
	var plain := _world()
	plain["frozen"] = true
	var stats := _carnivore_stats()
	stats.predation = null
	var idle := _dino(plain, stats, Vector2.ZERO, "c1")
	_herd(plain, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 300.0), 3)
	_run(plain, 3.0)
	_check(_target(plain, idle) == null and idle.hunt_target == null and not idle.state_machine.is_aggressive,
			"A20: a espécie sem perfil não caça, mesmo agressiva e com presa ao lado")
	var source := FileAccess.get_file_as_string("res://src/world/PredationSystem.gd") \
			+ FileAccess.get_file_as_string("res://src/world/DinoRelation.gd")
	_check(not source.contains("utahraptor") and not source.contains("placeholder_dino"), "A20: a regra não cita id de espécie")


## A21: o alcance é a percepção da espécie, em elipse; sem candidato, o natural.
func _test_a21_range_is_the_species_perception() -> void:
	var world := _world()
	var hunter := _dino(world, _carnivore_stats(6.0), Vector2.ZERO, "c1")
	var start := hunter.global_position
	var prey := _herd(world, _herbivore_stats(), Vector2(6.5 * TILE, 0.0), Vector2(0.0, 600.0), 3)
	var locked := false
	for _i in 20:
		_run(world, 3.0)  # 60 s no total
		locked = locked or _target(world, hunter) != null or hunter.state_machine.is_aggressive
	_check(not locked and hunter.global_position.distance_to(start) < 1.0 and prey[0].global_position.x > 6.0 * TILE,
			"A21: presa a 6,5 tiles (percepção 6) nunca é travada e o carnívoro não anda até ela em 60 s")
	var ellipse := _world()
	ellipse["frozen"] = true
	var seer := _dino(ellipse, _carnivore_stats(6.0), Vector2.ZERO, "c1")
	var out := _herd(ellipse, _herbivore_stats(), Vector2(0.0, 4.0 * TILE), Vector2(600.0, 0.0), 3)
	_run(ellipse, 2.0)
	_check(_target(ellipse, seer) == null, "A21: dy de 4 tiles (efetivo 6,4) fica fora da elipse de 6")
	out[0].global_position = Vector2(5.9 * TILE, 0.0)
	_run(ellipse, 1.0)
	_check(_target(ellipse, seer) == out[0], "A21: dx de 5,9 tiles fica dentro")
	out[0].global_position = Vector2(FAR, FAR)
	_run(ellipse, 1.0)
	_check(_target(ellipse, seer) == null, "A21: sem candidato, volta ao natural (sem alvo)")


## A22: o mais próximo, histerese de 30% e trava de 2 s; oscilar 5% não troca.
func _test_a22_closest_with_hysteresis() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var a := _herd(world, _herbivore_stats(), Vector2(120.0, 0.0), Vector2(0.0, 900.0), 3, "ha")
	var b := _herd(world, _herbivore_stats(), Vector2(0.0, 900.0), Vector2(0.0, 900.0), 3, "hb")
	var player: Player = world["player"]
	_run(world, 1.0)
	_check(_target(world, hunter) == a[0], "A22: trava a presa dentro do alcance")
	b[0].global_position = Vector2(96.0, 0.0)  # 0,8x da distância da atual
	_run(world, 4.0)
	_check(_target(world, hunter) == a[0], "A22: presa a 0,8x da distância da atual não troca")
	var fresh := _world()
	fresh["frozen"] = true
	var young := _dino(fresh, _carnivore_stats(), Vector2.ZERO, "c1")
	var first := _herd(fresh, _herbivore_stats(), Vector2(120.0, 0.0), Vector2(0.0, 900.0), 3, "ha")
	var other := _herd(fresh, _herbivore_stats(), Vector2(0.0, 900.0), Vector2(0.0, 900.0), 3, "hb")
	_run(fresh, 0.6)
	_check(_target(fresh, young) == first[0], "A22: (trava recente) travou a primeira presa")
	other[0].global_position = Vector2(78.0, 0.0)  # 0,65x da distância da atual
	_run(fresh, 0.6)
	_check(_target(fresh, young) == first[0], "A22: a 0,65x não troca logo (a trava de 2 s vale)")
	_run(fresh, 4.0)
	_check(_target(fresh, young) == other[0], "A22: a 0,65x troca depois de 2 s")
	var calm := _world()
	calm["frozen"] = true
	var seeker := _dino(calm, _carnivore_stats(), Vector2.ZERO, "c1")
	var left := _herd(calm, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 900.0), 3, "ha")
	var right := _herd(calm, _herbivore_stats(), Vector2(-100.0, 0.0), Vector2(0.0, 900.0), 3, "hb")
	var changes := 0
	var last: Node2D = null
	for second in 60:
		left[0].global_position = Vector2(100.0 + (5.0 if second % 2 == 0 else -5.0), 0.0)
		right[0].global_position = Vector2(-100.0 - (5.0 if second % 2 == 0 else -5.0), 0.0)
		_run(calm, 1.0)
		var now_target := _target(calm, seeker)
		if last != null and now_target != last:
			changes += 1
		last = now_target
	_check(changes <= 1, "A22: dois alvos oscilando 5%% por 60 s: %d troca(s)" % changes)


## A23: em combate o jogador não é candidato; dano do jogador troca; quem mordeu o jogador não troca para presa.
func _test_a23_combat_ignores_the_player() -> void:
	var world := _world()
	world["frozen"] = true
	var player: Player = world["player"]
	var hunter := _dino(world, _carnivore_stats(), Vector2(60.0, 0.0), "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(84.0, 0.0), Vector2(0.0, 900.0), 3)
	for dino in prey:
		_sturdy(dino)
	player.global_position = Vector2(60.0, 16.0)  # a 1 tile do carnívoro
	var life := player.health.current_health
	_run(world, 20.0)
	_check(player.health.current_health == life and _target(world, hunter) == prey[0] \
			and prey[0].health.current_health < prey[0].health.max_health,
			"A23: em combate com a presa, 20 s com o jogador a 1 tile: nenhuma mordida nele, alvo igual, a presa mordida")
	var state_before := hunter.state_machine.current_id
	var hit := hunter.receive_hit(1.0, 0.0, TamingRules.ATTACKER_PLAYER, player.player_id)
	_run(world, 0.6)
	_check(_target(world, hunter) == null and hunter.hunt_target == null and hunter._target_body == player,
			"A23: dano do jogador no carnívoro troca para ele em até 0,5 s (estado %d, antes %d, acertou %s)" \
			% [hunter.state_machine.current_id, state_before, hit])
	var chase := _world()
	chase["frozen"] = true
	var seeker := _dino(chase, _carnivore_stats(), Vector2.ZERO, "c1")
	var far_prey := _herd(chase, _herbivore_stats(), Vector2(112.0, 0.0), Vector2(0.0, 900.0), 3)
	var watcher: Player = chase["player"]
	_run(chase, 1.0)
	_check(_target(chase, seeker) == far_prey[0], "A23: perseguindo (longe de `engage`), trava a presa")
	watcher.global_position = Vector2(70.0, 0.0)  # 0,625x da distância da presa (112 px) e fora do escudo da presa
	_run(chase, 3.0)
	_check(_target(chase, seeker) == watcher, "A23: perseguição a mais de engage_tiles: o jogador 30%% mais perto toma o alvo")
	var biter := _world()
	biter["frozen"] = true
	var raptor := _dino(biter, _carnivore_stats(), Vector2.ZERO, "c1")
	var meal := _herd(biter, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 900.0), 3)
	var victim: Player = biter["player"]
	victim.global_position = Vector2(0.0, 90.0)
	raptor.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	raptor.bit_player_episode = raptor.state_machine.episode_id
	_run(biter, 3.0)
	_check(_target(biter, raptor) != meal[0], "A23: quem já mordeu o jogador neste episódio não troca para presa")


## A24: a presa some, escolhe outra em até 0,5 s; ou o jogador; ou o natural.
func _test_a24_prey_dies_picks_another() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 40.0), 4)
	_run(world, 1.0)
	var first := _target(world, hunter)
	_check(first == prey[0], "A24: trava a mais próxima")
	prey[0].health.take_damage(prey[0].health.max_health * 2.0)
	_run(world, 0.5)
	_check(_target(world, hunter) == prey[1], "A24: a presa morreu: em até 0,5 s escolhe outra dentro do alcance")
	for dino in prey:
		if dino.health.current_health > 0.0:
			dino.global_position = Vector2(FAR, FAR)
	_run(world, 2.0)
	_check(_target(world, hunter) == null, "A24: presa fora do alcance nunca é perseguida; sem candidato, o natural")


## A25: porte.
func _test_a25_size_and_pack_bonus() -> void:
	var hunter_stats := _carnivore_stats()
	var small := _herbivore_stats("test_herbivore_small", Enums.DinoSize.SMALL)
	var medium := _herbivore_stats("test_herbivore", Enums.DinoSize.MEDIUM)
	var large := _herbivore_stats("test_herbivore_large", Enums.DinoSize.LARGE)
	_check(DinoRelation.is_prey_species(hunter_stats, small) and DinoRelation.is_prey_species(hunter_stats, medium)
			and not DinoRelation.is_prey_species(hunter_stats, large), "A25: Médio caça Pequeno e Médio e não Grande")
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, hunter_stats, Vector2.ZERO, "c1")
	var giants := _herd(world, large, Vector2(100.0, 0.0), Vector2(0.0, 900.0), 3)
	_run(world, 2.0)
	_check(_target(world, hunter) == null, "A25: o Grande não é presa (bônus de bando desligado por padrão)")
	var pack_stats := _carnivore_stats()
	pack_stats.predation.pack_size_bonus_min_members = 2
	var pack := _world()
	pack["frozen"] = true
	var lead := _dino(pack, pack_stats, Vector2.ZERO, "c1")
	var tail := _dino(pack, pack_stats, Vector2(0.0, 40.0), "c1")
	var giant := _herd(pack, large, Vector2(100.0, 0.0), Vector2(0.0, 900.0), 3)
	_run(pack, 2.0)
	_check(_target(pack, lead) == giant[0] and _target(pack, tail) != null,
			"A25: com o bônus ligado e 2 acordados do bando a 8 tiles, caça Grande")
	tail.global_position = Vector2(0.0, 60.0 * TILE)  # o parceiro se afasta: sem 2 acordados juntos o Grande some do alvo
	_run(pack, 6.0)
	_check(giants.size() == 3 and _target(pack, lead) != giant[0], "A25: sem 2 acordados do bando juntos o Grande deixa de ser presa")


# ----------------------------------------------------------------------------- A26

## A26: carnívoro não fere carnívoro; `may_strike`; o ajudante só fere o carnívoro que feriu o bando.
func _test_a26_carnivore_vs_carnivore_and_may_strike() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var first := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var other_stats := _species("test_carnivore_b", TamingRules.ATTACKER_CARNIVORE, Enums.DinoSize.MEDIUM)
	var second := _dino(world, other_stats, Vector2(TILE, 0.0), "c2")
	var life_a := first.health.current_health
	var life_b := second.health.current_health
	_run(world, 60.0, 0.1)
	_check(first.health.current_health == life_a and second.health.current_health == life_b \
			and _target(world, first) == null and _target(world, second) == null, "A26: 2 carnívoros a 1 tile por 60 s: zero dano e zero trava")
	_check(not authority.may_strike(first, second) and not authority.may_strike(second, first), "A26: carnívoro contra carnívoro: recusa")
	var herb := _herbivore_stats()
	var mate_a := _dino(world, herb, Vector2(0.0, 300.0), "hx")
	var mate_b := _dino(world, herb, Vector2(0.0, 340.0), "hx")
	var other_herb := _dino(world, _herbivore_stats("test_herbivore_other"), Vector2(0.0, 380.0), "hy")
	_check(not authority.may_strike(mate_a, mate_b) and not authority.may_strike(mate_a, other_herb),
			"A26: herbívoro contra herbívoro: recusa")
	_check(authority.may_strike(first, mate_a) and authority.may_strike(mate_a, first), "A26: carnívoro e herbívoro: nos dois sentidos")
	var same_herd := _dino(world, _carnivore_stats(), Vector2(0.0, 500.0), "hx")
	_check(not authority.may_strike(same_herd, mate_a), "A26: mesmo bando (herd_id): recusa")
	var twin := _dino(world, _carnivore_stats(), Vector2(0.0, 540.0), "c9")
	_check(not authority.may_strike(first, twin), "A26: mesma espécie: recusa")
	# ajudante: só o carnívoro que feriu o bando
	var arena := _world()
	arena["frozen"] = true
	var attacker := _dino(arena, _carnivore_stats(), Vector2(-40.0, 0.0), "c1")
	var band := _herd(arena, herb, Vector2.ZERO, Vector2(24.0, 0.0), 4)
	var bystander := _dino(arena, herb, Vector2(24.0, 40.0), "hz")
	var player: Player = arena["player"]
	player.global_position = Vector2(24.0, 12.0)
	var arena_authority: WorldAuthority = arena["authority"]
	arena_authority.resolve_dino_attack(arena_authority.id_of(attacker), arena_authority.id_of(band[0]), 8.0)
	_run(arena, 0.6)
	var helpers: Array[Dino] = []
	for member in band:
		if member.state_machine.is_helper:
			helpers.append(member)
	var ok := helpers.size() == 2
	for helper in helpers:
		ok = ok and helper._target_body == attacker
	_check(ok, "A26/A28: o golpe no bando chama 2 ajudantes em 0,5 s, com alvo no carnívoro")
	var life := player.health.current_health
	var bystander_life := bystander.health.current_health
	_run(arena, 8.0)
	_check(player.health.current_health == life and bystander.health.current_health == bystander_life,
			"A26: o ajudante só tem o carnívoro como alvo (nem o jogador a 1 tile, nem outro herbívoro)")


# ----------------------------------------------------------------------------- A27

## Mundo com 1 caçador e um bando de 4 presas, onde a primeira presa está à beira da morte (1 mordida).
func _meal_world() -> Dictionary:
	var world := _world()
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 900.0), 4)
	prey[0].health.current_health = 1.0
	for dino in prey:
		dino.state_machine.holding = true  # a presa não corre: o teste é da refeição, não da perseguição
	world["hunter"] = hunter
	world["prey"] = prey
	return world


func _until_eating(world: Dictionary) -> bool:
	var system: PredationSystem = world["system"]
	for _i in 400:
		_run(world, 0.1)
		if system.is_eating(world["hunter"]):
			return true
	return false


## A27: a carcaça nasce, encolhe em linha reta e some ao fim; saciedade 60 s por carne; saciado trava o jogador, não a presa.
func _test_a27_kill_eat_and_sated() -> void:
	var world := _meal_world()
	var hunter: Dino = world["hunter"]
	var carcasses: CarcassField = world["carcasses"]
	var system: PredationSystem = world["system"]
	_check(_until_eating(world) and carcasses.count() == 1, "A27: o carnívoro mata e a carcaça nasce para ele comer")
	var node := carcasses.nodes()[0]
	var meat := carcasses.meat_of(node)
	var total := 2.0 * float(meat)
	var started := _now(world)
	_run(world, total * 0.5, 0.1)
	_check(carcasses.count() == 1 and absf(float(carcasses.meat_of(node)) - float(meat) * 0.5) <= 1.0,
			"A27: a carne encolhe em linha reta: no meio da refeição sobra metade (%d de %d)" % [carcasses.meat_of(node), meat])
	_run(world, total * 0.5 + 0.5, 0.1)
	_check(carcasses.count() == 0 and not system.is_eating(hunter), "A27: a carcaça some ao fim de 2 s x carne (%d s)" % int(total))
	var sated := hunter.sated_until - started
	_check(absf(sated - minf(60.0 * float(meat), 600.0) - total) < 2.0,
			"A27: saciedade de 60 s por carne comida (%.0f s)" % (hunter.sated_until - _now(world)))
	(world["prey"] as Array[Dino])[1].global_position = Vector2(70.0, 0.0)
	_run(world, 3.0)
	_check(_target(world, hunter) == null, "A27: saciado não trava presa")
	var player: Player = world["player"]
	player.global_position = Vector2(30.0, 50.0)
	_run(world, 2.0)
	_check(hunter.state_machine.is_aggressive and hunter._target_body == player, "A27: saciado ainda trava o jogador")
	player.global_position = PARKED
	hunter.global_position = Vector2.ZERO  # o bravo tinha ido até o jogador: volta ao ponto de partida, calmo
	hunter.state_machine.transition_to(Enums.DinoStateId.IDLE)
	(world["authority"] as WorldAuthority).clock.advance(700.0)
	_run(world, 3.0)
	_check(_target(world, hunter) != null, "A27: passado o prazo, volta a caçar")
	_check(carcasses.count() <= carcasses.rules.max_carcasses, "A27: a caça nunca passa o teto de carcaças")


## A27: o jogador entra no meio da refeição: o `EAT` para, a sobra fica e a saciedade é proporcional.
func _test_a27_interrupted_meal() -> void:
	var world := _meal_world()
	var hunter: Dino = world["hunter"]
	var carcasses: CarcassField = world["carcasses"]
	_until_eating(world)
	var node := carcasses.nodes()[0]
	var meat := carcasses.meat_of(node)
	var total := 2.0 * float(meat)
	_run(world, total * 0.5, 0.1)
	(world["player"] as Player).global_position = Vector2(30.0, 40.0)
	_run(world, 0.3, 0.1)
	var system: PredationSystem = world["system"]
	var left := carcasses.meat_of(node)
	_check(not system.is_eating(hunter) and carcasses.count() == 1 and left > 0 and left < meat,
			"A27: o jogador na elipse interrompe a refeição e a sobra fica no chão (%d de %d)" % [left, meat])
	var sated := hunter.sated_until - _now(world)
	_check(sated > 0.0 and sated < 60.0 * float(meat), "A27: saciedade proporcional ao que comeu (%.0f s de %d)" % [sated, 60 * meat])
	_check(carcasses.count() >= 1, "A27: a carcaça interrompida segue no mundo")


## A27: o golpe final de um saciado deixa a carcaça inteira.
func _test_a27_sated_final_blow() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(20.0, 0.0), Vector2(0.0, 900.0), 4)
	hunter.sated_until = _now(world) + 100.0
	prey[0].health.current_health = 1.0
	_run(world, 0.2)
	var authority: WorldAuthority = world["authority"]
	authority.resolve_dino_attack(authority.id_of(hunter), authority.id_of(prey[0]), 8.0)
	_run(world, 30.0)
	var carcasses: CarcassField = world["carcasses"]
	_check(prey[0].health.is_dead() and carcasses.count() == 1 and not (world["system"] as PredationSystem).is_eating(hunter),
			"A27: golpe final de um saciado: a carcaça fica no mundo e ninguém a come em 30 s")
	_check(carcasses.meat_of(carcasses.nodes()[0]) == int(carcasses.nodes()[0].def.yield_amount), "A27: e com toda a carne")


# ----------------------------------------------------------------------------- A28

## A28: recuo a 25% e 60 s sem travar o mesmo bando; bando de 3 contra 1 carnívoro não termina em abate.
func _test_a28_helpers_retreat_and_pack() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2(60.0, 0.0), "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 900.0), 3)
	_run(world, 1.0)
	_check(_target(world, hunter) == prey[0], "A28: o carnívoro trava a presa")
	hunter.health.current_health = hunter.health.max_health * 0.2
	_run(world, 0.6)
	_check(_target(world, hunter) == null, "A28: abaixo de 25%% de vida o carnívoro recua da caçada")
	_run(world, 30.0)
	_check(_target(world, hunter) == null, "A28: e não trava o mesmo bando por 60 s")
	(world["authority"] as WorldAuthority).clock.advance(40.0)
	hunter.health.current_health = hunter.health.max_health
	_run(world, 2.0)
	_check(_target(world, hunter) != null, "A28: passado o prazo (60 s), volta a travar")
	var duel := _world()
	var raptor := _dino(duel, _carnivore_stats(), Vector2.ZERO, "c1")
	raptor.level = 20
	raptor.health.current_health = raptor.health.max_health
	var herd := _herd(duel, _herbivore_stats(), Vector2(70.0, 0.0), Vector2(0.0, 30.0), 3)
	_run(duel, 120.0)
	var dead := 0
	for member in herd:
		if member.health.is_dead():
			dead += 1
	_check(dead == 0, "A28: bando de 3 contra 1 carnívoro nível 20 não termina em abate (%d morto)" % dead)


# ----------------------------------------------------------------------------- A29

## A29: 2 h de relógio, bando de 4 exposto a 3 carnívoros, jogador perto: o bando nunca fica com menos de 2 vivos.
func _test_a29_floor_never_below_two() -> void:
	var world := _world()
	var hunters: Array[Dino] = []
	for i in 3:
		hunters.append(_dino(world, _carnivore_stats(), Vector2(-60.0 - 20.0 * float(i), 40.0 * float(i)), "c%d" % i))
	var prey := _herd(world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 30.0), 4)
	for member in prey:
		member.state_machine.holding = true  # parada, a presa não escapa: o piso é a única coisa que a salva
	var player: Player = world["player"]
	player.global_position = Vector2(0.0, 150.0)  # perto (raio ativo), mas fora do alcance dos caçadores
	var lowest := 4
	for _minute in 120:
		for dino in hunters:
			if is_instance_valid(dino):
				dino.health.current_health = dino.health.max_health  # carnívoros sempre com vida: quem limita é o piso
		_run(world, 60.0, 0.25)
		var alive := 0
		for member in prey:
			if is_instance_valid(member) and not member.health.is_dead():
				alive += 1
		lowest = mini(lowest, alive)
	_check(lowest >= 2, "A29: 2 h de caça: o bando de 4 nunca fica com menos de 2 vivos (mínimo %d)" % lowest)
	_check(lowest == 2, "A29: e o piso foi mesmo atingido (a caça funciona; mínimo %d)" % lowest)


## A29: longe do jogador (fora do raio ativo) ninguém caça; presa na zona segura nunca morre.
func _test_a29_far_from_player_no_kill_and_safe_zone() -> void:
	var world := _world()
	var hunter := _dino(world, _carnivore_stats(), Vector2(40.0 * TILE, 0.0), "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(40.0 * TILE + 60.0, 0.0), Vector2(0.0, 30.0), 4)
	_run(world, 120.0, 0.25)
	var dead := 0
	for member in prey:
		if member.health.is_dead():
			dead += 1
	_check(dead == 0 and _target(world, hunter) == null and hunter.hunt_target == null,
			"A29: jogador a mais de 16 tiles (fora do raio ativo): zero abates, zero caçada")
	var safe := _world(Rect2(-400.0, -400.0, 800.0, 800.0))
	var predator := _dino(safe, _carnivore_stats(), Vector2(-60.0, 0.0), "c1")
	var meals := _herd(safe, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 30.0), 4)
	_run(safe, 120.0, 0.25)
	var casualties := 0
	for member in meals:
		if member.health.is_dead():
			casualties += 1
	_check(casualties == 0 and _target(safe, predator) == null, "A29: presa dentro da zona segura do nascimento nunca é caçada nem morta")


# ----------------------------------------------------------------------------- A30

## A30: com 360 dinos e 32 ativos, os testes de distância ficam em P x A + P e o tick de predação é barato.
func _test_a30_performance() -> void:
	var world := _world()
	world["frozen"] = true
	var herb := _herbivore_stats()
	var carn := _carnivore_stats()
	var hunters: Array[Dino] = []
	for i in 6:
		hunters.append(_dino(world, carn, Vector2(float(i) * 30.0, -100.0), "c%d" % i))
	for i in 26:
		_dino(world, herb, Vector2(float(i % 13) * 14.0 - 90.0, 20.0 + float(i / 13) * 40.0), "p%d" % (i / 4))
	for i in 328:
		_dino(world, herb, Vector2(5000.0 + float(i) * 40.0, 5000.0), "far%d" % (i / 4))
	(world["player"] as Player).global_position = Vector2(60.0, 60.0)
	var zone: DinoZone = world["zone"]
	zone.reclassify()
	var system: PredationSystem = world["system"]
	_run(world, 1.0)
	var active := zone.active_count
	_check(zone.dino_count() == 360 and active <= 32, "A30: 360 dinos no mundo e %d ativos (teto 32)" % active)
	system.refresh_active()
	var before := system.distance_tests
	for hunter in hunters:
		system._hunts[hunter].eval_left = 0.0
	system.tick(0.0001)
	var spent := system.distance_tests - before
	var limit := hunters.size() * active + hunters.size()
	_check(spent <= limit, "A30: uma reavaliação de %d caçadores faz %d testes de distância (<= P x A + P = %d)"
			% [hunters.size(), spent, limit])
	var per_tick := INF
	for _batch in 5:  # o melhor de 5 lotes: o ruído da máquina não reprova
		var started := Time.get_ticks_usec()
		for _i in 200:
			system.tick(0.05)
		per_tick = minf(per_tick, float(Time.get_ticks_usec() - started) / 200.0)
	_check(per_tick < 300.0, "A30: o tick de predação custa %.0f us (< 300 us, headless)" % per_tick)
	var batches: Array[float] = []  # o pior quadro de cada lote; vale o menor (um pico de relógio ou de GC não reprova)
	for _batch in 5:
		var worst := 0.0  # com a reclassificação da zona e o `refresh_active` incluídos
		for _i in 200:
			var frame := Time.get_ticks_usec()
			zone.reclassify()
			system.refresh_active()
			system.tick(0.05)
			worst = maxf(worst, float(Time.get_ticks_usec() - frame))
		batches.append(worst)
	var best: float = batches.min()
	var shown := ", ".join(batches.map(func(v: float) -> String: return "%.0f" % v))
	print("      A30: pior quadro por lote (reclassify + refresh_active + tick): %s us" % shown)
	_check(best < 8000.0, "A30: o pior quadro custa %.0f us (menor de 5 lotes; < 8 ms, metade do quadro de 60 Hz, headless)" % best)
	var gap := 0
	for hunter in hunters:
		var hunt: Variant = system._hunts[hunter]
		gap += 1 if hunt.eval_left > 0.0 else 0
	_check(gap == hunters.size(), "A30: depois de reavaliar, cada caçador espera 0,5 s (a fase por id escalona)")


# ----------------------------------------------------------------------------- A31

## A31: salvar no meio da caçada: a caçada não vai e a saciedade volta igual.
func _test_a31_hunt_not_saved() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 900.0), 3)
	_run(world, 2.0)
	hunter.sated_until = 321.5
	_check(hunter.is_hunting_prey() and prey[0] != null, "A31: o carnívoro está caçando")
	var saved := JSON.parse_string(JSON.stringify(hunter.to_dict())) as Dictionary
	var restored := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	_check(restored.from_dict(saved) and restored.hunt_target == null and not restored.state_machine.is_aggressive \
			and is_equal_approx(restored.sated_until, 321.5), "A31: carrega sem erro, sem caçada e com a mesma saciedade")
	var old := saved.duplicate()
	old.erase("sated_until")
	var older := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	_check(older.from_dict(old) and older.sated_until == 0.0, "A31: save antigo (sem `sated_until`) carrega sem saciedade")


## A29 (reposição) e A31 (save): 1 membro a cada 600 s só com o jogador a mais de 40 tiles; `regen_due_at` volta igual.
func _test_a29_regen_and_a31_save() -> void:
	var tree := _root.get_tree()
	var main := _main("predation_regen", 20, true)
	main.predation.set_physics_process(false)
	await tree.physics_frame
	var slot_id := _distant_slot(main)
	var members: Array = main.wild.slot_info(slot_id)["members"]
	var herd_size := members.size()
	var spawned: Array = []
	main.wild.group_spawned.connect(func(creatures: Array[Dino]) -> void: spawned.append_array(creatures))
	var killed: Array[Dino] = []
	for index in 2:
		var creature := main.wild.creature_at(members[index])
		creature.health.take_damage(creature.health.max_health * 2.0)
		killed.append(creature)
	var start := main.authority.clock.now()
	main.wild.tick(start)
	var info := main.wild.slot_info(slot_id)
	_check(not info["waiting"] and spawned.is_empty(), "A29: com membros vivos o bando não espera o respawn inteiro")
	main.authority.clock.advance(599.0)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.is_empty(), "A29: antes de 600 s nada é reposto")
	main.authority.clock.advance(1.5)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.size() == 1, "A29: 600 s depois volta 1 membro (%d)" % spawned.size())
	main.authority.clock.advance(601.0)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.size() == 2, "A29: e mais 600 s depois, o segundo (%d)" % spawned.size())
	main.authority.clock.advance(1200.0)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.size() == 2 and _alive_count(main, slot_id) == herd_size, "A29: bando completo: nada mais é reposto")
	# o jogador perto (40 tiles) segura a reposição
	var near := main.wild.creature_at(members[0])
	near.health.take_damage(near.health.max_health * 2.0)
	main.wild.tick(main.authority.clock.now())
	main.authority.clock.advance(700.0)
	var cell: Vector2i = main.wild.slot_info(slot_id)["center"]
	main.player.global_position = main.map.center_of(cell)
	main.wild.tick(main.authority.clock.now())
	_check(spawned.size() == 2, "A29: com o jogador a menos de 40 tiles a reposição espera")
	main.player.global_position = Vector2.ZERO
	main.wild.tick(main.authority.clock.now())
	_check(spawned.size() == 3, "A29: o jogador se afasta e o membro volta")
	# save: `regen_due_at` e o que já estava morto
	var other := main.wild.creature_at(members[1])
	other.health.take_damage(other.health.max_health * 2.0)
	main.wild.tick(main.authority.clock.now())
	var due := -1.0
	for entry: Dictionary in main.wild.groups_to_list():
		if entry["slot"] == slot_id:
			due = float(entry.get("regen_due_at", -1.0))
	_check(due > main.authority.clock.now(), "A31: o save leva `regen_due_at` da vaga")
	var groups := JSON.parse_string(JSON.stringify(main.wild.groups_to_list())) as Array
	var list := JSON.parse_string(JSON.stringify(main.wild.to_list())) as Array
	_check(main.wild.restore(list, [], groups, main.wild.world_seed, main.authority.clock.now()), "A31: o save com `regen_due_at` carrega")
	var back := -1.0
	for entry: Dictionary in main.wild.groups_to_list():
		if entry["slot"] == slot_id:
			back = float(entry.get("regen_due_at", -1.0))
	_check(is_equal_approx(back, due), "A31: `regen_due_at` volta igual (%.1f)" % back)
	var legacy: Array = []
	for entry: Dictionary in groups:
		var copy := entry.duplicate()
		copy.erase("regen_due_at")
		legacy.append(copy)
	_check(main.wild.restore(list, [], legacy, main.wild.world_seed, main.authority.clock.now()),
			"A31: save antigo (sem `regen_due_at`) carrega")
	_check(killed.size() == 2, "A31: (controle)")


func _alive_count(main: Main, slot_id: String) -> int:
	var count := 0
	for member_id: String in main.wild.slot_info(slot_id)["members"]:
		var creature := main.wild.creature_at(member_id)
		if creature != null and not creature.health.is_dead():
			count += 1
	return count
