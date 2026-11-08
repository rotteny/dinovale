# SPDX-License-Identifier: MIT
class_name TitleScreen
extends Control
## Tela de apresentação: nome do jogo, menu (Um jogador, Multijogador, Configurações, Créditos, Sair),
## Configurações (tela cheia e volume) e Créditos (de `assets/CREDITS.md`). Teclado (setas, Enter,
## Esc) e mouse. Só apresentação: as decisões são sinais (`action_chosen`); com `auto_perform` a
## própria tela troca de cena ou fecha o jogo. A tela cheia só muda aqui, em Configurações.
## Multijogador não existe ainda: o item fica visível e desabilitado.
## "Um jogador" abre Continuar (só com save utilizável) e Novo jogo; Novo jogo com save existente pede
## confirmação, com Cancelar selecionado e uma guarda de cliques (500 ms: maior que a janela de duplo clique de alguns sistemas).

signal action_chosen(id: String)

const SINGLE_PLAYER := "single_player"
const MULTIPLAYER := "multiplayer"
const SETTINGS := "settings"
const CREDITS := "credits"
const QUIT := "quit"
const CONTINUE := "continue"
const NEW_GAME := "new_game"
const CANCEL := "cancel"
const START_NEW := "start_new"
const NEW_GAME_WARNING := "Já existe um jogo salvo. O novo jogo o substitui no primeiro salvamento."
const UNREADABLE_WARNING := "Há um save que não pôde ser lido; ele será guardado ao lado, não apagado."
const FULLSCREEN := "fullscreen"
const VOLUME := GameSettings.LEVEL_MASTER
const MUSIC := GameSettings.LEVEL_MUSIC
const SFX := GameSettings.LEVEL_SFX
const MUTE := "mute"
const BACK := "back"
const GAME_SCENE := "res://src/world/Main.tscn"
const GAME_TITLE := "Dino Vale"
const SOON := "Em breve"
const SCROLL_STEP := 16
## Tamanhos para o viewport de 320x180.
const TITLE_FONT_SIZE := 16
const CREDITS_SIZE := Vector2(260, 108)
const LOGO: Texture2D = preload("res://assets/ui/menu/menu_logo.png")
## Áreas seguras do fundo (`menu_fundo.json`): o título (logo) e a coluna de botões, em pixels de tela.
const LOGO_POSITION := Vector2(81, 16)
const MENU_POSITION := Vector2(106, 64)
const MENU_WIDTH := 108.0
## O aviso das telas sem painel cabe na faixa entre o logo e os botões.
const NOTICE_RECT := Rect2(20, 50, 280, 12)
## Telas com fundo livre (logo e botões sobre o fundo); as outras abrem num painel no centro.
const BACKDROP_VIEWS: Array[String] = ["menu", "single", "confirm"]

## Desligue nos testes para só observar os sinais.
@export var auto_perform: bool = true
## Onde as configurações são lidas e gravadas.
@export var settings_path: String = GameSettings.PATH
## Pasta dos saves; vazio = `GameSession.save_root`.
@export var save_root: String = ""
## Cliques na confirmação do novo jogo são ignorados por este tempo depois que ela abre: o segundo
## clique de um duplo clique em "Novo jogo" cairia em "Começar do zero".
@export var confirm_guard_msec: int = 500

var settings: GameSettings
var view: String = "menu"

