# SPDX-License-Identifier: MIT
class_name DinoLevelTests
extends RefCounted
## Testes de nível, Eficiência, dano no dino, arma do jogador, faixas de torpor e a
## apresentação (barras e `DinoView`). Chamado por `run_tests.gd`; não é um runner:
## recebe a raiz da árvore, o registro de nós para liberar e o `_check` do runner.

const DinoScene := preload("res://src/entities/dino/Dino.tscn")
const PlayerScene := preload("res://src/entities/player/Player.tscn")
const LEVEL_RULES: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
const TAMING_RULES: TamingRules = preload("res://data/balance/taming_rules.tres")
const TORPOR_BANDS: TorporBandRules = preload("res://data/balance/torpor_bands.tres")
const SLEEP_STAFF: WeaponDef = preload("res://data/weapons/sleep_staff.tres")
const MAIN_SCENE: PackedScene = preload("res://src/world/Main.tscn")
const BASE_STATS: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")

var _root: Node
var _track: Callable
var _check_fn: Callable


func _init(root: Node, track: Callable, check: Callable) -> void:
	_root = root
	_track = track
	_check_fn = check


func run() -> void:
	_test_level_rules_formulas()
	_test_balance_data_files()
	_test_dino_level_stats_and_save()
	_test_efficiency_time_and_meals()
	_test_attack_on_sleeping_and_awake()
	_test_final_level_on_taming()
	_test_death_fails_taming()
	_test_player_weapon_attack()
	_test_torpor_bands_and_hysteresis()
	_test_torpor_band_effects()
	_test_efficiency_and_health_bars()
	_test_dino_view_feedback()
	_test_dino_view_sound_hook()
	_test_dino_save_level_efficiency_json()
	_test_sprite_facing()
	_test_dino_view_sprite_frames()
	_test_player_view_frames()
	_test_player_view_attack_sound()
	_test_terrain_scene()
	_test_world_sounds_and_filter()
	_test_ui_theme_and_icons()


func _check(condition: bool, label: String) -> void:
	_check_fn.call(condition, label)


func _spawn_dino() -> Dino:
	var dino: Dino = DinoScene.instantiate()
	_root.add_child(dino)
	_track.call(dino)
	return dino


func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	_root.add_child(player)
	_track.call(player)
	return player


func _spawn_bars(dino: Dino) -> DinoStatusBars:
	var bars := DinoStatusBars.new()
	bars.dino = dino
	_root.add_child(bars)
	_track.call(bars)
	return bars

## Dino dormindo e selvagem, sem comida, no nível dado, com o relógio manual.
func _sleeping_dino_at(level: int) -> Dino:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.level = level
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	return dino


## Regras de Eficiência sem queda nenhuma, para isolar a fórmula do nível final.
func _no_drain_rules(dino: Dino) -> void:
	var rules: TamingRules = dino.taming.rules.duplicate()
	rules.time_drain_per_second = 0.0
	rules.meal_drain = {}
	dino.taming.rules = rules


func _test_level_rules_formulas() -> void:
	var rules: DinoLevelRules = LEVEL_RULES
	# Tabela 10.2 do documento (fatores) em L1, L10, L20, L30.
	var table := {1: [0.64, 0.82, 0.865], 10: [1.0, 1.0, 1.0], 20: [1.4, 1.2, 1.15], 30: [1.8, 1.4, 1.3]}
	for level: int in table:
		var expected: Array = table[level]
		_check(is_equal_approx(rules.health_factor(level), expected[0]), "fator de vida/dano em L%d" % level)
		_check(is_equal_approx(rules.torpor_factor(level), expected[1]), "fator de torpor em L%d" % level)
		_check(is_equal_approx(rules.meals_factor(level), expected[2]), "fator de refeições em L%d" % level)
	_check(is_equal_approx(rules.max_health(80.0, 30), 144.0), "vida 80 em L30 = 144")
	_check(is_equal_approx(rules.max_health(300.0, 30), 540.0), "vida 300 em L30 = 540")
	_check(is_equal_approx(rules.damage(18.0, 20), 25.2), "dano escala como a vida")
	_check(is_equal_approx(rules.max_torpor(100.0, 40), 160.0), "torpor 100 em L40 = 160")
	_check(rules.health_factor(-100) == 0.5 and rules.torpor_factor(-100) == 0.7, "pisos de vida e torpor")
	_check(rules.meals_factor(-100) == 0.85, "piso do fator de refeições")
	_check(rules.meals_required(5, 1.0, 10) == 5 and rules.meals_required(5, 1.0, 20) == 6
			and rules.meals_required(5, 1.0, 30) == 7, "refeições da baga em L10/L20/L30")
	_check(rules.meals_required(8, 2.0, 10) == 16 and rules.meals_required(8, 2.0, 28) == 21,
			"refeições com dificuldade 2,0: 16 em L10 e 21 em L28")
	_check(rules.meals_required(1, 0.1, 1) == 1, "no mínimo uma refeição")
	# Seção 10.4: (nível, Eficiência) -> nível final.
	var finals := [[20, 100.0, 30], [20, 99.0, 30], [20, 75.0, 28], [20, 50.0, 25], [20, 0.0, 20],
			[7, 100.0, 11], [7, 60.0, 9], [1, 100.0, 2], [60, 100.0, 90]]
	for entry: Array in finals:
		_check(rules.final_level(entry[0], entry[1]) == entry[2],
				"nível final (%d, %d%%) = %d" % [entry[0], entry[1], entry[2]])
	_check(rules.final_level(20, 500.0) == 30 and rules.final_level(20, -50.0) == 20,
			"Eficiência fora de 0..100 é limitada")
	_check(rules.clamp_level(0) == 1 and rules.clamp_level(999) == 75, "nível limitado a 1..75")


