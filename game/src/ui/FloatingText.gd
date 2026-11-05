# SPDX-License-Identifier: MIT
class_name FloatingText
extends RefCounted
## Número flutuante (dano, nível): sobe e some. Só apresentação.

const RISE := 12.0
const SECONDS := 0.9


## Cria o texto em `host` (um nó 2D) na posição local `start` e o remove ao fim.
static func spawn(host: Node2D, text: String, color: Color, start: Vector2, rise: float = RISE,
		seconds: float = SECONDS) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = start
	host.add_child(label)
	var tween := host.create_tween().set_parallel()
	tween.tween_property(label, "position:y", start.y - rise, seconds)
	tween.tween_property(label, "modulate:a", 0.0, seconds)
	tween.chain().tween_callback(label.queue_free)


## Texto de dano: "-5" (sem casa decimal inútil).
static func damage_text(amount: float) -> String:
	return "-" + String.num(snappedf(amount, 0.1)).trim_suffix(".0")