var _menu := MenuColumn.new()
var _single_menu := MenuColumn.new()
var _confirm_menu := MenuColumn.new()
var _single_box := VBoxContainer.new()
var _confirm_box := VBoxContainer.new()
var _confirm_panel := PanelContainer.new()
var _confirm_label := Label.new()
var _confirm_since: int = 0
var _has_save_files: bool = false
var _settings_menu := MenuColumn.new()
var _menu_box := VBoxContainer.new()
var _settings_box := VBoxContainer.new()
var _credits_box := VBoxContainer.new()
var _credits_scroll := ScrollContainer.new()
var _credits_label := Label.new()
var _notice := Label.new()
var _panel_notice := Label.new()
var _free_root := Control.new()
var _panel_root := CenterContainer.new()
var _logo := TextureRect.new()
var _music := MusicPlayer.new()


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	settings = GameSettings.load_from(settings_path)
	settings.apply()
	_build_background()
	add_child(_music)
	_music.play_track(MusicPlayer.TRACK_MENU)
	_build_free_root()
	_build_panel_root()
	_build_menu()
	_build_single()
	_build_settings()
	_build_credits()
	_show("menu")
	_set_notice(GameSession.take_notice())  # ex.: o Continuar falhou e a Main voltou para cá


## Fundo: as 5 camadas do menu com parallax leve pelo mouse, só desenho (sem física nem lógica).
func _build_background() -> void:
	# Camada própria atrás da UI.
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	layer.add_child(MenuBackdrop.new())


## Telas com o fundo livre: logo no alto e a coluna de botões na área segura, sem painel.
func _build_free_root() -> void:
	_free_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_free_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_free_root)
	_logo.texture = LOGO
	_logo.position = LOGO_POSITION
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_root.add_child(_logo)
	_notice.position = NOTICE_RECT.position
	_notice.size = NOTICE_RECT.size
	_style_notice(_notice, true)
	_free_root.add_child(_notice)
	var stack := VBoxContainer.new()
	stack.position = MENU_POSITION
	stack.custom_minimum_size.x = MENU_WIDTH
	stack.add_theme_constant_override("separation", 2)
	_free_root.add_child(stack)
	stack.add_child(_menu_box)
	stack.add_child(_single_box)
	_confirm_panel.add_child(_confirm_box)
	stack.add_child(_confirm_panel)


## Configurações e Créditos: painel de madeira no centro (sem título: a lista de seis botões já ocupa quase a tela de 180).
func _build_panel_root() -> void:
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)
	var panel := PanelContainer.new()
	_panel_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 1)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	stack.add_child(_settings_box)
	stack.add_child(_credits_box)
	_style_notice(_panel_notice, false)
	_panel_notice.custom_minimum_size.x = 220
	stack.add_child(_panel_notice)


func _style_notice(label: Label, on_backdrop: bool) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if on_backdrop:  # sobre o fundo: texto claro com contorno escuro
		label.add_theme_color_override("font_color", Color("#fce2ca"))
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
		label.add_theme_constant_override("outline_size", 2)
	else:
		label.add_theme_color_override("font_color", UiTheme.INK)


func _build_menu() -> void:
	_menu_box.add_child(_menu)
	_menu.setup([
		{"id": SINGLE_PLAYER, "label": "Um jogador"},
		{"id": MULTIPLAYER, "label": "Multijogador (%s)" % SOON, "enabled": false},
		{"id": SETTINGS, "label": "Configurações"},
		{"id": CREDITS, "label": "Créditos"},
		{"id": QUIT, "label": "Sair"},
	])
	_menu.activated.connect(_on_menu_activated)


func _build_single() -> void:
	_single_box.add_child(_single_menu)
	_single_menu.activated.connect(_on_single_activated)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size.x = 170
	_confirm_label.add_theme_color_override("font_color", UiTheme.INK)
	_confirm_box.add_child(_confirm_label)
	_confirm_box.add_child(_confirm_menu)
	_confirm_menu.setup([
		{"id": CANCEL, "label": "Cancelar"},
		{"id": START_NEW, "label": "Começar do zero"},
	])
	_confirm_menu.activated.connect(_on_confirm_activated)


