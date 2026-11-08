# SPDX-License-Identifier: MIT
class_name PresentationTests
extends TestSuite
## "Nv N" do selvagem (`WildLevelTag`) e cursor contextual (`CursorView`).

const RANGE_PX := 96.0  # 6 tiles de 16 px (DinoLevelRules)


func run() -> void:
	_test_level_tag()
	_test_cursor()
	_test_sex_icon()
	_test_menu_theme_and_backdrop()
	_test_day_night_music()


func _tag_for(creature: Dino, viewer: Node2D) -> WildLevelTag:
	var tag := WildLevelTag.new()
	tag.dino = creature
	tag.viewer = viewer
	_root.add_child(tag)
	_track.call(tag)
	return tag


func _test_level_tag() -> void:
	var rules: DinoLevelRules = load("res://data/balance/dino_level_rules.tres")
	_check(is_equal_approx(rules.level_tag_range(), RANGE_PX), "o alcance do Nv vem do Resource: 6 tiles = 96 px")
	var player := _spawn_player()
	var creature := _spawn_dino()
	creature.level = 17
	player.global_position = Vector2.ZERO
	creature.global_position = Vector2(RANGE_PX - 1.0, 0.0)
	var tag := _tag_for(creature, player)
	tag.tick()
	_check(tag.tag_visible() and tag.tag_text() == "Nv 17", "selvagem vivo a 6 tiles: mostra 'Nv 17'")
	creature.global_position = Vector2(RANGE_PX + 1.0, 0.0)
	tag.tick()
	_check(not tag.tag_visible(), "além de 6 tiles: some")
	creature.global_position = Vector2(RANGE_PX - 1.0, 0.0)
	creature.torpor.add_torpor(creature.torpor.max_torpor)
	tag.tick()
	_check(creature.torpor.is_unconscious and not tag.tag_visible(), "desmaiado: a barra de doma já mostra o nível, o Nv de cima some")
	var marker := DinoMarker.new()
	marker.dino = creature
	_root.add_child(marker)
	_track.call(marker)
	creature.torpor.is_unconscious = false  # acordado: só o "domado" pode esconder o Nv aqui
	creature.state_machine.is_tamed = true
	creature.owner_player_id = Player.LOCAL_PLAYER_ID
	tag.tick()
	marker.set_process(false)
	marker._sync()
	_check(not tag.tag_visible() and marker.is_marked(), "domado: o Nv do selvagem some e fica só a placa")
	creature.state_machine.is_tamed = false
	tag.tick()
	_check(tag.tag_visible(), "voltou a selvagem e acordado: volta o Nv")
	creature.health.take_damage(creature.health.max_health * 3.0)
	tag.tick()
	_check(not tag.tag_visible(), "morto: não mostra")
	var other := _spawn_dino()
	var orphan := _tag_for(other, null)
	orphan.tick()
	_check(not orphan.tag_visible(), "sem quem olhar: não mostra")


func _test_cursor() -> void:
	_check(CursorView.size_for(720) == 32 and CursorView.size_for(800) == 32, "janela até 800 px de altura: cursor de 32")
	_check(CursorView.size_for(801) == 48 and CursorView.size_for(1080) == 48 and CursorView.size_for(2160) == 48, "acima de 800 px: 48")
	_check(CursorView.image_path(&"mao", true, 32) == "res://assets/ui/cursores/mao_32.png"
			and CursorView.image_path(&"mao", false, 48) == "res://assets/ui/cursores/mao_fora_48.png", "caminho: normal e variante fora de alcance")
	var hotspots := CursorView.load_hotspots()
	var files_ok := true
	var sizes_ok := true
	var hotspots_ok := true
	for action in CursorView.ACTIONS:
		for size in [CursorView.SIZE_SMALL, CursorView.SIZE_MEDIUM, CursorView.SIZE_LARGE]:
			for reach in [true, false]:
				var path := CursorView.image_path(action, reach, size)
				files_ok = files_ok and CursorView.TEXTURES.has(path)
				var texture: Texture2D = CursorView.TEXTURES.get(path)
				sizes_ok = sizes_ok and texture != null and texture.get_size() == Vector2(size, size)
			var point: Variant = (hotspots.get(action, {}) as Dictionary).get(str(size))
			hotspots_ok = hotspots_ok and point is Array and (point as Array).size() == 2 \
					and int((point as Array)[0]) < size and int((point as Array)[1]) < size
	_check(files_ok and sizes_ok, "as 36 imagens existem, quadradas, no tamanho do nome")
	_check(hotspots_ok, "cada ação tem hotspot dentro da imagem em 16, 32 e 48")
	var node := CursorView.new()
	_root.add_child(node)
	_track.call(node)
	_check(node.apply_count >= 1 and node.applied_action == &"padrao" and node.applied_size == CursorView.size_for(node.get_window().size.y),
			"o cursor padrão é aplicado ao entrar na árvore, no tamanho da janela")
	var count: int = node.apply_count
	node.apply(&"padrao", true)
	_check(node.apply_count == count, "o mesmo estado não troca o cursor do sistema de novo")
	node.apply(&"mao", false)
	_check(node.applied_action == &"mao" and not node.applied_in_reach and node.apply_count == count + 1, "ação nova ou fora de alcance troca")
	_check(CursorView.SHAPES.has(Input.CURSOR_ARROW) and CursorView.SHAPES.has(Input.CURSOR_POINTING_HAND)
			and CursorView.SHAPES.size() == 17, "vale para todas as formas do sistema (mão, texto...), não só a seta")
	var before: int = node.apply_count
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(node.apply_count == before + 1, "voltar o foco à janela reaplica o cursor")
	node.refresh()
	_check(node.applied_action == &"padrao", "sem fonte (título), o cursor é o padrão")
	var fake := FakeCursorSource.new()
	_track.call(fake)
	node.source = fake
	fake.state = {"action": &"machado", "in_reach": false}
	node.refresh()
	_check(node.applied_action == &"machado" and not node.applied_in_reach, "com fonte: a ação e o alcance vêm dela (machado apagado)")
	var settled: int = node.apply_count
	node.refresh()
	_check(node.apply_count == settled, "consultar de novo sem mudança não troca o cursor do sistema")
	var probe := Button.new()
	_check(probe.mouse_default_cursor_shape == Control.CURSOR_ARROW, "o botão do tema usa a forma padrão (coberta pelo cursor do jogo)")
	probe.free()
	node.refresh()  # sem erro de script (o contador de erros do runner reprova); o cursor do SO não se lê de volta


