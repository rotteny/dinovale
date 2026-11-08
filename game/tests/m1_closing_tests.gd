# SPDX-License-Identifier: MIT
class_name M1ClosingTests
extends DownedTests
## M1, etapa 7: fechamento. (1) Os números em uso nos `.tres` batem com as tabelas da especificação
## (`m1-ameaca-e-corpo.md`, seções 1 a 5 e 10), com as exceções documentadas lá. (2) O dano em área continua sem efeito
## nas duas espécies do jogo. (3) Carga: 32 dinos ativos, bravos ou caçando ao mesmo tempo, no mapa real com a grade de
## navegação ligada. As regressões de fome por atividade, stamina, coleta por golpes (intervalo de 1 a 2 s) e itens no
## chão já têm suíte própria (`HungerTests`, `DinoStateTests`, `GatherDamageTests`, `GroundItemTests`).

const SPECIES_PAQUI := "res://data/dino/placeholder_dino.tres"
const SPECIES_RAPTOR := "res://data/dino/utahraptor.tres"
## Campina: terreno aberto do mapa real, onde a carga roda.
const OPEN_GROUND := Vector2(1992.0, 3208.0)
const LOAD_FRAME := 1.0 / 60.0
const LOAD_SECONDS := 30.0
const LOAD_WORLD_RULES: WorldRules = preload("res://data/world/world_rules.tres")
const LOAD_NAV_RULES: NavigationRules = preload("res://data/balance/navigation_rules.tres")

var _frame_us: Array[float] = []


func run() -> void:
	await _test_review_downed_locks_the_screens()
	await _test_review_two_bodies_and_hotbar()
	_test_review_corpse_save_defaults()
	_test_review_downed_player_only_for_biters()
	_test_review_herd_floor_boundary()
	_test_numbers_match_the_spec()
	_test_area_attack_has_no_effect_on_the_two_species()
	_test_downed_and_corpse_art()
	_test_load_32_active()


func _same(actual: Variant, expected: Variant, label: String) -> void:
	_check(is_equal_approx(float(actual), float(expected)), "número do M1: %s = %s (spec %s)" % [label, actual, expected])


# ----------------------------------------------------------------------------- correções da revisão da etapa 6

## Caído não abre inventário, menu de opções nem mexe nos atalhos; acordar destranca; morto segue trancado.
func _test_review_downed_locks_the_screens() -> void:
	var main := _main("m1_lock")
	await _root.get_tree().physics_frame
	var player := main.player
	player.set_physics_process(false)
	main.screen.open_own()
	_check(main.screen.is_open and not main.screen.locked, "caído: de pé o inventário abre")
	player.perform_down(false)
	_check(not main.screen.is_open and main.screen.locked and not player.input_locked,
			"caído: o desmaio fecha a tela que estava aberta e a tranca")
	main.screen.open_own()
	_check(not main.screen.is_open, "caído: o atalho do inventário não abre a tela")
	var options: Array[Dictionary] = [{"id": "x", "label": "X"}]
	_check(not bool(main.controller.menu_opener.call(Vector2.ZERO, "t", 1, options)) and not main.interaction_menu.visible,
			"caído: o menu de opções do mouse não abre")
	var before := player.hotbar.item_at(0)
	main._on_hotbar_assign_requested(0, "fern", "")
	_check(player.hotbar.item_at(0) == before, "caído: o arrasto de atalho não muda a barra (%s)" % before)
	player.perform_wake()
	_check(not main.screen.locked, "caído: ao acordar a tela destranca")
	main.screen.open_own()
	_check(main.screen.is_open, "caído: acordado o inventário abre de novo")
	player.health.protection_left = 0.0  # a graça de 2 s ao acordar barraria o dano
	TestWorld.kill(player)
	_check(main.screen.locked and not main.screen.is_open, "morto: a tela segue trancada e fechada")


