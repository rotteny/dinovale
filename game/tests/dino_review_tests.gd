# SPDX-License-Identifier: MIT
class_name DinoReviewTests
extends DinoLevelTests
## Testes das duas revisões do recorte de nível/Eficiência/dano: cada regra do save e do
## combate com a sua prova. Reaproveita os auxiliares de `DinoLevelTests`.


func run() -> void:
	_test_review_fixes()


## Achados da revisão: cada regra tem a sua prova.
func _test_review_fixes() -> void:
	# Vida perdida (não a atual) sobrevive à mudança de nível: 132/140 em L30 é 172/180.
	var lost := _spawn_dino()
	lost.set_physics_process(false)
	lost.level = 20
	lost.health.take_damage(8.0)
	lost.level = 30
	_check(is_equal_approx(lost.health.current_health, 172.0) and is_equal_approx(lost.health.max_health, 180.0),
			"nível 20 -> 30 mantém a vida perdida: 172/180")
	# Fórmulas do nível final com tolerância e teto.
	_check(LEVEL_RULES.final_level(50, 26.0) == 57 and LEVEL_RULES.final_level(50, 30.0) == 58, "(50,26%)=57 e (50,30%)=58")
	_check(LEVEL_RULES.final_level(60, 5.0) == 62 and LEVEL_RULES.final_level(75, 76.0) == 104, "(60,5%)=62 e (75,76%)=104")
	_check(LEVEL_RULES.final_level(20, 50.0) == 25 and LEVEL_RULES.final_level(1, 100.0) == 2, "valores exatos 20@50%=25 e 1@100%=2")
	_check(LEVEL_RULES.final_level(60, 100.0) == 90, "teto 1,5x: 60 vira no máximo 90")
	var top := _sleeping_dino_at(75)
	_check(top.taming.preview_level() == 75, "prévia limitada ao nível máximo do mundo (75)")
	var mid := _sleeping_dino_at(20)
	mid.taming.efficiency = 50.0
	_check(mid.taming.preview_level() == 25, "prévia com valor exato: L20 a 50% = 25")
	# Atacante desconhecido: nem dano nem torpor.
	var wild := _spawn_dino()
	wild.set_physics_process(false)
	_check(not wild.receive_hit(5.0, 30.0, "alienigena") and wild.torpor.current_torpor == 0.0
			and is_equal_approx(wild.health.current_health, 100.0), "atacante desconhecido: sem dano e sem torpor")
	# Dano 0 dormindo ainda aplica o fixo; dano negativo não.
	var zero := _sleeping_dino_at(10)
	zero.take_damage(0.0, TamingRules.ATTACKER_PLAYER)
	_check(is_equal_approx(zero.taming.efficiency, 96.0), "dano 0 dormindo: fixo de 4 de Eficiência")
	_check(not zero.take_damage(-3.0, TamingRules.ATTACKER_PLAYER) and is_equal_approx(zero.taming.efficiency, 96.0),
			"dano negativo é ignorado")
	# Drenagem negativa recupera até 100.
	var heal := _sleeping_dino_at(10)
	var rules: TamingRules = heal.taming.rules.duplicate()
	rules.time_drain_per_second = -5.0
	heal.taming.rules = rules
	heal.taming.efficiency = 90.0
	heal.taming.tick(1.0)
	_check(is_equal_approx(heal.taming.efficiency, 95.0), "drenagem negativa recupera 5")
	heal.taming.tick(10.0)
	_check(is_equal_approx(heal.taming.efficiency, 100.0), "recuperação limitada a 100")
	# Segundo nocaute zera o relógio da pausa.
	var ko: TorporComponent = _track.call(TorporComponent.new())
	ko.decay_per_second = 0.0
	ko.add_torpor(80.0)
	ko.tick(0.1)
	ko.tick(3.2)
	_check(ko.to_dict()["pause_clock"] > 3.0, "relógio da pausa corre na faixa 3")
	ko.add_torpor(100.0)
	ko.tick(0.1)
	_check(ko.to_dict()["pause_clock"] == 0.0 and not ko.is_paused(), "nocaute zera o relógio da pausa")
	ko.reset()
	ko.add_torpor(80.0)
	ko.tick(0.1)
	_check(ko.to_dict()["pause_clock"] < 0.2, "segundo nocaute: relógio recomeça do zero")
	_test_review_save_rules()


