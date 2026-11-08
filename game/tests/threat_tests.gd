# SPDX-License-Identifier: MIT
class_name ThreatTests
extends TestSuite
## M1, etapa 4: `ThreatProfile` por espécie, ordem das fases, ameaça correndo de longe, mordida do Utahraptor (A12: dano 8,
## recarga 1,5 s) aplicada pela autoridade, log `dino_hit_player`, `reset_calm` ao atacar, folhas de 17 e 18 colunas e os
## sons no banco. A mordida nunca tira vida sozinha: o dino só pede (`attack_requested`).

const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
const PAQUI: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
const RAPTOR_PROFILE: ThreatProfile = preload("res://data/dino/utahraptor_threat.tres")
const PAQUI_PROFILE: ThreatProfile = preload("res://data/dino/paquicefalo_threat.tres")
const BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")
const TILE := 16.0
const DT := 0.05
const SOUND_IDS: Array[StringName] = [&"paqui_bufada", &"paqui_cabecada", &"raptor_rosnado", &"raptor_mordida", &"dino_dor"]


func run() -> void:
	_test_data()
	_test_phase_order()
	_test_threat_runs_when_far()
	_test_a12_cooldown()
	_test_miss_still_cools_down()
	_test_attack_resets_calm()
	_test_authority_applies_damage()
	_test_log_once_per_episode()
	_test_authority_rules()
	_test_area_only_for_large()
	_test_sheets()
	_test_view_and_sounds()


# ----------------------------------------------------------------------------- montagem

## Máquina do Utahraptor com o alvo parado a `tiles` à direita; `_sim` anda o corpo.
func _raptor(tiles: float) -> DinoStateMachine:
	var machine := _make_machine()
	machine.configure(RAPTOR, 40.0, TILE)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	machine.observe_target(Vector2(tiles * TILE, 0.0), true)
	return machine


## Simula `seconds` de corpo: aplica a direção desejada e a velocidade ao `self_position`, como o `Dino` faz na física.
func _sim(machine: DinoStateMachine, seconds: float, on_step: Callable = Callable()) -> void:
	for i in roundi(seconds / DT):
		machine.tick(DT)
		machine.self_position += machine.desired_direction * 40.0 * machine.speed_multiplier * DT
		machine.observe(machine.self_position, Vector2.ZERO, false)
		if on_step.is_valid():
			on_step.call()


## Quando cada golpe saiu (relógio da simulação) e se acertou.
func _record_strikes(machine: DinoStateMachine, clock: Array[float]) -> Array[Dictionary]:
	var strikes: Array[Dictionary] = []
	machine.struck.connect(func(in_reach: bool) -> void: strikes.append({"t": clock[0], "hit": in_reach}))
	return strikes


# ----------------------------------------------------------------------------- testes

func _test_data() -> void:
	_check(RAPTOR.threat_profile == RAPTOR_PROFILE and RAPTOR_PROFILE != null, "o Utahraptor tem o perfil de ameaça do .tres")
	_check(is_equal_approx(RAPTOR_PROFILE.threat_seconds, 0.8) and is_equal_approx(RAPTOR_PROFILE.damage, 8.0) \
			and is_equal_approx(RAPTOR_PROFILE.cooldown_s, 1.5) and is_equal_approx(RAPTOR_PROFILE.run_threat_tiles, 4.0), \
			"Utahraptor: ameaça 0,8 s, corre a mais de 4 tiles, mordida 8, recarga 1,5 s (do .tres)")
	_check(is_equal_approx(RAPTOR_PROFILE.attack_reach_px, 30.0) and is_equal_approx(RAPTOR_PROFILE.windup_s, 0.3), \
			"Utahraptor: alcance 30 px e aviso de 0,3 s")
	_check(is_equal_approx(PAQUI_PROFILE.damage, 6.0) and is_equal_approx(PAQUI_PROFILE.cooldown_s, 1.6) \
			and is_equal_approx(PAQUI_PROFILE.lunge_speed_px_s, 150.0), "Paquicéfalo: o perfil já está em .tres (cabeçada, etapa 5)")
	_check(PAQUI.threat_profile == null, "o Paquicéfalo ainda não usa o perfil (só persegue até a etapa 5)")


