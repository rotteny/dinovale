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
## Variação de tema dos botões de menu (título, pausa, morte, configurações); o `Button` comum (inventário) não muda.
const MENU_BUTTON := &"MenuItemButton"
## Arte dos botões de menu (`assets/ui/menu/botao_*.png`, `botoes.json`): um 9-slice por estado, textura de 24x20,
## margens esquerda/direita/base 6 e topo 5, miolo liso (estica sem borrar), filtro nearest. Altura mínima 20.
const MENU_BUTTON_TEXTURES := {
	"normal": preload("res://assets/ui/menu/botao_normal.png"),
	"hover": preload("res://assets/ui/menu/botao_hover.png"),
	"pressed": preload("res://assets/ui/menu/botao_pressed.png"),
	"disabled": preload("res://assets/ui/menu/botao_disabled.png"),
}
## Folga do texto acima e abaixo, por estado (de `botoes.json`, `content_margin_sugerida`): o botão tem um degrau de 3 px
## embaixo, e o pressionado "afunda" 2 px, então o texto desce junto.
const MENU_BUTTON_TEXT_MARGINS := {
	"normal": Vector2i(0, 3), "hover": Vector2i(0, 3), "pressed": Vector2i(2, 1), "disabled": Vector2i(0, 3),
}
## Sombra do texto (1 px abaixo), a do estado normal.
const MENU_BUTTON_SHADOW := Color("#965340")
const MENU_BUTTON_STATES := ["normal", "hover", "pressed", "disabled"]
const MENU_BUTTON_MARGINS := {SIDE_LEFT: 6, SIDE_RIGHT: 6, SIDE_TOP: 5, SIDE_BOTTOM: 6}
## Paleta provisória dos botões (a mesma da arte: madeira e creme).
const BUTTON_FILL := {"normal": Color("#965340"), "hover": Color("#b3664f"), "pressed": Color("#4e484a"), "disabled": Color("#b3957f")}
const BUTTON_TEXT := {"normal": Color("#fce2ca"), "hover": Color.WHITE, "pressed": Color("#fce2ca"), "disabled": Color("#4e484a")}
const FOCUS_RING := Color("#fce2ca")

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
		_add_menu_button(_theme)
	return _theme


## Variação `MenuItemButton`: StyleBox por estado (provisório, ou 9-slice se `MENU_BUTTON_TEXTURES` o tiver) e anel de foco.
static func _add_menu_button(theme: Theme) -> void:
	theme.set_type_variation(MENU_BUTTON, &"Button")
	for state in MENU_BUTTON_STATES:
		theme.set_stylebox(state, MENU_BUTTON, menu_button_box(state))
		var color: Color = BUTTON_TEXT[state]
		var key := "font_color" if state == "normal" else "font_%s_color" % state
		theme.set_color(key, MENU_BUTTON, color)
	theme.set_color("font_focus_color", MENU_BUTTON, BUTTON_TEXT["normal"])
	theme.set_color("font_hover_pressed_color", MENU_BUTTON, BUTTON_TEXT["pressed"])
	theme.set_color("font_shadow_color", MENU_BUTTON, MENU_BUTTON_SHADOW)
	theme.set_constant("shadow_offset_x", MENU_BUTTON, 0)
	theme.set_constant("shadow_offset_y", MENU_BUTTON, 1)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(1)
	ring.border_color = FOCUS_RING
	theme.set_stylebox("focus", MENU_BUTTON, ring)


## StyleBox de um estado do botão de menu: 9-slice se a arte final foi configurada, senão caixa lisa na paleta.
static func menu_button_box(state: String) -> StyleBox:
	if MENU_BUTTON_TEXTURES.has(state):
		var box := StyleBoxTexture.new()
		box.texture = MENU_BUTTON_TEXTURES[state] as Texture2D
		for side in MENU_BUTTON_MARGINS:
			box.set_texture_margin(side, MENU_BUTTON_MARGINS[side])
			box.set_content_margin(side, MENU_BUTTON_MARGINS[side] - 3)
		var text_margins: Vector2i = MENU_BUTTON_TEXT_MARGINS[state]
		box.set_content_margin(SIDE_TOP, text_margins.x)
		box.set_content_margin(SIDE_BOTTOM, text_margins.y)
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		return box
	var flat := StyleBoxFlat.new()
	flat.bg_color = BUTTON_FILL[state]
	flat.set_border_width_all(1)
	flat.border_color = INK
	flat.set_content_margin_all(2)
	return flat


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
