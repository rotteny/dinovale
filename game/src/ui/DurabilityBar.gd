# SPDX-License-Identifier: MIT
class_name DurabilityBar
extends Control
## Barra fina de durabilidade na base de uma célula (inventário, vaga de equipamento, atalho): verde, depois amarela,
## depois vermelha. Só aparece em item individual com `durab_max > 0`. Só apresentação: recebe valores prontos.

const HEIGHT := 2.0
const BACK_COLOR := Color(0.0, 0.0, 0.0, 0.8)
const GOOD_COLOR := Color("#5fd35f")
const WARN_COLOR := Color("#f0d24a")
const BAD_COLOR := Color("#e04848")
## Limiares da fração restante: acima de HALF verde, acima de QUARTER amarelo, senão vermelho.
const HALF := 0.5
const QUARTER := 0.25

var _ratio := 0.0


func _init() -> void:
	name = "Durab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	offset_left = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	visible = false


## Põe a barra na célula `cell` e a devolve.
static func attach(cell: Control) -> DurabilityBar:
	var bar := DurabilityBar.new()
	cell.add_child(bar)
	return bar


## Cor para a fração restante.
static func color_for(ratio: float) -> Color:
	if ratio > HALF:
		return GOOD_COLOR
	return WARN_COLOR if ratio > QUARTER else BAD_COLOR


## Mostra a durabilidade do item (`{durab, durab_max}`); sem durabilidade (pilha, vazio) a barra some.
func show_item(item: Dictionary) -> void:
	var maximum := int(item.get("durab_max", 0))
	visible = maximum > 0 and item.has("durab")
	_ratio = clampf(float(item.get("durab", 0)) / float(maxi(maximum, 1)), 0.0, 1.0) if visible else 0.0
	queue_redraw()


func ratio() -> float:
	return _ratio


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)), color_for(_ratio))
