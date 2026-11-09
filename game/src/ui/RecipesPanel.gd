# SPDX-License-Identifier: MIT
class_name RecipesPanel
extends PanelContainer
## Aba Receitas da tela P (E7b, PRO-13): lista plana (D18) de TODAS as receitas, ordenada por custo de Saber, com o custo em
## material, o estado (conhecida, aprendível ou travada, com o que falta) e o botão Aprender. SÓ observa o jogador e emite
## `learn_requested`; a `Main` o transforma em `request_learn_recipe` e a autoridade decide.

signal learn_requested(recipe_id: String)

## Ação da tecla P, criada por código para não mexer em `project.godot`.
const RECIPES_PANEL := &"recipes_panel"
const WIDTH := 170.0
const LIST_HEIGHT := 110.0
const REFRESH_SECONDS := 0.25

var recipe_book: RecipeBook = null
var player: Player = null

var _list: VBoxContainer = null
var _title: Label = null
var _since_refresh: float = 0.0
var _last_signature: String = ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


static func ensure_action() -> void:
	if InputMap.has_action(RECIPES_PANEL):
		return
	InputMap.add_action(RECIPES_PANEL)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	InputMap.action_add_event(RECIPES_PANEL, event)


func _unhandled_input(event: InputEvent) -> void:
	ensure_action()
	if event.is_action_pressed(RECIPES_PANEL):
		set_open(not visible)
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	visible = open and player != null and recipe_book != null and not player.is_incapacitated()
	if visible:
		_last_signature = ""
		refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	if player == null or player.is_incapacitated():
		visible = false
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		refresh()


## Reconstrói a lista só se algo mudou (o botão não some debaixo do mouse a cada quadro).
func refresh() -> void:
	_since_refresh = 0.0
	if _list == null or recipe_book == null or player == null or not visible:
		return
	var signature := _signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_title.text = "Receitas (P)  Saber livre: %d" % player.progression.saber_free()
	for recipe in recipe_book.by_cost():
		_list.add_child(_row(recipe))


func _signature() -> String:
	var parts: PackedStringArray = [str(player.progression.saber_free())]
	for recipe in recipe_book.all():
		parts.append("%s=%d" % [recipe.id, RecipeStatus.of(recipe, player.progression)])
	return "|".join(parts)


func _row(recipe: RecipeDef) -> Control:
	var state := RecipeStatus.of(recipe, player.progression)
	var row := HBoxContainer.new()
	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", UiTheme.INK)
	text.text = "%s\n%s\n%s" % [recipe.display_name, materials_text(recipe), RecipeStatus.label(recipe, player.progression)]
	row.add_child(text)
	if state != RecipeStatus.State.KNOWN:
		var button := Button.new()
		button.text = "Aprender"
		button.disabled = state != RecipeStatus.State.LEARNABLE
		var recipe_id := recipe.id
		button.pressed.connect(func() -> void: learn_requested.emit(recipe_id))
		row.add_child(button)
	return row


## "Madeira x8, Pedra x2" (o custo em material, sem o que o jogador tem: isso é da tela de fabricar).
static func materials_text(recipe: RecipeDef) -> String:
	var parts: PackedStringArray = []
	for item_id: String in recipe.inputs:
		parts.append("%s x%d" % [Items.display_name(item_id), int(recipe.inputs[item_id])])
	return ", ".join(parts)