func _test_phase_order() -> void:
	var machine := _raptor(3.0)
	var phases: Array[Enums.ThreatPhase] = []
	var times: Dictionary = {}
	var clock: Array[float] = [0.0]
	machine.threat_phase_changed.connect(func(phase: Enums.ThreatPhase) -> void:
		phases.append(phase)
		times[phase] = times.get(phase, clock[0]))
	_check(machine.threat_phase == Enums.ThreatPhase.NONE, "calmo: sem fase de ameaça")
	machine.tick(DT)  # avista o alvo a 3 tiles e fica bravo
	_check(machine.is_aggressive and machine.threat_phase == Enums.ThreatPhase.THREAT, "bravo: começa pela ameaça")
	_check(machine.desired_direction == Vector2.ZERO, "alvo a menos de 4 tiles: a ameaça é uma pausa, parado")
	_sim(machine, 0.7)
	_check(machine.threat_phase == Enums.ThreatPhase.THREAT, "aos 0,75 s ainda é ameaça")
	_sim(machine, 0.2)
	_check(machine.threat_phase != Enums.ThreatPhase.THREAT, "passados 0,8 s a ameaça acaba")
	_sim(machine, 4.0)
	var expected: Array[Enums.ThreatPhase] = [Enums.ThreatPhase.THREAT, Enums.ThreatPhase.APPROACH,
			Enums.ThreatPhase.CIRCLE, Enums.ThreatPhase.WINDUP, Enums.ThreatPhase.LUNGE, Enums.ThreatPhase.RECOVER]
	_check(phases.slice(0, 6) == expected, "ordem: THREAT, APPROACH, CIRCLE, WINDUP, LUNGE, RECOVER (veio %s)" % [phases.slice(0, 6)])
	_check(phases.count(Enums.ThreatPhase.THREAT) == 1, "THREAT só na entrada do episódio, não a cada investida")
	_check(phases.count(Enums.ThreatPhase.LUNGE) >= 2, "o ciclo continua: investe de novo depois da recuperação")


func _test_threat_runs_when_far() -> void:
	var far := _raptor(8.0)
	far.tick(DT)
	_check(far.threat_phase == Enums.ThreatPhase.THREAT and far.threat_cycle.runs_threat, "alvo a 8 tiles: ameaça feita correndo")
	_check(far.desired_direction.is_equal_approx(Vector2.RIGHT), "na ameaça de longe ele corre em direção ao alvo, sem parar")
	_sim(far, 0.4)
	_check(far.self_position.x > 20.0 and far.threat_phase == Enums.ThreatPhase.THREAT, "durante a ameaça de longe o corpo avança")
	var edge := _raptor(4.0)
	edge.tick(DT)
	_check(not edge.threat_cycle.runs_threat, "alvo a exatamente 4 tiles: pausa (a corrida é para mais de 4)")
	var near := _raptor(4.5)
	near.tick(DT)
	_check(near.threat_cycle.runs_threat, "alvo a 4,5 tiles: corrida")


func _test_a12_cooldown() -> void:
	var machine := _raptor(3.0)
	var clock: Array[float] = [0.0]
	var strikes := _record_strikes(machine, clock)
	var steps: Callable = func() -> void: clock[0] += DT
	_sim(machine, 12.0, steps)
	_check(strikes.size() >= 4, "A12: em 12 s o raptor morde várias vezes (%d)" % strikes.size())
	var min_gap := INF
	for i in range(1, strikes.size()):
		min_gap = minf(min_gap, float(strikes[i]["t"]) - float(strikes[i - 1]["t"]))
	_check(min_gap >= RAPTOR_PROFILE.cooldown_s - 0.001, "A12: dois golpes nunca ficam a menos de 1,5 s (menor intervalo %.2f)" % min_gap)
	var within := strikes.filter(func(strike: Dictionary) -> bool: return float(strike["t"]) <= 8.4 and strike["hit"])
	_check(within.size() >= 4 and within.size() <= 6, "A12: em 8,4 s de contato saem 4 a 6 mordidas (%d), 8 de dano cada" % within.size())
	_check(is_equal_approx(RAPTOR_PROFILE.damage * 5.0, 40.0), "A12: 5 mordidas = 40 de vida")
	# Unidade: a recarga segura o aviso mesmo com a fase pronta.
	var cycle := ThreatCycle.new(RAPTOR_PROFILE, RandomNumberGenerator.new())
	cycle.begin(48.0, TILE)
	cycle.cooldown_left = 5.0
	var lunged: Array[bool] = [false]
	cycle.phase_changed.connect(func(phase: Enums.ThreatPhase) -> void: lunged[0] = lunged[0] or phase == Enums.ThreatPhase.LUNGE)
	for i in 90:  # 4,5 s com o alvo a 30 px (no alcance)
		cycle.tick(DT, 30.0, TILE)
	_check(not lunged[0] and cycle.phase == Enums.ThreatPhase.WINDUP, "com recarga pendente o raptor fica no aviso e não investe")
	for i in 40:
		cycle.tick(DT, 30.0, TILE)
	_check(lunged[0], "vencida a recarga ele investe")


