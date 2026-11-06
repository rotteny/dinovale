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
const VOLUME := "volume"
const BACK := "back"
const GAME_SCENE := "res://src/world/Main.tscn"
const GAME_TITLE := "Dino Vale"
const SOON := "Em breve"
const SCROLL_STEP := 16
## Tamanhos para o viewport de 320x180.
const TITLE_FONT_SIZE := 16
const CREDITS_SIZE := Vector2(260, 108)
const BACKGROUND := preload("res://src/world/Terrain.tscn")

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


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	settings = GameSettings.load_from(settings_path)
	settings.apply()
	_build_background()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 1)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", UiTheme.INK)
	stack.add_child(title)
	stack.add_child(_menu_box)
	stack.add_child(_single_box)
	stack.add_child(_confirm_box)
	stack.add_child(_settings_box)
	stack.add_child(_credits_box)
	_build_menu()
	_build_single()
	_build_settings()
	_build_credits()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size.x = 220
	_notice.add_theme_color_override("font_color", UiTheme.INK)
	stack.add_child(_notice)
	_show("menu")
	_notice.text = GameSession.take_notice()  # ex.: o Continuar falhou e a Main voltou para cá


## Fundo: o terreno do jogo (arte Ninja Adventure) escurecido, só desenho (sem física nem lógica).
func _build_background() -> void:
	# Camada própria atrás da UI: a folhagem do terreno tem `z_index` 5 e cobriria o painel do menu.
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var terrain := BACKGROUND.instantiate()
	terrain.process_mode = Node.PROCESS_MODE_DISABLED
	layer.add_child(terrain)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)


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
		_notice.text = outcome.message


func _build_settings() -> void:
	_settings_box.add_child(_settings_menu)
	_settings_menu.setup([
		{"id": FULLSCREEN, "label": ""},
		{"id": VOLUME, "label": ""},
		{"id": BACK, "label": "Voltar"},
	])
	_settings_menu.activated.connect(_on_settings_activated)
	var hint := Label.new()
	hint.text = "Esquerda e direita ajustam o volume"
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
	_confirm_box.visible = which == "confirm"
	_settings_box.visible = which == "settings"
	_credits_box.visible = which == "credits"
	_notice.text = ""
	if which == "credits":
		_credits_scroll.scroll_vertical = 0


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


func credits_scroll() -> ScrollContainer:
	return _credits_scroll


func credits_text() -> String:
	return _credits_label.text


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
	if _settings_menu.selected_id() == VOLUME:
		if event.is_action_pressed("ui_left"):
			_change_volume(-GameSettings.VOLUME_STEP)
			return true
		if event.is_action_pressed("ui_right"):
			_change_volume(GameSettings.VOLUME_STEP)
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
		VOLUME:
			settings.cycle_volume()
			_commit_settings()
		BACK:
			_show("menu")


func _change_volume(step: float) -> void:
	settings.set_volume(settings.volume + step)
	_commit_settings()


func _commit_settings() -> void:
	settings.apply()
	if not settings.save_to(settings_path):
		_notice.text = "Não foi possível gravar as configurações."
	_refresh_settings()


func _refresh_settings() -> void:
	_settings_menu.set_label(FULLSCREEN, "Tela cheia: %s" % ("Sim" if settings.fullscreen else "Não"))
	_settings_menu.set_label(VOLUME, "Volume geral: %d%%" % roundi(settings.volume * 100.0))


func _choose(id: String) -> void:
	action_chosen.emit(id)
	if not auto_perform:
		return
	if id == CONTINUE or id == NEW_GAME:
		GameSession.continue_requested = id == CONTINUE
		get_tree().change_scene_to_file(GAME_SCENE)
	elif id == QUIT:
		get_tree().quit()
