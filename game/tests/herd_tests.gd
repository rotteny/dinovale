# SPDX-License-Identifier: MIT
class_name HerdTests
extends TestSuite
## M1, etapa 5: revide do Paquicéfalo e chamada do bando. A8 (bando de 3 e de 4), A10 (cabeçada: dano 6, recarga 1,6 s,
## empurrão de 24 px, para no obstáculo, não empurra caído), A11 (vida baixa foge e volta depois de 10 s com o atacante
## a mais de 10 tiles), limite de ajudantes, teto de 12 s do ajudante, bando de outro lugar, domado e dormindo não ajudam,
## e "sem fogo amigo" (a cabeçada só acerta o jogador; a regra de `pvp` vale para o domado).

const PAQUI: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
const PROFILE: ThreatProfile = preload("res://data/dino/paquicefalo_threat.tres")
const HERD_RULES: HerdCallRules = preload("res://data/balance/herd_call_rules.tres")
const AGGRESSION: AggressionRules = preload("res://data/balance/aggression_rules.tres")
const TILE := 16.0
## Ponto longe de tudo (os testes anteriores deixam corpos perto da origem): para o teste de colisão do empurrão.
const FAR_Y := 5000.0
const DT := 0.05
const HERD := "g1.0"
## Jogador a 60 px do golpeado; B e C são os dois mais próximos dele, D o mais longe (todos a menos de 8 tiles do golpeado).
const STRUCK_AT := Vector2.ZERO
const PLAYER_AT := Vector2(60.0, 0.0)
const B_AT := Vector2(30.0, -20.0)
const C_AT := Vector2(-40.0, 10.0)
const D_AT := Vector2(-100.0, 0.0)
## Com o jogador em (20, 0): todos no alcance do golpe (a elipse pesa o vertical), então a autoridade confirma o dano.
const NEAR_B := Vector2(30.0, -5.0)
const NEAR_C := Vector2(10.0, 10.0)


func run() -> void:
	_test_data()
	_test_band_of_three()
	_test_band_of_four()
	_test_helper_limit()
	_test_who_does_not_help()
	_test_helper_time_cap()
	_test_helper_struck_becomes_principal()
	_test_aggressor_filter()
	_test_a10_damage_and_cooldown()
	await _test_a10_knockback()
	_test_no_friendly_fire()
	_test_area_attack_null_hits_one()
	_test_a11_flee_machine()
	_test_flee_in_world()
	_test_herd_id_from_member_id()


# ----------------------------------------------------------------------------- montagem

## Jogador com vida folgada (os testes de tempo não podem acabar com ele) e um Paquicéfalo por posição, todos do bando `HERD`.
func _band(positions: Array[Vector2], player_at: Vector2 = PLAYER_AT) -> Dictionary:
	var player := _spawn_player()
	player.set_physics_process(false)
	player.global_position = player_at
	player.health.max_health = 100000.0
	player.health.current_health = 100000.0
	var authority: WorldAuthority = player.authority
	var dinos: Array[Dino] = []
	for at in positions:
		dinos.append(_paqui(at, player, authority))
	return {"player": player, "authority": authority, "dinos": dinos}


func _paqui(at: Vector2, player: Player, authority: WorldAuthority) -> Dino:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	dino.global_position = at
	dino.herd_id = HERD
	dino.state_machine.rng.seed = 7
	dino.target_locator = func() -> Array: return [player]
	authority.register(dino)
	return dino


## Faz o ciclo do dino dar um golpe NOVO (fase de golpe, recarga correndo) e pede o dano em `target`, como o `Dino` faria.
func _strike(dino: Dino, target: Node2D) -> void:
	if not dino.state_machine.is_aggressive:
		dino.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	var cycle := dino.state_machine.threat_cycle
	cycle._enter(Enums.ThreatPhase.LUNGE)
	cycle.cooldown_left = cycle.profile.cooldown_s
	cycle.strike_count += 1
	dino.attack_requested.emit(target, PAQUI.base_damage, dino.state_machine.episode_id)


