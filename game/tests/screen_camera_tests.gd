# SPDX-License-Identifier: MIT
class_name ScreenCameraTests
extends DinoLevelTests
## Etapa A da integração (viewport 320x180): escala inteira, câmera centrada que só para no limite do
## mapa, névoa de borda, HUD compacta, telas que cabem em 320x180, jogador de 32x32 (folha, pés e
## hitbox em dado). Reaproveita os auxiliares de `DinoLevelTests`.

const TITLE_SCENE := preload("res://src/ui/TitleScreen.tscn")
const VIEW := Vector2(320.0, 180.0)
## A HUD sempre ligada (barras e atalhos) ocupa menos que isto da tela; com todos os avisos juntos, o teto maior.
const HUD_BASE_MAX_RATIO := 0.09  # 08/11: subiu de 8% com a barra de Stamina pedida pelo dono
const HUD_WORST_MAX_RATIO := 0.14


func run() -> void:
	_test_project_screen_settings()
	_test_map_bounds_rules()
	_test_sheet_definition()
	_test_player_body_by_data()
	await _test_camera_follows_and_stops_at_edges()
	_release_worlds()
	await _test_fog_frame()
	_release_worlds()
	await _test_hud_coverage()
	_release_worlds()
	await _test_screens_fit()
	_release_worlds()
	await _test_title_long_notice()
	_release_worlds()
	await _test_continue_first_frame()
	_release_worlds()
	await _test_camera_pixel_snap()
	_release_worlds()
	_test_hostile_sheet()
	await _test_inventory_cells_and_detail()
	_release_worlds()


func _test_project_screen_settings() -> void:
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 320
			and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 180, "viewport do projeto é 320x180")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport"
			and ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer"
			and ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "esticar: viewport, escala inteira, mantém a proporção")
	var text := FileAccess.get_file_as_string("res://project.godot")
	_check(text.contains("viewport_width=320") and text.contains("viewport_height=180") and text.contains('window/stretch/mode="viewport"'),
			"project.godot declara 320x180 com esticar em viewport")
	_check(int(ProjectSettings.get_setting("display/window/size/window_width_override")) % 320 == 0
			or not ProjectSettings.has_setting("display/window/size/window_width_override"), "a janela inicial, se definida, é múltipla de 320")
	_check(_root.get_viewport().get_visible_rect().size == VIEW, "a área visível da raiz é 320x180")


func _test_map_bounds_rules() -> void:
	var bounds: MapBounds = load("res://data/world/map_bounds.tres")
	_check(bounds != null and bounds.rect == Rect2(0, 0, 4096, 4096) and bounds.fits_view(VIEW), "limite do mapa vem do dado")
	_check(bounds.clamp_center(Vector2(2048, 2048), VIEW) == Vector2(2048, 2048), "no meio: o centro é o alvo")
	_check(bounds.clamp_center(Vector2(5, 5), VIEW) == Vector2(160, 90), "canto de cima à esquerda: para a meia tela da borda")
	_check(bounds.clamp_center(Vector2(4200, 4200), VIEW) == Vector2(3936, 4006), "canto de baixo à direita: para a meia tela da borda")
	_check(bounds.clamp_center(Vector2(100, 2048), VIEW) == Vector2(160, 2048), "só um eixo preso: o outro segue o alvo")
	var tiny := MapBounds.new()
	tiny.rect = Rect2(0, 0, 100, 50)
	_check(not tiny.fits_view(VIEW) and tiny.clamp_center(Vector2(0, 0), VIEW) == Vector2(50, 25), "mapa menor que a tela: centra o mapa")


