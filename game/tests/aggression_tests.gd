# SPDX-License-Identifier: MIT
class_name AggressionTests
extends TestSuite
## M1, etapa 3: estado de agressão (A7 velocidade e sinal, A9 acalmar em 8 s), relógio zerado por novo golpe, atalhos
## de distância (D2), distância mínima sem empurrar e bravo fora do save. Sem ataque ainda.

const RULES: AggressionRules = preload("res://data/balance/aggression_rules.tres")
const PAQUI: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
const TILE := 16.0
const DT := 0.1


func run() -> void:
	_test_data()
	_test_a7_logic()
	_test_a9_calms_in_eight_seconds()
	_test_new_hit_resets_clock()
	_test_distance_shortcuts()
	_test_no_push()
	_test_only_awake_wild_reacts()
	_test_not_saved()
	_test_dino_body_hit()
	_test_a7_signal()


## Máquina do Paquicéfalo com o alvo (o jogador que bateu) a `tiles` à direita.
func _paqui(tiles: float = 5.0) -> DinoStateMachine:
	var machine := _make_machine()
	machine.configure(PAQUI, 40.0, TILE)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	machine.observe_target(Vector2(tiles * TILE, 0.0), true)
	return machine


func _run_for(machine: DinoStateMachine, seconds: float) -> void:
	for i in roundi(seconds / DT):
		machine.tick(DT)


func _test_data() -> void:
	_check(is_equal_approx(RULES.calm_seconds, 8.0) and is_equal_approx(RULES.far_tiles, 12.0) \
			and is_equal_approx(RULES.far_seconds, 5.0), "os números de acalmar vêm do .tres (8 s; 12 tiles por 5 s)")
	_check(is_equal_approx(PAQUI.chase_speed, 80.0) and is_equal_approx(RAPTOR.chase_speed, 90.0), \
			"velocidade brava: Paquicéfalo 80 e Utahraptor 90 (do dado da espécie)")
	_check(is_equal_approx(RULES.far_px(TILE), 192.0), "12 tiles de 16 px = 192 px")


func _test_a7_logic() -> void:
	var machine := _paqui()
	var changes: Array[bool] = []
	machine.aggression_changed.connect(func(aggressive: bool) -> void: changes.append(aggressive))
	_check(not machine.is_aggressive and is_equal_approx(machine.speed_multiplier, 1.0), "calmo: velocidade natural (40)")
	machine.tick(DT)
	_check(not machine.is_aggressive, "sem golpe o Paquicéfalo não fica bravo, mesmo com o jogador perto")
	machine.provoke()
	_check(machine.is_aggressive and machine.current_id == Enums.DinoStateId.AGGRESSIVE, "golpe: fica bravo")
	_check(is_equal_approx(machine.speed_multiplier * 40.0, 80.0), "bravo: 80 px/s (natural 40 x 2)")
	machine.tick(DT)
	_check(machine.desired_direction.is_equal_approx(Vector2.RIGHT), "persegue na direção de quem bateu")
	_check(changes == [true], "aggression_changed(true) uma vez")
	var raptor := _make_machine()
	raptor.configure(RAPTOR, 40.0, TILE)
	raptor.observe(Vector2.ZERO, Vector2.ZERO, false)
	raptor.observe_target(Vector2(5.0 * TILE, 0.0), true)
	raptor.tick(DT)
	_check(raptor.is_aggressive and is_equal_approx(raptor.speed_multiplier * 40.0, 90.0), \
			"o Agressivo fica bravo ao avistar o jogador, a 90 px/s")


func _test_a9_calms_in_eight_seconds() -> void:
	var machine := _paqui()
	var changes: Array[bool] = []
	machine.aggression_changed.connect(func(aggressive: bool) -> void: changes.append(aggressive))
	machine.provoke()
	_run_for(machine, 7.8)
	_check(machine.is_aggressive, "aos 7,8 s sem dano ainda está bravo")
	_run_for(machine, 0.4)
	_check(not machine.is_aggressive and machine.current_id == Enums.DinoStateId.IDLE, "aos 8 s sem dano acalma")
	_check(is_equal_approx(machine.speed_multiplier, 1.0) and machine.desired_direction == Vector2.ZERO, \
			"calmo volta a 40 px/s e para de perseguir")
	_check(changes == [true, false], "aggression_changed(false) ao acalmar")
	_run_for(machine, 3.0)
	_check(not machine.is_aggressive, "sem rancor: não volta a ficar bravo sozinho")
	machine.provoke()
	_check(machine.is_aggressive and is_equal_approx(machine.calm_left(), 8.0), "o próximo golpe é um episódio novo (8 s cheios)")


