# SPDX-License-Identifier: MIT
class_name PlayerHud
extends Control
## HUD do jogador (GDD 5.7): vida, fome, stamina, XP com "Nv N" e a barra de atalhos 1 a 9, mais o
## prompt de interação. A barra de Stamina (decisão do dono, 08/11) mostra quanto ainda dá para correr; o som e a nuvem
## de fôlego seguem no `PlayerView`. Sem sede e sem durabilidade. O XP vem do `ProgressionComponent` do jogador (E6,
## UIX-12): barra e "Nv N" ouvem `xp_changed`; o selo de Saber só aparece com Saber livre e pulsa devagar; subir de nível
## mostra um aviso de 3 s. Só apresentação: lê sinais do `player`; nenhuma regra aqui.
## Pode ser removida sem efeito no jogo (roda igual sem ela, inclusive headless).

## Medidas para o viewport de 320x180 (a HUD compacta deixa quase toda a área de visão livre): as barras
## ficam num bloco pequeno no canto de cima, à esquerda, e o XP fino e os atalhos numa faixa embaixo. Não há
## painel de madeira: rótulos e barras levam contorno escuro.
const HOTBAR_WIDTH := 9 * HotbarBar.SLOT_SIZE.x + 8 * HotbarBar.SLOT_GAP
const EDGE_MARGIN := 3.0
## Vida e fome discretas: ícone pequeno, barra curta e o número ao lado (cantinho de cima, longe do centro).
const BAR_SIZE := Vector2(26.0, 4.0)
const ICON_SIZE := Vector2(8.0, 8.0)
const NOTICE_SECONDS := 2.0
const NOTICE_WIDTH := 200.0
## Distância do prompt e do aviso ao pé da tela (acima da barra de atalhos).
const PROMPT_BOTTOM := 36
const NOTICE_BOTTOM := 48
const OUTLINE_SIZE := 2  # a Vale Mini em 8 px não desenha contorno de 1 px (arredonda para 0)
const SAVING_SECONDS := 1.0
const SAVING_TEXT := "Salvando"
const PHASE_TOP := 11.0
## Amarelo claro com contorno escuro: legível sobre qualquer terreno.
const HUNGER_WARNING_COLOR := Color("#ffe27a")
const HUNGRY_TEXT := "Com fome: coma algo"
const STARVING_TEXT := "Morrendo de fome!"
## Stamina: verde-água (diferente da vida e da fome); abaixo do limiar de ofego muda de tom; esgotada fica cinza.
const STAMINA_COLOR := Color("#6fd6c4")
const STAMINA_WINDED_COLOR := Color("#f0a35a")
const STAMINA_EXHAUSTED_COLOR := Color("#7d7d7d")
## Barra do caído (tempo que falta para acordar, em segundos): laranja escuro, só aparece caído.
const DOWNED_COLOR := Color("#d9792b")
## Dica de contexto bloqueada (ex.: falta ferramenta): cinza.
const HINT_BLOCKED_COLOR := Color("#a8a8a8")

@export var player: Player
## Autoridade só para ler a faixa do dia (o rótulo da fase); sem ela o rótulo fica escondido. A `Main` a liga.
@export var authority: WorldAuthority

var _health_bar := StatBar.new("Vida", Color(0.8, 0.2, 0.2), BAR_SIZE,
		preload("res://assets/third_party/ninja-adventure/ui/icon_heart.png"), ICON_SIZE, true)
var _hunger_bar := StatBar.new("Fome", Color(0.98, 0.85, 0.35), BAR_SIZE,
		preload("res://assets/third_party/ninja-adventure/items/food_meat.png"), ICON_SIZE, true)
var _stamina_bar := StatBar.new("Stamina", STAMINA_COLOR, BAR_SIZE,
		preload("res://assets/sprites/ui/icon_stamina_8.png"), ICON_SIZE, true)