func _test_sheet_definition() -> void:
	var sheet := SpriteSheetDef.from_json_file(PlayerView.SHEET_PATH)
	_check(sheet.is_valid() and sheet.frame_size == Vector2i(32, 32) and sheet.columns == 10 and sheet.rows == 8,
			"jogador.json: quadro 32x32, 10 colunas, 8 linhas")
	_check(sheet.direction_rows[SpriteFacing.DOWN] == "down" and sheet.direction_rows[SpriteFacing.UP] == "up"
			and sheet.direction_rows[SpriteFacing.LEFT] == "left" and sheet.direction_rows[SpriteFacing.RIGHT] == "right",
			"a ordem das linhas do JSON é a de SpriteFacing (baixo, cima, esquerda, direita)")
	_check(sheet.direction_rows.size() == sheet.rows and sheet.direction_rows[SpriteFacing.DOWN_LEFT] == "down_left"
			and sheet.direction_rows[SpriteFacing.UP_RIGHT] == "up_right", "as 4 diagonais seguem na ordem de SpriteFacing")
	for name in ["idle", "walk", "hit", "fall"]:
		_check(sheet.has_animation(name), "jogador.json tem a animação %s" % name)
	_check(sheet.column_at("walk", 0.0) == 2 and sheet.column_at("walk", 0.13) == 3 and sheet.column_at("walk", 0.5) == 2,
			"walk: colunas 2 a 5 a 8 fps, em laço")
	_check(sheet.column_at("hit", 9.0) == 8 and is_equal_approx(sheet.duration("hit"), 0.3), "hit: sem laço, termina no quadro 8, 0,3 s")
	var texture := load("res://assets/sprites/jogador/jogador.png") as Texture2D
	_check(texture.get_size() == Vector2(sheet.frame_size * Vector2i(sheet.columns, sheet.rows)), "o PNG tem o tamanho que o JSON descreve")
	var broken := SpriteSheetDef.new()
	broken.load_dict({"quadro": "x", "animacoes": [1, 2], "colunas": -5})
	_check(not broken.is_valid() and not SpriteSheetDef.from_json_file("res://nao_existe.json").is_valid(),
			"JSON torto ou ausente não aborta")


func _test_player_body_by_data() -> void:
	var player := _spawn_player()
	player.set_physics_process(false)
	var sheet := SpriteSheetDef.from_json_file(PlayerView.SHEET_PATH)
	var box := player.get_node("CollisionShape2D") as CollisionShape2D
	var size := (box.shape as RectangleShape2D).size
	_check(Vector2i(size) == sheet.feet_collision, "a caixa de colisão é a colisao_pes do JSON (12x8)")
	_check(is_equal_approx(box.position.y + size.y / 2.0, 0.0), "a caixa fica apoiada nos pés (borda de baixo na origem)")
	var frame_height := float(sheet.frame_size.y)
	_check(is_equal_approx(player.visual.offset.y, -frame_height / 2.0)
			and player.visual.hframes == sheet.columns and player.visual.vframes == sheet.rows,
			"a origem do corpo é a base do quadro: a ordem de profundidade (y_sort) usa os pés")
	_check(player.visual.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "sprite herda o filtro do projeto (nearest)")


func _test_main_for_camera() -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.scheduler.frozen = true
	return main


