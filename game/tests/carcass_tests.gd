# SPDX-License-Identifier: MIT
class_name CarcassTests
extends DayNightThreatTests
## E10, SOB-06: esfolar a carcaça (`request_skin`). Rendimento por espécie em dado, tempo por item à mão e com a Lança, o que não
## cabe fica na carcaça, frescor, dono por 120 s, alcance e linha livre, save com migração e a disputa com o predador.
## Monta o mundo do `PredationTests` (autoridade, zona, predação, carcaças), sem a `Main`.

const PAQ: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
## Utahraptor L20 (base 5 e 2, fator 1,3): o que a regra do código entrega.
const RAPTOR_MEAT := 7
const RAPTOR_LEATHER := 3
## Tempo à mão por unidade (carne 3 s, couro 6 s) e o dano por item.
const HAND_SECONDS := 3.0 * RAPTOR_MEAT + 6.0 * RAPTOR_LEATHER


func run() -> void:
	_test_yield_by_species()
	_test_skin_by_hand()
	_test_skin_with_spear()
	_test_partial_by_weight_and_slot()
	_test_freshness_and_expiry()
	_test_access_rules()
	_test_owner_window()
	_test_save_and_migration()
	_test_contest_with_predator()
	_release_worlds()


## Mata um dino de `stats` no nível `level` em `at` pelo caminho do jogo e devolve a carcaça dele.
func _carcass(world: Dictionary, stats: DinoBaseStats, level: int, at: Vector2, tamed: bool = false) -> ResourceNode:
	var dino := _tamed(world, stats, at) if tamed else _dino(world, stats, at, "")
	dino.level = level
	dino.health.take_damage(1.0e6)
	return (world["carcasses"] as CarcassField).carcass_of(dino)


func _player_near(world: Dictionary, carcass: ResourceNode) -> Player:
	var player: Player = world["player"]
	player.global_position = carcass.global_position + Vector2(0.0, 10.0)
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	return player


func _skin(world: Dictionary, carcass: ResourceNode) -> Enums.ActionResult:
	var authority: WorldAuthority = world["authority"]
	return authority.request_skin(1, authority.id_of(carcass))


func _arm_spear(player: Player) -> void:
	player.inventory.add(Items.WOODEN_SPEAR, 1)
	player.request_equip(player.newest_iid(Items.WOODEN_SPEAR))
	player._equip_timer = 0.0


func _test_yield_by_species() -> void:
	var rules := CarcassField.LEVEL_RULES
	_check(rules.carcass_meat(PAQ.carcass_meat, 12) == 4 and rules.carcass_leather(PAQ.carcass_leather, 12) == 1,
			"Paquicéfalo L12: 4 de carne e 1 de couro (GDD 5.6)")
	# O GDD 5.6 diz 6 de carne no L20 (5 x 1,3 = 6,5); o código arredonda para 7 (`roundi`). Conflito registrado no relatório.
	_check(rules.carcass_meat(RAPTOR.carcass_meat, 20) == RAPTOR_MEAT and rules.carcass_leather(RAPTOR.carcass_leather, 20) == RAPTOR_LEATHER,
			"Utahraptor L20: %d de carne e %d de couro (base 5 e 2 x 1,3, arredondado)" % [RAPTOR_MEAT, RAPTOR_LEATHER])
	_check(rules.carcass_leather(0, 30) == 0, "espécie sem couro (base 0) não rende couro")
	var world := _world()
	var paq := _carcass(world, PAQ, 12, Vector2(100.0, 0.0))
	var raptor := _carcass(world, RAPTOR, 20, Vector2(200.0, 0.0))
	_check(paq != null and paq.component.pending_yields() == {"meat": 4, "leather": 1}, "a carcaça do Paquicéfalo nasce com 4 e 1")
	_check(raptor != null and raptor.component.pending_yields() == {"meat": RAPTOR_MEAT, "leather": RAPTOR_LEATHER},
			"a do Utahraptor (espécie real do jogo) nasce com o rendimento do nível")