## Segunda morte mantém o primeiro corpo (cada um com o seu prazo); recuperar devolve os atalhos.
func _test_review_two_bodies_and_hotbar() -> void:
	var main := _main("m1_bodies")
	await _root.get_tree().physics_frame
	var player := main.player
	var first := _die_with_items(main)
	TestWorld.pass_time(main, 300.0)
	_check(main.request_respawn("campina") == "", "preparo: renasce")
	player.set_physics_process(false)
	player.inventory.add(Items.BERRY, 2)
	var second := main.corpses.deposit(player)
	_check(main.corpses.count() == 2 and is_instance_valid(first) and not first.is_empty() and second != null
			and first.count("wooden_spear") == 1 and second.count("berry") == 2,
			"corpos: a segunda morte mantém o primeiro corpo, cada um com os seus itens")
	TestWorld.pass_time(main, 301.0)
	_check(main.corpses.count() == 1 and main.corpses._corpses.has(second),
			"corpos: o primeiro expira no prazo dele e o segundo continua")
	TestWorld.pass_time(main, 300.0)
	_check(main.corpses.count() == 0, "corpos: o segundo expira no prazo dele")
	var again := main.corpses.deposit(player)
	_check(again == null, "preparo: sem itens não há corpo")
	player.health.protection_left = 0.0  # a proteção do renascer barraria o dano
	player.inventory.add(Items.BERRY, 3)
	player.hotbar.assign(4, Items.BERRY)
	player.inventory.add("wooden_spear", 1)
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		if slot.get("id", "") == "wooden_spear":
			player.hotbar.assign_iid(5, str(slot["iid"]), "wooden_spear")
	var third := _die_with_items(main)
	var marks := third.hotbar_slots.duplicate(true)
	_check(marks.size() >= 2, "preparo: o corpo guardou os atalhos (%s)" % [marks])
	main.request_respawn("campina")
	player.set_physics_process(false)
	for index in HotbarComponent.SLOT_COUNT:
		player.hotbar.clear(index)
	player.global_position = third.global_position
	_check(main.authority.request_recover_corpse(main.authority.id_of(player), main.authority.id_of(third)) == Enums.ActionResult.OK,
			"preparo: recupera o corpo")
	var restored := 0
	for mark: Dictionary in marks:
		var got := player.hotbar.entry_at(int(mark["slot"]))
		restored += 1 if got.get("id", "") == mark["id"] and got.get("iid", "") == mark["iid"] else 0
	_check(restored == marks.size() and restored > 0,
			"atalhos: recuperar o corpo devolve os atalhos às posições de antes (%d de %d)" % [restored, marks.size()])


## Save corrompido sem `due_at`: vale agora mais 10 min (não agora); atalhos salvos lixo são descartados.
func _test_review_corpse_save_defaults() -> void:
	var field := CorpseField.new()
	var clock := TestWorld.TestClock.new()
	clock.time = 100.0
	field.clock = clock.now
	_root.add_child(field)
	_track.call(field)
	field.restore_list([{"player_id": "a", "items": [{"id": "berry", "count": 1}],
			"hotbar": [{"slot": 2, "id": "berry", "iid": ""}, {"slot": 99, "id": "berry"}, {"slot": 3, "id": "zzz"}, 7]}])
	var body := field.corpse_of("a")
	_check(body != null and is_equal_approx(body.due_at, 100.0 + 600.0), "save sem due_at: o corpo vale 10 min a partir de agora")
	_check(body != null and body.hotbar_slots.size() == 1 and int(body.hotbar_slots[0]["slot"]) == 2,
			"save: só o atalho válido volta (%s)" % [body.hotbar_slots if body != null else []])


## O jogador caído só é candidato de quem ataca caído.
func _test_review_downed_player_only_for_biters() -> void:
	for bites: bool in [false, true]:
		var world := _world()
		world["frozen"] = true
		var stats := _carnivore_stats()
		stats.threat_profile.attacks_downed = bites
		var hunter := _dino(world, stats, Vector2.ZERO, "c1")
		var player: Player = world["player"]
		player.global_position = Vector2(40.0, 0.0)
		player.downed.enter()
		_run(world, 1.0)
		_check((_target(world, hunter) == player) == bites,
				"caçador %s caído: o jogador caído %s alvo" % ["que ataca" if bites else "que não ataca", "é" if bites else "não é"])


