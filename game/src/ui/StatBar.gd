# SPDX-License-Identifier: MIT
class_name StatBar
extends HBoxContainer
## Rótulo + barra de progresso. Só apresentação: recebe valores prontos.

const LABEL_WIDTH := 44.0
const BAR_SIZE := Vector2(76.0, 8.0)
const ICON_SIZE := Vector2(18.0, 16.0)

var _label := Label.new()
var _bar := ProgressBar.new()


## Sem texto, a barra vem sem rótulo (versão compacta, ex.: sobre o dino). Com `icon`,
## o ícone ocupa o lugar do rótulo (o texto vira dica).
func _init(label_text: String = "", color: Color = Color.WHITE, bar_size: Vector2 = BAR_SIZE,
		icon: Texture2D = null) -> void:
	_label.text = label_text
	_label.custom_minimum_size.x = LABEL_WIDTH
	_bar.custom_minimum_size = bar_size
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.1, 0.1, 0.8)))
	_bar.add_theme_stylebox_override("fill", _flat(color))
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_rect.tooltip_text = label_text
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon_rect)
		_label.free()
	elif label_text != "":
		add_child(_label)
	else:
		_label.free()  # nó solto não é de ninguém: evita vazar
	add_child(_bar)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(current: float, maximum: float) -> void:
	_bar.max_value = maxf(maximum, 1.0)
	_bar.value = current


func value() -> float:
	return _bar.value


func max_value() -> float:
	return _bar.max_value


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box