func _test_review_save_rules() -> void:
	# Faixa na zona de histerese: o save diz 1 com 23%, e vale; sem o save seria 0.
	var band: TorporComponent = _track.call(TorporComponent.new())
	band.from_dict({"current": 23.0, "band": 1})
	_check(band.band == 1, "load na histerese: faixa salva 1 vale")
	band.from_dict({"current": 23.0, "band": 0})
	_check(band.band == 0, "load na histerese: faixa salva 0 vale")
	band.from_dict({"current": 10.0, "band": 3})
	_check(band.band == 0, "faixa salva incompatível com a fração é corrigida")
	var bands: Array[int] = []
	band.band_changed.connect(func(value: int) -> void: bands.append(value))
	band.from_dict({"current": 80.0, "band": 3})
	_check(bands.is_empty(), "from_dict não emite band_changed")
	# Relógio da pausa vai no save; a fase muda entre dinos.
	var source: TorporComponent = _track.call(TorporComponent.new())
	source.decay_per_second = 0.0
	source.pause_phase = 1.3
	source.add_torpor(80.0)
	for i in 18:
		source.tick(0.1)
	# Ciclo = relógio + 1,3; a pausa começa em 3,2: faltam 0,1 s, então não está pausada.
	var copy: TorporComponent = _track.call(TorporComponent.new())
	copy.decay_per_second = 0.0
	copy.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())))
	_check(not source.is_paused() and copy.band == 3 and is_equal_approx(copy.pause_phase, 1.3)
			and is_equal_approx(copy.to_dict()["pause_clock"], source.to_dict()["pause_clock"]), "relógio e fase restaurados")
	var same := true
	var paused_ticks := 0
	for i in 60:
		source.tick(0.1)
		copy.tick(0.1)
		same = same and source.is_paused() == copy.is_paused()
		paused_ticks += 1 if copy.is_paused() else 0
	_check(same and paused_ticks >= 6, "mesma pausa depois do load, tick a tick (%d ticks pausados)" % paused_ticks)
	var first := _dino_at(Vector2(10, 20))
	var second := _dino_at(Vector2(300, 80))
	_check(first.torpor.pause_phase != second.torpor.pause_phase, "dinos em pontos diferentes têm fases de pausa diferentes")
	# `max` adulterado e campos inválidos.
	var tiny: TorporComponent = _track.call(TorporComponent.new())
	tiny.from_dict({"current": 50.0, "max": 1.0, "is_unconscious": false})
	_check(not tiny.is_unconscious and tiny.max_torpor == 100.0 and tiny.current_torpor == 50.0, "max adulterado não decide consciência")
	var dino := _spawn_dino()
	var levels: Array[int] = []
	dino.level_changed.connect(func(value: int) -> void: levels.append(value))
	var junk := {
		"position": {"x": null, "y": [1]}, "level": null,
		"health": {"current": null}, "torpor": {"current": [1], "band": "x", "pause_clock": NAN, "is_unconscious": 3},
		"taming": {"progress": NAN, "meal_timer": INF, "efficiency": null}, "inventory": 5, "state_machine": "x",
	}
	dino.from_dict(junk)
	_check(dino.level == LEVEL_RULES.base_level and is_equal_approx(dino.health.current_health, 100.0)
			and dino.torpor.current_torpor == 0.0 and dino.taming.efficiency == 100.0, "campos null/Array/NaN não alteram o estado")
	_check(dino.taming.taming_progress == 0.0 and dino.taming.to_dict()["meal_timer"] == 0.0
			and dino.torpor.to_dict()["pause_clock"] == 0.0 and not dino.state_machine.is_tamed,
			"progress, meal_timer e pause_clock inválidos ficam no padrão (nem NaN nem INF)")
	dino.level = 30
	dino.from_dict({})
	_check(dino.level == LEVEL_RULES.base_level, "nível ausente usa o nível padrão do dado")
	levels.clear()
	dino.from_dict({"level": 40})
	_check(dino.level == 40 and levels.is_empty(), "from_dict não emite level_changed")
	# Carga com mudança de nível e de máximo de torpor: nenhuma faixa é anunciada.
	var src := _spawn_dino()
	src.set_physics_process(false)
	src.level = 30
	src.torpor.add_torpor(80.0)
	var dest := _spawn_dino()
	dest.set_physics_process(false)
	var announced := [0]
	dest.torpor.band_changed.connect(func(_value: int) -> void: announced[0] += 1)
	dest.from_dict(JSON.parse_string(JSON.stringify(src.to_dict())))
	_check(dest.level == 30 and announced[0] == 0, "Dino.from_dict não emite band_changed (%d)" % announced[0])
	# Vida 0 no save: morto na carga, sem died.
	var corpse := _spawn_dino()
	var deaths := [0]
	corpse.health.died.connect(func() -> void: deaths[0] += 1)
	corpse.from_dict({"health": {"current": 0.0}})
	_check(corpse.health.is_dead() and corpse.is_queued_for_deletion() and deaths[0] == 0, "vida 0 no save: morto, sem died")
	# progress=100 dormindo não trava: a próxima refeição conclui.
	var asleep := _sleeping_dino_at(10)
	var saved := asleep.to_dict()
	saved["taming"] = {"progress": 100.0, "meal_timer": 0.0, "efficiency": 80.0}
	var loaded := _spawn_dino()
	loaded.set_physics_process(false)
	loaded.from_dict(saved)
	_check(loaded.taming.taming_progress < 100.0 and not loaded.state_machine.is_tamed, "progress 100 dormindo volta à penúltima refeição")
	loaded.inventory.add(loaded.taming.ideal_food, 1)
	loaded.taming.tick(loaded.taming.seconds_per_meal)
	_check(loaded.state_machine.is_tamed and loaded.inventory.count(loaded.taming.ideal_food) == 0,
			"e UMA baga basta para concluir")
	_test_review_followups()