func _hit(dino: Dino, player: Player) -> void:
	dino.receive_hit(2.0, 0.0, TamingRules.ATTACKER_PLAYER, player.player_id)


## Passa `seconds` de jogo: autoridade (bando) e cada dino, como os quadros fariam.
func _drive(band: Dictionary, seconds: float) -> void:
	var authority: WorldAuthority = band["authority"]
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	for i in roundi(seconds / DT):
		authority.tick_herd(DT)
		for dino in dinos:
			dino.observe_targets()
			dino.state_machine.tick(DT)


func _angry(band: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	for dino: Dino in band["dinos"]:
		out.append(dino.state_machine.is_aggressive)
	return out


# ----------------------------------------------------------------------------- testes

func _test_data() -> void:
	_check(PAQUI.threat_profile == PROFILE and is_equal_approx(PAQUI.base_damage, 6.0),
			"o Paquicéfalo usa o perfil do .tres e dano 6 (base_damage)")
	_check(PAQUI.attacker_kind == TamingRules.ATTACKER_HERBIVORE, "atacante herbívoro")
	_check(is_equal_approx(HERD_RULES.call_radius_tiles, 8.0) and is_equal_approx(HERD_RULES.call_delay_s, 0.5) \
			and HERD_RULES.max_helpers == 2 and is_equal_approx(HERD_RULES.helper_max_seconds, 12.0), \
			"chamada do bando: 8 tiles, 0,5 s, 2 ajudantes, teto de 12 s (do .tres)")
	_check(is_equal_approx(AGGRESSION.flee_health_ratio, 0.25) and is_equal_approx(AGGRESSION.flee_resume_seconds, 10.0) \
			and is_equal_approx(AGGRESSION.flee_resume_tiles, 10.0), "fuga: abaixo de 25%, volta em 10 s com o atacante a 10 tiles")
	_check(is_equal_approx(PROFILE.knockback_px, 24.0) and is_equal_approx(PROFILE.knockback_seconds, 0.15), "empurrão de 24 px em 0,15 s")


## A8: bando de 3, golpe em um, 0,5 s depois os 2 outros entram, com ameaça própria.
func _test_band_of_three() -> void:
	var band := _band([STRUCK_AT, B_AT, C_AT])
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	_hit(dinos[0], band["player"])
	_check(_angry(band) == [true, false, false], "no golpe só o golpeado fica bravo")
	_drive(band, 0.4)
	_check(_angry(band) == [true, false, false], "aos 0,4 s os ajudantes ainda não entraram")
	_drive(band, 0.2)
	_check(_angry(band) == [true, true, true], "A8: aos 0,6 s os 2 outros entraram")
	_check(dinos[1].state_machine.is_helper and not dinos[0].state_machine.is_helper, "só os chamados são ajudantes")
	_check(dinos[1].state_machine.episode_id == 1 and dinos[1].state_machine.threat_phase != Enums.ThreatPhase.NONE, \
			"o ajudante tem a ameaça própria")


## A8: bando de 4, entram exatamente 2 (os mais próximos do jogador) e o 4º não anda.
func _test_band_of_four() -> void:
	var band := _band([STRUCK_AT, B_AT, C_AT, D_AT])
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	_hit(dinos[0], band["player"])
	_drive(band, 1.0)
	_check(_angry(band) == [true, true, true, false], "A8: bando de 4: entram 2 e o 4º continua pastando (%s)" % [_angry(band)])
	_check(dinos[3].state_machine.desired_direction == Vector2.ZERO and dinos[3].global_position == D_AT, "o 4º não anda")


func _test_helper_limit() -> void:
	var band := _band([STRUCK_AT, B_AT, C_AT, D_AT])
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	var authority: WorldAuthority = band["authority"]
	_hit(dinos[0], band["player"])
	_hit(dinos[0], band["player"])  # segunda chamada ainda dentro do atraso: não escala ninguém a mais
	_check(authority.herd.pending_count() == 2, "dois golpes seguidos escalam só 2 (%d)" % authority.herd.pending_count())
	_drive(band, 1.0)
	_hit(dinos[0], band["player"])
	_hit(dinos[1], band["player"])  # o ajudante golpeado vira principal, mas o bando já tem 2 ajudantes (ele não conta mais)
	_drive(band, 1.0)
	var count := 0
	for dino in dinos:
		if dino.state_machine.is_aggressive:
			count += 1
	_check(count <= 3, "nunca passa de 1 principal + 2 ajudantes (%d bravos)" % count)
	_check(not dinos[3].state_machine.is_aggressive, "o 4º segue de fora (limite max_helpers)")


func _test_who_does_not_help() -> void:
	# Outro bando, tamanho de domado, dormindo, fora de 8 tiles e morto: ninguém ajuda.
	var band := _band([STRUCK_AT, B_AT, C_AT, D_AT, Vector2(-140.0, 0.0)])
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	dinos[1].herd_id = "g2.0"
	dinos[2].state_machine.is_tamed = true
	dinos[2].owner_player_id = "outro_dono"
	dinos[3].torpor.add_torpor(100.0)
	_hit(dinos[0], band["player"])
	_drive(band, 1.0)
	_check(_angry(band) == [true, false, false, false, false], \
			"outro bando, domado, dormindo e a mais de 8 tiles não ajudam (%s)" % [_angry(band)])
	# Bando de 1 (herd_id vazio): o golpe não chama ninguém.
	var lone := _band([STRUCK_AT, B_AT])
	var lone_dinos: Array[Dino] = []
	lone_dinos.assign(lone["dinos"])
	lone_dinos[0].herd_id = ""
	lone_dinos[1].herd_id = ""
	_hit(lone_dinos[0], lone["player"])
	_drive(lone, 1.0)
	_check(_angry(lone) == [true, false], "sem bando, ninguém é chamado")
	# Dormir ou ser domado no meio do atraso cancela a entrada.
	var late := _band([STRUCK_AT, B_AT, C_AT])
	var late_dinos: Array[Dino] = []
	late_dinos.assign(late["dinos"])
	_hit(late_dinos[0], late["player"])
	_drive(late, 0.3)
	late_dinos[1].torpor.add_torpor(100.0)
	_drive(late, 0.5)
	_check(not late_dinos[1].state_machine.is_aggressive and late_dinos[2].state_machine.is_aggressive, "quem dormiu no atraso não entra")


## O ajudante some do estado bravo aos 12 s da entrada, mesmo brigando; o principal segue (sem teto, só o limite do episódio).
func _test_helper_time_cap() -> void:
	var band := _band([STRUCK_AT, NEAR_B, NEAR_C], Vector2(20.0, 0.0))  # perto: todos brigam e o relógio de 8 s não acalma
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	_hit(dinos[0], band["player"])
	_drive(band, 0.6)  # entraram
	_drive(band, 11.0)
	_check(_angry(band) == [true, true, true], "aos ~11,6 s o ajudante ainda briga (%s)" % [_angry(band)])
	_drive(band, 1.0)
	_check(_angry(band) == [true, false, false], "aos ~12,6 s o teto de 12 s tirou os ajudantes (%s)" % [_angry(band)])


## O Passivo bravo mira só quem bateu (ou quem o bando disse), e esquece o agressor ao acalmar.
func _test_aggressor_filter() -> void:
	var band := _band([STRUCK_AT], Vector2(80.0, 0.0))
	var dino: Dino = band["dinos"][0]
	var first: Player = band["player"]
	first.player_id = "a"
	var second := _spawn_player()
	second.set_physics_process(false)
	second.player_id = "b"
	second.global_position = Vector2(30.0, 0.0)  # mais perto que o primeiro
	dino.target_locator = func() -> Array: return [first, second]
	dino.receive_hit(2.0, 0.0, TamingRules.ATTACKER_PLAYER, "a")
	_check(dino.state_machine.target_position == first.global_position, "bravo por golpe: mira quem bateu, não o mais perto")
	dino.state_machine.transition_to(Enums.DinoStateId.IDLE)
	_check(dino._aggressor_id == "", "ao acalmar, esquece o agressor")
	_check(dino.join_call("b", HERD_RULES.helper_max_seconds) and dino.state_machine.target_position == second.global_position, \
			"a chamada do bando traz o atacante explícito (não o agressor antigo)")
	dino.state_machine.transition_to(Enums.DinoStateId.IDLE)
	var bystander := _paqui(Vector2(-20.0, 0.0), first, band["authority"])
	bystander.target_locator = func() -> Array: return [first, second]
	_check(bystander.join_call("a", HERD_RULES.helper_max_seconds) and bystander.state_machine.target_position == first.global_position, \
			"o ajudante chamado contra A mira A, mesmo com B mais perto")


func _test_helper_struck_becomes_principal() -> void:
	var band := _band([STRUCK_AT, NEAR_B, NEAR_C], Vector2(20.0, 0.0))
	var dinos: Array[Dino] = []
	dinos.assign(band["dinos"])
	_hit(dinos[0], band["player"])
	_drive(band, 0.6)
	_hit(dinos[1], band["player"])
	_check(not dinos[1].state_machine.is_helper, "o ajudante golpeado vira principal")
	_drive(band, 12.0)
	_check(_angry(band) == [true, true, false], "o principal passa dos 12 s; o outro ajudante saiu (%s)" % [_angry(band)])


## A10: dano 6 pela autoridade e recarga de 1,6 s entre cabeçadas.
func _test_a10_damage_and_cooldown() -> void:
	var band := _band([STRUCK_AT])
	var dino: Dino = band["dinos"][0]
	var player: Player = band["player"]
	player.global_position = Vector2(20.0, 0.0)
	_hit(dino, player)
	var times: Array[float] = []
	var seen := player.health.current_health
	var t := 0.0
	for i in roundi(8.0 / DT):
		t += DT
		dino.observe_targets()
		dino.state_machine.tick(DT)
		if player.health.current_health < seen:
			_check(is_equal_approx(seen - player.health.current_health, 6.0), "cada cabeçada tira 6")
			times.append(t)
		seen = player.health.current_health
	_check(times.size() >= 3, "o Paquicéfalo cabeceia repetidamente (%d golpes)" % times.size())
	var spaced := true
	for i in range(1, times.size()):
		spaced = spaced and times[i] - times[i - 1] >= 1.6 - DT
	_check(spaced, "A10: recarga de 1,6 s entre cabeçadas (%s)" % [times])


## A10: empurra 24 px em 0,15 s, para no primeiro obstáculo e não empurra caído.
func _test_a10_knockback() -> void:
	var band := _band([Vector2(0.0, FAR_Y)])  # longe dos corpos que os outros testes deixaram na árvore
	var dino: Dino = band["dinos"][0]
	var player: Player = band["player"]
	var authority: WorldAuthority = band["authority"]
	player.global_position = Vector2(20.0, FAR_Y)
	_strike(dino, player)
	_check(is_equal_approx(player.health.current_health, 100000.0 - 6.0), "a autoridade aplicou os 6")
	_check(player.knockback_left().is_equal_approx(Vector2(24.0, 0.0)),
			"empurrão de 24 px para longe do dino (%s)" % [player.knockback_left()])
	var start := player.global_position
	for i in 3:
		await _root.get_tree().physics_frame
		player.step_knockback(0.05)
	_check(player.global_position.distance_to(start) > 23.9 and player.global_position.y == start.y \
			and player.knockback_left() == Vector2.ZERO, \
			"empurrou 24 px em 0,15 s (%s)" % [player.global_position - start])
	# Obstáculo a 10 px: para no primeiro.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8.0, 200.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector2(200.0, FAR_Y)
	_root.add_child(wall)
	_track.call(wall)
	player.global_position = Vector2(180.0, FAR_Y)
	dino.global_position = Vector2(160.0, FAR_Y)
	await _root.get_tree().physics_frame
	var before := player.global_position
	_strike(dino, player)
	for i in 4:
		await _root.get_tree().physics_frame
		player.step_knockback(0.05)
	var moved := player.global_position.x - before.x
	_check(moved < 20.0 and moved >= 0.0 and player.knockback_left() == Vector2.ZERO, "para no obstáculo (andou %.1f px)" % moved)
	# Caído (sem vida): leva o dano, não é empurrado.
	player.global_position = Vector2(20.0, FAR_Y + 100.0)
	dino.global_position = Vector2(0.0, FAR_Y + 100.0)
	player.health.current_health = 4.0
	_strike(dino, player)
	_check(player.health.is_dead() and player.knockback_left() == Vector2.ZERO, "quem caiu não é empurrado")
	_check(authority != null, "autoridade viva")


func _test_no_friendly_fire() -> void:
	var band := _band([STRUCK_AT, B_AT])
	var attacker: Dino = band["dinos"][0]
	var mate: Dino = band["dinos"][1]
	var authority: WorldAuthority = band["authority"]
	var attacker_id := authority.id_of(attacker)
	var mate_id := authority.id_of(mate)
	var before := mate.health.current_health
	_check(authority.resolve_dino_attack(attacker_id, mate_id, 6.0).is_empty(), "a cabeçada não acerta outro Paquicéfalo do bando")
	_strike(attacker, mate)
	_check(is_equal_approx(mate.health.current_health, before), "nem pelo pedido da autoridade")
	# Domado: nunca por selvagem; do mesmo dono nunca; de outro dono só com pvp e só por domado.
	var tamed_a := _paqui(Vector2(0.0, 40.0), band["player"], authority)
	var tamed_b := _paqui(Vector2(0.0, 60.0), band["player"], authority)
	var tamed_c := _paqui(Vector2(0.0, 80.0), band["player"], authority)
	for pair: Array in [[tamed_a, "dono_1"], [tamed_b, "dono_1"], [tamed_c, "dono_2"]]:
		(pair[0] as Dino).state_machine.is_tamed = true
		(pair[0] as Dino).owner_player_id = pair[1]
	var a_id := authority.id_of(tamed_a)
	var b_id := authority.id_of(tamed_b)
	var c_id := authority.id_of(tamed_c)
	for pvp in [false, true]:
		authority.pvp_enabled = pvp
		_check(authority.resolve_dino_attack(attacker_id, a_id, 6.0).is_empty(), "selvagem não acerta domado (pvp %s)" % pvp)
		_check(authority.resolve_dino_attack(a_id, b_id, 6.0).is_empty(), "domado não acerta domado do mesmo dono (pvp %s)" % pvp)
	authority.pvp_enabled = false
	_check(authority.resolve_dino_attack(a_id, c_id, 6.0).is_empty(), "sem pvp, domado de outro dono fica a salvo")
	authority.pvp_enabled = true
	_check(authority.resolve_dino_attack(a_id, c_id, 6.0).has(c_id), "a regra de pvp continua valendo (outro dono, pvp ligado)")
	# O ciclo inteiro com o bando em volta: só o jogador perde vida.
	var arena := _band([STRUCK_AT, B_AT, C_AT])
	var dinos: Array[Dino] = []
	dinos.assign(arena["dinos"])
	var player: Player = arena["player"]
	player.global_position = Vector2(20.0, 0.0)
	_hit(dinos[0], player)
	_drive(arena, 6.0)
	_check(player.health.current_health < 100000.0, "o bando acerta o jogador")
	_check(is_equal_approx(dinos[1].health.current_health, dinos[1].health.max_health) \
			and is_equal_approx(dinos[2].health.current_health, dinos[2].health.max_health), "e nenhum membro do bando")


func _test_area_attack_null_hits_one() -> void:
	_check(PAQUI.area_rules() == null, "Paquicéfalo não tem golpe em área")
	var band := _band([STRUCK_AT, Vector2(0.0, 30.0)])
	var attacker: Dino = band["dinos"][0]
	var bystander: Dino = band["dinos"][1]
	var player: Player = band["player"]
	player.global_position = Vector2(20.0, 0.0)
	var authority: WorldAuthority = band["authority"]
	var hits := authority.resolve_dino_attack(authority.id_of(attacker), authority.id_of(player), 6.0)
	_check(hits.size() == 1 and hits.has(authority.id_of(player)), "a cabeçada acerta um alvo só")
	_check(is_equal_approx(bystander.health.current_health, bystander.health.max_health), "o vizinho do jogador não leva dano")


## A11 (máquina): vida abaixo de 25% foge do atacante, sem revidar; só volta depois de 10 s com o atacante a mais de 10 tiles.
func _test_a11_flee_machine() -> void:
	var machine := _make_machine()
	machine.configure(PAQUI, 40.0, TILE)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	machine.observe_target(Vector2(30.0, 0.0), true)
	machine.observe_health(0.2)
	var strikes: Array[bool] = []
	machine.struck.connect(func(in_reach: bool) -> void: strikes.append(in_reach))
	machine.provoke()
	_check(machine.is_aggressive and machine.should_flee(), "vida a 20%: bravo e foge")
	var target := Vector2(30.0, 0.0)
	var t := 0.0
	var early_calm := false
	for i in roundi(9.5 / DT):
		t += DT
		machine.tick(DT)
		machine.self_position += machine.desired_direction * 40.0 * machine.speed_multiplier * DT
		machine.observe(machine.self_position, Vector2.ZERO, false)
		machine.observe_target(target, true)
		early_calm = early_calm or not machine.is_aggressive
	_check(strikes.is_empty(), "A11: não revida enquanto foge")
	_check(machine.self_position.x < -300.0 and is_equal_approx(machine.speed_multiplier, 2.0), \
			"foge para longe do atacante na velocidade brava (x %.0f, vel x%.1f)" % [machine.self_position.x, machine.speed_multiplier])
	_check(not early_calm and machine.is_aggressive, "aos 9,5 s ainda foge (ignora o relógio de 8 s e a distância)")
	for i in roundi(1.0 / DT):
		machine.tick(DT)
		machine.self_position += machine.desired_direction * 40.0 * machine.speed_multiplier * DT
		machine.observe(machine.self_position, Vector2.ZERO, false)
	_check(not machine.is_aggressive, "aos 10 s, com o atacante a mais de 10 tiles, volta ao natural")
	# Atacante colado (a menos de 10 tiles): continua fugindo depois dos 10 s.
	var close := _make_machine()
	close.configure(PAQUI, 40.0, TILE)
	close.observe(Vector2.ZERO, Vector2.ZERO, false)
	close.observe_target(Vector2(30.0, 0.0), true)
	close.observe_health(0.2)
	close.provoke()
	for i in roundi(12.0 / DT):
		close.tick(DT)
		close.observe_target(close.self_position + Vector2(40.0, 0.0), true)  # o atacante acompanha
	_check(close.is_aggressive, "com o atacante a menos de 10 tiles não volta aos 10 s")
	# Com 30% de vida não foge: revida.
	var healthy := _make_machine()
	healthy.configure(PAQUI, 40.0, TILE)
	healthy.observe(Vector2.ZERO, Vector2.ZERO, false)
	healthy.observe_target(Vector2(20.0, 0.0), true)
	healthy.observe_health(0.3)
	healthy.provoke()
	_check(not healthy.should_flee(), "com 30% de vida revida (não foge)")


func _test_flee_in_world() -> void:
	var band := _band([STRUCK_AT])
	var dino: Dino = band["dinos"][0]
	var player: Player = band["player"]
	player.global_position = Vector2(20.0, 0.0)
	dino.health.take_damage(dino.health.max_health * 0.8)
	var before := player.health.current_health
	_hit(dino, player)
	_drive(band, 4.0)
	_check(is_equal_approx(player.health.current_health, before), "ferido, o Paquicéfalo não cabeceia")
	_check(dino.state_machine.is_aggressive and dino.state_machine.desired_direction.x < 0.0, "e corre para longe do jogador")


func _test_herd_id_from_member_id() -> void:
	_check(WildPopulation.herd_of("g7.0.2") == "g7.0" and WildPopulation.herd_of("g7.1.2") == "g7.1", "bando = vaga + geração")