func _test_new_hit_resets_clock() -> void:
	var machine := _paqui()
	machine.provoke()
	_run_for(machine, 6.0)
	_check(machine.calm_left() < 2.1, "aos 6 s faltam cerca de 2 s")
	machine.provoke()
	_check(is_equal_approx(machine.calm_left(), 8.0) and machine.is_aggressive, "novo golpe zera o relógio para 8 s")
	_run_for(machine, 7.0)
	_check(machine.is_aggressive, "13 s depois do primeiro golpe e 7 s do segundo: ainda bravo")
	_run_for(machine, 1.2)
	_check(not machine.is_aggressive, "8 s depois do último golpe: acalma")


func _test_distance_shortcuts() -> void:
	# atacante a mais de 12 tiles por 5 s acalma antes dos 8 s
	var far := _paqui(13.0)
	far.provoke()
	_run_for(far, 4.8)
	_check(far.is_aggressive, "a 13 tiles por 4,8 s: ainda bravo")
	_run_for(far, 0.4)
	_check(not far.is_aggressive, "a 13 tiles por 5 s: acalma, sem esperar os 8 s")
	# voltar para perto zera a contagem dos 5 s
	var back := _paqui(13.0)
	back.provoke()
	_run_for(back, 4.0)
	back.observe_target(Vector2(5.0 * TILE, 0.0), true)
	_run_for(back, 0.5)
	back.observe_target(Vector2(13.0 * TILE, 0.0), true)
	_run_for(back, 3.0)
	_check(back.is_aggressive, "voltou a menos de 12 tiles: a contagem recomeça")
	# a 12 tiles justos não conta como longe
	var edge := _paqui(12.0)
	edge.provoke()
	_run_for(edge, 6.0)
	_check(edge.is_aggressive, "a exatamente 12 tiles não é 'mais de 12'")
	# desiste a 20 tiles na hora; e depois de 15 s com golpes seguidos
	var gone := _paqui(21.0)
	gone.provoke()
	gone.tick(DT)
	_check(not gone.is_aggressive, "alvo além de 20 tiles: desiste na hora")
	var long_fight := _paqui(5.0)
	long_fight.provoke()
	for i in 148:
		long_fight.tick(DT * 1.0)
		if i % 50 == 49:
			long_fight.provoke()
	_check(long_fight.is_aggressive, "aos 14,8 s com golpes seguidos ainda bravo")
	_run_for(long_fight, 0.4)
	_check(not long_fight.is_aggressive, "passa de 15 s de episódio: desiste mesmo apanhando")


func _test_no_push() -> void:
	var machine := _paqui(10.0)
	machine.provoke()
	var position := Vector2.ZERO
	var target := Vector2(10.0 * TILE, 0.0)
	var closest := INF
	var delta := 1.0 / 60.0
	for i in 360:  # 6 s, abaixo dos 8 s: o relógio ainda não acalmou
		machine.observe(position, Vector2.ZERO, false)
		machine.observe_target(target, true)
		machine.tick(delta)
		position += machine.desired_direction * 40.0 * machine.speed_multiplier * delta
		closest = minf(closest, position.distance_to(target))
	_check(machine.is_aggressive, "chegou perto e segue bravo (o que só revida não desiste ao alcançar)")
	_check(closest >= PAQUI.chase_stop_px - 1.5 and machine.desired_direction == Vector2.ZERO, \
			"para na distância mínima (%.1f px) e não empurra o jogador" % closest)


func _test_only_awake_wild_reacts() -> void:
	var tamed := _paqui()
	tamed.is_tamed = true
	tamed.provoke()
	_check(not tamed.is_aggressive, "o domado não fica bravo")
	var asleep := _paqui()
	asleep.torpor.add_torpor(asleep.torpor.max_torpor)
	asleep.provoke()
	_check(not asleep.is_aggressive, "dormindo não reage")
	var machine := _paqui()
	machine.provoke()
	machine.torpor.add_torpor(machine.torpor.max_torpor)
	_check(not machine.is_aggressive and machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "nocauteado, o bravo se acalma")