func _test_camera_follows_and_stops_at_edges() -> void:
	var main := _test_main_for_camera()
	var camera := main.get_node("PlayerCamera") as PlayerCamera
	_check(camera != null and camera.is_current() and not camera.position_smoothing_enabled, "câmera atual, sem suavização que borre o pixel")
	_check(camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 4096 and camera.limit_bottom == 4096,
			"limites da câmera vêm do dado do mapa")
	main.player.set_physics_process(false)
	await _root.get_tree().process_frame
	for point: Vector2 in [Vector2(2048, 2048), Vector2(2049, 2048), Vector2(2061, 2061), Vector2(2028, 1998)]:
		main.player.global_position = point
		await _root.get_tree().process_frame
		var expected := point + camera.focus_offset
		_check(camera.shown_center().is_equal_approx(expected), "no meio do mapa a câmera está centrada no personagem %s" % [point])
		_check(camera.global_position == camera.global_position.round(), "posição da câmera em pixel inteiro")
	# Bordas: a câmera para; o personagem segue andando.
	var cases := {
		Vector2(10, 2048): Vector2(160, 2048) + camera.focus_offset * Vector2(0, 1),
		Vector2(4091, 2048): Vector2(3936, 2048) + camera.focus_offset * Vector2(0, 1),
		Vector2(2048, 10): Vector2(2048, 90) + camera.focus_offset * Vector2(1, 0),
		Vector2(2048, 4086): Vector2(2048, 4006) + camera.focus_offset * Vector2(1, 0),
		Vector2(5, 5): Vector2(160, 90),
		Vector2(4095, 4095): Vector2(3936, 4006),
	}
	for point: Vector2 in cases:
		main.player.global_position = point
		await _root.get_tree().process_frame
		_check(camera.shown_center().is_equal_approx(cases[point]),
				"câmera no limite do mapa com o personagem em %s: %s" % [point, camera.shown_center()])
	# Nada fora do mapa aparece em nenhum caso.
	var bounds := Rect2(0, 0, 4096, 4096)
	main.player.global_position = Vector2(2, 2)
	await _root.get_tree().process_frame
	_check(bounds.encloses(Rect2(camera.shown_center() - VIEW / 2.0, VIEW)), "a janela da câmera nunca passa da borda do mapa")
	# Com o personagem andando de verdade, a câmera anda junto (mesma distância).
	main.player.global_position = Vector2(2048, 2048)
	await _root.get_tree().process_frame
	var before := camera.shown_center()
	main.player.global_position += Vector2(24, -16)
	await _root.get_tree().process_frame
	_check(camera.shown_center() - before == Vector2(24, -16), "a câmera anda junto com o personagem, sem atraso")


func _test_fog_frame() -> void:
	var main := _test_main_for_camera()
	var fog := main.get_node("UI/FogFrame") as FogFrame
	await _root.get_tree().process_frame
	_check(fog != null and fog.mouse_filter == Control.MOUSE_FILTER_IGNORE and fog.focus_mode == Control.FOCUS_NONE,
			"névoa não captura clique nem foco")
	_check(fog.size == VIEW and fog.get_index() == 0, "névoa cobre a tela e fica atrás da HUD (primeiro filho da UI)")
	_check(fog.max_alpha <= 0.5 and fog.steps >= 2, "névoa leve: opacidade máxima até 0,5, em degraus")
	# Lê a máscara que o shader aplica: opaca na borda, nula no miolo, só dentro de 2 tiles (32 px).
	var corner := fog.alpha_at(Vector2i(0, 0))
	var edge_mid := fog.alpha_at(Vector2i(int(VIEW.x) / 2, 0))
	var center := fog.alpha_at(Vector2i(int(VIEW.x) / 2, int(VIEW.y) / 2))
	_check(is_equal_approx(edge_mid, fog.max_alpha) and corner >= edge_mid, "névoa mais forte na borda: %.2f" % edge_mid)
	_check(center == 0.0, "névoa não cobre o centro da tela")
	_check(fog.alpha_at(Vector2i(32, 90)) == 0.0 and fog.alpha_at(Vector2i(31, 90)) > 0.0, "névoa acaba a 32 px da borda")
	var levels := {}
	var inverted := false
	for x in range(0, 33):
		var here := fog.alpha_at(Vector2i(x, 90))
		levels[snappedf(here, 0.001)] = true
		inverted = inverted or here < fog.alpha_at(Vector2i(mini(x + 1, 32), 90))
	_check(not inverted and levels.size() == fog.steps + 1, "névoa decresce da borda ao miolo em %d degraus" % fog.steps)


