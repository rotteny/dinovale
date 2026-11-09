# SPDX-License-Identifier: MIT
class_name CraftPanel
extends PanelContainer
## Painel de fabricação (E7a), aberto pela tecla C: lista as receitas conhecidas, o que falta de material, a barra de
## progresso e o botão de fabricar. SÓ observa a autoridade e o inventário do jogador; o que o jogador quer sai por sinal
## (`craft_requested`, `cancel_requested`, `place_requested`) e a `Main` o transforma em pedido (`request_*`).

signal craft_requested(recipe_id: String)
signal cancel_requested
## Colocar a peça `item_id` à frente do jogador.
signal place_requested(item_id: String)

## Ação da tecla C, criada por código para não mexer em `project.godot`.
const CRAFT_PANEL := &"craft_panel"
const WIDTH := 150.0
const REFRESH_SECONDS := 0.25

var authority: WorldAuthority = null
var player: Player = null

var _list: VBoxContainer = null
var _progress: ProgressBar = null
var _status: Label = null
var _cancel: Button = null
var _since_refresh: float = 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Fabricar (C)"
	title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 6.0)
	_progress.max_value = 1.0
	box.add_child(_progress)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.INK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	_cancel = Button.new()
	_cancel.text = "Cancelar"
	_cancel.pressed.connect(func() -> void: cancel_requested.emit())
	footer.add_child(_cancel)


static func ensure_action() -> void:
	if InputMap.has_action(CRAFT_PANEL):
		return
	InputMap.add_action(CRAFT_PANEL)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	InputMap.action_add_event(CRAFT_PANEL, event)


func _unhandled_input(event: InputEvent) -> void:
	ensure_action()
	if event.is_action_pressed(CRAFT_PANEL):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	visible = open and player != null and not player.is_incapacitated()
	if visible:
		refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	if player == null or authority == null or player.is_incapacitated():
		visible = false  # caído ou morto não fabrica: o painel fecha
		return
	_progress.value = authority.crafting.progress(authority.id_of(player))
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		refresh()


## Reconstrói as linhas (poucas): nome, material que tem/precisa e o botão. O botão só diz que dá; quem decide é a autoridade.
func refresh() -> void:
	_since_refresh = 0.0
	if _list == null or authority == null or player == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var actor_id := authority.id_of(player)
	var crafting := not authority.crafting.job(actor_id).is_empty()
	for recipe in authority.crafting.recipe_book.known():
		_list.add_child(_row(recipe, crafting))
	if player.inventory.count(Items.WORKBENCH) > 0:
		var place := Button.new()
		place.text = "Colocar %s" % Items.display_name(Items.WORKBENCH)
		place.pressed.connect(func() -> void: place_requested.emit(Items.WORKBENCH))
		_list.add_child(place)
	_cancel.visible = crafting
	_status.text = ""
	if crafting:
		var job := authority.crafting.job(actor_id)
		var current := authority.crafting.recipe_book.find(str(job.get("recipe", "")))
		_status.text = "Fabricando %s" % (Items.display_name(current.output_id) if current != null else "")


func _row(recipe: RecipeDef, crafting: bool) -> Control:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", UiTheme.INK)
	text.text = "%s\n%s" % [recipe.display_name, needs_text(recipe, player.inventory)]
	row.add_child(text)
	var button := Button.new()
	button.text = "Fazer"
	button.disabled = crafting or not recipe.missing_from(player.inventory).is_empty()
	var recipe_id := recipe.id
	button.pressed.connect(func() -> void: craft_requested.emit(recipe_id))
	row.add_child(button)
	return row


## "Madeira 2/3, Pedra 2/2": o que o jogador tem e o que a receita pede. O que falta vem marcado com "!".
static func needs_text(recipe: RecipeDef, inventory: InventoryComponent) -> String:
	var parts: PackedStringArray = []
	for item_id: String in recipe.inputs:
		var have := inventory.count(item_id)
		var need := int(recipe.inputs[item_id])
		parts.append("%s%s %d/%d" % ["!" if have < need else "", Items.display_name(item_id), mini(have, need), need])
	return ", ".join(parts)