func _test_balance_data_files() -> void:
	var rules: TamingRules = TAMING_RULES
	_check(rules.time_drain_per_second == 0.3 and rules.loss_per_health_percent == 0.5, "dados: queda por tempo e por vida")
	_check(rules.meal_loss("berry") == 2.0 and rules.meal_loss("fern") == 0.0, "dados: queda por refeição de baga")
	_check(rules.attack_loss(TamingRules.ATTACKER_PLAYER, 0.0) == 4.0
			and rules.attack_loss(TamingRules.ATTACKER_CARNIVORE, 0.0) == 8.0, "dados: fixo 4 (jogador) e 8 (carnívoro)")
	_check(absf(rules.attack_loss(TamingRules.ATTACKER_PLAYER, 2.0 / 73.6 * 100.0) - 5.36) < 0.01,
			"Paquicéfalo L8 com o bastão perde ~5,4 de Eficiência")
	_check(rules.attack_loss("desconhecido", 50.0) == 0.0 and not rules.knows_attacker("desconhecido"),
			"atacante desconhecido não existe")
	var weapon: WeaponDef = SLEEP_STAFF
	_check(weapon.damage == 2.0 and weapon.torpor == 30.0 and weapon.cooldown == 0.7, "dados: bastão 2/30/0,7 s")
	var bands: TorporBandRules = TORPOR_BANDS
	_check(bands.thresholds == [0.25, 0.5, 0.75] and is_equal_approx(bands.hysteresis, 0.03), "dados: limiares e histerese")
	_check(is_equal_approx(bands.speed_multiplier(2), 0.85) and is_equal_approx(bands.speed_multiplier(3), 0.65)
			and bands.speed_multiplier(0) == 1.0 and bands.speed_multiplier(1) == 1.0, "dados: velocidade por faixa")
	_check(bands.pause_period == 4.0 and bands.pause_duration == 0.8 and bands.pause_band == 3, "dados: pausa 0,8 s a cada 4 s")
	var level_rules: DinoLevelRules = LEVEL_RULES
	_check(level_rules.base_level == 10 and level_rules.taming_cap == 1.5, "dados: nível base 10 e teto 1,5")
	var stats: DinoBaseStats = BASE_STATS
	_check(stats.base_meals == 5 and stats.base_health == 100.0 and stats.base_torpor == 100.0, "dados: atributos base do dino")


func _test_dino_level_stats_and_save() -> void:
	var dino := _spawn_dino()
	_check(dino.level == 10 and dino.health.max_health == 100.0 and dino.torpor.max_torpor == 100.0,
			"nível 10: atributos base")
	dino.level = 20
	_check(is_equal_approx(dino.health.max_health, 140.0) and is_equal_approx(dino.torpor.max_torpor, 120.0),
			"nível 20: vida 140 e torpor 120")
	_check(is_equal_approx(dino.health.current_health, 140.0), "vida cheia continua cheia ao mudar de nível")
	_check(is_equal_approx(dino.attack_damage, 5.6) and dino.taming.meals_required() == 6, "dano 5,6 e 6 refeições em L20")
	dino.level = 0
	_check(dino.level == 1, "nível mínimo 1")
	var preset: Dino = DinoScene.instantiate()
	preset.level = 30
	_root.add_child(preset)
	_track.call(preset)
	_check(is_equal_approx(preset.health.max_health, 180.0), "nível definido antes de entrar na árvore vale")
	# Save: nível volta, máximos vêm da fórmula e não do save, dado inválido é limitado.
	var hurt := _spawn_dino()
	hurt.level = 20
	hurt.health.take_damage(40.0)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(hurt.to_dict()))
	_check(parsed["level"] == 20, "to_dict traz o nível")
	var copy := _spawn_dino()
	var events := [0]
	copy.health.died.connect(func() -> void: events[0] += 1)
	copy.from_dict(parsed)
	_check(copy.level == 20 and is_equal_approx(copy.health.current_health, 100.0), "from_dict restaura nível e vida")
	var tampered: Dictionary = parsed.duplicate(true)
	tampered["level"] = 99999
	tampered["health"] = {"current": 1e9, "max": 1e9}
	tampered["torpor"] = {"current": 0.0, "max": 1e9}
	copy.from_dict(tampered)
	_check(copy.level == LEVEL_RULES.max_level, "nível do save acima do teto é limitado")
	_check(is_equal_approx(copy.health.max_health, 100.0 * (1.0 + 0.04 * 65.0)) and copy.torpor.max_torpor < 1000.0,
			"máximos de vida e torpor vêm do nível, não do save")
	copy.from_dict({"level": "lixo"})
	_check(copy.level == LEVEL_RULES.base_level, "nível ilegível usa o nível padrão")
	var old := _spawn_dino()
	old.from_dict({"health": {"current": 50.0, "max": 100.0}})
	_check(old.level == 10, "save sem nível usa o padrão")
	_check(events[0] == 0, "restaurar não emite died")


func _test_efficiency_time_and_meals() -> void:
	var dino := _sleeping_dino_at(10)
	_check(dino.taming.efficiency == 100.0, "Eficiência começa em 100 no nocaute")
	var changes := [0]
	dino.taming.efficiency_changed.connect(func(_e: float) -> void: changes[0] += 1)
	dino.taming.tick(10.0)
	_check(is_equal_approx(dino.taming.efficiency, 97.0), "dormindo: -0,3 por segundo (sem comida)")
	_check(changes[0] > 0, "emite efficiency_changed")
	dino.inventory.add("berry", 1)
	dino.taming.tick(5.0)
	# 5 s: -1,5 de tempo e -2 da baga.
	_check(is_equal_approx(dino.taming.efficiency, 93.5), "cada baga custa 2 de Eficiência")
	var awake := _spawn_dino()
	awake.taming.tick(100.0)
	_check(awake.taming.efficiency == 100.0, "acordado não perde Eficiência com o tempo")
	var tamed := _sleeping_dino_at(10)
	tamed.state_machine.mark_tamed()
	var kept: float = tamed.taming.efficiency
	tamed.taming.tick(100.0)
	_check(tamed.taming.efficiency == kept, "domesticado não perde Eficiência")
	var preview := [0, 0]
	dino.taming.level_preview_changed.connect(func(l: int, p: int) -> void:
		preview[0] = l
		preview[1] = p)
	dino.taming.tick(60.0)
	_check(preview[0] == 10 and preview[1] >= 10, "o aviso de prévia traz o nível e a prévia")
	_check(dino.taming.efficiency >= 0.0, "Eficiência nunca fica negativa")
	dino.taming.tick(100000.0)
	_check(dino.taming.efficiency == 0.0 and dino.taming.preview_level() == 10, "chega a 0 e a prévia vira o nível puro")
	var woke := _sleeping_dino_at(10)
	woke.taming.tick(20.0)
	woke.torpor.reduce_torpor(woke.torpor.max_torpor)
	_check(woke.taming.efficiency == 100.0, "acordar selvagem zera a tentativa: Eficiência volta a 100")