## Fronteira do piso: bando com exatamente `herd_floor_alive` vivos NÃO é presa; com um a mais, é.
func _test_review_herd_floor_boundary() -> void:
	var floor_count := 2
	for count: int in [floor_count, floor_count + 1]:
		var world := _world()
		world["frozen"] = true
		var system: PredationSystem = world["system"]
		var hunter := _dino(world, _carnivore_stats(), Vector2.ZERO, "c1")
		var herd := _herd(world, _herbivore_stats(), Vector2(60.0, 0.0), Vector2(0.0, 24.0), count)
		_run(world, 1.0)
		var ok := system._prey_ok(hunter, herd[0], _now(world), true, false)
		_check(ok == (count > system.rules.herd_floor_alive),
				"piso: bando com %d vivos (piso %d) %s presa" % [count, system.rules.herd_floor_alive, "é" if ok else "não é"])
		_check((_target(world, hunter) != null) == (count > system.rules.herd_floor_alive),
				"piso: com %d vivos o caçador %s" % [count, "trava" if count > floor_count else "não trava presa"])


# ----------------------------------------------------------------------------- números

func _test_numbers_match_the_spec() -> void:
	var nav := LOAD_NAV_RULES
	_same(nav.tile_px, 16, "navegação: tile_px")
	_same(nav.max_request_tiles, 48, "navegação: max_request_tiles")
	_same(nav.repath_interval_s, 0.5, "navegação: repath_interval_s")
	_same(nav.max_requests_per_frame, 3, "navegação: max_requests_per_frame")
	_same(nav.clearance_small, 0, "navegação: folga Pequeno")
	_same(nav.clearance_medium, 0, "navegação: folga Médio (provisório 08/11)")
	_same(nav.clearance_large, 1, "navegação: folga Grande (provisório 08/11)")
	_same(nav.stuck_check_seconds, 1.0, "navegação: stuck_check_seconds")
	_same(nav.stuck_min_progress_px, 6.0, "navegação: stuck_min_progress_px")
	_same(nav.stuck_give_up_seconds, 3.0, "navegação: stuck_give_up_seconds")
	_same(nav.blocked_cell_seconds, 5.0, "navegação: blocked_cell_seconds")
	_same(nav.stuck_far_tiles, 14.0, "navegação: stuck_far_tiles")
	_same(nav.stuck_offscreen_margin_tiles, 2.0, "navegação: stuck_offscreen_margin_tiles")
	_same(nav.stuck_retry_min_seconds, 5.0, "navegação: stuck_retry_min_seconds")
	_same(nav.stuck_clear_tiles, 4.0, "navegação: stuck_clear_tiles")
	var aggression: AggressionRules = load("res://data/balance/aggression_rules.tres")
	_same(aggression.calm_seconds, 8.0, "agressão: calm_seconds")
	_same(aggression.far_tiles, 12.0, "agressão: far_tiles")
	_same(aggression.far_seconds, 5.0, "agressão: far_seconds")
	_same(aggression.flee_health_ratio, 0.25, "agressão: flee_health_ratio")
	_same(aggression.flee_resume_seconds, 10.0, "agressão: flee_resume_seconds")
	_same(aggression.flee_resume_tiles, 10.0, "agressão: flee_resume_tiles")
	_same(aggression.flee_goal_tiles, 6.0, "agressão: flee_goal_tiles")
	var herd: HerdCallRules = load("res://data/balance/herd_call_rules.tres")
	_same(herd.call_radius_tiles, 8.0, "bando: call_radius_tiles")
	_same(herd.call_delay_s, 0.5, "bando: call_delay_s")
	_same(herd.max_helpers, 2, "bando: max_helpers")
	_same(herd.helper_max_seconds, 12.0, "bando: helper_max_seconds")
	var downed: DownedRules = load("res://data/balance/downed_rules.tres")
	_same(downed.downed_seconds, 10.0, "caído: downed_seconds")
	_same(downed.downed_health, 70.0, "caído: downed_health")
	_same(downed.wake_grace_seconds, 2.0, "caído: wake_grace_seconds")
	_same(downed.wake_torpor, 50.0, "caído: wake_torpor")
	_same(downed.wake_min_health, 20.0, "caído: wake_min_health")
	_same(downed.starving_torpor_per_second, 2.0, "caído: torpor da fome zerada")
	_same(downed.body_minutes, 10.0, "corpo: body_minutes")
	var respawn: RespawnRules = load("res://data/balance/respawn_rules.tres")
	_same(respawn.max_attempts, 30, "renascer: max_attempts")
	_same(respawn.min_distance_from_wild, 128.0, "renascer: min_distance_from_wild")
	_same(respawn.protection_seconds, 3.0, "renascer: protection_seconds")
	_same(respawn.health_ratio, 1.0, "renascer: vida")
	_same(respawn.hunger_ratio, 0.5, "renascer: fome")
	var predation: PredationRules = load("res://data/balance/predation_rules.tres")
	_same(predation.herd_floor_alive, 2, "população: herd_floor_alive")
	_same(predation.member_regen_seconds, 600.0, "população: member_regen_seconds")
	_same(predation.spawn_safe_margin_tiles, 8.0, "população: spawn_safe_margin_tiles")
	_same(predation.prey_alarm_tiles, 6.0, "predação: prey_alarm_tiles")
	_same(predation.owner_shield_tiles, 4.0, "predação: owner_shield_tiles")
	_same(predation.tie_ratio, 0.05, "predação: tie_ratio")
	_same(predation.tamed_attacked_rearm_s, 30.0, "predação: tamed_attacked_rearm_s")
	var zone: ZoneRules = load("res://data/world/zone_rules.tres")
	_same(zone.active_radius_tiles, 16.0, "população: raio ativo")
	_same(zone.max_active, 32, "população: max_active")
	var world := LOAD_WORLD_RULES
	_same(world.group_respawn_player_clearance_tiles, 40.0, "população: folga do jogador na reposição")
	_test_paqui_numbers()
	_test_raptor_numbers()