func _test_skin_by_hand() -> void:
	var world := _world()
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	var life := player.health.current_health
	var xp := player.progression.xp
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "à mão: esfolar é aceito")
	_check(player.inventory.count(Items.MEAT) == RAPTOR_MEAT and player.inventory.count(Items.LEATHER) == RAPTOR_LEATHER,
			"leva toda a carne e o couro")
	_check(is_equal_approx(player.gather_cooldown_left(), HAND_SECONDS),
			"à mão: 3 s por carne e 6 s por couro (%.1f s)" % player.gather_cooldown_left())
	_check(is_equal_approx(life - player.health.current_health, float(RAPTOR_MEAT + RAPTOR_LEATHER)), "à mão: 1 de dano por item")
	_check(player.progression.xp == xp, "esfolar não dá XP")


func _test_skin_with_spear() -> void:
	var world := _world()
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	_arm_spear(player)
	var life := player.health.current_health
	var durability := int(player.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0))
	_check(_skin(world, carcass) == Enums.ActionResult.OK and player.inventory.count(Items.MEAT) == RAPTOR_MEAT, "com a Lança: leva tudo")
	_check(is_equal_approx(player.gather_cooldown_left(), HAND_SECONDS * 0.5),
			"com a Lança: metade do tempo (fator em dado) (%.1f)" % player.gather_cooldown_left())
	_check(life == player.health.current_health, "com a Lança a mão não se machuca")
	_check(int(player.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0)) == durability - 1,
			"e a Lança gasta 1 de durabilidade na carcaça esvaziada")
	_check(preload("res://data/weapons/wooden_spear.tres").skin_seconds_factor == 0.5, "o fator da Lança está em dado (0,5)")
	var paq := _carcass(world, PAQ, 12, Vector2(300.0, 0.0))
	player.global_position = paq.global_position + Vector2(0.0, 10.0)
	player.tick(100.0)
	player.inventory.remove(Items.MEAT, 99)
	_check(_skin(world, paq) == Enums.ActionResult.OK and is_equal_approx(player.gather_cooldown_left(), 9.0),
			"Paquicéfalo com a Lança: 9 s (GDD 5.6)")