var _downed_bar := StatBar.new("Caído", DOWNED_COLOR, BAR_SIZE, null, ICON_SIZE, true)
var _xp_label := Label.new()
var _xp_bar := StatBar.new("", Color(0.45, 0.6, 1.0), Vector2(StatBar.BAR_SIZE.x, 3.0))
var _hotbar := HotbarBar.new()
var _prompt := Label.new()
var _highlighted: ResourceNodeView = null
var _notice := Label.new()
var _hunger_warning := Label.new()
var _saving := Label.new()
var _saving_left: float = 0.0
var _notice_tween: Tween
var _watched: InteractableArea = null
var _bars_block := VBoxContainer.new()
var _bottom := VBoxContainer.new()
var _xp_row := HBoxContainer.new()
var _saber_badge := Label.new()
var _phase_label := Label.new()
var _saber_tween: Tween


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bloco de cima: vida, fome e, fino, o XP com "Nv N". Sem painel por trás.
	var bars := _bars_block
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 0)
	bars.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	_downed_bar.visible = false
	for bar in [_health_bar, _hunger_bar, _stamina_bar, _downed_bar]:
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # a linha ocupa só o seu tamanho, não a largura do aviso
		bars.add_child(bar)
	_outline(_hunger_warning)
	_hunger_warning.add_theme_color_override("font_color", HUNGER_WARNING_COLOR)
	_hunger_warning.visible = false
	bars.add_child(_hunger_warning)
	add_child(bars)

	# Parte de baixo: o XP fino sobre a fileira de atalhos, no pé da tela.
	_hotbar.player = player
	# XP fino ("Nv N" no começo) logo acima dos atalhos, como no GDD 5.7.
	var xp_row := _xp_row
	xp_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_theme_constant_override("separation", 2)
	_outline(_xp_label)
	_xp_label.custom_minimum_size.x = StatBar.ICON_SIZE.x + 4.0
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	xp_row.add_child(_xp_label)
	_outline(_saber_badge)
	_saber_badge.visible = false  # só quando há Saber a gastar (sem janela, sem interrupção)
	xp_row.add_child(_saber_badge)
	xp_row.add_child(_xp_bar)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override("separation", 0)
	_bottom.add_child(xp_row)
	_bottom.add_child(_hotbar)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(EDGE_MARGIN))
	_bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_bottom)
	set_experience(1, 0.0, 1.0)

	_place_bottom_center(_prompt, PROMPT_BOTTOM)
	_outline(_prompt)
	_prompt.visible = false
	add_child(_prompt)

	_place_bottom_center(_notice, NOTICE_BOTTOM)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_notice)
	_notice.visible = false
	add_child(_notice)

	_saving.text = SAVING_TEXT
	_saving.set_anchors_preset(Control.PRESET_TOP_RIGHT)  # o tamanho vem do texto (o rótulo ainda não está na árvore)
	_saving.offset_right = -EDGE_MARGIN
	_saving.offset_top = EDGE_MARGIN
	_saving.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_outline(_saving)
	_saving.modulate = Color(1, 1, 1, 0.8)
	_saving.visible = false
	add_child(_saving)

	_phase_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)  # abaixo do "Salvando", que ocupa o canto de cima
	_phase_label.offset_right = -EDGE_MARGIN
	_phase_label.offset_top = EDGE_MARGIN + PHASE_TOP
	_phase_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_outline(_phase_label)
	_phase_label.visible = false
	add_child(_phase_label)

	if player == null:
		return
	player.equip_refused.connect(show_notice_for)
	player.health.health_changed.connect(_health_bar.set_values)
	player.hunger.hunger_changed.connect(_refresh_hunger_bar)
	player.hunger.hunger_changed.connect(_refresh_hunger_warning)
	player.stamina.stamina_changed.connect(_refresh_stamina)
	player.stamina.exhausted.connect(_refresh_stamina_state)
	player.stamina.recovered.connect(_refresh_stamina_state)
	player.downed.time_changed.connect(_downed_bar.set_values)
	player.downed.state_changed.connect(_refresh_downed)
	player.target_changed.connect(_on_target_changed)
	player.input_lock_changed.connect(_on_lock_changed)
	_health_bar.set_values(player.health.current_health, player.health.max_health)
	_refresh_hunger_bar(player.hunger.current_hunger, player.hunger.max_hunger)
	_refresh_hunger_warning(player.hunger.current_hunger, player.hunger.max_hunger)
	_refresh_stamina(player.stamina.current_stamina, player.stamina.max_stamina)
	_downed_bar.set_values(player.downed.left, player.downed_rules.downed_seconds)
	_refresh_downed(player.downed.is_downed)
	_on_target_changed(player.target)
	player.progression.xp_changed.connect(_on_xp_changed)
	player.progression.saber_changed.connect(set_saber_free)
	player.progression.leveled_up.connect(_on_leveled_up)
	_on_xp_changed(player.progression.level, player.progression.xp, player.progression.xp_needed())
	set_saber_free(player.progression.saber_free())


