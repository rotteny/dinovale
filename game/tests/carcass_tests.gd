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
## Passo do teste do tempo da esfola (divide 1,5, 3 e 6 s sem sobra).
const STEP := 0.25


func run() -> void:
	_test_yield_by_species()
	_test_skin_by_hand()
	_test_skin_with_spear()
	_test_timed_action()
	_test_interruptions_and_wear()
	_test_set_meat_keeps_leather()
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


## Passa `seconds` da esfola (passos de `STEP`), parando se a tarefa acabar. Devolve os segundos andados.
func _pass(world: Dictionary, seconds: float) -> float:
	var authority: WorldAuthority = world["authority"]
	var elapsed := 0.0
	while elapsed < seconds - 0.0001 and not authority.skinning.job(1).is_empty():
		authority.skinning.tick(STEP)
		elapsed += STEP
	return elapsed


## Pede e deixa a tarefa correr até o fim. Devolve a resposta do pedido.
func _skin_through(world: Dictionary, carcass: ResourceNode) -> Enums.ActionResult:
	var result := _skin(world, carcass)
	_pass(world, 600.0)
	return result


func _events(world: Dictionary) -> Array[String]:
	var seen: Array[String] = []
	(world["authority"] as WorldAuthority).game_event.connect(func(code: String, params: Dictionary) -> void:
		seen.append(str(params.get("reason", "")) if code == "action_refused" else code))
	return seen


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
	var seconds := _pass(world, 600.0)
	_check(player.inventory.count(Items.MEAT) == RAPTOR_MEAT and player.inventory.count(Items.LEATHER) == RAPTOR_LEATHER,
			"leva toda a carne e o couro")
	_check(is_equal_approx(seconds, HAND_SECONDS), "à mão: 3 s por carne e 6 s por couro (%.1f s)" % seconds)
	_check(is_equal_approx(life - player.health.current_health, float(RAPTOR_MEAT + RAPTOR_LEATHER)), "à mão: 1 de dano por item")
	_check(player.progression.xp == xp, "esfolar não dá XP")


