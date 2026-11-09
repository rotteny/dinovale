# SPDX-License-Identifier: MIT
class_name PredationTamedTests
extends PredationTests
## M1, etapa 5b (segunda parte): o domado do jogador como presa (aceite A32 a A36). Usa a montagem de `PredationTests`.


func run() -> void:
	_test_a32_tamed_is_prey()
	_test_a33_tamed_reaction()
	_test_a34_owner_log()
	_test_a35_tamed_death_drops_bag()
	_test_a36_bait_and_shield()
	_release_worlds()

## A32: o domado do jogador é presa se o porte vale; domado carnívoro e porte inválido, não; longe do jogador, nunca.
func _test_a32_tamed_is_prey() -> void:
	var world := _world()
	world["frozen"] = true
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var tamed := _tamed(world, _herbivore_stats("test_herbivore_tamed"), Vector2(100.0, 0.0))
	_run(world, 2.0)
	_check(_target(world, hunter) == tamed, "A32: domado acordado de porte válido dentro da elipse é travado")
	var sleeping := _world()
	sleeping["frozen"] = true
	var killer := _dino(sleeping, _carnivore_stats(), Vector2.ZERO, "c1")
	var asleep := _tamed(sleeping, _herbivore_stats("test_herbivore_tamed"), Vector2(100.0, 0.0))
	asleep.torpor.add_torpor(asleep.torpor.max_torpor)
	_run(sleeping, 2.0)
	_check(asleep.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and _target(sleeping, killer) == asleep,
			"A32: domado dormindo é elegível")
	var rival := _world()
	rival["frozen"] = true
	var lone := _dino(rival, _carnivore_stats(), Vector2.ZERO, "c1")
	var kind_b := _species("test_carnivore_b", TamingRules.ATTACKER_CARNIVORE, Enums.DinoSize.MEDIUM)
	var pet_carnivore := _tamed(rival, kind_b, Vector2(100.0, 0.0))
	_run(rival, 2.0)
	_check(_target(rival, lone) == null and pet_carnivore != null, "A32: domado carnívoro nunca é presa")
	var big := _world()
	big["frozen"] = true
	var hungry := _dino(big, _carnivore_stats(), Vector2.ZERO, "c1")
	_tamed(big, _herbivore_stats("test_herbivore_large", Enums.DinoSize.LARGE), Vector2(100.0, 0.0))
	_run(big, 2.0)
	_check(_target(big, hungry) == null, "A32: porte inválido (Grande) não é presa")
	var away := _world()
	away["frozen"] = true
	var far_hunter := _dino(away, _carnivore_stats(), Vector2(50.0 * TILE, 0.0), "c1")
	var far_pet := _tamed(away, _herbivore_stats("test_herbivore_tamed"), Vector2(50.0 * TILE + 80.0, 0.0))
	_run(away, 3.0)
	_check(_target(away, far_hunter) == null and far_pet.health.current_health == far_pet.health.max_health,
			"A32: domado longe do jogador (caçador fora do raio ativo) nunca é caçado")
	var wild := _world()
	wild["frozen"] = true
	var wild_hunter := _dino(wild, _carnivore_stats(), Vector2.ZERO, "c1")
	var asleep_wild := _herd(wild, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 900.0), 4)
	asleep_wild[0].torpor.add_torpor(asleep_wild[0].torpor.max_torpor)
	_run(wild, 2.0)
	_check(_target(wild, wild_hunter) != asleep_wild[0],
			"A32: selvagem em doma NÃO é presa de espécie que não escuta o ronco (sem hears_sleepers)")
	var listening := _world()
	listening["frozen"] = true
	var listener_stats := _carnivore_stats()
	listener_stats.predation.hears_sleepers = true
	var listener := _dino(listening, listener_stats, Vector2.ZERO, "c1")
	var asleep_heard := _herd(listening, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 900.0), 4)
	asleep_heard[0].torpor.add_torpor(asleep_heard[0].torpor.max_torpor)
	_run(listening, 2.0)
	_check(_target(listening, listener) == asleep_heard[0],
			"A32 (D-E4, reverte o D15): selvagem em doma é presa de espécie com hears_sleepers, dentro do ronco")
	var floor_world := _world()
	floor_world["frozen"] = true
	var floor_hunter := _dino(floor_world, _carnivore_stats(), Vector2.ZERO, "c1")
	var pair := _herd(floor_world, _herbivore_stats(), Vector2(100.0, 0.0), Vector2(0.0, 40.0), 2)
	_run(floor_world, 2.0)
	_check(_target(floor_world, floor_hunter) == null and pair.size() == 2, "A32: bando de 2 (no piso) não é presa")
	var pet := _tamed(floor_world, _herbivore_stats("test_herbivore_tamed"), Vector2(100.0, 20.0))
	_run(floor_world, 2.0)
	_check(_target(floor_world, floor_hunter) == pet, "A32: o piso do bando não protege o domado")


