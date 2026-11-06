# SPDX-License-Identifier: MIT
class_name MenuTests
extends DinoLevelTests
## Apresentação, navegação do menu, configurações (JSON), créditos e pausa. Reaproveita os
## auxiliares de `DinoLevelTests`. Eventos de teclado entram como `InputEventAction`, direto no `_input`.

const TEMP := "user://test_settings.json"
## Saves dos testes: caminho descartável, apagado no fim.
const SAVE_ROOT := "user://test_saves/menu"
const TITLE_SCENE: PackedScene = preload("res://src/ui/TitleScreen.tscn")


func run() -> void:
	GameSession.save_root = SAVE_ROOT
	SaveTests.remove_tree(SAVE_ROOT)
	_test_navigation()
	_test_settings_file()
	_test_credits_text()
	await _test_title_menu()
	await _test_title_settings()
	await _test_title_credits()
	await _test_pause()
	await _test_round_trip()
	GameSession.save_root = SaveTests.ROOT
	GameSession.continue_requested = false
	SaveTests.remove_tree(SAVE_ROOT)


func _key(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _items(enabled: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for i in enabled.size():
		items.append({"id": "i%d" % i, "enabled": enabled[i]})
	return items


func _test_navigation() -> void:
	var nav := MenuNavigation.new(_items([true, false, true, true]))
	_check(nav.index() == 0 and nav.current_id() == "i0", "começa no primeiro habilitado")
	nav.move(1)
	_check(nav.index() == 2, "descer pula o desabilitado")
	nav.move(1)
	nav.move(1)
	_check(nav.index() == 0, "descer na ponta dá a volta")
	nav.move(-1)
	_check(nav.index() == 3, "subir no topo dá a volta")
	nav.move(-1)
	nav.move(-1)
	_check(nav.index() == 0, "subir pula o desabilitado")
	_check(not nav.select(1) and nav.index() == 0, "selecionar desabilitado é ignorado")
	_check(not nav.select(9) and not nav.select(-1), "selecionar fora do intervalo é ignorado")
	_check(nav.select(3) and nav.current_id() == "i3" and nav.activate() == "i3", "selecionar e ativar o habilitado")
	var first_disabled := MenuNavigation.new(_items([false, true]))
	_check(first_disabled.index() == 1, "primeiro desabilitado não é o inicial")
	var none := MenuNavigation.new(_items([false, false]))
	none.move(1)
	_check(none.index() == -1 and none.activate() == "" and none.current_id() == "", "tudo desabilitado: nada seleciona nem ativa")
	var empty := MenuNavigation.new()
	empty.move(1)
	_check(empty.activate() == "", "vazio: sem efeito")


func _test_settings_file() -> void:
	DirAccess.remove_absolute(TEMP)
	var defaults := GameSettings.load_from(TEMP)
	_check(defaults.fullscreen and is_equal_approx(defaults.volume, GameSettings.DEFAULT_VOLUME), "sem arquivo: tela cheia e volume padrão")
	var settings := GameSettings.new()
	settings.fullscreen = false
	settings.set_volume(0.35)
	_check(settings.save_to(TEMP), "grava")
	var loaded := GameSettings.load_from(TEMP)
	_check(not loaded.fullscreen and is_equal_approx(loaded.volume, 0.35), "roundtrip de tela cheia e volume")
	_write(TEMP, '{"fullscreen": "talvez", "volume": 7.5}')
	var hostile := GameSettings.load_from(TEMP)
	_check(hostile.fullscreen and is_equal_approx(hostile.volume, 1.0), "tipo errado cai no padrão e o volume é limitado a 1")
	_write(TEMP, '{"volume": "alto"}')
	_check(is_equal_approx(GameSettings.load_from(TEMP).volume, GameSettings.DEFAULT_VOLUME), "volume que não é número: padrão")
	_write(TEMP, '{"volume": -3.0}')
	_check(GameSettings.load_from(TEMP).volume == 0.0, "volume negativo vira 0")
	_write(TEMP, '{"fullscreen": [1, 2], "volume": {"a": 1}}')
	var weird := GameSettings.load_from(TEMP)
	_check(weird.fullscreen and is_equal_approx(weird.volume, GameSettings.DEFAULT_VOLUME), "valores de estrutura errada: padrões")
	for junk: String in ['{"fullscreen": tr', "[1, 2]", "42", "", "[game]\nvolume=0.2\n", "\u0001\u0002 lixo",
			'volume=Object(RefCounted,"script":null)', '{"volume": 0.3, "x": ' + "9".repeat(GameSettings.MAX_FILE_BYTES) + "}"]:
		_write(TEMP, junk)
		var broken := GameSettings.load_from(TEMP)
		_check(broken.fullscreen and is_equal_approx(broken.volume, GameSettings.DEFAULT_VOLUME),
				"arquivo ilegível ou grande demais: padrões (%s)" % junk.left(12))
	var cycle := GameSettings.new()
	cycle.set_volume(0.0)
	var seen: Array[float] = []
	for _i in 11:
		cycle.cycle_volume()
		seen.append(cycle.volume)
	_check(is_equal_approx(seen[0], 0.1) and is_equal_approx(seen[9], 1.0) and seen[10] == 0.0,
			"ciclo de volume: de 10 em 10%, passa de 100% e volta a 0")
	cycle.set_volume(0.95)
	cycle.cycle_volume()
	_check(cycle.volume == 0.0, "ciclo a partir de 95%: passou de 100%, volta a 0")
	settings.set_volume(5.0)
	_check(settings.volume == 1.0, "set_volume limita a 1")
	settings.set_volume(-1.0)
	_check(settings.volume == 0.0, "set_volume limita a 0")
	_check(GameSettings.volume_to_db(0.0) == GameSettings.MIN_DB and is_equal_approx(GameSettings.volume_to_db(1.0), 0.0)
			and GameSettings.volume_to_db(0.5) < GameSettings.volume_to_db(0.9), "volume em dB: mudo, cheio e monótono")
	var before := AudioServer.get_bus_volume_db(0)
	settings.set_volume(0.5)
	settings.apply()
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), GameSettings.volume_to_db(0.5)), "apply muda o volume do barramento")
	AudioServer.set_bus_volume_db(0, before)
	AudioServer.set_bus_mute(0, false)
	DirAccess.remove_absolute(TEMP)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_credits_text() -> void:
	var sample := "Licença dos assets próprios: CC BY 4.0.\n\n## Registro\n\n| Arquivo | Origem | Autor | Fonte | Licença | Alt | Data |\n" \
			+ "|---|---|---|---|---|---|---|\n| a.png | terceiro | Fulano | http://x | CC0 | - | d |\n" \
			+ "| b.png | terceiro | Fulano | http://x | CC0 | - | d |\n" \
			+ "| c.png | `propria` | Ciclana | - | CC-BY-4.0 | - | d |\n"
	sample += "<!-- Exemplos\n| d.png | propria | Exemplar | - | CC0 | - | d |\n-->\n"
	var text := CreditsText.from_markdown(sample)
	_check(not text.contains("Exemplar"), "comentário HTML do markdown não vira crédito")
	_check(text.contains("Licença dos assets próprios: CC BY 4.0.") and text.contains("Fulano") and text.contains("Ciclana"),
			"créditos: licença e autores do markdown")
	_check(text.contains("a.png; b.png") and text.count("Fulano") == 1, "mesmo autor, licença e fonte: um grupo com os dois arquivos")
	_check(text.contains("Fonte: http://x") and not text.contains("Fonte: -") and text.contains("Origem: propria"),
			"fonte vazia omitida; crases removidas")
	_check(not CreditsText.load_text().contains("Beltrano") and not CreditsText.load_text().contains("ferramenta e modelo"),
			"os exemplos comentados do CREDITS.md não aparecem")
	_check(CreditsText.from_markdown("") == CreditsText.UNAVAILABLE
			and CreditsText.from_markdown("  \n# só um título\n") == CreditsText.UNAVAILABLE,
			"sem texto de créditos (arquivo vazio ou fora da exportação): aviso na tela, não tela em branco")
	var real := FileAccess.get_file_as_string(CreditsText.SOURCE)
	var shown := CreditsText.load_text()
	_check(real != "" and shown.contains("Pixel-Boy e AAA") and shown.contains("CC0") and shown.contains(CreditsText.LICENSE_PREFIX),
			"créditos reais: Ninja Adventure, CC0 e licença do projeto")
	var missing := ""
	for line in real.split("\n"):
		var cells := line.split("|")
		if line.begins_with("| game/assets/third_party") and cells.size() > 4 and not shown.contains(cells[3].strip_edges()):
			missing += cells[3]
	_check(missing == "", "todo autor de terceiros da tabela aparece nos créditos")