## Rótulo centrado em baixo, a `bottom` px do pé da tela; o tamanho segue o texto. Não usa
## `set_anchors_and_offsets_preset(MINSIZE)`: antes de entrar na árvore o rótulo mede o texto com a
## fonte padrão da engine (16 px) e ficaria com o tamanho errado.
func _place_bottom_center(label: Label, bottom: int) -> void:
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = -bottom
	label.offset_bottom = -bottom
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Reancora o rótulo no centro com a largura do texto atual (o texto muda; a posição não pode ir junto).
func _recenter(label: Label) -> void:
	var width := label.get_combined_minimum_size().x
	label.offset_left = -floorf(width / 2.0)
	label.offset_right = ceilf(width / 2.0)


## Texto branco com contorno preto: lê-se sobre qualquer terreno.
func _outline(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)


## Retângulos (em coordenadas da tela) que a HUD ocupa agora: cada linha de barras, os atalhos e os textos
## visíveis. Serve para medir a cobertura da tela (a HUD tem de deixar quase toda a visão livre).
func covered_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var blocks: Array[Control] = [_hotbar, _xp_row, _prompt, _notice, _saving]
	for row in _bars_block.get_children():
		blocks.append(row as Control)
	for control in blocks:
		if control.is_visible_in_tree():
			rects.append(control.get_global_rect())
	return rects


func health_bar() -> StatBar:
	return _health_bar


func xp_bar() -> StatBar:
	return _xp_bar


func xp_label() -> Label:
	return _xp_label


func hotbar_bar() -> HotbarBar:
	return _hotbar


## Desenha o nível e a barra. `needed` 0 = no teto: barra cheia.
func set_experience(level: int, current: float, needed: float) -> void:
	_xp_label.text = "Nv %d" % level
	_xp_bar.set_values(current if needed > 0.0 else 1.0, needed if needed > 0.0 else 1.0)


func _on_xp_changed(level: int, current: int, needed: int) -> void:
	set_experience(level, float(current), float(needed))


## Selo de Saber ao lado do nível: visível só com Saber livre; pulsa devagar (sem som, sem janela).
func set_saber_free(free: int) -> void:
	_saber_badge.visible = free > 0
	_saber_badge.text = "Saber %d" % free
	if _saber_tween != null:
		_saber_tween.kill()
		_saber_tween = null
	_saber_badge.modulate = Color.WHITE
	if free > 0 and is_inside_tree():
		_saber_tween = create_tween().set_loops()
		_saber_tween.tween_property(_saber_badge, "modulate:a", 0.55, 0.9)
		_saber_tween.tween_property(_saber_badge, "modulate:a", 1.0, 0.9)


func saber_badge() -> Label:
	return _saber_badge


## Aviso de 3 s ao subir de nível (o log do jogo recebe o mesmo fato pelo código `player_level_up`).
func _on_leveled_up(level: int, saber_gained: int) -> void:
	show_notice(GameMessages.text_of("player_level_up", {"level": level, "saber": saber_gained}), player.progression.rules.notice_seconds)


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
	_refresh_phase()