## A33: o domado foge a 80 para longe do carnívoro (não em direção ao dono), não revida, não chama bando; a ordem sobrevive.
func _test_a33_tamed_reaction() -> void:
	var world := _world()
	var player: Player = world["player"]
	player.global_position = Vector2(0.0, -10.0 * TILE)  # o dono ao norte
	var stats := _herbivore_stats("test_herbivore_tamed")
	var hunter := _dino(world, _carnivore_stats(), Vector2(-5.0 * TILE, 0.0), "c1")
	var pet := _tamed(world, stats, Vector2.ZERO)
	pet.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	_sturdy(pet)
	var friends := _herd(world, _herbivore_stats(), Vector2(0.0, 60.0), Vector2(30.0, 0.0), 3, "hq")
	var attacks := 0
	pet.attack_requested.connect(func(_t: Node2D, _d: float, _e: int) -> void: attacks += 1)
	_run(world, 1.0)
	var speed := pet.move_speed * pet.state_machine.speed_multiplier
	_check(pet.state_machine.current_id == Enums.DinoStateId.FLEEING and absf(speed - 80.0) < 1.0,
			"A33: o domado travado e com o carnívoro a menos de 6 tiles foge a 80 (%.0f)" % speed)
	var before := pet.global_position
	_run(world, 1.0)
	var moved := pet.global_position - before
	_check(moved.x > 20.0 and absf(moved.y) < moved.x, "A33: foge para longe do carnívoro, não para o dono (%s)" % moved)
	var authority: WorldAuthority = world["authority"]
	_check(attacks == 0 and authority.herd.pending_count() == 0, "A33: o domado não revida e não chama o bando")
	var calm := true
	for friend in friends:
		calm = calm and not friend.state_machine.is_aggressive
	_check(calm, "A33: ninguém do bando de fora entra na briga")
	hunter.health.take_damage(hunter.health.max_health * 2.0)
	_run(world, 2.0)
	_check(pet.state_machine.current_id == Enums.DinoStateId.TAMED and pet.state_machine.order == Enums.DinoOrder.FOLLOW,
			"A33: acabada a caçada, a ordem (Seguir) sobrevive")
	var sleeper_world := _world()
	var killer := _dino(sleeper_world, _carnivore_stats(), Vector2(-5.0 * TILE, 0.0), "c1")
	var sleeper := _tamed(sleeper_world, stats, Vector2.ZERO)
	_sturdy(sleeper)
	sleeper.torpor.add_torpor(sleeper.torpor.max_torpor)
	_run(sleeper_world, 2.0)
	_check(sleeper.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and _target(sleeper_world, killer) == sleeper,
			"A33: dormindo não foge (e segue elegível)")


