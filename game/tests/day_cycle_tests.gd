# SPDX-License-Identifier: MIT
class_name DayCycleTests
extends SaveTests
## E9 (dia e noite, SOB-03): fases nas fronteiras, hora no save, relógio parado na pausa, eventos de log, chave do
## servidor, tinta (nunca preta, transição suave), luz e o isolamento da UI. A percepção do Agressivo e o núcleo seguro
## estão em `DayNightThreatTests`.

const DAY_END := 420.0
const DUSK_END := 480.0
const NIGHT_END := 660.0
const CYCLE := 720.0
const RULES: DayCycleRules = preload("res://data/balance/day_cycle_rules.tres")


func run() -> void:
	_test_data()
	_test_phase_boundaries()
	_test_tint()
	_test_server_key()
	_test_events()
	_test_save_mid_night()
	await _test_pause_freezes_phase()
	_test_view_and_hud()


func _cycle() -> DayCycle:
	return DayCycle.new(RULES)


func _test_data() -> void:
	var rules := RULES
	_check(rules != null and rules.cycle_seconds == CYCLE, "E9: o ciclo padrão tem 12 min")
	var cycle := _cycle()
	_check(is_equal_approx(cycle.end_of(DayCycle.Phase.DAY), 420.0) and is_equal_approx(cycle.end_of(DayCycle.Phase.DUSK), 60.0 + 420.0)
			and is_equal_approx(cycle.end_of(DayCycle.Phase.NIGHT), 660.0) and is_equal_approx(cycle.end_of(DayCycle.Phase.DAWN), CYCLE),
			"E9: 7 min de dia, 1 de entardecer, 3 de noite e 1 de amanhecer")
	_check(rules.night_perception_multiplier == 1.5 and rules.light_radius_tiles == 5.0, "E9: percepção x1,5 e luz de 5 tiles em dado")
	var names := {}
	for phase in DayCycle.ORDER:
		names[DayCycle.name_of(phase)] = DayCycle.phase_from_name(DayCycle.name_of(phase)) == phase
	_check(names.size() == 4 and not names.values().has(false), "E9: a fase vai pelo nome estável, nunca pelo número")
	_check(DayCycle.phase_from_name("lixo", DayCycle.Phase.NIGHT) == DayCycle.Phase.NIGHT, "E9: nome desconhecido devolve o reserva")


func _test_phase_boundaries() -> void:
	var cycle := _cycle()
	var phases := DayCycle.Phase
	var cases := [
		[0.0, phases.DAY], [DAY_END - 0.001, phases.DAY], [DAY_END, phases.DUSK], [DUSK_END - 0.001, phases.DUSK], [DUSK_END, phases.NIGHT],
		[NIGHT_END - 0.001, phases.NIGHT], [NIGHT_END, phases.DAWN], [CYCLE - 0.001, phases.DAWN], [CYCLE, phases.DAY],
		[CYCLE + DUSK_END, phases.NIGHT],
		[CYCLE * 5.0 + DAY_END, phases.DUSK], [-5.0, phases.DAY], [INF, phases.DAY], [NAN, phases.DAY],
	]
	for entry: Array in cases:
		_check(cycle.phase_at(entry[0]) == entry[1], "E9: t=%s é %s" % [entry[0], DayCycle.name_of(entry[1])])
	_check(cycle.perception_scale(DUSK_END) == 1.5 and cycle.perception_scale(NIGHT_END - 0.001) == 1.5,
			"E9: x1,5 do primeiro ao último instante da noite")
	_check(cycle.perception_scale(DUSK_END - 0.001) == 1.0 and cycle.perception_scale(NIGHT_END) == 1.0 and cycle.perception_scale(0.0) == 1.0,
			"E9: x1 no entardecer, no amanhecer e de dia")