func _test_miss_still_cools_down() -> void:
	var machine := _raptor(3.0)
	var hits: Array[bool] = []
	machine.struck.connect(func(in_reach: bool) -> void: hits.append(in_reach))
	var moved: Array[bool] = [false]
	machine.threat_phase_changed.connect(func(phase: Enums.ThreatPhase) -> void:
		if phase == Enums.ThreatPhase.LUNGE and not moved[0]:
			moved[0] = true
			machine.observe_target(machine.self_position + Vector2(100.0, 0.0), true))  # o alvo some do alcance ao investir
	_sim(machine, 3.0)
	_check(hits.size() >= 1 and not hits[0], "alvo fora do alcance no fim da investida: a mordida erra")
	_check(machine.threat_cycle.cooldown_left > 0.0 or machine.threat_cycle.phase == Enums.ThreatPhase.RECOVER,
			"o erro também gasta a recarga")


func _test_attack_resets_calm() -> void:
	var machine := _raptor(3.0)
	var clock: Array[float] = [0.0]
	var strikes := _record_strikes(machine, clock)
	machine.tick(DT)
	_sim(machine, 3.0)
	_check(strikes.size() >= 1, "o raptor mordeu em 3 s")
	var calm := machine.calm_left()
	_check(calm > 6.0, "ao atacar o relógio de calma volta ao início (sobram %.1f s)" % calm)
	# Sem `reset_calm`, 8 s depois ele acalmaria; mordendo, continua bravo além disso.
	_sim(machine, 7.0)
	_check(machine.is_aggressive, "mordendo, aos 10 s ele segue bravo (o relógio de 8 s é zerado a cada golpe)")


## Raptor real no mundo: corpo do Dino sem física, jogador a `gap` px, tudo pela autoridade.
func _arena(gap: float) -> Dictionary:
	var dino := _spawn_dino()
	dino.stats = RAPTOR
	dino._apply_level()
	dino.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	dino.global_position = Vector2.ZERO
	dino.state_machine.rng.seed = 7  # rodeio reproduzível
	var player := _spawn_player()
	player.set_physics_process(false)
	player.global_position = Vector2(gap, 0.0)
	dino.target_locator = func() -> Array: return [player]
	var authority: WorldAuthority = player.authority
	authority.register(dino)
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void:
		if code == "dino_hit_player":
			events.append("%s|%s" % [params.get("species"), params.get("amount")]))
	return {"dino": dino, "player": player, "authority": authority, "events": events}


func _drive(dino: Dino, seconds: float) -> void:
	for i in roundi(seconds / DT):
		dino.observe_targets()
		dino.state_machine.tick(DT)


func _test_authority_applies_damage() -> void:
	var arena := _arena(20.0)
	var dino: Dino = arena["dino"]
	var player: Player = arena["player"]
	var before := player.health.current_health
	_drive(dino, 0.6)
	_check(is_equal_approx(player.health.current_health, before), "ameaça e aviso não tiram vida")
	_drive(dino, 1.6)
	_check(is_equal_approx(player.health.current_health, before - 8.0), "a mordida tira 8 de vida, aplicada pela autoridade")
	_drive(dino, 2.0)
	_check(is_equal_approx(player.health.current_health, before - 16.0), "a segunda mordida só vem depois da recarga (-16)")
	# O dino não aplica dano sozinho: sem a autoridade ouvindo, nada acontece.
	var lone := _spawn_dino()
	lone.stats = RAPTOR
	lone._apply_level()
	lone.set_physics_process(false)
	lone.state_machine.set_physics_process(false)
	var victim := _spawn_player()
	victim.set_physics_process(false)
	victim.global_position = Vector2(20.0, 0.0)
	lone.target_locator = func() -> Array: return [victim]
	var victim_before := victim.health.current_health
	_drive(lone, 3.0)
	_check(is_equal_approx(victim.health.current_health, victim_before), "sem autoridade registrada, a mordida não tira vida")