func _test_attack_on_sleeping_and_awake() -> void:
	var player_kind := TamingRules.ATTACKER_PLAYER
	var dino := _sleeping_dino_at(10)
	var damaged := [0.0]
	dino.health.damaged.connect(func(a: float) -> void: damaged[0] += a)
	_check(dino.take_damage(2.0, player_kind), "ataque ao dormindo causa dano")
	_check(is_equal_approx(dino.health.current_health, 98.0) and is_equal_approx(damaged[0], 2.0), "vida cai 2")
	# fixo 4 + 0,5 x 2% = 5.
	_check(is_equal_approx(dino.taming.efficiency, 95.0), "ataque do jogador ao dormindo: -4 fixo -1 (2% da vida)")
	dino.take_damage(2.0, TamingRules.ATTACKER_CARNIVORE)
	_check(is_equal_approx(dino.taming.efficiency, 95.0 - 9.0), "carnívoro ao dormindo: -8 fixo -1")
	_check(not dino.take_damage(2.0, "alienigena") and is_equal_approx(dino.health.current_health, 96.0),
			"atacante desconhecido é rejeitado, sem dano")
	_check(not dino.take_damage(-5.0, player_kind), "dano negativo é ignorado")
	var awake := _spawn_dino()
	awake.set_physics_process(false)
	_check(awake.take_damage(2.0, player_kind), "ataque ao acordado causa dano")
	_check(is_equal_approx(awake.health.current_health, 98.0) and awake.taming.efficiency == 100.0,
			"acordado: só tira vida, a Eficiência não cai")
	_check(awake.taming.apply_attack(TamingRules.ATTACKER_PLAYER, 50.0) == 0.0 and awake.taming.efficiency == 100.0,
			"a regra do componente também ignora o acordado")
	# O golpe que derruba (dano antes do torpor) não conta como ataque ao dormindo.
	var knock := _spawn_dino()
	knock.set_physics_process(false)
	knock.torpor.add_torpor(knock.torpor.max_torpor - 10.0)
	_check(knock.receive_hit(2.0, 30.0, player_kind), "golpe acerta")
	_check(knock.torpor.is_unconscious and knock.taming.efficiency == 100.0,
			"o golpe que derruba não tira Eficiência")
	_check(knock.receive_hit(2.0, 30.0, player_kind) and knock.taming.efficiency < 100.0,
			"o golpe seguinte, já dormindo, tira")
	var tamed := _sleeping_dino_at(10)
	tamed.state_machine.mark_tamed()
	_check(not tamed.receive_hit(2.0, 30.0, player_kind) and tamed.health.current_health == tamed.health.max_health,
			"golpe do jogador não atinge domesticado")
	var big := _sleeping_dino_at(30)
	big.take_damage(2.0, player_kind)
	var expected_loss := 4.0 + 0.5 * (2.0 / 180.0 * 100.0)
	_check(is_equal_approx(big.taming.efficiency, 100.0 - expected_loss),
			"dino maior perde menos por ataque (termo de % da vida)")


func _test_final_level_on_taming() -> void:
	var dino := _sleeping_dino_at(20)
	_no_drain_rules(dino)
	dino.inventory.add("berry", 10)
	var finalized := [0]
	dino.taming.level_finalized.connect(func(l: int) -> void: finalized.append(l))
	var before_hp: float = dino.health.current_health
	for i in 40:
		dino.taming.tick(1.0)
	_check(dino.state_machine.is_tamed, "domesticou")
	_check(dino.level == 30 and finalized[-1] == 30, "(20, 100%%) vira nível 30 (%d)" % dino.level)
	_check(is_equal_approx(dino.health.max_health, 100.0 * 1.8), "o nível final reajusta a vida máxima")
	_check(dino.health.current_health >= before_hp, "vida não diminui ao subir de nível")
	var mid := _sleeping_dino_at(7)
	_no_drain_rules(mid)
	mid.taming.efficiency = 60.0
	mid.inventory.add("berry", 10)
	for i in 40:
		mid.taming.tick(1.0)
	_check(mid.state_machine.is_tamed and mid.level == 9, "(7, 60%%) vira nível 9 (%d)" % mid.level)
	var zero := _sleeping_dino_at(20)
	_no_drain_rules(zero)
	zero.taming.efficiency = 0.0
	zero.inventory.add("berry", 10)
	for i in 40:
		zero.taming.tick(1.0)
	_check(zero.state_machine.is_tamed and zero.level == 20, "com 0% ainda domestica, sem bônus")
	# Fluxo natural: 30 s de tempo + 6 refeições x 2 = 79%, nível 28 (conta da seção 10.4).
	var natural := _sleeping_dino_at(20)
	natural.inventory.add("berry", 6)
	for i in 40:
		natural.taming.tick(1.0)
	_check(natural.state_machine.is_tamed and is_equal_approx(natural.taming.efficiency, 79.0), "Eficiência natural 79")
	_check(natural.level == 28, "nível natural 28")
	_check(natural.inventory.count("berry") == 0, "gastou as 6 bagas")