func _title() -> TitleScreen:
	var scene: TitleScreen = TITLE_SCENE.instantiate()
	scene.auto_perform = false
	scene.settings_path = TEMP
	_root.add_child(scene)
	_track.call(scene)
	return scene


func _test_title_menu() -> void:
	DirAccess.remove_absolute(TEMP)
	var title := _title()
	await _root.get_tree().process_frame
	var menu := title.menu()
	var labels: Array[String] = []
	for id in [TitleScreen.SINGLE_PLAYER, TitleScreen.MULTIPLAYER, TitleScreen.SETTINGS, TitleScreen.CREDITS, TitleScreen.QUIT]:
		labels.append(menu.label_of(id))
	_check(labels[0] == "Um jogador" and labels[2] == "Configurações" and labels[3] == "Créditos" and labels[4] == "Sair"
			and labels[1].begins_with("Multijogador"), "cinco itens, na ordem pedida")
	_check(menu.button_of(TitleScreen.MULTIPLAYER).disabled and labels[1].contains(TitleScreen.SOON),
			"Multijogador visível, desabilitado e com aviso de que chega depois")
	_check(menu.selected_id() == TitleScreen.SINGLE_PLAYER, "começa em Um jogador")
	var chosen: Array[String] = []
	title.action_chosen.connect(func(id: String) -> void: chosen.append(id))
	title._input(_key("ui_down"))
	_check(menu.selected_id() == TitleScreen.SETTINGS, "descer pula Multijogador")
	title._input(_key("ui_up"))
	title._input(_key("ui_up"))
	_check(menu.selected_id() == TitleScreen.QUIT, "subir do primeiro dá a volta até Sair")
	title._input(_key("ui_down"))
	title._input(_key("ui_accept"))
	_check(chosen.is_empty() and title.view == "single", "Enter em Um jogador abre Continuar e Novo jogo (não começa sozinho)")
	title._input(_key("ui_cancel"))
	_check(title.view == "menu", "Esc volta ao menu principal")
	chosen.clear()
	menu.button_of(TitleScreen.MULTIPLAYER).pressed.emit()
	_check(chosen.is_empty() and menu.selected_id() == TitleScreen.SINGLE_PLAYER, "clique em Multijogador não faz nada")
	menu.button_of(TitleScreen.QUIT).mouse_entered.emit()
	_check(menu.selected_id() == TitleScreen.QUIT, "o mouse seleciona o item")
	menu.button_of(TitleScreen.QUIT).pressed.emit()
	_check(chosen == [TitleScreen.QUIT], "clique em Sair pede para sair")
	title._input(_key("ui_cancel"))
	_check(title.view == "menu", "Esc no menu principal não faz nada")
	_check(not title.auto_perform and ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/TitleScreen.tscn",
			"a apresentação é a cena inicial")
	var stretch := "display/window/stretch/"
	_check(ProjectSettings.get_setting("display/window/size/mode") == 3 and ProjectSettings.get_setting(stretch + "scale_mode") == "integer"
			and ProjectSettings.get_setting(stretch + "aspect") == "keep", "tela cheia padrão com escala inteira e sem esticar")
	var shortcuts: Array[String] = []
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key := event as InputEventKey
				var codes := [key.keycode, key.physical_keycode, key.key_label]
				if codes.has(KEY_F11) or (key.alt_pressed and (codes.has(KEY_ENTER) or codes.has(KEY_KP_ENTER))):
					shortcuts.append(str(action))
	_check(shortcuts.is_empty(), "nenhuma ação mapeia F11 nem Alt+Enter: tela cheia só pelo menu de Configurações (%s)" % str(shortcuts))
	_check(not InputMap.has_action("toggle_fullscreen"), "nem uma ação própria de tela cheia")
	DirAccess.remove_absolute(TEMP)


