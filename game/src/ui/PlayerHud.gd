# SPDX-License-Identifier: MIT
class_name PlayerHud
extends Control
## HUD do jogador (GDD 5.7): vida, fome, XP com "Nv N" e a barra de atalhos 1 a 9, mais o
## prompt de interação. Sem barra de stamina (o fôlego vira som e nuvem no `PlayerView`), sem
## sede e sem durabilidade. O XP ainda não existe no jogo: `set_experience` é só o ponto de
## ligação e a HUD nasce mostrando Nv 1 e XP 0. Só apresentação: lê sinais do `player`; nenhuma regra aqui.
## Pode ser removida sem efeito no jogo (roda igual sem ela, inclusive headless).

const HOTBAR_WIDTH := 9 * 26.0 + 8 * 2.0
const BOTTOM_MARGIN := 4.0
const NOTICE_SECONDS := 2.0
const NOTICE_WIDTH := 420.0
const SAVING_SECONDS := 1.0
const SAVING_TEXT := "Salvando"
## Amarelo claro com contorno escuro: legível sobre o painel laranja.
const HUNGER_WARNING_COLOR := Color("#ffe27a")
const HUNGRY_TEXT := "Com fome: coma algo"
const STARVING_TEXT := "Morrendo de fome!"

@export var player: Player

var _health_bar := StatBar.new("Vida", Color(0.8, 0.2, 0.2), StatBar.BAR_SIZE,
		preload("res://assets/third_party/ninja-adventure/ui/icon_heart.png"))
var _hunger_bar := StatBar.new("Fome", Color(0.98, 0.85, 0.35), StatBar.BAR_SIZE,
		preload("res://assets/third_party/ninja-adventure/items/food_meat.png"))
var _xp_label := Label.new()
var _xp_bar := StatBar.new("", Color(0.45, 0.6, 1.0), Vector2(HOTBAR_WIDTH - 30.0, 4.0))
var _hotbar := HotbarBar.new()
var _prompt := Label.new()
var _notice := Label.new()
var _hunger_warning := Label.new()
var _saving := Label.new()
var _saving_left: float = 0.0
var _notice_tween: Tween
var _watched: InteractableArea = null


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bars := VBoxContainer.new()
	for bar in [_health_bar, _hunger_bar]:
		bars.add_child(bar)
	_hunger_warning.add_theme_font_size_override("font_size", 8)
	_hunger_warning.add_theme_color_override("font_color", HUNGER_WARNING_COLOR)
	_hunger_warning.add_theme_color_override("font_outline_color", Color.BLACK)
	_hunger_warning.add_theme_constant_override("outline_size", 3)
	_hunger_warning.visible = false
	bars.add_child(_hunger_warning)
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bars)
	add_child(panel)

	# Parte de baixo: XP fino ("Nv N" no começo) acima dos atalhos.
	var xp_row := HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_label.add_theme_color_override("font_color", Color.WHITE)
	_xp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_xp_label.add_theme_constant_override("outline_size", 3)
	_xp_label.custom_minimum_size.x = 30.0
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_label)
	xp_row.add_child(_xp_bar)
	_hotbar.player = player
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 2)
	bottom.add_child(xp_row)
	bottom.add_child(_hotbar)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(BOTTOM_MARGIN))
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	set_experience(1, 0.0, 1.0)

	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 56)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.visible = false
	add_child(_prompt)

	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 76)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.custom_minimum_size.x = NOTICE_WIDTH
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 4)
	_notice.visible = false
	add_child(_notice)

	_saving.text = SAVING_TEXT
	_saving.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_saving.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saving.add_theme_font_size_override("font_size", 8)
	_saving.add_theme_color_override("font_outline_color", Color.BLACK)
	_saving.add_theme_constant_override("outline_size", 3)
	_saving.modulate = Color(1, 1, 1, 0.8)
	_saving.visible = false
	add_child(_saving)

	if player == null:
		return
	player.equip_refused.connect(show_notice_for)
	player.health.health_changed.connect(_health_bar.set_values)
	player.hunger.hunger_changed.connect(_hunger_bar.set_values)
	player.hunger.hunger_changed.connect(_refresh_hunger_warning)
	player.target_changed.connect(_on_target_changed)
	player.input_lock_changed.connect(_on_lock_changed)
	_health_bar.set_values(player.health.current_health, player.health.max_health)
	_hunger_bar.set_values(player.hunger.current_hunger, player.hunger.max_hunger)
	_refresh_hunger_warning(player.hunger.current_hunger, player.hunger.max_hunger)
	_on_target_changed(player.target)


func health_bar() -> StatBar:
	return _health_bar


func xp_bar() -> StatBar:
	return _xp_bar


func xp_label() -> Label:
	return _xp_label


func hotbar_bar() -> HotbarBar:
	return _hotbar


## Ponto de ligação do XP: quem tiver nível e experiência chama isto. Hoje ninguém chama
## (a HUD começa em Nv 1 e XP 0); nenhuma regra de XP, ponto ou Saber existe ainda.
func set_experience(level: int, current: float, needed: float) -> void:
	_xp_label.text = "Nv %d" % level
	_xp_bar.set_values(current, needed)


func hunger_bar() -> StatBar:
	return _hunger_bar


func _process(delta: float) -> void:
	tick(delta)


## Passo do indicador de salvamento (separado do `_process` para testar sem quadros).
func tick(delta: float) -> void:
	_saving_left = maxf(_saving_left - delta, 0.0)
	_saving.visible = _saving_left > 0.0
	if _watched != null:  # o prompt do domado muda com a ordem, e a área não emite sinal por isso
		_refresh_prompt()


## Indicador discreto de 1 s no canto: o jogo salvou (nunca bloqueia nem pergunta).
func show_saving() -> void:
	_saving_left = SAVING_SECONDS
	_saving.visible = true


func saving_label() -> Label:
	return _saving


func hunger_warning_label() -> Label:
	return _hunger_warning


## O limiar vem dos dados (`PlayerRules.hunger_warning_ratio`); a HUD só mostra.
func _refresh_hunger_warning(current: float, maximum: float) -> void:
	_hunger_warning.visible = player.rules.is_hungry(current, maximum)
	_hunger_warning.text = STARVING_TEXT if current <= 0.0 else HUNGRY_TEXT


func prompt_label() -> Label:
	return _prompt


func notice_label() -> Label:
	return _notice


## Aviso curto de uma recusa de equipar (a tecla de atalho não abre a tela, então o aviso é daqui).
func show_notice_for(reason: String) -> void:
	show_notice(EquipmentComponent.refusal_message(reason))


## Aviso curto no centro de baixo; some sozinho depois de `seconds`. Texto vazio não mostra nada.
func show_notice(message: String, seconds: float = NOTICE_SECONDS) -> void:
	if message == "":
		return
	_notice.text = message
	_notice.visible = true
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(seconds)
	_notice_tween.tween_callback(func() -> void: _notice.visible = false)


func _on_target_changed(target: InteractableArea) -> void:
	if _watched != null and is_instance_valid(_watched):
		_watched.availability_changed.disconnect(_on_availability_changed)
	_watched = target
	if _watched != null:
		_watched.availability_changed.connect(_on_availability_changed)
	_refresh_prompt()


func _on_availability_changed(_available: bool) -> void:
	_refresh_prompt()


func _on_lock_changed(_locked: bool) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	var can_show := _watched != null and is_instance_valid(_watched) \
			and _watched.can_prompt() and not player.input_locked
	_prompt.visible = can_show
	if can_show:
		_prompt.text = "E para %s" % _watched.prompt