func _test_death_fails_taming() -> void:
	var dino := _sleeping_dino_at(10)
	dino.inventory.add("berry", 10)
	dino.taming.tick(15.0)
	_check(is_equal_approx(dino.taming.taming_progress, 60.0), "60% antes do ataque")
	var failed := [0]
	var tamed := [0]
	dino.taming.taming_failed.connect(func() -> void: failed[0] += 1)
	dino.state_machine.state_changed.connect(func(_p: int, c: int) -> void:
		if c == Enums.DinoStateId.TAMED: tamed[0] += 1)
	dino.take_damage(1000.0, TamingRules.ATTACKER_CARNIVORE)
	_check(dino.health.is_dead() and failed[0] == 1, "morrer dormindo falha a domesticação")
	_check(dino.taming.has_failed and dino.taming.taming_progress == 0.0, "a comida gasta é perdida: progresso zerado")
	dino.taming.tick(100.0)
	_check(not dino.state_machine.is_tamed and tamed[0] == 0 and dino.inventory.count("berry") == 7,
			"morto não termina nem consome mais")
	var awake := _spawn_dino()
	awake.set_physics_process(false)
	var awake_failed := [0]
	awake.taming.taming_failed.connect(func() -> void: awake_failed[0] += 1)
	awake.take_damage(1000.0, TamingRules.ATTACKER_PLAYER)
	_check(awake.health.is_dead() and awake_failed[0] == 0, "morrer acordado não é domesticação falha")
	var done := _sleeping_dino_at(10)
	done.state_machine.mark_tamed()
	var done_failed := [0]
	done.taming.taming_failed.connect(func() -> void: done_failed[0] += 1)
	done.take_damage(1000.0, TamingRules.ATTACKER_CARNIVORE)
	_check(done_failed[0] == 0, "domesticado que morre não falha domesticação")


func _test_player_weapon_attack() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.torpor.set_physics_process(false)
	player.target = dino.interactable
	player._in_range.append(dino.interactable)
	_check(player.weapon.id == "sleep_staff", "arma inicial vem dos dados")
	_check(player.attack(), "golpe acerta")
	_check(is_equal_approx(dino.health.current_health, 98.0), "bastão causa 2 de dano")
	_check(is_equal_approx(dino.torpor.current_torpor, 30.0), "bastão aplica 30 de torpor")
	player.tick(0.69)
	_check(not player.attack(), "0,69 s: ainda em recarga")
	player.tick(0.02)
	_check(player.attack(), "0,71 s: recarga de 0,7 s acabou")
	var other: WeaponDef = WeaponDef.new()
	other.damage = 18.0
	other.torpor = 6.0
	other.cooldown = 0.9
	player.weapon = other
	player.tick(1.0)
	_check(player.attack() and is_equal_approx(dino.health.current_health, 98.0 - 2.0 - 18.0), "outra arma, outros números")
	player.tick(0.5)
	_check(not player.attack(), "recarga de 0,9 s da outra arma")
	var hits := 0
	var player2 := _spawn_player()
	var full := _spawn_dino()
	full.set_physics_process(false)
	full.torpor.set_physics_process(false)
	player2.target = full.interactable
	player2._in_range.append(full.interactable)
	for i in 4:
		player2.tick(0.7)
		if player2.attack():
			hits += 1
	_check(hits == 4 and full.torpor.is_unconscious, "4 golpes de 30 derrubam o nível 10 sem decaimento")


func _test_torpor_bands_and_hysteresis() -> void:
	var torpor: TorporComponent = _track.call(TorporComponent.new())
	var bands: Array[int] = []
	torpor.band_changed.connect(func(b: int) -> void: bands.append(b))
	var knocked := [0]
	torpor.knocked_out.connect(func() -> void: knocked[0] += 1)
	_check(torpor.band == 0, "começa na faixa 0")
	torpor.add_torpor(24.5)
	_check(torpor.band == 0, "24,5%: faixa 0")
	torpor.add_torpor(0.5)
	_check(torpor.band == 1, "25%: sobe para 1")
	torpor.reduce_torpor(2.0)
	_check(torpor.band == 1, "23%: a histerese segura a faixa 1")
	torpor.reduce_torpor(0.8)
	_check(torpor.band == 1, "22,2%: ainda 1")
	torpor.reduce_torpor(0.7)
	_check(torpor.band == 0, "21,5%: desce para 0")
	torpor.add_torpor(28.5)
	_check(torpor.band == 2 and is_equal_approx(torpor.current_torpor, 50.0), "50%: faixa 2")
	torpor.reduce_torpor(2.5)
	_check(torpor.band == 2, "47,5%: segura a 2")
	torpor.reduce_torpor(1.0)
	_check(torpor.band == 1, "46,5%: desce para 1")
	torpor.add_torpor(28.5)
	_check(torpor.band == 3, "75%: faixa 3")
	torpor.reduce_torpor(2.5)
	_check(torpor.band == 3, "72,5%: segura a 3")
	torpor.reduce_torpor(1.0)
	_check(torpor.band == 2, "71,5%: desce para 2")
	torpor.add_torpor(100.0)
	_check(torpor.band == 3 and torpor.is_unconscious and knocked[0] == 1, "cheio: faixa 3 e desmaia")
	torpor.reset()
	_check(torpor.band == 0, "zerar volta à faixa 0")
	_check(bands == [1, 0, 2, 1, 3, 2, 3, 0], "sequência de band_changed: %s" % [bands])
	torpor.add_torpor(60.0)
	torpor.reduce_torpor(14.0)
	_check(torpor.band == 1, "salto de 60% para 46% cai de 2 para 1")
	# Salto de várias faixas de uma vez.
	var jump: TorporComponent = _track.call(TorporComponent.new())
	jump.add_torpor(90.0)
	_check(jump.band == 3, "salto de 0 a 90%: faixa 3")
	jump.reduce_torpor(90.0)
	_check(jump.band == 0, "e de volta a 0")
	# Salvar e restaurar: faixa recalculada, sem knocked_out nem woke_up.
	var source: TorporComponent = _track.call(TorporComponent.new())
	source.add_torpor(80.0)
	var copy: TorporComponent = _track.call(TorporComponent.new())
	var events := [0]
	copy.knocked_out.connect(func() -> void: events[0] += 1)
	copy.woke_up.connect(func() -> void: events[0] += 1)
	copy.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())))
	_check(copy.band == 3 and copy.to_dict()["band"] == 3, "faixa restaurada e salva")
	copy.from_dict({"current": 100.0, "max": 100.0})
	_check(events[0] == 0, "restaurar não dispara eventos")
	var resize: TorporComponent = _track.call(TorporComponent.new())
	resize.add_torpor(60.0)
	resize.max_torpor = 200.0
	_check(resize.band == 1, "mudar o máximo recalcula a faixa (30%)")