## Rótulo da faixa do dia ("Dia", "Noite"...): só lê o `DayCycle` da autoridade. Sem autoridade fica escondido.
func _refresh_phase() -> void:
	if authority == null:
		_phase_label.visible = false
		return
	var key := DayCycle.name_of(authority.day_phase())
	var text: String = GameMessages.PHASE_LABELS.get(key, "")
	if _phase_label.text != text:
		_phase_label.text = text
	_phase_label.visible = text != ""


func phase_label() -> Label:
	return _phase_label


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
	# O aviso curto ocupa só o texto; o longo quebra a linha em NOTICE_WIDTH.
	var font := _notice.get_theme_font("font")
	var text_width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, _notice.get_theme_font_size("font_size")).x
	var fits_one_line := text_width + 2.0 * OUTLINE_SIZE <= NOTICE_WIDTH
	_notice.autowrap_mode = TextServer.AUTOWRAP_OFF if fits_one_line else TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size.x = 0.0 if fits_one_line else NOTICE_WIDTH
	_recenter(_notice)
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
	_highlight(target)
	_refresh_prompt()


## Só o nó de recurso que o jogador está a ponto de tocar ganha contorno e nome; o resto do mundo, nada.
func _highlight(target: InteractableArea) -> void:
	if _highlighted != null and is_instance_valid(_highlighted):
		_highlighted.set_highlight(false)
	_highlighted = null
	if target == null or not (target.entity is ResourceNode):
		return
	for child in target.entity.get_children():
		if child is ResourceNodeView:
			_highlighted = child
			_highlighted.set_highlight(true)


func _on_availability_changed(_available: bool) -> void:
	if _highlighted != null and is_instance_valid(_highlighted):
		_highlighted.set_highlight(_available)
	_refresh_prompt()


func _on_lock_changed(_locked: bool) -> void:
	_refresh_prompt()


## O alvo é o domado de OUTRO jogador (a dica de ordem só vale no seu)?
func _is_foreign_command() -> bool:
	var dino := _watched.entity as Dino
	return dino != null and dino.can_command() and not dino.can_interact() and dino.owner_player_id != player.player_id


## Dica de contexto do alvo ao alcance: nó de vários golpes mostra o gesto certo (e o que falta); o resto, "E para ...".
func _hint_for(area: InteractableArea) -> Dictionary:
	var node := area.entity as ResourceNode
	if node != null and node.def.is_struck():
		return ActionHints.for_resource(node.def, player.gather_damage_on(node.def), player.gather_blocked_now(node))
	return {"text": "E para %s" % area.prompt, "blocked": node != null and player.gather_blocked_now(node)}


## Barra de Fome: valor atual e, mais claro à frente, a parte que ainda vai subir (comida na fila).
func _refresh_hunger_bar(current: float, maximum: float) -> void:
	_hunger_bar.set_values(current, maximum)
	_hunger_bar.set_pending(current, player.hunger.pending, maximum)


## Barra de Stamina: o valor vem do sinal; o tom, do estado (esgotada, ofegando, normal). A UI não calcula nada.
func _refresh_stamina(current: float, maximum: float) -> void:
	_stamina_bar.set_values(current, maximum)
	_refresh_stamina_state()


func _refresh_stamina_state() -> void:
	var color := STAMINA_COLOR
	if player.stamina.is_exhausted:
		color = STAMINA_EXHAUSTED_COLOR
	elif player.stamina.is_winded():
		color = STAMINA_WINDED_COLOR
	_stamina_bar.set_fill_color(color)


## A barra do caído só existe enquanto o jogador está caído.
func _refresh_downed(downed: bool) -> void:
	_downed_bar.visible = downed


func downed_bar() -> StatBar:
	return _downed_bar


func stamina_bar() -> StatBar:
	return _stamina_bar


func _refresh_prompt() -> void:
	var can_show := _watched != null and is_instance_valid(_watched) \
			and _watched.can_prompt() and not player.input_locked and not _is_foreign_command()
	_prompt.visible = can_show
	if can_show:
		var hint := _hint_for(_watched)
		_prompt.text = hint["text"]
		_prompt.modulate = HINT_BLOCKED_COLOR if hint["blocked"] else Color.WHITE
		_recenter(_prompt)