func _test_title_settings() -> void:
	DirAccess.remove_absolute(TEMP)
	var title := _title()
	await _root.get_tree().process_frame
	title._input(_key("ui_down"))
	title._input(_key("ui_accept"))
	_check(title.view == "settings", "Configurações abre")
	var menu := title.settings_menu()
	_check(menu.label_of(TitleScreen.FULLSCREEN) == "Tela cheia: Sim" and menu.label_of(TitleScreen.VOLUME) == "Volume geral: 80%",
			"mostra os valores atuais")
	title._input(_key("ui_accept"))
	_check(menu.label_of(TitleScreen.FULLSCREEN) == "Tela cheia: Não" and not GameSettings.load_from(TEMP).fullscreen,
			"Enter alterna a tela cheia e grava")
	title._input(_key("ui_down"))
	title._input(_key("ui_left"))
	_check(menu.label_of(TitleScreen.VOLUME) == "Volume geral: 75%" and is_equal_approx(GameSettings.load_from(TEMP).volume, 0.75),
			"esquerda baixa o volume em 5% e grava")
	title._input(_key("ui_right"))
	title._input(_key("ui_right"))
	_check(menu.label_of(TitleScreen.VOLUME) == "Volume geral: 85%", "direita sobe")
	var bus_before := AudioServer.get_bus_volume_db(0)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), GameSettings.volume_to_db(0.85)), "a mudança vale na hora (barramento de áudio)")
	for i in 5:
		title._input(_key("ui_right"))
	_check(title.settings.volume == 1.0, "o volume para em 100%")
	title._input(_key("ui_accept"))
	_check(title.settings.volume == 0.0, "Enter no volume cheio volta a 0")
	title._input(_key("ui_left"))
	_check(title.settings.volume == 0.0, "o volume não fica negativo")
	title._input(_key("ui_up"))
	title._input(_key("ui_left"))
	_check(title.settings.volume == 0.0 and menu.selected_id() == TitleScreen.FULLSCREEN, "esquerda fora da linha do volume não o altera")
	title._input(_key("ui_cancel"))
	_check(title.view == "menu", "Esc volta ao menu")
	AudioServer.set_bus_volume_db(0, bus_before)
	AudioServer.set_bus_mute(0, false)
	# Recarrega: o arquivo vale na próxima abertura.
	var again := _title()
	await _root.get_tree().process_frame
	_check(not again.settings.fullscreen and again.settings.volume == 0.0, "as configurações persistem entre aberturas")
	DirAccess.remove_absolute(TEMP)