func _test_skin_with_spear() -> void:
	var world := _world()
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	_arm_spear(player)
	var life := player.health.current_health
	var durability := int(player.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0))
	var first := _skin(world, carcass)
	var seconds := _pass(world, 600.0)
	_check(first == Enums.ActionResult.OK and player.inventory.count(Items.MEAT) == RAPTOR_MEAT, "com a Lança: leva tudo")
	_check(is_equal_approx(seconds, HAND_SECONDS * 0.5), "com a Lança: metade do tempo (fator em dado) (%.1f)" % seconds)
	_check(life == player.health.current_health, "com a Lança a mão não se machuca")
	_check(int(player.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0)) == durability - 1,
			"e a Lança gasta 1 de durabilidade na carcaça esvaziada")
	_check(preload("res://data/weapons/wooden_spear.tres").skin_seconds_factor == 0.5, "o fator da Lança está em dado (0,5)")
	var paq := _carcass(world, PAQ, 12, Vector2(300.0, 0.0))
	player.global_position = paq.global_position + Vector2(0.0, 10.0)
	(world["authority"] as WorldAuthority).clock.advance(100.0)  # passa o intervalo entre coletas
	player.inventory.remove(Items.MEAT, 99)
	var second := _skin(world, paq)
	_check(second == Enums.ActionResult.OK and is_equal_approx(_pass(world, 600.0), 9.0), "Paquicéfalo com a Lança: 9 s (GDD 5.6)")


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
			and player.inventory.carried_grams() == full_state and (world["authority"] as WorldAuthority).skinning.job(1).is_empty(),
			"a recusa não gasta a carcaça, a vida nem abre tarefa")
	player.inventory.remove(Items.WOOD, 1)  # 1 kg de folga: 2 de carne (1 kg); o couro (0,4) já não cabe
	var partial := _skin(world, carcass)
	var seconds := _pass(world, 600.0)
	_check(partial == Enums.ActionResult.OK and player.inventory.count(Items.MEAT) == 2
			and carcass.component.pending_yields() == {"meat": 2, "leather": 1},
			"o que cabe no Peso entra e o resto fica na carcaça (sem sacolinha)")
	_check(is_equal_approx(seconds, 6.0) and is_equal_approx(life - player.health.current_health, 2.0),
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
	_check(_skin_through(world, carcass) == Enums.ActionResult.OK and carcasses.count() == 1,
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
	_skin_through(world, carcass)  # cabe 1 pilha só de carne: couro fica
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
	var prey_stats := _herbivore_stats()
	prey_stats.carcass_leather = 2  # com couro: a refeição do predador só pode mexer na carne
	var prey := _herd(world, prey_stats, Vector2(60.0, 0.0), Vector2(0.0, 900.0), 4)
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
	_check(node.component.pending_yields().get(Items.LEATHER, 0) == 2, "o couro segue intacto depois da refeição do predador (2)")
	var skin_result := _skin_through(world, node)
	var taken := player.inventory.count(Items.MEAT)
	_check(skin_result == Enums.ActionResult.OK and taken == left_mid and player.inventory.count(Items.LEATHER) == 2,
			"o jogador esfola o que SOBROU (%d de %d) e o couro inteiro (2)" % [taken, meat0])
	_run(world, 2.0 * float(meat0), 0.1)
	_check(taken < meat0 and meat0 - taken == meat0 - left_mid and player.inventory.count(Items.MEAT) == taken,
			"a carne nunca duplica: o jogador ficou com %d e o resto (%d) foi do predador" % [taken, meat0 - left_mid])
	_check(not system.is_eating(hunter),
			"sem carne, o predador para e a carcaça não gera carne nova")
	_check(hunter.sated_until > 0.0, "e a saciedade é proporcional ao que ele comeu")


## Esfolar tem tempo: a barra, a entrega unidade por unidade e o que o jogador tem no meio da ação.
func _test_timed_action() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	var life := player.health.current_health
	_check(_skin(world, carcass) == Enums.ActionResult.OK and not authority.skinning.job(1).is_empty(), "o pedido abre a tarefa")
	_check(player.inventory.count(Items.MEAT) == 0 and authority.skinning.progress(1) == 0.0, "e nada entra na hora")
	_check(_skin(world, carcass) == Enums.ActionResult.COOLDOWN, "pedir de novo enquanto esfola não reinicia (silencioso)")
	_pass(world, 2.75)
	_check(player.inventory.count(Items.MEAT) == 0, "aos 2,75 s ainda não saiu a primeira carne (3 s)")
	_pass(world, 0.25)
	_check(player.inventory.count(Items.MEAT) == 1 and is_equal_approx(life - player.health.current_health, 1.0),
			"aos 3 s sai a primeira carne e custa 1 de vida à mão")
	_pass(world, 6.0)
	_check(player.inventory.count(Items.MEAT) == 3 and player.inventory.count(Items.LEATHER) == 0
			and carcass.component.pending_yields() == {"meat": RAPTOR_MEAT - 3, "leather": RAPTOR_LEATHER},
			"aos 9 s: 3 carnes, nenhum couro, e a carcaça guarda o resto")
	var progress := authority.skinning.progress(1)
	_check(is_equal_approx(progress, 9.0 / HAND_SECONDS), "a barra marca 9 de 39 s (%.3f)" % progress)
	_pass(world, 600.0)
	_check(player.inventory.count(Items.MEAT) == RAPTOR_MEAT and player.inventory.count(Items.LEATHER) == RAPTOR_LEATHER
			and authority.skinning.job(1).is_empty() and not carcass.is_available(), "no fim tudo entrou, a carcaça esvaziou e a tarefa fecha")
	_check(authority.gather_wait_left(1) > 0.0, "esfolar abre o intervalo entre coletas")
	_test_progress_bar(world, player)
	var next := _carcass(world, PAQ, 12, Vector2(300.0, 0.0))
	player.global_position = next.global_position + Vector2(0.0, 10.0)
	_check(_skin(world, next) == Enums.ActionResult.COOLDOWN and authority.skinning.job(1).is_empty(),
			"dentro do intervalo outro pedido é recusado em silêncio e não abre tarefa")
	authority.clock.advance(100.0)
	_check(_skin(world, next) == Enums.ActionResult.OK, "passado o intervalo, esfola de novo")


## Andar mais de 3 tiles, apanhar ou cair interrompem e o que já saiu fica; a Lança só gasta ao esvaziar a carcaça.
func _test_interruptions_and_wear() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	var events := _events(world)
	var tile := authority.rules.tile_size
	_skin(world, carcass)
	_pass(world, 9.0)
	player.global_position += Vector2(2.0 * tile, 0.0)
	_pass(world, 0.25)
	_check(not authority.skinning.job(1).is_empty(), "andar 2 tiles não interrompe (o limite é 3)")
	player.global_position += Vector2(2.0 * tile, 0.0)
	authority.skinning.tick(STEP)
	_check(authority.skinning.job(1).is_empty() and events.has("skin_cancelled"), "andar mais de 3 tiles interrompe e avisa")
	_check(player.inventory.count(Items.MEAT) == 3
			and carcass.component.pending_yields() == {"meat": RAPTOR_MEAT - 3, "leather": RAPTOR_LEATHER},
			"o que já saiu fica com o jogador e a carcaça guarda o resto")
	player.global_position = carcass.global_position + Vector2(0.0, 10.0)
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "dá para retomar (a interrupção não abre o intervalo)")
	_pass(world, 3.0)
	player.health.take_damage(5.0)
	authority.skinning.tick(STEP)
	_check(authority.skinning.job(1).is_empty() and player.inventory.count(Items.MEAT) == 4,
			"tomar dano interrompe e mantém a carne já entregue")
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "retoma outra vez")
	player.health.take_damage(1.0e9)
	authority.skinning.tick(STEP)
	_check(authority.skinning.job(1).is_empty(), "cair (vida zerada) interrompe")
	# A carcaça some no meio (venceu): a tarefa fecha sem erro e o que entrou fica.
	var gone_world := _world()
	var gone := _carcass(gone_world, PAQ, 12, Vector2(100.0, 0.0))
	var walker := _player_near(gone_world, gone)
	_skin(gone_world, gone)
	_pass(gone_world, 3.0)
	gone.free()
	(gone_world["authority"] as WorldAuthority).skinning.tick(STEP)
	_check((gone_world["authority"] as WorldAuthority).skinning.job(1).is_empty() and walker.inventory.count(Items.MEAT) == 1,
			"a carcaça some no meio da esfola: a tarefa fecha e a carne já entregue fica")
	# Lança: o desgaste é por carcaça esvaziada; interrompida no meio, a Lança não gasta.
	var spear_world := _world()
	var spear_authority: WorldAuthority = spear_world["authority"]
	var meat := _carcass(spear_world, PAQ, 12, Vector2(100.0, 0.0))
	var hunter := _player_near(spear_world, meat)
	_arm_spear(hunter)
	var durability := int(hunter.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0))
	_skin(spear_world, meat)
	_pass(spear_world, 3.0)
	hunter.health.take_damage(2.0)
	spear_authority.skinning.tick(STEP)
	_check(hunter.inventory.count(Items.MEAT) == 2 and meat.component.pending_yields() == {"meat": 2, "leather": 1}
			and int(hunter.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0)) == durability,
			"com a Lança, parcial: entregou 2 carnes (1,5 s cada), a carcaça não esvaziou e a Lança não gastou")
	_skin(spear_world, meat)
	_pass(spear_world, 600.0)
	_check(int(hunter.equipment.item_in(EquipmentLayout.WEAPON).get("durab", 0)) == durability - 1,
			"ao esvaziar a carcaça a Lança gasta 1 (por carcaça, GDD 5.6)")


