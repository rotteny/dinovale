# SPDX-License-Identifier: MIT
class_name UiTheme
extends RefCounted
## Tema único da UI: fonte padrão da engine em tamanho legível em 640x360, painéis de
## madeira 9-slice e células de inventário do pacote Ninja Adventure (CC0).
## Cada raiz de UI (HUD, tela de inventário) aplica o mesmo tema.

const FONT_SIZE := 10
const PANEL_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/panel_a.png")
const CELL_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/inventory_cell.png")
const FOCUS_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/focus.png")
## Tinta escura do pacote (a cor mais escura da paleta): texto sobre painel e célula.
const INK := Color("#141b1b")
const PANEL_MARGIN := 6
const CELL_MARGIN := 3

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = FONT_SIZE
		_theme.set_stylebox("panel", "PanelContainer", _nine(PANEL_TEXTURE, PANEL_MARGIN, Color.WHITE))
		_theme.set_stylebox("normal", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color.WHITE))
		_theme.set_stylebox("hover", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color(1.25, 1.25, 1.25)))
		_theme.set_stylebox("pressed", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color(0.75, 0.75, 0.75)))
		_theme.set_stylebox("focus", "Button", _nine(FOCUS_TEXTURE, CELL_MARGIN, Color.WHITE))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(color_name, "Button", INK)
	return _theme


## Painel 9-slice: os cantos e bordas são do pacote; só o miolo estica.
static func _nine(texture: Texture2D, margin: int, tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, margin)
	return box