func _test_hud_coverage() -> void:
	var main := _test_main_for_camera()
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	var hud := main.hud
	var base := _coverage(hud.covered_rects())
	_check(base > 0.0 and base <= HUD_BASE_MAX_RATIO,
			"HUD sempre ligada ocupa %.1f%% da tela (teto %.0f%%)" % [base * 100.0, HUD_BASE_MAX_RATIO * 100.0])
	for rect in hud.covered_rects():
		_check(Rect2(Vector2.ZERO, VIEW).encloses(rect), "bloco da HUD dentro da tela: %s" % [rect])
	# Pior caso: fome, aviso de duas linhas, prompt e salvando ao mesmo tempo.
	main.player.hunger.current_hunger = 5.0
	main.player.hunger.hunger_changed.emit(5.0, main.player.hunger.max_hunger)
	hud.show_notice("Inventário cheio.", 30.0)
	hud.prompt_label().text = "E para Examinar"
	hud.prompt_label().visible = true
	hud.show_saving()
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	var notice_rect := hud.notice_label().get_global_rect()
	_check(absf(notice_rect.get_center().x - VIEW.x / 2.0) <= 1.0 and is_equal_approx(notice_rect.end.y, VIEW.y - PlayerHud.NOTICE_BOTTOM),
			"aviso centrado em baixo, acima da barra de atalhos: %s" % [notice_rect])
	_check(notice_rect.end.y <= hud.hotbar_bar().get_global_rect().position.y, "o aviso não cobre os atalhos")
	var worst := _coverage(hud.covered_rects())
	_check(worst <= HUD_WORST_MAX_RATIO, "HUD com todos os avisos ocupa %.1f%% (teto %.0f%%)" % [worst * 100.0, HUD_WORST_MAX_RATIO * 100.0])
	for rect in hud.covered_rects():
		_check(Rect2(Vector2.ZERO, VIEW).encloses(rect), "com avisos, nada da HUD sai da tela: %s" % [rect])
	print("   cobertura da HUD (retângulos): base %.2f%%, pior caso %.2f%%" % [base * 100.0, worst * 100.0])


## Fração da tela coberta pela união dos retângulos (sem contar a sobreposição duas vezes).
func _coverage(rects: Array[Rect2]) -> float:
	var covered := 0
	for y in int(VIEW.y):
		for x in int(VIEW.x):
			var point := Vector2(x + 0.5, y + 0.5)
			for rect in rects:
				if rect.has_point(point):
					covered += 1
					break
	return float(covered) / (VIEW.x * VIEW.y)


## Todo controle visível de uma tela cabe nos 320x180 (nada cortado). Filhos de `ScrollContainer` rolam.
func _fits(node: Node) -> bool:
	var ok := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Control and not (current as Control).is_visible_in_tree():
			continue
		if current is ScrollContainer:
			var rect := (current as Control).get_global_rect()
			ok = ok and Rect2(Vector2.ZERO, VIEW).grow(0.01).encloses(rect)
			continue
		if current is Control and (current as Control).is_visible_in_tree():
			var rect := (current as Control).get_global_rect()
			if rect.size.x > 0.0 and not Rect2(Vector2.ZERO, VIEW).grow(0.01).encloses(rect):
				ok = false
				print("   fora da tela: %s %s" % [current.get_path(), rect])
		stack.append_array(current.get_children())
	return ok


func _test_screens_fit() -> void:
	var main := _test_main_for_camera()
	main.player.set_physics_process(false)
	await _root.get_tree().process_frame
	# Inventário compartilhado (o maior): jogador com 12 vagas e criatura com 8.
	main.screen.open_with(main.player.inventory, main.dino.inventory, main.dino.interactable, "Criatura")
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	_check(_fits(main.screen), "inventário compartilhado cabe em 320x180")
	var first := main.screen.slot_button(true, 0)
	_check(first.has_focus(), "inventário: o foco começa na primeira célula")
	_check(main.screen.detail_text() == main.screen.slot_text(true, 0).replace("\n", "  "), "linha de detalhe mostra a célula focada")
	main.screen.close()
	main.screen.open_own()
	await _root.get_tree().process_frame
	_check(_fits(main.screen), "inventário próprio cabe em 320x180")
	main.screen.close()
	# Pausa.
	main.pause.open()
	await _root.get_tree().process_frame
	_check(_fits(main.pause), "pausa cabe em 320x180")
	main.pause.close()
	# Morte.
	main.death_screen.open(main.player.global_position)
	await _root.get_tree().process_frame
	_check(_fits(main.death_screen), "tela de morte cabe em 320x180")
	main.death_screen.close()
	# Título, todas as vistas.
	var title: TitleScreen = TITLE_SCENE.instantiate()
	title.auto_perform = false
	_root.add_child(title)
	_track.call(title)
	await _root.get_tree().process_frame
	for view_name in ["menu", "single", "confirm", "settings", "credits"]:
		title._show(view_name)
		await _root.get_tree().process_frame
		await _root.get_tree().process_frame
		_check(_fits(title), "título, vista '%s' cabe em 320x180" % view_name)