## Símbolo de sexo ao lado do "Nv" do selvagem e da placa do domado: lê `sex`, cores do guia, fica depois do texto.
func _test_sex_icon() -> void:
	_check(SexIcon.texture_for("x") == null, "sexo: valor desconhecido não ganha ícone")
	_check(SexIcon.texture_for(DinoBaseStats.SEX_MALE) != SexIcon.texture_for(DinoBaseStats.SEX_FEMALE)
			and SexIcon.texture_for(DinoBaseStats.SEX_MALE) != null, "sexo: macho e fêmea têm ícones diferentes")
	var colors: Dictionary = {}
	for texture: Texture2D in [SexIcon.MALE, SexIcon.FEMALE]:
		var image := texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.5:
					colors[pixel.to_html(false)] = true
	_check(colors.has("71ddee") and colors.has("ef9597"), "sexo: os ícones usam #71ddee (macho) e #ef9597 (fêmea)")
	var player := _spawn_player()
	var creature := _spawn_dino()
	creature.sex = DinoBaseStats.SEX_MALE
	player.global_position = Vector2.ZERO
	creature.global_position = Vector2(RANGE_PX - 1.0, 0.0)
	var tag := _tag_for(creature, player)
	tag.tick()
	_check(tag.sex_icon_visible() and tag.sex_icon_texture() == SexIcon.MALE, "Nv do selvagem macho: ícone de macho")
	creature.sex = DinoBaseStats.SEX_FEMALE
	tag.tick()
	_check(tag.sex_icon_texture() == SexIcon.FEMALE, "Nv do selvagem fêmea: ícone de fêmea")
	creature.sex = ""
	tag.tick()
	_check(not tag.sex_icon_visible(), "sexo desconhecido: sem ícone")
	var icon := Sprite2D.new()
	var label := Label.new()
	label.theme = UiTheme.get_theme()
	label.size = Vector2(40.0, 10.0)
	label.position = Vector2(-20.0, -38.0)
	label.text = "Nv 9"
	SexIcon.place(icon, label, DinoBaseStats.SEX_MALE)
	var text_width := label.get_theme_font("font").get_string_size("Nv 9", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE).x
	_check(icon.visible and icon.position.x > text_width * 0.5, "o ícone fica depois do fim do texto")
	icon.free()
	label.free()
	creature.state_machine.is_tamed = true
	creature.owner_player_id = Player.LOCAL_PLAYER_ID
	creature.sex = DinoBaseStats.SEX_FEMALE
	var marker := DinoMarker.new()
	marker.dino = creature
	_root.add_child(marker)
	_track.call(marker)
	marker.set_process(false)
	marker._sync()
	_check(marker.is_marked() and marker.sex_icon_texture() == SexIcon.FEMALE, "placa do domado: ícone de fêmea")