func _test_paqui_numbers() -> void:
	var stats: DinoBaseStats = load(SPECIES_PAQUI)
	var threat := stats.threat_profile
	_same(stats.base_damage, 6.0, "Paquicéfalo: dano")
	_same(stats.chase_speed, 80.0, "Paquicéfalo: velocidade brava")
	_same(stats.group_size_min, 3, "Paquicéfalo: bando mínimo")
	_same(stats.group_size_max, 4, "Paquicéfalo: bando máximo")
	_check(stats.attacker_kind == "herbivore" and stats.predation == null, "Paquicéfalo: herbívoro e sem perfil de caça")
	_same(threat.threat_seconds, 0.8, "Paquicéfalo: threat_seconds")
	_same(threat.circle_seconds.x, 0.8, "Paquicéfalo: circle_seconds mín")
	_same(threat.circle_seconds.y, 1.5, "Paquicéfalo: circle_seconds máx")
	_same(threat.circle_radius_tiles, 3.0, "Paquicéfalo: circle_radius_tiles")
	_same(threat.circle_speed_factor, 0.6, "Paquicéfalo: circle_speed_factor")
	_same(threat.windup_s, 0.5, "Paquicéfalo: windup_s")
	_same(threat.lunge_speed_px_s, 150.0, "Paquicéfalo: lunge_speed_px_s")
	_same(threat.lunge_max_s, 0.3, "Paquicéfalo: lunge_max_s")
	_same(threat.attack_reach_px, 26.0, "Paquicéfalo: attack_reach_px")
	_same(threat.cooldown_s, 1.6, "Paquicéfalo: cooldown_s")
	_same(threat.knockback_px, 24.0, "Paquicéfalo: knockback_px")
	_same(threat.knockback_seconds, 0.15, "Paquicéfalo: knockback_seconds")
	_check(not threat.attacks_downed, "Paquicéfalo: não ataca o caído")