## A refeição do predador só muda a carne: o couro e o que sobrou ficam como estavam.
func _test_set_meat_keeps_leather() -> void:
	var world := _world()
	var carcasses: CarcassField = world["carcasses"]
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	carcasses.set_meat(carcass, 3)
	_check(carcass.component.pending_yields() == {"meat": 3, "leather": RAPTOR_LEATHER}, "refeição inteira: 3 de carne e 3 de couro")
	carcass.component.leave({"meat": 5, "leather": 1})  # esfolada em parte: sobra 1 de couro
	carcasses.set_meat(carcass, 2)
	_check(carcass.component.pending_yields() == {"meat": 2, "leather": 1},
			"esfolada em parte: a refeição leva a carne para 2 e o couro fica em 1")
	carcasses.set_meat(carcass, 4)
	_check(carcass.component.pending_yields() == {"meat": 2, "leather": 1}, "a refeição nunca aumenta a carne")
	# Save e carga: lixo é descartado.
	var now := (world["authority"] as WorldAuthority).clock.now()
	carcasses.restore_list([
			{"species": "utahraptor", "level": 20, "x": 1.0, "y": 1.0, "born_at": now, "format": 7},
			{"species": "utahraptor", "level": 20, "x": 2.0, "y": 1.0, "born_at": now, "format": "dois"},
			{"species": "utahraptor", "level": 20, "x": 3.0, "y": 1.0, "born_at": now, "format": 2, "left": {"meat": -4, "leather": 0}},
			{"species": "utahraptor", "level": 20, "x": 4.0, "y": 1.0, "born_at": now - carcasses.rules.fresh_seconds - 1.0, "format": 2},
			{"species": "utahraptor", "level": 20, "x": 5.0, "y": 1.0, "born_at": now, "format": 2.0, "left": {"meat": 2, "leather": -9}}])
	var kept := carcasses.nodes()
	_check(kept.size() == 1 and kept[0].component.pending_yields() == {"meat": 2},
			"no load: format inválido, `left` negativo ou zero e carcaça vencida são descartados; o bom (format 2.0 do JSON) entra com o que sobrou")


## A HUD mostra a barra de esfolar só enquanto há tarefa, e ela sobe com o tempo (só lê a autoridade).
func _test_progress_bar(world: Dictionary, player: Player) -> void:
	var authority: WorldAuthority = world["authority"]
	var carcass := _carcass(world, PAQ, 12, Vector2(500.0, 0.0))
	player.global_position = carcass.global_position + Vector2(0.0, 10.0)
	authority.clock.advance(100.0)
	var hud := PlayerHud.new()
	hud.player = player
	hud.authority = authority
	_root.add_child(hud)
	_track.call(hud)
	hud.tick(0.1)
	_check(not hud.skin_bar().visible, "HUD: sem tarefa a barra de esfolar fica escondida")
	_skin(world, carcass)
	_pass(world, 9.0)
	hud.tick(0.1)
	_check(hud.skin_bar().visible and hud.skin_bar().value() > 0.0 and hud.skin_bar().value() < 1.0,
			"HUD: com tarefa a barra aparece e marca o progresso (%.2f)" % hud.skin_bar().value())
	_pass(world, 600.0)
	hud.tick(0.1)
	_check(not hud.skin_bar().visible, "HUD: a barra some quando a tarefa termina")