## Botões do menu em 9-slice com a arte, e o fundo do título com parallax em pixels inteiros.
func _test_menu_theme_and_backdrop() -> void:
	for state: String in UiTheme.MENU_BUTTON_STATES:
		var box := UiTheme.menu_button_box(state)
		_check(box is StyleBoxTexture and (box as StyleBoxTexture).texture.get_size() == Vector2(24, 20)
				and (box as StyleBoxTexture).get_texture_margin(SIDE_TOP) == 5.0
				and (box as StyleBoxTexture).get_texture_margin(SIDE_BOTTOM) == 6.0, "botão do menu '%s': 9-slice 24x20 com a arte" % state)
	var theme := UiTheme.get_theme()
	_check(theme.get_stylebox("normal", UiTheme.MENU_BUTTON) is StyleBoxTexture, "a variação MenuItemButton usa o 9-slice")
	var backdrop := MenuBackdrop.new()
	_root.add_child(backdrop)
	_track.call(backdrop)
	_check(backdrop.layer_count() == 5 and backdrop.layer_position(0) == MenuBackdrop.ORIGIN, "fundo: 5 camadas, no centro")
	backdrop.tick(10.0, Vector2(1.0, 1.0))
	var far_sky := MenuBackdrop.ORIGIN - backdrop.layer_position(0)
	var front := MenuBackdrop.ORIGIN - backdrop.layer_position(4)
	_check(front.x > far_sky.x and front.x <= MenuBackdrop.MAX_SHIFT + 0.01 and front.y <= MenuBackdrop.MAX_SHIFT + 0.01,
			"fundo: a camada da frente anda mais que o céu, no máximo 16 px")
	var whole := true
	for i in backdrop.layer_count():
		var at := backdrop.layer_position(i)
		whole = whole and at == at.round()
	_check(whole, "fundo: sempre em pixels inteiros")
	backdrop.tick(10.0, Vector2(9.0, -9.0))
	_check(MenuBackdrop.ORIGIN.x - backdrop.layer_position(4).x <= MenuBackdrop.MAX_SHIFT + 0.01, "fundo: o mouse fora do limite é contido")
	backdrop.tick(10.0, Vector2.ZERO)
	_check(backdrop.layer_position(4) == MenuBackdrop.ORIGIN, "fundo: sem mouse, volta ao centro")


## Música: dia e noite seguem o `WorldClock`, com crossfade; a troca não reinicia a faixa que já toca.
func _test_day_night_music() -> void:
	var rules: MusicRules = load("res://data/balance/music_rules.tres")
	var day := rules.day_length_seconds
	_check(not rules.is_night(0.0) and not rules.is_night(day * rules.night_start_fraction - 1.0), "música: o amanhecer e o dia são dia")
	_check(rules.is_night(day * rules.night_start_fraction + 1.0) and rules.is_night(day - 1.0), "música: depois do limite é noite")
	_check(not rules.is_night(day + 1.0) and rules.is_night(day * 2.0 - 1.0), "música: o ciclo se repete")
	_check(not rules.is_night(-5.0) and not rules.is_night(INF) and not rules.is_night(NAN), "música: tempo inválido conta como dia")
	var music := MusicPlayer.new()
	_root.add_child(music)
	_track.call(music)
	var clock := WorldClock.new()
	music.follow_world(clock)
	_check(music.current_track() == MusicPlayer.TRACK_DAY and music.is_playing() and not music.is_crossfading(),
			"música: de dia toca a faixa de dia")
	_check(music.audio_player().bus == GameSettings.BUS_MUSIC, "música: no barramento Music")
	_check(MusicPlayer.TRACK_DAY.loop_mode == AudioStreamWAV.LOOP_FORWARD, "música: a faixa de dia entra em loop")
	clock.advance(day * rules.night_start_fraction + 1.0)
	music.tick(0.0)
	_check(music.current_track() == MusicPlayer.TRACK_NIGHT and music.is_crossfading(),
			"música: ao anoitecer troca para a noite com crossfade")
	var fresh := music.audio_player()
	var old := music._players[1 - music._active]
	_check(old.playing and fresh.playing and fresh.volume_db < old.volume_db, "música: a nova sobe enquanto a antiga ainda toca")
	music.tick(rules.crossfade_seconds * 0.5)
	_check(fresh.volume_db > MusicPlayer.SILENT_DB and old.volume_db < 0.0 and old.playing, "música: no meio do fade as duas soam")
	music.tick(rules.crossfade_seconds)
	_check(not music.is_crossfading() and not old.playing and is_zero_approx(fresh.volume_db),
			"música: o fade termina: só a nova, no volume cheio")
	var starts := 0
	music.track_changed.connect(func(_stream: AudioStream) -> void: starts += 1)
	music.tick(1.0)
	_check(starts == 0, "música: a mesma faixa não reinicia a cada quadro")
	music.follow_world(null)
	music.stop_track()
	_check(music.current_track() == null and not music.is_playing(), "música: parar silencia")


## Fonte de cursor de mentira para o `CursorView`.
class FakeCursorSource extends CursorSource:
	var state: Dictionary = {"action": &"padrao", "in_reach": true}

	func current_cursor() -> Dictionary:
		return state