## A34: `tamed_attacked` uma vez por episódio (rearma 30 s depois); `tamed_killed` na morte; só ao dono.
func _test_a34_owner_log() -> void:
	var world := _world()
	world["frozen"] = true
	var authority: WorldAuthority = world["authority"]
	var events: Array[Dictionary] = []
	authority.owner_event.connect(func(owner_id: String, code: String, params: Dictionary) -> void:
		events.append({"owner": owner_id, "code": code, "params": params}))
	_fail_events.clear()
	var hunter := _dino(world, _carnivore_stats(), Vector2(-60.0, 0.0), "c1")
	var pet := _tamed(world, _herbivore_stats("test_herbivore_tamed"), Vector2.ZERO)
	_sturdy(pet)
	_run(world, 5.0)
	var warned := events.filter(func(e: Dictionary) -> bool: return e["code"] == "tamed_attacked")
	_check(warned.size() == 1 and warned[0]["owner"] == "owner1", "A34: tamed_attacked uma vez por episódio, ao dono (%d)" % warned.size())
	_run(world, 5.0)
	var repeated := events.filter(func(e: Dictionary) -> bool: return e["code"] == "tamed_attacked")
	_check(repeated.size() == 1, "A34: sem repetir durante o mesmo episódio")
	hunter.health.take_damage(hunter.health.max_health * 2.0)
	_run(world, 10.0)
	var second := _dino(world, _carnivore_stats(), Vector2(-60.0, 0.0), "c2")
	_run(world, 5.0)
	_check(events.filter(func(e: Dictionary) -> bool: return e["code"] == "tamed_attacked").size() == 1 and second != null,
			"A34: dentro dos 30 s depois do fim da caçada o aviso ainda não rearmou")
	second.health.take_damage(second.health.max_health * 2.0)
	_run(world, 31.0)
	var third := _dino(world, _carnivore_stats(), Vector2(-60.0, 0.0), "c3")
	_run(world, 5.0)
	_check(events.filter(func(e: Dictionary) -> bool: return e["code"] == "tamed_attacked").size() == 2 and third != null,
			"A34: rearma 30 s depois do fim da caçada")
	pet.health.current_health = 1.0
	third.global_position = Vector2(-20.0, 0.0)
	authority.resolve_dino_attack(authority.id_of(third), authority.id_of(pet), 8.0)
	var killed := events.filter(func(e: Dictionary) -> bool: return e["code"] == "tamed_killed")
	_check(killed.size() == 1 and killed[0]["owner"] == "owner1", "A34: tamed_killed na morte, ao dono")
	_check(not _fail_events.has("tamed_attacked") and not _fail_events.has("tamed_killed"),
			"A34: os dois só chegam ao dono (nunca no game_event geral)")
	_check(GameMessages.text_of("tamed_attacked", {"prey": "Rex", "species": "Raptor"}) == "Rex está sendo atacado por Raptor." \
			and GameMessages.text_of("tamed_killed", {"prey": "Rex", "species": "Raptor"}) == "Rex foi morto por Raptor.",
			"A34: os textos estão em GameMessages")


## A35: o domado morto deixa o alforje no chão (uma pilha por stack, 4 a 12 px, 300 s), sem perder nada pelo teto.
func _test_a35_tamed_death_drops_bag() -> void:
	var world := _world()
	world["frozen"] = true
	var ground: GroundItemField = world["ground"]
	var authority: WorldAuthority = world["authority"]
	var spot := Vector2(128.0, 128.0)  # longe das bordas das células de 256 px do teto por área
	(world["player"] as Player).global_position = Vector2(128.0, 330.0)  # ativo, mas fora da elipse do carnívoro
	var hunter := _dino(world, _carnivore_stats(), spot + Vector2(-20.0, 0.0), "c1")
	var pet := _tamed(world, _herbivore_stats("test_herbivore_tamed"), spot)
	pet.inventory.add("berry", 7)
	pet.inventory.add("meat", 2)
	for index in ground.rules.max_per_area:
		ground.spawn_scatter("stone", 1, spot + Vector2(float(index), 40.0))
	var before := ground.count()
	_run(world, 0.6)  # o carnívoro trava o domado (a caçada existe antes do golpe final)
	pet.health.current_health = 1.0
	authority.resolve_dino_attack(authority.id_of(hunter), authority.id_of(pet), 8.0)
	var piles := 0
	var near := true
	var now := authority.clock.now()
	var due_ok := true
	for item in ground.items():
		if item.item_id == "berry" or item.item_id == "meat":
			piles += 1
			var distance := item.global_position.distance_to(pet.global_position)
			near = near and distance >= 3.99 and distance <= 12.01
			due_ok = due_ok and is_equal_approx(item.due_at - now, 300.0)
	_check(ground.total_of("berry") == 7 and ground.total_of("meat") == 2, "A35: nada do alforje se perde (7 de baga, 2 de carne)")
	_check(piles == 4 and near and due_ok, "A35: uma pilha por stack (3 + 3 + 1 de baga e 2 de carne = %d), a 4 a 12 px, por 300 s" % piles)
	_check(ground.count() == before + piles, "A35: o drop passou do teto de %d por área, sem apagar nada" % ground.rules.max_per_area)
	_check(pet.health.is_dead() and pet.is_queued_for_deletion(), "A35: o domado morto sai do mundo (e do save)")
	var carcasses: CarcassField = world["carcasses"]
	var system: PredationSystem = world["system"]
	_check(carcasses.count() == 1 and system.is_eating(hunter), "A35: a carcaça do domado vira a refeição do carnívoro")
	_run(world, 60.0)
	_check(carcasses.count() == 0, "A35: a carcaça é comida inteira")