func _test_title_long_notice() -> void:
	GameSession.notice = "O save está corrompido e o backup também não pôde ser lido. Comece um jogo novo ou restaure uma cópia do arquivo."
	var title: TitleScreen = TITLE_SCENE.instantiate()
	title.auto_perform = false
	_root.add_child(title)
	_track.call(title)
	for i in 3:
		await _root.get_tree().process_frame
	var notice: Label = title._notice
	_check(notice.text.begins_with("O save") and notice.autowrap_mode != TextServer.AUTOWRAP_OFF, "aviso longo do título quebra linha")
	_check(notice.get_global_rect().size.x <= VIEW.x and _fits(title), "aviso longo do título cabe em 320x180 (fluxo real)")
	var menu_rect: Rect2 = (title._notice.get_parent() as Control).get_global_rect()
	_check(Rect2(Vector2.ZERO, VIEW).grow(0.01).encloses(menu_rect), "menu do título não é cortado pelo aviso: %s" % [menu_rect])


func _test_continue_first_frame() -> void:
	var world := "cam_first_frame"
	var first: Main = MAIN_SCENE.instantiate()
	first.world_id = world
	_root.add_child(first)
	_track.call(first)
	await _root.get_tree().process_frame
	first.player.global_position = Vector2(2300, 3150)
	first.save_game(SaveManager.Reason.EXIT_MENU)
	first.scheduler.frozen = true
	first.free()
	GameSession.continue_requested = true
	var second: Main = MAIN_SCENE.instantiate()
	second.world_id = world
	second.menu_scene = ""
	_root.add_child(second)  # _ready já rodou: lê o desenhado agora, antes de qualquer quadro
	_track.call(second)
	second.scheduler.frozen = true
	var camera := second.get_node("PlayerCamera") as PlayerCamera
	var wanted := (second.player.global_position + camera.focus_offset).round()
	_check(second.player.global_position.distance_to(Vector2(2300, 3150)) < 1.0, "Continuar restaurou o jogador em (2300, 3150)")
	var expected := camera.bounds.clamp_center(wanted, VIEW)
	_check(camera.global_position == wanted, "Continuar: logo após o _ready da Main a câmera já está no jogador (%s, esperado %s)"
			% [camera.global_position, wanted])
	await _root.get_tree().process_frame
	var drawn_origin := -second.get_viewport().canvas_transform.origin
	_check(drawn_origin.is_equal_approx(expected - VIEW / 2.0) and camera.shown_center().is_equal_approx(expected),
			"Continuar: o primeiro quadro desenhado já enquadra o jogador (canvas em %s)" % [drawn_origin])


func _test_camera_pixel_snap() -> void:
	var main := _test_main_for_camera()
	main.player.set_physics_process(false)
	main.scheduler.frozen = true
	var camera := main.get_node("PlayerCamera") as PlayerCamera
	main.player.global_position = Vector2(300.4, 200.6)
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	var center := camera.shown_center()
	_check(center.x == roundf(center.x) and center.y == roundf(center.y),
			"câmera cai em pixel inteiro com o jogador fracionário: %s" % [center])


