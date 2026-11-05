class_name PlayerHud
extends Control
## HUD do jogador: barras de vida, stamina e fome, painel da criatura-alvo e o
## prompt de interação. Só apresentação: lê sinais do `player`; nenhuma regra aqui.
## Pode ser removida sem efeito no jogo (roda igual sem ela, inclusive headless).

@export var player: Player

var _health_bar := StatBar.new("Vida", Color(0.8, 0.2, 0.2))
var _stamina_bar := StatBar.new("Stamina", Color(0.25, 0.7, 0.3))
var _hunger_bar := StatBar.new("Fome", Color(0.85, 0.55, 0.2))
var _dino_panel := DinoPanel.new()
var _prompt := Label.new()
var _watched: InteractableArea = null


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bars := VBoxContainer.new()
	bars.position = Vector2(6, 6)
	for bar in [_health_bar, _stamina_bar, _hunger_bar]:
		bars.add_child(bar)
	add_child(bars)

	add_child(_dino_panel)
	_dino_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)

	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.visible = false
	add_child(_prompt)

	if player == null:
		return
	player.health.health_changed.connect(_health_bar.set_values)
	player.stamina.stamina_changed.connect(_stamina_bar.set_values)
	player.hunger.hunger_changed.connect(_hunger_bar.set_values)
	player.target_changed.connect(_on_target_changed)
	player.input_lock_changed.connect(_on_lock_changed)
	_health_bar.set_values(player.health.current_health, player.health.max_health)
	_stamina_bar.set_values(player.stamina.current_stamina, player.stamina.max_stamina)
	_hunger_bar.set_values(player.hunger.current_hunger, player.hunger.max_hunger)
	_on_target_changed(player.target)


func health_bar() -> StatBar:
	return _health_bar


func stamina_bar() -> StatBar:
	return _stamina_bar


func hunger_bar() -> StatBar:
	return _hunger_bar


func dino_panel() -> DinoPanel:
	return _dino_panel


func prompt_label() -> Label:
	return _prompt


func _on_target_changed(target: InteractableArea) -> void:
	if _watched != null and is_instance_valid(_watched):
		_watched.availability_changed.disconnect(_on_availability_changed)
	_watched = target
	if _watched != null:
		_watched.availability_changed.connect(_on_availability_changed)
	_dino_panel.show_dino(target.entity as Dino if target != null else null)
	_refresh_prompt()


func _on_availability_changed(_available: bool) -> void:
	_refresh_prompt()


func _on_lock_changed(_locked: bool) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	var can_show := _watched != null and is_instance_valid(_watched) \
			and _watched.can_interact() and not player.input_locked
	_prompt.visible = can_show
	if can_show:
		_prompt.text = "E para %s" % _watched.prompt
