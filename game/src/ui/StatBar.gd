class_name StatBar
extends HBoxContainer
## Rótulo + barra de progresso. Só apresentação: recebe valores prontos.

const LABEL_WIDTH := 44.0
const BAR_SIZE := Vector2(76.0, 8.0)

var _label := Label.new()
var _bar := ProgressBar.new()


func _init(label_text: String = "", color: Color = Color.WHITE) -> void:
	_label.text = label_text
	_label.custom_minimum_size.x = LABEL_WIDTH
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.1, 0.1, 0.8)))
	_bar.add_theme_stylebox_override("fill", _flat(color))
	add_child(_label)
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