func _test_tint() -> void:
	var cycle := _cycle()
	var rules := cycle.rules
	var darkest := 1.0
	var steepest := 0.0
	var previous := cycle.tint_at(0.0)
	for second in range(1, int(CYCLE) * 2):
		var tint := cycle.tint_at(float(second))
		darkest = minf(darkest, minf(tint.r, minf(tint.g, tint.b)))
		steepest = maxf(steepest, maxf(absf(tint.r - previous.r), maxf(absf(tint.g - previous.g), absf(tint.b - previous.b))))
		previous = tint
	_check(darkest >= rules.min_tint_channel - 0.0001 and rules.min_tint_channel >= 0.3,
			"E9: a tinta nunca vai a preto (mínimo %.2f)" % darkest)
	_check(steepest < 0.05, "E9: a transição entre faixas é suave (maior salto por segundo %.3f)" % steepest)
	_check(cycle.tint_at(200.0).is_equal_approx(rules.day_tint) and cycle.tint_at(560.0).is_equal_approx(rules.night_tint),
			"E9: no meio de cada faixa vale a tinta dela")
	var severe := rules.duplicate() as DayCycleRules
	severe.night_tint = Color(0.0, 0.0, 0.0)
	var clamped := DayCycle.new(severe).tint_at(560.0)
	var floor_value := severe.min_tint_channel - 0.0001
	_check(clamped.r >= floor_value and clamped.g >= floor_value and clamped.b >= floor_value, "E9: tinta preta no dado é erguida ao mínimo")


func _test_server_key() -> void:
	var defaults := ServerRulesDefaults.new(RespawnRules.new(), load("res://data/world/world_rules.tres"),
			load("res://data/balance/taming_rules.tres"))
	var base := ServerRules.parse("{}", defaults)
	_check(base.day_cycle_seconds == CYCLE and ServerRules.NUMBER_RANGES.has("ciclo_dia_s"), "E9: ciclo_dia_s tem o padrão do .tres")
	var custom := ServerRules.parse('{"version": 1, "ciclo_dia_s": 360}', defaults)
	var rules := custom.apply_day_cycle(defaults.day_cycle)
	var cycle := DayCycle.new(rules)
	_check(rules.cycle_seconds == 360.0 and defaults.day_cycle.cycle_seconds == CYCLE, "E9: a cópia leva a duração e o .tres fica intacto")
	_check(cycle.phase_at(239.0) == DayCycle.Phase.DUSK and cycle.phase_at(240.0) == DayCycle.Phase.NIGHT,
			"E9: com 360 s a noite começa em 240 s (as faixas são partes do ciclo)")
	var bad := ServerRules.parse('{"version": 1, "ciclo_dia_s": 5}', defaults)
	_check(bad.day_cycle_seconds == CYCLE and not bad.problems.is_empty(), "E9: duração fora da faixa volta ao padrão com aviso")
	_check(base.as_file_data().has("ciclo_dia_s"), "E9: o arquivo novo do operador traz a chave")


func _authority() -> WorldAuthority:
	var authority := WorldAuthority.new()
	_track.call(authority)
	return authority


func _test_events() -> void:
	var authority := _authority()
	var codes: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: codes.append(code))
	authority.tick_day()  # a primeira conferência só grava a faixa
	authority.clock.advance(DAY_END)
	authority.tick_day()  # entardecer: sem evento
	authority.clock.advance(DUSK_END - DAY_END)
	authority.tick_day()
	authority.tick_day()  # sem mudança: sem repetir
	_check(codes == ["night_started"], "E9: a noite anuncia night_started uma vez (%s)" % [codes])
	authority.clock.advance(NIGHT_END - DUSK_END)
	authority.tick_day()  # amanhecer: sem evento
	authority.clock.advance(CYCLE - NIGHT_END)
	authority.tick_day()
	_check(codes == ["night_started", "day_started"], "E9: o dia anuncia day_started (%s)" % [codes])
	for code in ["night_started", "day_started"]:
		_check(GameMessages.EVENTS.has(code) and GameMessages.text_of(code) != "", "E9: o texto de %s existe" % code)
	var skipper := _authority()
	var skipped: Array[String] = []
	skipper.game_event.connect(func(code: String, _params: Dictionary) -> void: skipped.append(code))
	skipper.tick_day()
	skipper.clock.advance(DUSK_END + 10.0)  # pulou o entardecer num só passo
	skipper.tick_day()
	_check(skipped == ["night_started"], "E9: um passo longo que pula o entardecer ainda anuncia a noite")