func _test_title_credits() -> void:
	DirAccess.remove_absolute(TEMP)
	var title := _title()
	await _root.get_tree().process_frame
	for i in 2:
		title._input(_key("ui_down"))
	title._input(_key("ui_accept"))
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	_check(title.view == "credits" and title.credits_text().contains("Pixel-Boy e AAA") and title.credits_text().contains("CC0"),
			"Créditos mostram os autores e licenças do CREDITS.md")
	var scroll := title.credits_scroll()
	_check(scroll.scroll_vertical == 0, "começa no topo")
	title._input(_key("ui_down"))
	var one := scroll.scroll_vertical
	_check(one > 0, "seta para baixo rola")
	title._input(_key("ui_page_down"))
	_check(scroll.scroll_vertical > one, "PgDn rola mais")
	title._input(_key("ui_up"))
	title._input(_key("ui_page_up"))
	title._input(_key("ui_page_up"))
	_check(scroll.scroll_vertical == 0, "para cima volta ao topo e não passa dele")
	title._input(_key("ui_cancel"))
	_check(title.view == "menu", "Esc volta ao menu")
	DirAccess.remove_absolute(TEMP)


func _test_pause() -> void:
	var tree := _root.get_tree()
	var pause: PauseMenu = _track.call(PauseMenu.new())
	_root.add_child(pause)
	var events: Array[String] = []
	pause.resumed.connect(func() -> void: events.append("resumed"))
	pause.menu_requested.connect(func() -> void: events.append("menu"))
	pause.open()
	_check(pause.is_open and tree.paused, "abrir pausa a árvore")
	_check(pause.column().label_of(PauseMenu.RESUME) == "Continuar" and pause.column().label_of(PauseMenu.MENU) == "Voltar ao menu",
			"Continuar e Voltar ao menu")
	pause._input(_key("ui_cancel"))
	_check(not pause.is_open and not tree.paused and events == ["resumed"], "Esc fecha e retoma")
	pause.open()
	pause._input(_key("ui_down"))
	_check(pause.column().marker_of(PauseMenu.MENU) == MenuColumn.MARKER and pause.column().marker_of(PauseMenu.RESUME) == "",
			"marcador acompanha a seleção")
	pause.close()
	pause.open()
	_check(pause.column().selected_id() == PauseMenu.RESUME and pause.column().marker_of(PauseMenu.RESUME) == MenuColumn.MARKER
			and pause.column().marker_of(PauseMenu.MENU) == "", "reabrir: seleção e marcador voltam ao primeiro item")
	events.clear()
	pause._input(_key("ui_down"))
	pause._input(_key("ui_accept"))
	_check(events == ["menu"], "Voltar ao menu pede direto, sem confirmação (o salvamento é de quem liga)")
	pause.close()
	_check(pause.column().button_of(PauseMenu.SAVE) == null, "sem save configurado, o item Salvar não existe")
	pause.set_save_available(true)
	pause.open()
	pause._input(_key("ui_down"))
	var saves: Array[int] = [0]
	pause.save_requested.connect(func() -> void: saves[0] += 1)
	pause._input(_key("ui_accept"))
	_check(pause.column().label_of(PauseMenu.SAVE) == "Salvar" and saves[0] == 1 and pause.is_open, "Salvar pede e a pausa continua aberta")
	pause.show_status("Jogo salvo.")
	_check(pause.status_text() == "Jogo salvo.", "o resultado aparece na pausa")
	pause.close()
	pause.open()
	_check(pause.status_text() == "", "reabrir limpa o resultado")
	pause.close()
	pause.set_menu_available(false)
	_check(pause.column().button_of(PauseMenu.MENU) == null, "sem cena de menu, o item não existe")
	tree.paused = false
	# Na Main: Esc abre a pausa só sem tela aberta; com a tela aberta, o Esc é dela.
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.dino.set_physics_process(false)
	main.player.set_physics_process(false)
	_check(main.pause != null and main.menu_scene.ends_with("TitleScreen.tscn"), "a Main tem pausa e aponta para a apresentação")
	main.screen.open_own()
	main.pause._unhandled_input(_key("ui_cancel"))
	_check(not main.pause.is_open and not tree.paused, "tela de inventário aberta: o Esc da Main não abre a pausa")
	main.screen._unhandled_input(_key("ui_cancel"))
	_check(not main.screen.is_open and not main.pause.is_open, "o Esc fecha só a tela de inventário")
	main.pause._unhandled_input(_key("ui_cancel"))
	_check(main.pause.is_open and tree.paused, "sem tela aberta, o Esc abre a pausa")
	main.pause._unhandled_input(_key("ui_cancel"))
	_check(main.pause.is_open, "Esc repetido em _unhandled_input não fecha a pausa (isso é do _input)")
	main.pause._input(_key("ui_cancel"))
	_check(not main.pause.is_open and not tree.paused, "Esc dentro da pausa retoma")
	tree.paused = false