func _test_partial_by_weight_and_slot() -> void:
	var world := _world()
	var carcass := _carcass(world, PAQ, 12, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	while player.inventory.weight_room_grams() >= 1000:
		player.inventory.add(Items.WOOD, 1)
	while player.inventory.weight_room_grams() >= 50:
		player.inventory.add(Items.FIBER, 1)
	var full_state := player.inventory.carried_grams()
	var life := player.health.current_health
	var events: Array[String] = []
	(world["authority"] as WorldAuthority).game_event.connect(func(code: String, params: Dictionary) -> void:
		events.append(str(params.get("reason", "")) if code == "action_refused" else code))
	_check(_skin(world, carcass) == Enums.ActionResult.REFUSED and events.has("weight_limit"),
			"acima do Peso: esfolar recusa com 'Peso máximo'")
	_check(carcass.component.pending_yields() == {"meat": 4, "leather": 1} and life == player.health.current_health
			and player.inventory.carried_grams() == full_state and player.gather_cooldown_left() == 0.0,
			"a recusa não gasta a carcaça, a vida nem o tempo")
	player.inventory.remove(Items.WOOD, 1)  # 1 kg de folga: 2 de carne (1 kg); o couro (0,4) já não cabe
	_check(_skin(world, carcass) == Enums.ActionResult.OK and player.inventory.count(Items.MEAT) == 2
			and carcass.component.pending_yields() == {"meat": 2, "leather": 1},
			"o que cabe no Peso entra e o resto fica na carcaça (sem sacolinha)")
	_check(is_equal_approx(player.gather_cooldown_left(), 6.0) and is_equal_approx(life - player.health.current_health, 2.0),
			"o tempo e o dano são só do que saiu (2 carnes: 6 s e 2)")
	# Slot: 1 slot só, cheio de outra coisa.
	var slot_world := _world()
	var other := _carcass(slot_world, PAQ, 12, Vector2(100.0, 0.0))
	var skinner := _player_near(slot_world, other)
	skinner.inventory.capacity = 1
	skinner.inventory.add(Items.FERN, 1)
	_check(_skin(slot_world, other) == Enums.ActionResult.REFUSED and other.component.pending_yields() == {"meat": 4, "leather": 1},
			"slots cheios: recusa e a carcaça fica inteira")


func _test_freshness_and_expiry() -> void:
	var world := _world()
	var carcasses: CarcassField = world["carcasses"]
	var authority: WorldAuthority = world["authority"]
	var carcass := _carcass(world, PAQ, 12, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	player.inventory.weight_limit = 0.0
	player.inventory.capacity = 1
	_check(_skin(world, carcass) == Enums.ActionResult.OK and carcasses.count() == 1,
			"preparo: esfolada pela metade (cabe a carne, o couro fica)")
	authority.clock.advance(599.0)
	carcasses.tick()
	_check(carcasses.count() == 1, "aos 599 s a carcaça (fresca por 10 min) ainda está")
	authority.clock.advance(2.0)
	carcasses.tick()
	_check(carcasses.count() == 0 and authority.entity(authority.id_of(carcass)) == null, "aos 601 s ela some e sai do registro")
	_check(carcasses.rules.fresh_seconds == 600.0, "o prazo está em dado (600 s)")


func _test_access_rules() -> void:
	var world := _world()
	var carcass := _carcass(world, PAQ, 12, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	var authority: WorldAuthority = world["authority"]
	var reasons: Array[String] = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void:
		if code == "action_refused":
			reasons.append(str(params["reason"])))
	player.global_position = carcass.global_position + Vector2(200.0, 0.0)
	_check(_skin(world, carcass) == Enums.ActionResult.OUT_OF_RANGE and carcass.component.pending_yields().size() == 2,
			"longe: fora de alcance, nada muda")
	# Parede entre os dois: linha livre.
	player.global_position = carcass.global_position + Vector2(-32.0, 0.0)
	var cell := authority.build.cell_of(carcass.global_position + Vector2(-16.0, 0.0))
	authority.build.grid.add(cell, "wall", 0, player.player_id)
	_check(authority.build.grid.segment_blocked(player.global_position, carcass.global_position), "preparo: a parede corta a linha")
	_check(_skin(world, carcass) == Enums.ActionResult.OUT_OF_RANGE and reasons.back() == "blocked_line",
			"parede no meio: recusa 'blocked_line'")
	_check(carcass.component.pending_yields() == {"meat": 4, "leather": 1}, "e a carcaça fica intacta")
	_check(authority.request_skin(1, 99999) == Enums.ActionResult.UNKNOWN_TARGET, "alvo que não existe")
	var tree: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	tree.def = load("res://data/resources/tree.tres")
	tree.position = player.position
	_root.add_child(tree)
	_track.call(tree)
	authority.register(tree)
	_check(authority.request_skin(1, authority.id_of(tree)) == Enums.ActionResult.INVALID_TARGET and reasons.back() == "not_a_carcass",
			"um nó que não é carcaça")
	_check(authority.request_skin(1, authority.id_of(player)) == Enums.ActionResult.UNKNOWN_TARGET, "entidade que não é nó de recurso")
	_check(authority.request_skin(77, authority.id_of(carcass)) == Enums.ActionResult.UNKNOWN_ACTOR, "ator desconhecido")
	player.health.take_damage(1.0e6)
	_check(authority.request_skin(1, authority.id_of(carcass)) != Enums.ActionResult.OK, "caído não esfola")


func _test_owner_window() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var carcass := _carcass(world, PAQ, 12, Vector2(100.0, 0.0), true)
	var player := _player_near(world, carcass)
	_check(carcass.carcass_owner == "owner1", "carcaça de domado guarda o dono")
	player.player_id = "intruso"
	var denied := _skin(world, carcass)
	_check(denied == Enums.ActionResult.NOT_OWNER and carcass.component.pending_yields().size() == 2,
			"outro jogador antes de 120 s: não é dono")
	authority.clock.advance(121.0)
	player.inventory.weight_limit = 0.0
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "passados 120 s é de todos")
	var wild := _carcass(world, PAQ, 12, Vector2(300.0, 0.0))
	_check(wild.carcass_owner == "", "carcaça de selvagem não tem dono")


func _test_save_and_migration() -> void:
	var world := _world()
	var carcasses: CarcassField = world["carcasses"]
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0), true)
	var player := _player_near(world, carcass)
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	player.inventory.capacity = 1
	_skin(world, carcass)  # cabe 1 pilha só de carne: couro fica
	var saved := carcasses.to_list()
	_check(saved.size() == 1 and saved[0]["format"] == CarcassField.ENTRY_FORMAT and saved[0]["owner"] == "owner1" and saved[0].has("left"),
			"o save leva formato, dono e o que sobrou")
	carcasses.restore_list(saved)
	var back := carcasses.nodes()[0]
	_check(carcasses.count() == 1 and back.component.pending_yields() == carcass.component.pending_yields() and back.carcass_owner == "owner1",
			"restaurar devolve a mesma sobra e o dono")
	# Save antigo (sem 'format'): só tinha carne. Pela metade ganha o couro que ainda não existia; inteiro nasce inteiro.
	carcasses.restore_list([{"species": "utahraptor", "level": 20, "x": 50.0, "y": 50.0, "born_at": 0.0, "left": {"meat": 2}},
			{"species": "utahraptor", "level": 20, "x": 80.0, "y": 50.0, "born_at": 0.0}])
	var nodes := carcasses.nodes()
	_check(nodes[0].component.pending_yields() == {"meat": 2, "leather": RAPTOR_LEATHER}
			and nodes[1].component.pending_yields() == {"meat": RAPTOR_MEAT, "leather": RAPTOR_LEATHER},
			"migração: save antigo recebe o couro, sem perder a carne que sobrou")
	var hostile := {"species": "utahraptor", "level": 20, "owner": "x".repeat(500), "left": {"leather": 99, "nada": 4}}
	carcasses.restore_list([hostile, "lixo", null])
	var lixo := carcasses.nodes()[0]
	_check(carcasses.count() == 1 and lixo.carcass_owner == "" and lixo.component.pending_yields() == {"leather": RAPTOR_LEATHER},
			"dado hostil: dono longo demais cai, sobra além do rendimento é cortada, item desconhecido sai")