func _test_torpor_band_effects() -> void:
	var torpor: TorporComponent = _track.call(TorporComponent.new())
	torpor.decay_per_second = 0.0
	_check(torpor.movement_multiplier() == 1.0, "faixa 0: velocidade x1")
	torpor.add_torpor(30.0)
	_check(torpor.movement_multiplier() == 1.0 and torpor.attack_cooldown_multiplier() == 1.0, "faixa 1: sem regra")
	torpor.add_torpor(25.0)
	_check(is_equal_approx(torpor.movement_multiplier(), 0.85), "faixa 2: velocidade x0,85")
	torpor.add_torpor(25.0)
	_check(is_equal_approx(torpor.movement_multiplier(), 0.65) and torpor.attack_cooldown_multiplier() == 1.5,
			"faixa 3: velocidade x0,65 e cooldown x1,5")
	# Pausa: 0,8 s ao fim de cada ciclo de 4 s, determinística.
	var pause_log: Array[bool] = []
	for i in 100:
		torpor.tick(0.1)
		pause_log.append(torpor.is_paused())
	var paused_ticks := pause_log.count(true)
	_check(paused_ticks >= 14 and paused_ticks <= 18, "10 s na faixa 3: 2 pausas de 0,8 s (%d ticks)" % paused_ticks)
	_check(not pause_log[27] and pause_log[33] and not pause_log[43] and pause_log[75] and not pause_log[85],
			"pausa entre 3,2 s e 4,0 s de cada ciclo de 4 s")
	var twin: TorporComponent = _track.call(TorporComponent.new())
	twin.decay_per_second = 0.0
	twin.add_torpor(80.0)
	var again: Array[bool] = []
	for i in 100:
		twin.tick(0.1)
		again.append(twin.is_paused())
	_check(again == pause_log, "mesma sequência, mesma pausa (determinística)")
	var shifted: TorporComponent = _track.call(TorporComponent.new())
	shifted.decay_per_second = 0.0
	shifted.pause_phase = 1.0
	shifted.add_torpor(80.0)
	shifted.tick(2.3)
	_check(shifted.is_paused() and not twin.is_paused(), "a fase desloca a pausa entre dinos")
	torpor.tick(1.5)
	_check(torpor.is_paused() and torpor.movement_multiplier() == 0.0, "pausado: velocidade 0")
	torpor.reduce_torpor(50.0)
	_check(not torpor.is_paused() and torpor.movement_multiplier() == 1.0, "saiu da faixa 3: sem pausa")
	var asleep: TorporComponent = _track.call(TorporComponent.new())
	asleep.add_torpor(100.0)
	asleep.tick(3.5)
	_check(not asleep.is_paused() and asleep.movement_multiplier() == 1.0, "inconsciente não tem pausa nem fator")
	# No corpo: velocidade real do Dino.
	var dino := _spawn_dino()
	dino.torpor.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	dino.state_machine.desired_direction = Vector2.RIGHT
	dino.torpor.decay_per_second = 0.0
	dino.torpor.add_torpor(60.0)
	dino._physics_process(0.016)
	_check(is_equal_approx(dino.velocity.x, dino.move_speed * 0.85), "Dino na faixa 2 anda a x0,85")
	dino.torpor.add_torpor(20.0)
	dino._physics_process(0.016)
	_check(is_equal_approx(dino.velocity.x, dino.move_speed * 0.65), "Dino na faixa 3 anda a x0,65")
	dino.torpor.tick(3.5)
	dino._physics_process(0.016)
	_check(dino.velocity == Vector2.ZERO, "Dino em pausa fica parado")


func _test_efficiency_and_health_bars() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.level = 20
	var bars := _spawn_bars(dino)
	_check(not bars.visible and not bars.health_bar_visible(), "inicial: nenhuma barra, nem de vida")
	# Vida: só depois de dano, some 5 s depois do último.
	dino.take_damage(2.0, TamingRules.ATTACKER_PLAYER)
	_check(bars.visible and bars.health_bar_visible() and not bars.panel_visible(), "dano: só a barra de vida")
	_check(is_equal_approx(bars.health_bar().value(), 138.0) and bars.health_bar().max_value() == 140.0,
			"barra de vida reflete 138/140")
	bars.tick(4.9)
	_check(bars.health_bar_visible(), "4,9 s depois: ainda aparece")
	dino.take_damage(2.0, TamingRules.ATTACKER_PLAYER)
	bars.tick(4.9)
	_check(bars.health_bar_visible(), "novo dano reinicia os 5 s")
	bars.tick(0.2)
	_check(not bars.health_bar_visible() and not bars.visible, "5 s depois do último dano: some")
	_check(not bars.panel_visible(), "acordado: sem barra de torpor, domesticação nem Eficiência")
	# Dormindo: Eficiência e nível previsto.
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	_check(bars.panel_visible() and bars.efficiency_bar().visible, "dormindo: barra de Eficiência")
	_check(bars.efficiency_bar().value() == 100.0 and bars.level_label().text == "Nv 20 -> 30",
			"100%%: prévia 'Nv 20 -> 30' (%s)" % bars.level_label().text)
	dino.taming.efficiency = 50.0
	dino.taming.apply_attack(TamingRules.ATTACKER_PLAYER, 0.0)
	_check(is_equal_approx(bars.efficiency_bar().value(), 46.0), "a barra acompanha a queda (50 - 4)")
	_check(bars.level_label().text == "Nv 20 -> 25", "prévia acompanha: %s" % bars.level_label().text)
	_check(bars.torpor_bar().visible and bars.taming_bar().visible, "torpor e domesticação junto da Eficiência")
	dino.torpor.reduce_torpor(dino.torpor.max_torpor)
	_check(not bars.panel_visible(), "acordou: a Eficiência some")
	var tamed := _sleeping_dino_at(10)
	tamed.state_machine.mark_tamed()
	var tamed_bars := _spawn_bars(tamed)
	tamed.torpor.add_torpor(tamed.torpor.max_torpor)
	_check(tamed_bars.panel_visible() and not tamed_bars.efficiency_bar().get_parent().visible,
			"domesticado dormindo: sem Eficiência")
	# Restaurar não conta como dano: a barra de vida não aparece.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(dino.to_dict()))
	var restored := _spawn_dino()
	restored.set_physics_process(false)
	var restored_bars := _spawn_bars(restored)
	restored.from_dict(saved)
	_check(not restored_bars.health_bar_visible(), "from_dict não mostra a barra de vida")
	# Morte: a barra some junto com o dino.
	var doomed := _spawn_dino()
	doomed.set_physics_process(false)
	var doomed_bars := _spawn_bars(doomed)
	doomed.take_damage(1000.0, TamingRules.ATTACKER_PLAYER)
	doomed.free()
	doomed_bars.follow()
	_check(doomed_bars.is_queued_for_deletion(), "barras somem com o dino")