## Ida e volta de verdade, com troca de cena: Título -> Um jogador -> Main -> pausa -> confirmar -> Título.
func _test_round_trip() -> void:
	var tree := _root.get_tree()
	var title: TitleScreen = TITLE_SCENE.instantiate()
	title.auto_perform = true
	title.settings_path = TEMP
	_root.add_child(title)
	await tree.process_frame
	title._input(_key("ui_accept"))  # Um jogador é o primeiro item
	title._input(_key("ui_accept"))  # sem save, Continuar está desabilitado: Novo jogo começa direto
	for _i in 3:
		await tree.process_frame
	var game := tree.current_scene as Main
	_check(game != null and game.menu_scene.ends_with("TitleScreen.tscn"), "Um jogador troca a cena para a Main")
	if game == null:
		title.queue_free()
		return
	title.queue_free()
	game.dino.set_physics_process(false)
	game.player.set_physics_process(false)
	game.pause._unhandled_input(_key("ui_cancel"))
	_check(game.pause.is_open and tree.paused, "Esc na Main abre a pausa")
	game.pause._input(_key("ui_down"))
	game.pause._input(_key("ui_down"))
	game.pause._input(_key("ui_accept"))  # Voltar ao menu: salva e volta direto
	for _i in 3:
		await tree.process_frame
	var back := tree.current_scene as TitleScreen
	_check(back != null and not tree.paused and not is_instance_valid(game),
			"Voltar ao menu salva e volta à apresentação, despausado, e a Main sai")
	_check(SaveManager.new(SAVE_ROOT).probe().status == SaveManager.Status.OK, "o save foi gravado no caminho de teste ao voltar ao menu")
	_check(back != null and back.view == "menu" and back.menu().selected_id() != TitleScreen.MULTIPLAYER
			and back.menu().button_of(TitleScreen.SINGLE_PLAYER) != null, "a apresentação reaparece no menu principal")
	if back != null:
		back.queue_free()
		await tree.process_frame
	tree.current_scene = null