func _test_hostile_sheet() -> void:
	# Colunas fora da folha são descartadas; linhas que não batem com `linhas_direcao` invalidam a folha.
	var odd := SpriteSheetDef.new()
	odd.load_dict({"quadro": [16, 32], "colunas": 2, "linhas": 1, "linhas_direcao": ["down"],
			"animacoes": {"idle": {"colunas": [0, 1, 2, 7], "fps": 4, "loop": true}}})
	_check(odd.is_valid() and odd.column_at("idle", 100.0) in [0, 1] and odd.duration("idle") == 0.5,
			"coluna fora da folha é descartada (restam 2 quadros)")
	var rows := SpriteSheetDef.new()
	rows.load_dict({"quadro": [16, 32], "colunas": 2, "linhas": 4, "linhas_direcao": ["down"],
			"animacoes": {"idle": {"colunas": [0, 1], "fps": 4, "loop": true}}})
	_check(not rows.is_valid(), "folha cujas linhas não batem com linhas_direcao é inválida")
	# PlayerView com folha de 40 colunas: sem ERROR (o contador de erros do runner falha o teste), quadro dentro da folha.
	var player := _spawn_player()
	player.set_physics_process(false)
	var view := PlayerView.new()
	view.player = player
	_root.add_child(view)
	_track.call(view)
	var big := SpriteSheetDef.new()
	big.load_dict({"quadro": [16, 32], "colunas": 40, "linhas": 4, "linhas_direcao": ["down", "up", "left", "right"],
			"animacoes": {"idle": {"colunas": [30, 39], "fps": 4, "loop": true}, "walk": {"colunas": [35], "fps": 4, "loop": true},
			"hit": {"colunas": [38], "fps": 4, "loop": false}, "fall": {"colunas": [39], "fps": 4, "loop": false}}})
	view.use_sheet(big)
	view.tick(0.1)
	var coords := player.visual.frame_coords
	_check(coords == Vector2i(0, SpriteFacing.DOWN),
			"folha de 40 colunas no sprite de 10: cai no primeiro quadro da direção, dentro da folha %s" % [coords])


func _test_inventory_cells_and_detail() -> void:
	var main := _test_main_for_camera()
	main.player.set_physics_process(false)
	main.scheduler.frozen = true
	await _root.get_tree().process_frame
	_empty_inventory(main.player.inventory)
	main.player.inventory.add(Items.BERRY, 7)
	main.player.hotbar.assign(2, Items.BERRY)
	main.screen.open_own()
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	var cell := main.screen.slot_button(true, 0)
	_check((cell.get_node("Count") as Label).text == "7", "célula mostra a quantidade (7)")
	_check((cell.get_node("Key") as Label).text == "3", "célula mostra o atalho 3 da barra")
	_empty_inventory(main.player.inventory)
	main.player.inventory.add(Items.BERRY, 1)
	main.screen.close()
	main.screen.open_own()
	await _root.get_tree().process_frame
	_check((main.screen.slot_button(true, 0).get_node("Count") as Label).text == "", "item único não mostra quantidade")
	# O mouse passa por uma célula e sai: a linha de detalhe não guarda o texto do passeio.
	main.screen.slot_button(true, 0).grab_focus()
	var other := main.screen.slot_button(true, 1)
	other.set_meta(&"text", "Texto do passeio")
	other.mouse_entered.emit()
	_check(main.screen.detail_text() == "Texto do passeio", "o mouse sobre a célula mostra o detalhe dela")
	other.mouse_exited.emit()
	_check(main.screen.detail_text() == main.screen.slot_text(true, 0).replace("\n", "  "), "o mouse sai: volta ao detalhe da célula focada")
	main.screen.slot_button(true, 0).release_focus()
	other.mouse_entered.emit()
	other.mouse_exited.emit()
	_check(main.screen.detail_text() == "", "o mouse sai sem foco: a linha fica vazia")
	main.screen.close()


func _empty_inventory(inventory: InventoryComponent) -> void:
	for i in inventory.slot_count():
		var slot := inventory.get_slot(i)
		if slot.is_empty():
			continue
		if slot.has("iid"):
			inventory.remove_iid(slot["iid"])
		else:
			inventory.remove(slot["id"], int(slot["count"]))