func _test_raptor_numbers() -> void:
	var stats: DinoBaseStats = load(SPECIES_RAPTOR)
	var threat := stats.threat_profile
	var hunt := stats.predation
	_same(stats.base_damage, 8.0, "Utahraptor: dano")
	_same(stats.chase_speed, 90.0, "Utahraptor: velocidade")
	_same(stats.perception_tiles, 8.0, "Utahraptor: percepção")
	_same(stats.perception_vertical_weight, 1.6, "Utahraptor: peso vertical")
	_same(stats.chase_give_up_tiles, 20.0, "Utahraptor: desiste a")
	_same(stats.chase_max_seconds, 15.0, "Utahraptor: chase_max_seconds")
	_same(stats.alert_seconds, 5.0, "Utahraptor: alerta")
	_same(stats.group_size_min, 2, "Utahraptor: bando mínimo")
	_same(stats.group_size_max, 3, "Utahraptor: bando máximo")
	_check(stats.attacker_kind == "carnivore" and stats.aggressive, "Utahraptor: carnívoro e agressivo")
	_same(threat.threat_seconds, 0.8, "Utahraptor: threat_seconds")
	_same(threat.run_threat_tiles, 4.0, "Utahraptor: run_threat_tiles")
	_same(threat.circle_seconds.x, 0.5, "Utahraptor: circle_seconds mín")
	_same(threat.circle_seconds.y, 1.0, "Utahraptor: circle_seconds máx")
	_same(threat.circle_radius_tiles, 2.5, "Utahraptor: circle_radius_tiles")
	_same(threat.windup_s, 0.3, "Utahraptor: windup_s")
	_same(threat.lunge_speed_px_s, 0.0, "Utahraptor: sem investida")
	_same(threat.lunge_max_s, 0.5, "Utahraptor: lunge_max_s (revisão: tempo de fechar o raio de 2,5 tiles)")
	_same(threat.attack_reach_px, 30.0, "Utahraptor: attack_reach_px")
	_same(threat.cooldown_s, 1.5, "Utahraptor: cooldown_s")
	_same(threat.knockback_px, 0.0, "Utahraptor: sem empurrão")
	_check(threat.attacks_downed, "Utahraptor: ataca o caído")
	_check(hunt.prey_kinds == ["herbivore"] and hunt.prey_exclude_ids.is_empty(), "caça: presa é herbívoro, sem exceção")
	_same(hunt.max_prey_size_delta, 0, "caça: max_prey_size_delta")
	_same(hunt.pack_size_bonus_min_members, 0, "caça: bônus de bando desligado")
	_same(hunt.reevaluate_s, 0.5, "caça: reevaluate_s")
	_same(hunt.lock_min_seconds, 2.0, "caça: lock_min_seconds")
	_same(hunt.switch_ratio, 0.7, "caça: switch_ratio")
	_same(hunt.engage_tiles, 4.0, "caça: engage_tiles")
	_same(hunt.hunt_max_seconds, 40.0, "caça: hunt_max_seconds")
	_same(hunt.fail_cooldown_s, 60.0, "caça: fail_cooldown_s")
	_same(hunt.no_sight_seconds, 5.0, "caça: no_sight_seconds")
	_check(hunt.switch_to_player_on_damage, "caça: troca para o jogador se levar dano")
	_same(hunt.eat_seconds_per_meat, 2.0, "caça: eat_seconds_per_meat")
	_same(hunt.eat_seconds_max, 20.0, "caça: eat_seconds_max")
	_same(hunt.sated_seconds_per_meat, 60.0, "caça: sated_seconds_per_meat")
	_same(hunt.sated_max_seconds, 600.0, "caça: sated_max_seconds")
	_same(hunt.wound_slow_factor, 0.5, "caça: wound_slow_factor")
	_same(hunt.wound_slow_seconds, 3.0, "caça: wound_slow_seconds")
	_same(hunt.retreat_health_ratio, 0.25, "caça: retreat_health_ratio")