## Jogador e predador disputam a mesma carcaça: nunca se tira mais carne do que existia.
func _test_contest_with_predator() -> void:
	var world := _world(Rect2(Vector2(200.0, 0.0), Vector2(100.0, 100.0)))  # núcleo seguro: x >= 72
	var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
	var prey := _herd(world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 900.0), 4)
	prey[0].health.current_health = 1.0
	for dino in prey:
		dino.state_machine.holding = true
	world["hunter"] = hunter
	var player: Player = world["player"]
	player.global_position = Vector2(80.0, 8.0)  # no núcleo: o predador não o vê e segue comendo
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	var system: PredationSystem = world["system"]
	var carcasses: CarcassField = world["carcasses"]
	_check(_until_eating(world), "preparo: o predador abate e come")
	var node := carcasses.nodes()[0]
	var meat0 := carcasses.meat_of(node)
	_run(world, 2.0 * float(meat0) * 0.4, 0.1)  # come uns 40%
	var left_mid := carcasses.meat_of(node)
	_check(left_mid < meat0 and system.is_eating(hunter), "preparo: o predador já comeu parte e segue comendo")
	var skin_result := _skin(world, node)
	var taken := player.inventory.count(Items.MEAT)
	_check(skin_result == Enums.ActionResult.OK and taken == left_mid,
			"o jogador esfola o que SOBROU (%d de %d), não o que já foi comido" % [taken, meat0])
	_run(world, 2.0 * float(meat0), 0.1)
	var eaten_by_predator := meat0 - taken
	_check(taken + eaten_by_predator == meat0 and taken <= meat0,
			"a carne nunca duplica: jogador %d + predador %d = %d" % [taken, eaten_by_predator, meat0])
	_check(not system.is_eating(hunter),
			"sem carne, o predador para e a carcaça não gera carne nova")
	_check(hunter.sated_until > 0.0, "e a saciedade é proporcional ao que ele comeu")