## Lê o estado do save e monta a lista de Um jogador: Continuar só vale com save utilizável.
func _open_single() -> void:
	var saves := SaveManager.new(save_root if save_root != "" else GameSession.save_root)
	var outcome := saves.probe()
	_has_save_files = saves.has_files()
	_single_menu.setup([
		{"id": CONTINUE, "label": "Continuar", "enabled": outcome.status == SaveManager.Status.OK},
		{"id": NEW_GAME, "label": "Novo jogo"},
		{"id": BACK, "label": "Voltar"},
	])
	_confirm_label.text = NEW_GAME_WARNING if outcome.status == SaveManager.Status.OK else UNREADABLE_WARNING
	_show("single")
	if outcome.status != SaveManager.Status.NONE:
		_set_notice(outcome.message)


func _build_settings() -> void:
	_settings_box.add_child(_settings_menu)
	_settings_menu.setup([
		{"id": FULLSCREEN, "label": ""},
		{"id": VOLUME, "label": ""},
		{"id": MUSIC, "label": ""},
		{"id": SFX, "label": ""},
		{"id": MUTE, "label": ""},
		{"id": BACK, "label": "Voltar"},
	])
	_settings_menu.activated.connect(_on_settings_activated)
	var hint := Label.new()
	hint.text = "Esquerda e direita ajustam os volumes"
	hint.add_theme_color_override("font_color", UiTheme.INK)
	_settings_box.add_child(hint)
	_refresh_settings()


func _build_credits() -> void:
	_credits_label.text = CreditsText.load_text()
	_credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_label.custom_minimum_size.x = CREDITS_SIZE.x - 14.0
	_credits_label.add_theme_color_override("font_color", UiTheme.INK)
	_credits_scroll.custom_minimum_size = CREDITS_SIZE
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.add_child(_credits_label)
	_credits_box.add_child(_credits_scroll)
	var hint := Label.new()
	hint.text = "Setas e PgUp/PgDn rolam   Esc ou Enter: voltar"
	hint.add_theme_color_override("font_color", UiTheme.INK)
	_credits_box.add_child(hint)


func _show(which: String) -> void:
	view = which
	_menu_box.visible = which == "menu"
	_single_box.visible = which == "single"
	_confirm_panel.visible = which == "confirm"
	_free_root.visible = which in BACKDROP_VIEWS
	_panel_root.visible = not _free_root.visible
	_settings_box.visible = which == "settings"
	_credits_box.visible = which == "credits"
	_set_notice("")
	if which == "credits":
		_credits_scroll.scroll_vertical = 0
	elif is_inside_tree():
		_column_of(which).focus_selected()


## Coluna de botões da tela da vez (a de créditos não tem).
func _column_of(which: String) -> MenuColumn:
	match which:
		"single":
			return _single_menu
		"confirm":
			return _confirm_menu
		"settings":
			return _settings_menu
	return _menu


## Menu principal (para testes).
func menu() -> MenuColumn:
	return _menu


func single_menu() -> MenuColumn:
	return _single_menu


func confirm_menu() -> MenuColumn:
	return _confirm_menu


func confirm_text() -> String:
	return _confirm_label.text if view == "confirm" else ""


func settings_menu() -> MenuColumn:
	return _settings_menu


func music() -> MusicPlayer:
	return _music


func credits_scroll() -> ScrollContainer:
	return _credits_scroll


func credits_text() -> String:
	return _credits_label.text


## Aviso (o das telas com fundo livre e o do painel andam juntos).
func _set_notice(text: String) -> void:
	_notice.text = text
	_panel_notice.text = text


func notice_text() -> String:
	return _notice.text


func _input(event: InputEvent) -> void:
	var viewport := get_viewport()  # guardado antes: trocar de cena tira esta tela da árvore
	var handled := false
	match view:
		"menu":
			handled = _menu.handle_event(event)
		"single":
			handled = _submenu_input(event, _single_menu, "menu")
		"confirm":
			handled = _submenu_input(event, _confirm_menu, "single")
		"settings":
			handled = _settings_input(event)
		"credits":
			handled = _credits_input(event)
	if handled:
		viewport.set_input_as_handled()