func _dino_at(point: Vector2) -> Dino:
	var dino: Dino = DinoScene.instantiate()
	dino.position = point
	_root.add_child(dino)
	_track.call(dino)
	return dino


func _test_review_followups() -> void:
	# Acordar e dormir de novo zera o relógio da refeição.
	var meal := _sleeping_dino_at(10)
	meal.inventory.add(meal.taming.ideal_food, 3)
	meal.taming.tick(meal.taming.seconds_per_meal * 0.5)
	_check(meal.taming.to_dict()["meal_timer"] > 0.0, "relógio da refeição andou")
	meal.torpor.reset()
	_check(meal.taming.to_dict()["meal_timer"] == 0.0, "acordar zera o relógio da refeição")
	meal.torpor.add_torpor(meal.torpor.max_torpor)
	_check(meal.taming.to_dict()["meal_timer"] == 0.0 and meal.taming.taming_progress == 0.0,
			"dormir de novo começa sem relógio nem progresso")
	# Guarda de morto: nem dano nem torpor num dino sem vida, e o golpe fatal não dá torpor.
	var corpse := _spawn_dino()
	corpse.set_physics_process(false)
	corpse.health.take_damage(1000.0)
	_check(not corpse.receive_hit(5.0, 30.0, TamingRules.ATTACKER_PLAYER) and corpse.torpor.current_torpor == 0.0,
			"receive_hit em morto: nada")
	var fatal := _spawn_dino()
	fatal.set_physics_process(false)
	_check(fatal.receive_hit(1000.0, 30.0, TamingRules.ATTACKER_PLAYER) and fatal.torpor.current_torpor == 0.0,
			"golpe fatal não aplica torpor")
	# Carga num dino vivo com torpor real: nenhuma faixa anunciada, mesmo com máximo novo.
	var src := _spawn_dino()
	src.set_physics_process(false)
	src.level = 30
	src.torpor.add_torpor(60.0)
	var live := _spawn_dino()
	live.set_physics_process(false)
	live.torpor.add_torpor(80.0)
	var heard := [0]
	live.torpor.band_changed.connect(func(_value: int) -> void: heard[0] += 1)
	live.from_dict(JSON.parse_string(JSON.stringify(src.to_dict())))
	_check(live.level == 30 and heard[0] == 0, "load em dino vivo não emite band_changed (%d)" % heard[0])
	# Nível salvo legítimo acima do teto é limitado; vida fracionária não é curada.
	live.from_dict({"level": 9999})
	_check(live.level == LEVEL_RULES.max_level, "nível acima do teto é limitado a %d" % LEVEL_RULES.max_level)
	var frac := _spawn_dino()
	frac.set_physics_process(false)
	frac.from_dict({"health": {"current": 0.5}})
	_check(is_equal_approx(frac.health.current_health, 0.5), "load não cura vida fracionária")
	# Prévia emitida pelo sinal é a mesma do final (com teto).
	var top := _sleeping_dino_at(75)
	var seen := [0]
	top.taming.level_preview_changed.connect(func(_lv: int, final_level: int) -> void: seen[0] = final_level)
	top.taming.efficiency = 100.0
	top.taming.apply_attack(TamingRules.ATTACKER_PLAYER, 0.0)
	_check(seen[0] == top.taming.preview_level() and seen[0] == 75, "sinal da prévia limita ao teto (%d)" % seen[0])
	# Fase da pausa definida na cena vale.
	var scene_dino: Dino = DinoScene.instantiate()
	scene_dino.get_node("TorporComponent").set("pause_phase", 2.5)
	scene_dino.position = Vector2(100, 100)
	_root.add_child(scene_dino)
	_track.call(scene_dino)
	_check(is_equal_approx(scene_dino.torpor.pause_phase, 2.5), "fase da pausa da cena não é sobrescrita")
	# SafeRead em máquina, jogador, stamina e fome.
	var sleepy := _sleeping_dino_at(10)
	var tamed_state := sleepy.state_machine.to_dict()
	tamed_state["is_tamed"] = "talvez"
	sleepy.from_dict({"torpor": sleepy.torpor.to_dict(), "state_machine": tamed_state})
	_check(sleepy.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and sleepy.torpor.is_unconscious,
			"is_tamed inválido: torpor e máquina concordam (dormindo)")
	var player := _spawn_player()
	player.from_dict({"position": {"x": null, "y": "a"}, "health": {"current": 40.0}, "stamina": {"current": null, "max": [1]},
			"hunger": {"current": NAN, "starvation_timer": INF}})
	_check(is_equal_approx(player.health.current_health, 40.0) and player.stamina.current_stamina == player.stamina.max_stamina
			and player.hunger.current_hunger == player.hunger.max_hunger, "Player: posição e campos inválidos não impedem a vida")
	player.from_dict({"stamina": {"current": 30.0, "is_exhausted": "sim"}, "hunger": {"current": 25.0, "max": 50.0}})
	_check(is_equal_approx(player.stamina.current_stamina, 30.0) and not player.stamina.is_exhausted
			and is_equal_approx(player.hunger.current_hunger, 25.0), "Stamina e Hunger validam tipos")
	# Barras: depois que `follow()` agenda a remoção, `tick` para (não toca no dino removido).
	var victim := _spawn_dino()
	victim.set_physics_process(false)
	var bars := _spawn_bars(victim)
	victim.take_damage(5.0, TamingRules.ATTACKER_PLAYER)
	victim.free()
	bars.tick(10.0)
	_check(bars.is_queued_for_deletion(), "barras somem junto com o dino removido")