## Salvar no meio da noite e carregar: a hora e a faixa voltam, e carregar não anuncia nada (não é evento de jogo).
func _test_save_mid_night() -> void:
	var source := _main("day_night_save")
	source.authority.clock.advance(560.0)
	_check(source.save_game(R.BED), "E9: salva no meio da noite")
	var saved := source.save_manager.read_file(source.save_manager.main_path())
	_check(saved.status == SaveManager.Status.OK and is_equal_approx(float(saved.data["world"]["time"]), 560.0),
			"E9: a hora do dia já está no save (world.time)")
	var target := _main("day_night_target")
	target.authority.tick_day()  # este mundo estava de dia
	var codes: Array[String] = []
	target.authority.game_event.connect(func(code: String, _params: Dictionary) -> void: codes.append(code))
	_check(WorldSnapshot.restore(saved.data, target.player, target.dino, target.resources, target.wild, target.carcasses,
			target.authority, target.ground, target.corpses, target.authority.build.grid), "E9: carrega o save da noite")
	target.authority.tick_day()
	_check(is_equal_approx(target.authority.clock.now(), 560.0) and target.authority.day_phase() == DayCycle.Phase.NIGHT,
			"E9: carregou e é noite, na mesma hora")
	_check(target.authority.perception_scale() == 1.5, "E9: a percepção da noite volta junto com a hora")
	_check(codes.is_empty(), "E9: carregar no meio da noite não anuncia a noite (%s)" % [codes])


## O relógio só anda em `_physics_process`, que a pausa suspende: a fase não avança com o jogo pausado.
func _test_pause_freezes_phase() -> void:
	var tree := _root.get_tree()
	var authority := WorldAuthority.new()
	_root.add_child(authority)
	_track.call(authority)
	authority.clock.restore(DAY_END - 0.01)  # a 10 ms de virar entardecer
	tree.paused = true
	var before := authority.clock.now()
	for _i in 5:
		await tree.physics_frame
	var frozen := authority.clock.now() == before and authority.day_phase() == DayCycle.Phase.DAY
	tree.paused = false
	for _i in 5:
		await tree.physics_frame
	_check(frozen, "E9: pausado, o relógio não anda e a fase não avança")
	_check(authority.clock.now() > before and authority.day_phase() == DayCycle.Phase.DUSK, "E9: despausado, o relógio volta e a fase vira")


func _test_view_and_hud() -> void:
	var main := _main("day_night_view")
	var view: DayNightView = null
	for child in main.get_children():
		if child is DayNightView:
			view = child
	_check(view != null, "E9: a Main monta a vista do dia e da noite")
	if view == null:
		return
	var rules := main.authority.day_cycle.rules
	main.authority.clock.restore(200.0)
	view.tick(0.0)
	main.hud.tick(0.0)
	_check(view.tint_node().color.is_equal_approx(rules.day_tint) and not view.light_node().visible, "E9: de dia sem tinta e sem luz")
	_check(main.hud.phase_label().visible and main.hud.phase_label().text == "Dia", "E9: o HUD mostra a fase (dia)")
	main.authority.clock.restore(560.0)
	view.tick(0.0)
	main.hud.tick(0.0)
	var night := view.tint_node().color
	_check(night.is_equal_approx(rules.night_tint) and view.light_node().visible, "E9: de noite com a tinta da faixa e a luz do jogador acesa")
	_check(main.hud.phase_label().text == "Noite", "E9: o HUD mostra a fase (noite)")
	var light := view.light_node()
	var radius_tiles: float = light.texture.get_width() * light.texture_scale / 2.0 / view.tile_px
	_check(is_equal_approx(radius_tiles, 5.0), "E9: a luz tem 5 tiles de raio (%.2f)" % radius_tiles)
	_check(light.global_position.is_equal_approx(main.player.global_position + view.light_offset), "E9: a luz acompanha o jogador")
	var center := Color(night.r + light.color.r, night.g + light.color.g, night.b + light.color.b)
	_check(center.is_equal_approx(Color(1, 1, 1)), "E9: no centro da luz a cor do mundo volta inteira (tinta + luz = 1)")
	# Estrutural: a tinta e a luz moram no canvas do mundo; o HUD fica num CanvasLayer, outro canvas.
	_check(view.tint_node().get_canvas_layer_node() == null and light.get_canvas_layer_node() == null,
			"E9: tinta e luz estão no canvas do mundo, fora de qualquer CanvasLayer")
	_check(main.hud.get_canvas_layer_node() != null and main.hud.get_canvas() != view.tint_node().get_canvas(),
			"E9: a HUD está num CanvasLayer próprio, em outro canvas que o da tinta")
	var strays := _modulates_under_layers(main)
	_check(strays == 0, "E9: nenhum CanvasModulate ou luz dentro de um CanvasLayer (%d)" % strays)


func _modulates_under_layers(node: Node) -> int:
	var found := 0
	for child in node.get_children():
		if (child is CanvasModulate or child is Light2D) and (child as CanvasItem).get_canvas_layer_node() != null:
			found += 1
		found += _modulates_under_layers(child)
	return found