## Esc volta para `back_to`; o resto é do menu da vez.
func _submenu_input(event: InputEvent, column: MenuColumn, back_to: String) -> bool:
	if event.is_action_pressed("ui_cancel"):
		_show(back_to)
		return true
	return column.handle_event(event)


func _settings_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		_show("menu")
		return true
	var selected := _settings_menu.selected_id()
	if selected in [VOLUME, MUSIC, SFX]:
		if event.is_action_pressed("ui_left"):
			_change_volume(selected, -GameSettings.VOLUME_STEP)
			return true
		if event.is_action_pressed("ui_right"):
			_change_volume(selected, GameSettings.VOLUME_STEP)
			return true
	return _settings_menu.handle_event(event)


func _credits_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_show("menu")
		return true
	var page := int(_credits_scroll.size.y) - SCROLL_STEP
	if event.is_action_pressed("ui_down"):
		_scroll_credits(SCROLL_STEP)
	elif event.is_action_pressed("ui_up"):
		_scroll_credits(-SCROLL_STEP)
	elif event.is_action_pressed("ui_page_down"):
		_scroll_credits(page)
	elif event.is_action_pressed("ui_page_up"):
		_scroll_credits(-page)
	else:
		return false
	return true


func _scroll_credits(delta: int) -> void:
	_credits_scroll.scroll_vertical = maxi(_credits_scroll.scroll_vertical + delta, 0)


func _on_menu_activated(id: String) -> void:
	match id:
		SINGLE_PLAYER:
			_open_single()
		SETTINGS:
			_show("settings")
		CREDITS:
			_show("credits")
		_:
			_choose(id)


func _on_single_activated(id: String) -> void:
	match id:
		CONTINUE:
			_choose(CONTINUE)
		NEW_GAME:
			if _has_save_files:
				_confirm_menu.reset_selection()
				_show("confirm")
				_confirm_since = Time.get_ticks_msec()
			else:
				_choose(NEW_GAME)
		BACK:
			_show("menu")


func _on_confirm_activated(id: String) -> void:
	if id == CANCEL:
		_show("single")
	elif id == START_NEW and Time.get_ticks_msec() - _confirm_since >= confirm_guard_msec:
		_choose(NEW_GAME)


func _on_settings_activated(id: String) -> void:
	match id:
		FULLSCREEN:
			settings.fullscreen = not settings.fullscreen
			_commit_settings()
		MUTE:
			settings.muted = not settings.muted
			_commit_settings()
		VOLUME, MUSIC, SFX:
			settings.cycle_level(id)
			_commit_settings()
		BACK:
			_show("menu")


func _change_volume(id: String, step: float) -> void:
	settings.set_level(id, settings.level(id) + step)
	_commit_settings()


func _commit_settings() -> void:
	settings.apply()
	if not settings.save_to(settings_path):
		_set_notice("Não foi possível gravar as configurações.")
	_refresh_settings()


func _refresh_settings() -> void:
	_settings_menu.set_label(FULLSCREEN, "Tela cheia: %s" % ("Sim" if settings.fullscreen else "Não"))
	_settings_menu.set_label(MUTE, "Mudo: %s" % ("Sim" if settings.muted else "Não"))
	_settings_menu.set_label(VOLUME, "Volume geral: %d%%" % roundi(settings.volume * 100.0))
	_settings_menu.set_label(MUSIC, "Música: %d%%" % roundi(settings.music_volume * 100.0))
	_settings_menu.set_label(SFX, "Efeitos: %d%%" % roundi(settings.sfx_volume * 100.0))


func _choose(id: String) -> void:
	action_chosen.emit(id)
	if not auto_perform:
		return
	if id == CONTINUE or id == NEW_GAME:
		GameSession.continue_requested = id == CONTINUE
		get_tree().change_scene_to_file(GAME_SCENE)
	elif id == QUIT:
		get_tree().quit()