# ----------------------------------------------------------------------------- dano em área

func _test_area_attack_has_no_effect_on_the_two_species() -> void:
	for path: String in [SPECIES_PAQUI, SPECIES_RAPTOR]:
		var stats: DinoBaseStats = load(path)
		_check(stats.area_attack == null and stats.area_rules() == null, "dano em área: %s não tem área" % stats.id)
	for size: Enums.DinoSize in [Enums.DinoSize.SMALL, Enums.DinoSize.MEDIUM]:
		var stats := DinoBaseStats.new()
		stats.size = size
		stats.area_attack = AreaAttackRules.new()
		_check(stats.area_rules() == null, "dano em área: porte %d nunca tem área, mesmo com o dado" % size)


# ----------------------------------------------------------------------------- arte do caído e do corpo

func _test_downed_and_corpse_art() -> void:
	_same(BodyArt.fps("caido.png", "respirar", -1.0), 1.0, "arte: respiração do caído (fps de corpo.json)")
	_same(BodyArt.fps("corpo.png", "brilho", -1.0), 2.0, "arte: brilho do corpo (fps de corpo.json)")
	_same(BodyArt.fps("nada.png", "x", 7.0), 7.0, "arte: sem entrada no json vale o padrão")
	_check(BodyArt.DOWNED_TEXTURE.get_size() == Vector2(64, 32) and BodyArt.CORPSE_TEXTURE.get_size() == Vector2(64, 32),
			"arte: caído e corpo têm 2 quadros de 32x32")
	_check(BodyArt.is_mirrored(SpriteFacing.RIGHT) and BodyArt.is_mirrored(SpriteFacing.DOWN_RIGHT)
			and BodyArt.is_mirrored(SpriteFacing.UP_RIGHT) and not BodyArt.is_mirrored(SpriteFacing.LEFT)
			and not BodyArt.is_mirrored(SpriteFacing.DOWN) and not BodyArt.is_mirrored(SpriteFacing.UP_LEFT),
			"arte: o caído espelha só nas três direções da direita")
	var player := _spawn_player()
	var view := PlayerView.new()
	view.player = player
	_root.add_child(view)
	_track.call(view)
	var standing := player.visual.texture
	view.tick(0.1)
	_check(player.visual.texture == standing, "arte: de pé usa a folha do jogador")
	player.velocity = Vector2(50.0, 0.0)  # olhando para a direita
	view.tick(0.1)
	player.velocity = Vector2.ZERO
	player.perform_down(true)
	view.tick(0.1)
	_check(player.visual.texture == BodyArt.DOWNED_TEXTURE and player.visual.flip_h and player.visual.hframes == 2,
			"arte: caído olhando para a direita usa a folha do caído com flip_h")
	var frames: Array[int] = []
	for _i in 4:
		view.tick(0.5)
		frames.append(player.visual.frame)
	_check(frames.has(0) and frames.has(1), "arte: caído respira (os 2 quadros se alternam: %s)" % [frames])
	player.perform_wake()
	view.tick(0.1)
	_check(player.visual.texture == standing and not player.visual.flip_h and player.visual.hframes == 10,
			"arte: ao acordar volta a folha do jogador, sem espelho")
	var corpse := PlayerCorpse.new()
	var corpse_view := CorpseView.new()
	corpse_view.corpse = corpse
	corpse.add_child(corpse_view)
	_root.add_child(corpse)
	_track.call(corpse)
	var shown: Array[int] = []
	for _i in 4:
		corpse_view._process(0.5)
		shown.append(corpse_view._sprite.frame)
	_check(corpse_view._sprite.texture == BodyArt.CORPSE_TEXTURE and shown.has(0) and shown.has(1),
			"arte: o corpo usa corpo.png e o brilho alterna os 2 quadros (%s)" % [shown])


