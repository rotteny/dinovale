# SPDX-License-Identifier: MIT
class_name UiTheme
extends RefCounted
## Tema único da UI, pensado para o viewport de 320x180 (1 px do viewport = 4 px da tela em 720p):
## fonte Vale Mini (bitmap de 8 px, derivada da Kenney Mini, CC0), sem suavização, sem hinting e sem
## posição subpixel (cada glifo cai na grade de pixels), painéis de madeira 9-slice e células do pacote
## Ninja Adventure (CC0). Cada raiz de UI (HUD, inventário, pausa, morte, título) aplica o mesmo tema.

## A fonte é desenhada em grade de 8 px: só vale 8 ou múltiplo inteiro (16, 24...).
const FONT_SIZE := 8
const FONT: FontFile = preload("res://assets/fonts/ValeMini.ttf")
## Espaço extra entre linhas de `Label` (1 px ou mais: sem ele o acento de uma linha encosta na de cima).
const LINE_SPACING := 1
const PANEL_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/panel_a.png")
const CELL_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/inventory_cell.png")
const FOCUS_TEXTURE := preload("res://assets/third_party/ninja-adventure/ui/focus.png")
## Tinta escura do pacote (a cor mais escura da paleta): texto sobre painel e célula.
const INK := Color("#141b1b")
## Margem de fatiamento da textura (os cantos do pacote) e folga interna do conteúdo.
const PANEL_MARGIN := 6
const PANEL_PADDING := 6
const CELL_MARGIN := 3

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = FONT_SIZE
		_theme.default_font = _pixel_font()
		_theme.set_constant("line_spacing", "Label", LINE_SPACING)
		_theme.set_stylebox("panel", "PanelContainer", _nine(PANEL_TEXTURE, PANEL_MARGIN, Color.WHITE, PANEL_PADDING))
		_theme.set_stylebox("normal", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color.WHITE))
		_theme.set_stylebox("hover", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color(1.25, 1.25, 1.25)))
		_theme.set_stylebox("pressed", "Button", _nine(CELL_TEXTURE, CELL_MARGIN, Color(0.75, 0.75, 0.75)))
		_theme.set_stylebox("focus", "Button", _nine(FOCUS_TEXTURE, CELL_MARGIN, Color.WHITE))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(color_name, "Button", INK)
	return _theme


## Painel 9-slice: os cantos e bordas são do pacote; só o miolo estica.
static func _nine(texture: Texture2D, margin: int, tint: Color, padding: int = -1) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, margin if padding < 0 else padding)
	return box


## Cópia da Vale Mini sem suavização, sem hinting e sem posição subpixel.
static func _pixel_font() -> Font:
	var font := FONT.duplicate() as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