func _spawn_view(dino: Dino) -> DinoView:
	var view := DinoView.new()
	view.dino = dino
	_root.add_child(view)
	_track.call(view)
	return view


func _test_dino_view_feedback() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.torpor.set_physics_process(false)
	dino.state_machine.set_physics_process(false)
	var view := _spawn_view(dino)
	view.tick(0.1)
	_check(dino.visual.rotation == 0.0 and dino.visual.modulate == Color.WHITE and not view.is_sleep_icon_visible(),
			"faixa 0: em pé, sem tinta e sem balão")
	dino.take_damage(3.0, TamingRules.ATTACKER_PLAYER)
	_check(view.is_flashing() and view.popup_count() == 1, "dano: flash e número flutuante")
	view.tick(0.01)
	_check(dino.visual.modulate.r > 1.0, "o flash clareia o placeholder")
	view.tick(0.2)
	_check(not view.is_flashing() and dino.visual.modulate == Color.WHITE, "flash dura 0,1 s")
	dino.take_damage(1.5, TamingRules.ATTACKER_PLAYER)
	_check(view.popup_count() == 2, "um número por dano")
	# Faixa 2: cambaleio leve; faixa 3: forte; pausa: texto e achatamento.
	dino.torpor.decay_per_second = 0.0
	dino.torpor.add_torpor(55.0)
	var max_rot_2 := 0.0
	for i in 60:
		view.tick(0.05)
		max_rot_2 = maxf(max_rot_2, absf(dino.visual.position.x))
	dino.torpor.add_torpor(25.0)
	var max_rot_3 := 0.0
	for i in 60:
		view.tick(0.05)
		max_rot_3 = maxf(max_rot_3, absf(dino.visual.position.x))
	_check(max_rot_2 == 1.0 and max_rot_3 == 2.0, "cambaleio: 1 px na faixa 2 e 2 px na faixa 3 (pixels inteiros)")
	dino.torpor.tick(3.5)
	view.tick(0.01)
	_check(dino.torpor.is_paused() and view.text_shown() == "..." and dino.visual.scale.y < 1.0, "pausa: texto e achatamento")
	dino.torpor.reduce_torpor(80.0)
	view.tick(0.01)
	_check(dino.visual.scale == Vector2.ONE, "sem pausa o corpo volta ao normal")
	# Bocejo na faixa 1: a cada 8 s, com o sinal de som.
	var cues: Array[StringName] = []
	view.sound_cue.connect(func(c: StringName) -> void: cues.append(c))
	dino.torpor.add_torpor(30.0)
	view.tick(7.5)
	_check(view.text_shown() != "Aaah...", "faixa 1: ainda não bocejou aos 7,5 s")
	view.tick(1.0)
	_check(view.text_shown() == "Aaah..." and cues.has(DinoView.CUE_YAWN), "faixa 1: boceja a cada 8 s")
	view.tick(1.0)
	_check(view.text_shown() == "", "o texto some depois de ~1 s")
	# Dormindo: sem cambaleio, tinta de sono.
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	view.tick(0.1)
	_check(is_equal_approx(dino.visual.rotation, PI / 2.0) and dino.visual.modulate == DinoView.SLEEP_COLOR
			and view.is_sleep_icon_visible(), "dormindo: sprite deitado, escurecido e com o balão zz")
	# Domar mostra o nível final.
	dino.state_machine.mark_tamed()
	dino.taming.level_finalized.emit(25)
	_check(cues.has(DinoView.CUE_TAMED), "domesticar emite o som de domado")
	var view_free := _spawn_view(_spawn_dino())
	view_free.dino.free()
	view_free.tick(0.1)
	_check(view_free.is_queued_for_deletion(), "a view some com o dino")


func _test_dino_view_sound_hook() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var view := _spawn_view(dino)
	var cues: Array[StringName] = []
	view.sound_cue.connect(func(c: StringName) -> void: cues.append(c))
	_check(view.audio_player() is AudioStreamPlayer2D and view.audio_player().stream == null, "player existe, sem stream")
	_check(view.cue_streams.is_empty(), "nenhum áudio foi criado")
	dino.take_damage(1.0, TamingRules.ATTACKER_PLAYER)
	_check(cues == [DinoView.CUE_HIT] and not view.audio_player().playing, "sem stream: só o sinal, nada toca")
	var stream := AudioStreamWAV.new()
	view.cue_streams[DinoView.CUE_HIT] = stream
	dino.take_damage(1.0, TamingRules.ATTACKER_PLAYER)
	_check(cues.size() == 2 and view.audio_player().stream == stream, "com stream: vai para o player")
	# Solta o stream e a reprodução: com o driver de áudio dummy, o playback vaza no encerramento.
	view.audio_player().stop()
	view.audio_player().stream = null
	view.cue_streams.clear()