# ----------------------------------------------------------------------------- carga

## 20 carnívoros e 12 herbívoros no mapa real, com a grade de navegação. Os herbívoros são provocados (bravos), os
## carnívoros miram o jogador ou os herbívoros: 32 dinos bravos ou caçando ao mesmo tempo. Quadro de 1/60 s inteiro:
## relógio, zona, caça, estado e movimento de cada dino, mais a grade.
func _test_load_32_active() -> void:
	var world := _world()
	var player: Player = world["player"]
	var zone: DinoZone = world["zone"]
	var system: PredationSystem = world["system"]
	var map := IslandMap.default_map()
	var provider := GridPathProvider.from_map(map, LOAD_WORLD_RULES, LOAD_NAV_RULES)
	zone.navigation = provider
	player.global_position = OPEN_GROUND
	var carn := _carnivore_stats()
	var herb := _herbivore_stats()
	var dinos: Array[Dino] = []
	for i in 20:
		var angle := TAU * float(i) / 20.0
		var radius := 60.0 + float(i % 3) * 20.0
		dinos.append(_dino(world, carn, OPEN_GROUND + Vector2(cos(angle) * radius * 1.3, sin(angle) * radius * 0.7), "c%d" % (i / 2)))
	for i in 12:
		var angle := TAU * float(i) / 12.0 + 0.2
		var dino := _dino(world, herb, OPEN_GROUND + Vector2(cos(angle) * 32.0, sin(angle) * 20.0), "p%d" % (i / 4))
		_sturdy(dino)
		dinos.append(dino)
	for dino in dinos:
		if dino.stats == herb:
			dino.state_machine.provoke()
	zone.reclassify()
	var peak_busy := 0
	var peak_active := 0
	var sum_us := 0.0
	var worst_us := 0.0
	var authority: WorldAuthority = world["authority"]
	for _i in roundi(LOAD_SECONDS / LOAD_FRAME):
		var started := Time.get_ticks_usec()
		provider.begin_frame(LOAD_FRAME)
		authority.clock.advance(LOAD_FRAME)
		authority.tick_herd(LOAD_FRAME)
		zone.reclassify()
		system.tick(LOAD_FRAME)
		var busy := 0
		for dino in dinos:
			if not is_instance_valid(dino) or dino.is_queued_for_deletion() or dino.health.is_dead():
				continue
			dino.observe_owner()
			dino.observe_targets()
			dino.state_machine.tick(LOAD_FRAME)
			dino.global_position += dino.state_machine.desired_direction * dino.move_speed \
					* dino.state_machine.speed_multiplier * LOAD_FRAME
			busy += 1 if dino.state_machine.is_aggressive else 0
		var spent := float(Time.get_ticks_usec() - started)
		sum_us += spent
		worst_us = maxf(worst_us, spent)
		peak_busy = maxi(peak_busy, busy)
		peak_active = maxi(peak_active, zone.active_count)
	var frames := roundi(LOAD_SECONDS / LOAD_FRAME)
	print(("      carga: pico de %d ativos e %d bravos/caçando; %d pedidos de caminho; média %.0f us, "
			+ "pior quadro %.0f us (%d quadros, headless)")
			% [peak_active, peak_busy, provider.requests_total, sum_us / float(frames), worst_us, frames])
	_check(peak_active == 32 and peak_busy >= 24, "carga: 32 ativos e pelo menos 24 bravos ao mesmo tempo (ativos %d, pico %d)"
			% [peak_active, peak_busy])
	_check(provider.requests_total > 0, "carga: a grade de navegação foi usada (%d pedidos)" % provider.requests_total)
	_check(sum_us / float(frames) < 4000.0, "carga: média do quadro abaixo de 4 ms (%.0f us)" % (sum_us / float(frames)))
	_check(worst_us < 16000.0, "carga: pior quadro abaixo de 16 ms (%.0f us)" % worst_us)