## A36: isca e escudo do dono.
func _test_a36_bait_and_shield() -> void:
	var world := _world()
	world["frozen"] = true
	var player: Player = world["player"]
	var hunter := _dino(world, _carnivore_stats(), Vector2(-24.0, 0.0), "c1")
	var pet := _tamed(world, _herbivore_stats("test_herbivore_tamed"), Vector2.ZERO)
	_sturdy(pet)
	player.global_position = Vector2(0.0, TILE)  # o dono a 1 tile do domado
	var life := player.health.current_health
	_run(world, 20.0)
	_check(player.health.current_health == life and _target(world, hunter) == pet and pet.health.current_health < pet.health.max_health,
			"A36: em combate com o domado a 1 tile do jogador, 20 s: nenhuma mordida nele e o alvo não troca")
	hunter.receive_hit(1.0, 0.0, TamingRules.ATTACKER_PLAYER, player.player_id)
	_run(world, 0.6)
	_check(_target(world, hunter) == null and hunter._target_body == player, "A36: dano do jogador troca em até 0,5 s")
	var shield := _world()
	shield["frozen"] = true
	var chaser := _dino(shield, _carnivore_stats(), Vector2.ZERO, "c1")
	var buddy := _tamed(shield, _herbivore_stats("test_herbivore_tamed"), Vector2(0.0, 200.0))
	var owner: Player = shield["player"]
	owner.global_position = Vector2(70.0, 0.0)
	chaser.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	_run(shield, 1.0)
	_check(_target(shield, chaser) == owner, "A36: o carnívoro persegue o dono (o único candidato)")
	buddy.global_position = Vector2(40.0, 0.0)  # mais perto do carnívoro que o dono, mas a 30 px (< 4 tiles) dele
	_run(shield, 6.0)
	_check(_target(shield, chaser) == owner, "A36: o domado a até 4 tiles do dono não toma o alvo de quem já o persegue")
	buddy.global_position = Vector2(-60.0, 0.0)  # longe do escudo e 14% mais perto que o dono: ainda dentro da histerese
	_run(shield, 6.0)
	_check(_target(shield, chaser) == owner, "A36: e fora do escudo só troca com a histerese de 30%")
	var biter := _world()
	biter["frozen"] = true
	var raptor := _dino(biter, _carnivore_stats(), Vector2.ZERO, "c1")
	var bait := _tamed(biter, _herbivore_stats("test_herbivore_tamed"), Vector2(70.0, 0.0))
	(biter["player"] as Player).global_position = Vector2(0.0, 100.0)
	raptor.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	raptor.bit_player_episode = raptor.state_machine.episode_id
	_run(biter, 3.0)
	_check(_target(biter, raptor) != bait, "A36: quem já mordeu o jogador não troca para o domado")