func _test_log_once_per_episode() -> void:
	var arena := _arena(20.0)
	var dino: Dino = arena["dino"]
	var events: Array[String] = arena["events"]
	_drive(dino, 6.0)
	_check(events == ["Utahraptor|8.0"], "dino_hit_player sai UMA vez no episódio, com espécie e dano (%s)" % [events])
	dino.state_machine.transition_to(Enums.DinoStateId.IDLE)
	dino.state_machine.transition_to(Enums.DinoStateId.AGGRESSIVE)
	_drive(dino, 4.0)
	_check(events.size() == 2, "episódio novo, aviso novo")
	_check(GameMessages.text_of("dino_hit_player", {"species": "Utahraptor", "amount": 8.0}) == "Utahraptor te acertou: -8.0 de vida.",
			"o texto em português do log")


func _test_authority_rules() -> void:
	var arena := _arena(20.0)
	var dino: Dino = arena["dino"]
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	var dino_id := authority.id_of(dino)
	var player_id := authority.id_of(player)
	var before := player.health.current_health
	dino.owner_player_id = player.player_id
	_check(authority.resolve_dino_attack(dino_id, player_id, 8.0).is_empty() and is_equal_approx(player.health.current_health, before),
			"o dono nunca é atingido pelo próprio dino")
	dino.owner_player_id = ""
	dino.attack_requested.emit(player, 999.0, 1)
	_check(is_equal_approx(player.health.current_health, before), "pedido de dano maior que o do perfil é recusado")
	player.global_position = Vector2(200.0, 0.0)
	dino.attack_requested.emit(player, 8.0, 1)
	_check(is_equal_approx(player.health.current_health, before), "pedido fora do alcance real é recusado")
	player.global_position = Vector2(20.0, 0.0)
	dino.attack_requested.emit(player, 8.0, 1)
	_check(is_equal_approx(player.health.current_health, before - 8.0), "no alcance e com o dano do perfil, passa")
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	_check(authority.resolve_dino_attack(dino_id, player_id, 8.0).is_empty(), "dino dormindo não ataca")
	# Domado de outro dono: só com PvP.
	var wild := _spawn_dino()
	wild.stats = RAPTOR
	var other := _tamed_of(wild, "outro")
	authority.register(other)
	var tamed := _spawn_dino()
	authority.register(tamed)
	tamed.torpor.add_torpor(tamed.torpor.max_torpor)
	tamed.state_machine.mark_tamed()
	tamed.owner_player_id = "local"
	var other_id := authority.id_of(other)
	var tamed_id := authority.id_of(tamed)
	authority.pvp_enabled = false
	_check(authority.resolve_dino_attack(tamed_id, other_id, 5.0).is_empty(), "sem PvP o domado não fere o domado de outro dono")
	authority.pvp_enabled = true
	_check(authority.resolve_dino_attack(tamed_id, other_id, 5.0).has(other_id), "com PvP ele fere o domado de outro dono")
	other.owner_player_id = "local"
	_check(authority.resolve_dino_attack(tamed_id, other_id, 5.0).is_empty(), "mesmo dono nunca, nem com PvP")


func _tamed_of(dino: Dino, owner: String) -> Dino:
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = owner
	return dino


func _test_area_only_for_large() -> void:
	var area := AreaAttackRules.new()
	var medium_stats := DinoBaseStats.new()
	medium_stats.id = "medio_de_teste"
	medium_stats.size = Enums.DinoSize.MEDIUM
	medium_stats.area_attack = area
	var large_stats := DinoBaseStats.new()
	large_stats.id = "grande_de_teste"
	large_stats.size = Enums.DinoSize.LARGE
	large_stats.area_attack = area
	for large in [false, true]:
		var attacker := _spawn_dino()
		attacker.stats = large_stats if large else medium_stats
		attacker.set_physics_process(false)
		attacker.position = Vector2(-400.0, 0.0)
		_tamed_of(attacker, "local")
		var main := _spawn_dino()
		main.set_physics_process(false)
		main.position = Vector2(0.0, 0.0)
		var near := _spawn_dino()
		near.set_physics_process(false)
		near.position = Vector2(TILE, 0.0)
		var player := _spawn_player()
		player.player_id = "local"
		var authority: WorldAuthority = player.authority
		authority.register(attacker)
		authority.register(main)
		authority.register(near)
		var hits := authority.resolve_dino_attack(authority.id_of(attacker), authority.id_of(main), 10.0)
		_check(hits.has(authority.id_of(main)) and hits.has(authority.id_of(near)) == large,
				"%s: golpe %s" % ["Grande" if large else "Médio", "atinge o vizinho (área)" if large else "só o alvo principal"])


