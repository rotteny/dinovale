# SPDX-License-Identifier: MIT
class_name UiTheme
extends RefCounted
## Tema único da UI: fonte padrão da engine em tamanho legível em 640x360.
## Cada raiz de UI (HUD, tela de inventário) aplica o mesmo tema.

const FONT_SIZE := 10

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = FONT_SIZE
	return _theme
