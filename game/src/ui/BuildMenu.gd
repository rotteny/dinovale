# SPDX-License-Identifier: MIT
class_name BuildMenu
extends PanelContainer
## Menu de peças do modo construção (E8a, CON-03): uma linha por peça do catálogo, com o custo em material (o que falta vem
## marcado com "!") e a peça escolhida em destaque. SÓ observa o inventário e as receitas do jogador; a escolha sai por
## `piece_chosen` e quem pede a construção é o `BuildMode` (que manda o pedido à autoridade).

signal piece_chosen(piece_id: String)

const WIDTH := 150.0
const REFRESH_SECONDS := 0.25

var catalog: PieceCatalog = null
var recipe_book: RecipeBook = null
var player: Player = null
## A peça escolhida agora ("" = nenhuma): o `BuildMode` a mantém e avisa por `show_selected`.
var selected: String = ""

var _list: VBoxContainer = null
var _hint: Label = null
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
	var title := Label.new()
	title.text = "Construir (B)"
	title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_hint = Label.new()
	_hint.text = "R gira, clique esquerdo constrói,\nclique direito remove, T porta"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(_hint)


func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		refresh()


## O `BuildMode` mudou a peça escolhida.
func show_selected(piece_id: String) -> void:
	selected = piece_id
	refresh(true)


## Reconstrói as linhas só quando algo mudou (reconstruir a cada quadro trocaria os botões sob o mouse).
func refresh(force: bool = false) -> void:
	_since_refresh = 0.0
	if _list == null or catalog == null or player == null or not visible:
		return
	var signature := _signature()
	if signature == _last_signature and not force:
		return
	_last_signature = signature
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for piece in catalog.buildable():
		_list.add_child(_row(piece))


## Texto de custo da peça: "Madeira 2/3, Pedra 0/1" (o que falta com "!") ou "Receita não aprendida (P)".
func cost_text(piece: PieceDef) -> String:
	var recipe := recipe_book.find(piece.recipe_id) if recipe_book != null else null
	if recipe == null:
		return ""
	if not player.progression.knows(recipe):
		return "Receita não aprendida (P)"
	return CraftPanel.needs_text(recipe, player.inventory)


func _signature() -> String:
	var parts: PackedStringArray = [selected]
	for piece in catalog.buildable():
		parts.append("%s=%s" % [piece.id, cost_text(piece)])
	return "|".join(parts)


func _row(piece: PieceDef) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE  # o botão não come o Espaço (ataque)
	button.text = "%s%s\n%s" % [">" if piece.id == selected else "", piece.display_name, cost_text(piece)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var piece_id := piece.id
	button.pressed.connect(func() -> void: piece_chosen.emit(piece_id))
	return button