func _test_sheets() -> void:
	var paqui := SpriteSheetDef.from_json_file("res://assets/sprites/dinos/paquicefalo.json")
	var raptor := SpriteSheetDef.from_json_file("res://assets/sprites/dinos/utahraptor.json")
	_check(paqui.is_valid() and paqui.columns == 18 and paqui.rows == 8, "folha do Paquicéfalo: 18 colunas x 8 linhas")
	_check(raptor.is_valid() and raptor.columns == 17 and raptor.rows == 4, "folha do Utahraptor: 17 colunas x 4 linhas")
	_check(paqui.animations["threat"]["columns"] == [11, 12, 13, 14] and paqui.animations["headbutt"]["columns"] == [15, 16, 17],
			"Paquicéfalo: threat 11-14 e headbutt 15-17")
	_check(raptor.animations["threat"]["columns"] == [11, 12, 13] and raptor.animations["bite"]["columns"] == [14, 15, 16],
			"Utahraptor: threat 11-13 e bite 14-16")
	for pair: Array in [["paquicefalo", paqui], ["utahraptor", raptor]]:
		var texture := load("res://assets/sprites/dinos/%s.png" % pair[0]) as Texture2D
		var sheet: SpriteSheetDef = pair[1]
		_check(texture != null and texture.get_size() == Vector2(sheet.frame_size * Vector2i(sheet.columns, sheet.rows)),
				"%s: o PNG tem o tamanho que o JSON diz" % pair[0])
	_check(SpriteFacing.facing_for(Vector2(1.0, 1.0), SpriteFacing.DOWN, raptor.rows) <= SpriteFacing.RIGHT,
			"folha de 4 direções (raptor): a diagonal cai numa das 4 direções")
	_check(SpriteFacing.facing_for(Vector2(1.0, 1.0), SpriteFacing.DOWN, paqui.rows) == SpriteFacing.DOWN_RIGHT,
			"folha de 8 direções (Paquicéfalo): a diagonal usa a linha própria")
	for animation: String in ["threat", "headbutt"]:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/dinos/paquicefalo.png")
		_check(SpriteFacing.fit_sheet(sprite, paqui) and sprite.hframes == 18 and paqui.column_at(animation, 0.0) >= 11,
				"o Sprite2D se ajusta à folha de 18 colunas (%s)" % animation)
		sprite.free()


func _test_view_and_sounds() -> void:
	for id in SOUND_IDS:
		var stream := BANK.streams.get(id) as AudioStreamWAV
		_check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and SfxPlayer.has(id),
				"som %s no banco, PCM sem loop" % id)
	var arena := _arena(48.0)
	var dino: Dino = arena["dino"]
	var player: Player = arena["player"]
	var view := DinoView.new()
	view.dino = dino
	_root.add_child(view)
	_track.call(view)
	view.tick(DT)
	_check(dino.visual.texture.get_size() == Vector2(544.0, 128.0), "a view troca o sprite pela folha do raptor")
	_check(dino.visual.hframes == 17 and dino.visual.vframes == 4, "a view ajusta o sprite à folha de 17 x 4 do raptor")
	dino.observe_targets()
	dino.state_machine.tick(DT)  # avista e fica bravo: THREAT a 3 tiles (pausa)
	_check(SfxPlayer.last_played == &"raptor_rosnado", "ameaça: toca o rosnado")
	view.tick(DT)
	_check(dino.visual.frame_coords.x >= 11 and dino.visual.frame_coords.x <= 13, "ameaça: quadro da animação threat (11-13)")
	_check(dino.visual.frame_coords.y == SpriteFacing.RIGHT, "ameaça: vira para o alvo (direita)")
	player.global_position = Vector2(20.0, 0.0)
	var heard: Array[bool] = [false]
	dino.state_machine.struck.connect(func(_in_reach: bool) -> void: heard[0] = heard[0] or SfxPlayer.last_played == &"raptor_mordida")
	_drive(dino, 3.0)  # ameaça 0,8 s + rodeio até 1 s + aviso 0,3 s: o golpe sai até ~2,2 s (o sorteio do rodeio não é fixo)
	_check(heard[0], "golpe: toca a mordida")
	dino.health.take_damage(1.0)
	_check(SfxPlayer.last_played == &"dino_dor", "dano recebido: toca dino_dor")