## Decisão: o bravo NÃO vai para o save (um episódio dura poucos segundos e o alvo não existe ao carregar).
func _test_not_saved() -> void:
	var machine := _paqui()
	machine.provoke()
	_check(machine.to_dict()["state"] == "IDLE", "salvo bravo, grava calmo")
	machine.from_dict({"state": "AGGRESSIVE", "is_tamed": false})
	_check(not machine.is_aggressive and is_equal_approx(machine.speed_multiplier, 1.0), "carregar sempre volta calmo")
	var fresh := _paqui()
	fresh.from_dict({"state": "AGGRESSIVE", "is_tamed": false})
	_check(not fresh.is_aggressive, "save com 'AGGRESSIVE' à mão não deixa bravo")


## O corpo: golpe do jogador (e só dele) deixa o selvagem bravo; o alvo é quem bateu.
func _test_dino_body_hit() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	var player := _spawn_player()
	player.global_position = Vector2(80.0, 0.0)
	dino.global_position = Vector2.ZERO
	dino.target_locator = func() -> Array: return [player]
	_check(dino.receive_hit(1.0, 0.0, TamingRules.ATTACKER_CARNIVORE), "golpe de carnívoro é aplicado")
	_check(not dino.state_machine.is_aggressive, "golpe que não é do jogador não deixa bravo")
	_check(dino.receive_hit(1.0, 0.0, TamingRules.ATTACKER_PLAYER, player.player_id), "golpe do jogador é aplicado")
	_check(dino.state_machine.is_aggressive, "golpe do jogador: o Paquicéfalo fica bravo")
	_check(dino.state_machine.target_known and dino.state_machine.target_position.is_equal_approx(player.global_position), \
			"o alvo já é o jogador que bateu, no quadro do golpe")
	dino.state_machine.tick(DT)
	_check(dino.state_machine.is_aggressive and dino.state_machine.desired_direction.x > 0.9, "persegue o jogador")
	_check(is_equal_approx(dino.move_speed * dino.state_machine.speed_multiplier, 80.0), "o corpo anda a 80 px/s bravo")
	# sem dano algum, o jogador vizinho ao lado não é alvo de um selvagem calmo
	var calm := _spawn_dino()
	calm.set_physics_process(false)
	calm.target_locator = func() -> Array: return [player]
	calm.observe_targets()
	_check(not calm.state_machine.target_known, "o Paquicéfalo calmo não mira o jogador")


func _test_a7_signal() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	var player := _spawn_player()
	player.global_position = Vector2(48.0, 0.0)
	dino.target_locator = func() -> Array: return [player]
	var view := DinoView.new()
	view.dino = dino
	_root.add_child(view)
	_track.call(view)
	var tag := WildLevelTag.new()
	tag.dino = dino
	tag.viewer = player
	_root.add_child(tag)
	_track.call(tag)
	view.tick(1.0)
	tag.tick(1.0)
	var calm_color := tag.tag_color()
	_check(not view.alert_mark_visible(), "calmo: sem '!'")
	dino.receive_hit(1.0, 0.0, TamingRules.ATTACKER_PLAYER, player.player_id)
	view.tick(DT)
	tag.tick(DT)
	_check(view.alert_mark_visible() and view.alert_mark_alpha() < 1.0, "golpe: o '!' começa a aparecer (fade)")
	view.tick(RULES.fade_seconds)
	tag.tick(RULES.fade_seconds)
	_check(is_equal_approx(view.alert_mark_alpha(), 1.0), "o '!' fica cheio")
	_check(tag.tag_color().is_equal_approx(RULES.alert_color) and not tag.tag_color().is_equal_approx(calm_color), \
			"o 'Nv' fica avermelhado (cor de perigo do dado)")
	_check(tag.tag_visible() and tag.tag_text() == "Nv %d" % dino.level, "o 'Nv' segue visível e com o mesmo texto")
	# acalma: some com fade
	for i in 82:
		dino.state_machine.tick(DT)
	_check(not dino.state_machine.is_aggressive, "acalmou depois de 8 s")
	view.tick(RULES.fade_seconds * 0.5)
	tag.tick(RULES.fade_seconds * 0.5)
	_check(view.alert_mark_visible() and view.alert_mark_alpha() > 0.0 and view.alert_mark_alpha() < 1.0, \
			"o '!' some com fade, não de uma vez")
	view.tick(RULES.fade_seconds)
	tag.tick(RULES.fade_seconds)
	_check(not view.alert_mark_visible(), "fim do fade: sem '!'")
	_check(tag.tag_color().is_equal_approx(calm_color), "o 'Nv' volta à cor normal")