func _test_dino_save_level_efficiency_json() -> void:
	var original := _sleeping_dino_at(20)
	original.inventory.add("berry", 3)
	original.taming.tick(6.0)
	original.take_damage(2.0, TamingRules.ATTACKER_PLAYER)
	var efficiency: float = original.taming.efficiency
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	_check(parsed["level"] == 20 and is_equal_approx(parsed["taming"]["efficiency"], efficiency), "JSON traz nível e Eficiência")
	var copy := _spawn_dino()
	copy.set_physics_process(false)
	var failed := [0]
	copy.taming.taming_failed.connect(func() -> void: failed[0] += 1)
	copy.from_dict(parsed)
	_check(copy.level == 20 and copy.taming.efficiency == efficiency, "nível e Eficiência restaurados")
	_check(copy.taming.preview_level() == original.taming.preview_level(), "prévia restaurada")
	_check(copy.torpor.band == original.torpor.band, "faixa recalculada igual")
	# O JSON guarda ~15 dígitos: o que volta é estável (salvar de novo não muda nada).
	_check(JSON.parse_string(JSON.stringify(copy.to_dict())) == parsed, "salvar o restaurado devolve o mesmo JSON")
	var bad: Dictionary = parsed.duplicate(true)
	bad["taming"]["efficiency"] = 1e9
	copy.from_dict(bad)
	_check(copy.taming.efficiency == 100.0, "Eficiência do save acima de 100 é limitada")
	bad["taming"]["efficiency"] = -50.0
	copy.from_dict(bad)
	_check(copy.taming.efficiency == 0.0, "Eficiência negativa vira 0")
	bad["taming"]["efficiency"] = "lixo"
	copy.from_dict(bad)
	_check(copy.taming.efficiency == 100.0, "Eficiência ilegível volta ao padrão")
	var old := _sleeping_dino_at(10)
	old.taming.from_dict({"progress": 20.0})
	_check(old.taming.efficiency == 100.0, "save sem Eficiência: 100")
	_check(failed[0] == 0, "restaurar não falha a domesticação")



# --- Sprites, mapa, sons e tema (pacote Ninja Adventure) ---

func _test_sprite_facing() -> void:
	_check(SpriteFacing.column_for(Vector2.DOWN, 9) == SpriteFacing.DOWN, "baixo = coluna 0")
	_check(SpriteFacing.column_for(Vector2.UP, 9) == SpriteFacing.UP, "cima = coluna 1")
	_check(SpriteFacing.column_for(Vector2.LEFT, 9) == SpriteFacing.LEFT, "esquerda = coluna 2")
	_check(SpriteFacing.column_for(Vector2.RIGHT, 9) == SpriteFacing.RIGHT, "direita = coluna 3")
	_check(SpriteFacing.column_for(Vector2(1.0, 0.4), 9) == SpriteFacing.RIGHT, "diagonal: eixo dominante")
	_check(SpriteFacing.column_for(Vector2.ZERO, 2) == 2, "sem direção: mantém o fallback")
	_check(SpriteFacing.walk_row(0.0) == 0 and SpriteFacing.walk_row(0.13) == 1 and SpriteFacing.walk_row(0.26) == 2
			and SpriteFacing.walk_row(0.38) == 3 and SpriteFacing.walk_row(0.5) == 0, "ciclo de 4 quadros a 8 por segundo")


func _test_dino_view_sprite_frames() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.torpor.set_physics_process(false)
	var view := _spawn_view(dino)
	_check(dino.visual.hframes == 4 and dino.visual.vframes == 4, "sprite do dino: folha 4x4")
	view.tick(0.01)
	_check(dino.visual.frame_coords == Vector2i(SpriteFacing.DOWN, 0), "parado: de frente, quadro 0")
	dino.velocity = Vector2.LEFT * 40.0
	view.tick(0.13)
	_check(dino.visual.frame_coords.x == SpriteFacing.LEFT and dino.visual.frame_coords.y > 0, "andando para a esquerda")
	dino.velocity = Vector2.UP * 40.0
	view.tick(0.01)
	_check(dino.visual.frame_coords.x == SpriteFacing.UP, "andando para cima")
	dino.velocity = Vector2.ZERO
	view.tick(0.01)
	_check(dino.visual.frame_coords == Vector2i(SpriteFacing.UP, 0), "parou: mantém a direção, quadro 0")
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	view.tick(0.01)
	_check(dino.visual.frame_coords == Vector2i(SpriteFacing.DOWN, 0) and is_equal_approx(dino.visual.rotation, PI / 2.0),
			"dormindo: quadro de frente girado 90 graus")
	dino.torpor.reduce_torpor(dino.torpor.max_torpor)
	view.tick(0.01)
	_check(dino.visual.rotation == 0.0 and not view.is_sleep_icon_visible(), "acordou: em pé de novo")


func _test_player_view_frames() -> void:
	var player := _spawn_player()
	player.set_physics_process(false)
	var view := PlayerView.new()
	view.player = player
	_root.add_child(view)
	_track.call(view)
	_check(player.visual.hframes == 4 and player.visual.vframes == 7, "sprite do jogador: folha 4x7")
	view.tick(0.01)
	_check(player.visual.frame_coords == Vector2i(SpriteFacing.DOWN, 0), "parado de frente")
	player.velocity = Vector2.RIGHT * 70.0
	view.tick(0.13)
	_check(player.visual.frame_coords.x == SpriteFacing.RIGHT and player.visual.frame_coords.y == 1, "andando para a direita, quadro 1")
	view.tick(0.13)
	_check(player.visual.frame_coords.y == 2, "ciclo de andar avança")
	for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT]:
		player.velocity = direction * 70.0
		view.tick(0.01)
		_check(player.visual.frame_coords.x == SpriteFacing.column_for(direction, 0), "anda em %s" % direction)
	player.velocity = Vector2.ZERO
	view.tick(0.01)
	_check(player.visual.frame_coords == Vector2i(SpriteFacing.LEFT, 0), "parado mantém a direção")
	player.health.take_damage(1000.0)
	view.tick(0.01)
	_check(player.visual.frame_coords == Vector2i(0, 6), "morto: linha 6, coluna 0")


