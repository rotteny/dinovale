# SPDX-License-Identifier: MIT
class_name StatBar
extends HBoxContainer
## Rótulo + barra de progresso. Só apresentação: recebe valores prontos.

## Medidas para o viewport de 320x180: rótulo de 4 letras em 8 px e barra fina.
const LABEL_WIDTH := 20.0
const BAR_SIZE := Vector2(34.0, 5.0)
const ICON_SIZE := Vector2(14.0, 12.0)
const VALUE_WIDTH := 16.0
const OUTLINE_SIZE := 2  # a Vale Mini em 8 px não desenha contorno de 1 px (arredonda para 0)

var _label := Label.new()
var _bar := ProgressBar.new()
var _value_label: Label = null


## Sem texto, a barra vem sem rótulo (versão compacta, ex.: sobre o dino). Com `icon`,
## o ícone ocupa o lugar do rótulo (o texto vira dica).
func _init(label_text: String = "", color: Color = Color.WHITE, bar_size: Vector2 = BAR_SIZE,
		icon: Texture2D = null, icon_size: Vector2 = ICON_SIZE, show_value: bool = false) -> void:
	_label.text = label_text
	_label.custom_minimum_size.x = LABEL_WIDTH
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	add_theme_constant_override("separation", 2)
	_bar.custom_minimum_size = bar_size
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _framed(Color(0.1, 0.1, 0.1, 0.8)))
	_bar.add_theme_stylebox_override("fill", _flat(color))
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = icon_size
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # a caixa é a de ICON_SIZE; o ícone de 15 px não a estica
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED if icon_size == ICON_SIZE else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.tooltip_text = label_text
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon_rect)
		_label.free()
	elif label_text != "":
		add_child(_label)
	else:
		_label.free()  # nó solto não é de ninguém: evita vazar
	add_child(_bar)
	if show_value:  # o número (valor atual) ao lado da barra
		_value_label = Label.new()
		_value_label.add_theme_color_override("font_color", Color.WHITE)
		_value_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_value_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		_value_label.custom_minimum_size.x = VALUE_WIDTH
		add_child(_value_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(current: float, maximum: float) -> void:
	_bar.max_value = maxf(maximum, 1.0)
	_bar.value = current
	if _value_label != null:
		_value_label.text = str(ceili(current))


## O número ao lado da barra (vazio sem `show_value`).
func value_text() -> String:
	return _value_label.text if _value_label != null else ""


func value() -> float:
	return _bar.value


func max_value() -> float:
	return _bar.max_value


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


## Fundo escuro com contorno de 1 px: a barra se lê sobre qualquer terreno sem painel por trás.
func _framed(color: Color) -> StyleBoxFlat:
	var box := _flat(color)
	box.set_border_width_all(1)
	box.border_color = Color.BLACK
	return box