func _test_player_view_attack_sound() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.torpor.set_physics_process(false)
	dino.global_position = player.global_position + Vector2(-20.0, 0.0)
	player.target = dino.interactable
	player._in_range.append(dino.interactable)
	var view := PlayerView.new()
	view.player = player
	_root.add_child(view)
	_track.call(view)
	var cues: Array[StringName] = []
	view.sound_cue.connect(func(c: StringName) -> void: cues.append(c))
	_check(view.audio_player().stream == null and view.cue_streams.is_empty(), "sem stream por padrão")
	_check(player.attack(), "golpe acerta")
	_check(cues == [PlayerView.CUE_ATTACK] and view.is_attacking(), "o golpe emite o som e anima")
	view.tick(0.01)
	_check(player.visual.frame_coords == Vector2i(SpriteFacing.LEFT, 4),
			"ataque: linha 4, virado para o alvo (esquerda)")
	view.tick(PlayerView.ATTACK_SECONDS)
	_check(not view.is_attacking() and player.visual.frame_coords.y == 0, "o ataque termina")
	_check(not player.attack() and cues.size() == 1, "golpe em recarga não faz som")
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	var main_view: PlayerView = main.get_node("PlayerView")
	_check(main_view.cue_streams.get(PlayerView.CUE_ATTACK) != null and main_view.volume_db == 6.0
			and main_view.audio_player().volume_db == 6.0, "Main liga o som de ataque com +6 dB")


func _test_terrain_scene() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	var terrain: Node = main.get_node("Terrain")
	var ground: TileMapLayer = terrain.get_node("Ground")
	var trees: TileMapLayer = terrain.get_node("Trees")
	var foliage: TileMapLayer = terrain.get_node("Foliage")
	var decor: TileMapLayer = terrain.get_node("Decor")
	_check(ground.get_used_cells().size() == 40 * 23, "chão cobre os 40x23 tiles")
	var path_cells := 0
	for cell in ground.get_used_cells():
		if ground.get_cell_atlas_coords(cell) != Vector2i(0, 12) and ground.get_cell_atlas_coords(cell).y >= 7 \
				and ground.get_cell_atlas_coords(cell).y <= 10:
			path_cells += 1
	_check(path_cells > 60, "o caminho de terra existe (%d tiles)" % path_cells)
	_check(trees.get_used_cells().size() == 6 and foliage.get_used_cells().size() > 10 and decor.get_used_cells().size() > 40,
			"árvores, folhagem de borda e miudezas")
	_check(foliage.z_index > main.player.z_index and ground.z_index < 0, "folhagem à frente do jogador, chão atrás")
	_check(main.y_sort_enabled and terrain.y_sort_enabled and trees.y_sort_enabled, "profundidade pela posição em y")
	var bounds: StaticBody2D = main.get_node("Bounds")
	_check(bounds.get_child_count() == 4, "a área segue fechada pelas 4 bordas de antes")
	# Colisão nova: só o tronco das árvores e a base da casa.
	var tile_data := trees.get_cell_tile_data(trees.get_used_cells()[0])
	_check(tile_data.get_collision_polygons_count(0) == 1, "a árvore bloqueia só no tronco")
	_check(foliage.get_cell_tile_data(foliage.get_used_cells()[0]).get_collision_polygons_count(0) == 0, "folhagem não bloqueia")
	_check(decor.get_cell_tile_data(decor.get_used_cells()[0]).get_collision_polygons_count(0) == 0, "miudezas não bloqueiam")
	var walls: StaticBody2D = terrain.get_node("House/Walls")
	_check(walls.get_child_count() == 1 and terrain.get_node("Chest") is Sprite2D
			and terrain.get_node("Chest").get_child_count() == 0, "casa com uma parede; baú só decorativo")
	# O jogador e o dino começam em chão livre: nenhuma árvore sobre eles.
	for point: Vector2 in [main.player.position, main.dino.position]:
		var cell := trees.local_to_map(point)
		var blocked := false
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var other := trees.get_cell_tile_data(cell + Vector2i(dx, dy))
				blocked = blocked or other != null
		_check(not blocked, "ponto de partida %s livre de árvores" % point)


func _test_world_sounds_and_filter() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	var view: DinoView = main.get_node("DinoView")
	_check(view.cue_streams.get(DinoView.CUE_HIT) != null, "som de dano ligado")
	_check(view.cue_streams.get(DinoView.CUE_TAMED) != null, "som de domesticado ligado")
	_check(view.volume_db == 6.0 and view.audio_player().volume_db == 6.0, "volume +6 dB compensa o pico de -10 dBFS")
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0,
			"filtro de textura nearest")
	main.dino.set_physics_process(false)
	var cues: Array[StringName] = []
	view.sound_cue.connect(func(c: StringName) -> void: cues.append(c))
	main.dino.take_damage(1.0, TamingRules.ATTACKER_PLAYER)
	_check(cues == [DinoView.CUE_HIT], "levar dano dispara o som")
	view.audio_player().stop()
	view.audio_player().stream = null


func _test_ui_theme_and_icons() -> void:
	var theme := UiTheme.get_theme()
	_check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "painéis do pacote no tema")
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxTexture
	_check(panel.get_texture_margin(SIDE_LEFT) == 6.0, "9-slice com margem 6")
	for item_id: String in Items.all_ids():
		_check(ItemIcons.icon_of(item_id) != null, "item %s tem ícone" % item_id)
	var player := _spawn_player()
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.health_bar().get_child(0) is TextureRect, "a barra de vida usa o ícone de coração")
	var screen := InventoryScreen.new()
	screen.player_inventory = player.inventory
	_root.add_child(screen)
	_track.call(screen)
	screen.open_own()
	_check(screen.slot_button(true, 0).icon == ItemIcons.icon_of("berry"), "slot da baga mostra o ícone")
	_check(screen.slot_button(true, 5).icon == null, "slot vazio sem ícone")
	screen.close()
