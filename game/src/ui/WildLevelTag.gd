# SPDX-License-Identifier: MIT
class_name WildLevelTag
extends Node2D
## "Nv N" pequeno e cinza (e o símbolo de sexo, `SexIcon`) sobre o dino SELVAGEM, só quando o jogador está perto
## (alcance em `DinoLevelRules`).
## Vale para o vivo e acordado; o desmaiado não mostra (as barras de doma já trazem "Nv 11 -> 17"), nem o morto
## nem o domado (que tem a placa de `DinoMarker`). Sem silhueta, nome nem vida, para não se confundir com essa placa. Só
## apresentação: lê o dino e o jogador e nunca os altera. Instancie FORA do `Dino.tscn`.

const TEXT_COLOR := Color(0.78, 0.82, 0.8)
const OUTLINE_COLOR := Color(0.08, 0.1, 0.1)
## Logo acima da cabeça (quadro de 32 px, pés em +8).
const LABEL_OFFSET := Vector2(-20.0, -38.0)
const LABEL_WIDTH := 40.0

@export var dino: Dino
## Quem olha: a distância é medida até ele.
@export var viewer: Node2D
@export var rules: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
@export var aggression_rules: AggressionRules = preload("res://data/balance/aggression_rules.tres")

var _label := Label.new()
var _sex_icon := Sprite2D.new()
var _alert_fade := AggressionFade.new()


func _ready() -> void:
	z_index = 10
	_label.theme = UiTheme.get_theme()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(LABEL_WIDTH, 10.0)
	_label.position = LABEL_OFFSET
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)
	add_child(_sex_icon)
	visible = false
	tick()


func _process(delta: float) -> void:
	tick(delta)


## Atualiza posição, texto, cor e visibilidade (público para testar sem quadros). `delta` move o fade do vermelho.
func tick(delta: float = 0.0) -> void:
	if not is_instance_valid(dino) or dino.is_queued_for_deletion():
		visible = false
		queue_free()
		return
	global_position = dino.global_position
	visible = should_show()
	var alpha := _alert_fade.step(delta, dino.state_machine.is_aggressive, aggression_rules)
	_label.add_theme_color_override("font_color", TEXT_COLOR.lerp(aggression_rules.alert_color, alpha))
	if visible:
		_label.text = "Nv %d" % dino.level
		SexIcon.place(_sex_icon, _label, dino.sex)


## Selvagem vivo e dentro do alcance do jogador?
func should_show() -> bool:
	if not is_instance_valid(dino) or not is_instance_valid(viewer):
		return false
	if dino.state_machine.is_tamed or dino.health.is_dead() or dino.torpor.is_unconscious:
		return false
	return dino.global_position.distance_to(viewer.global_position) <= rules.level_tag_range()


func tag_visible() -> bool:
	return visible


## Cor atual do "Nv" (avermelhada enquanto o dino está bravo).
func tag_color() -> Color:
	return _label.get_theme_color("font_color")


func tag_text() -> String:
	return _label.text


## O símbolo de sexo ao lado do texto está visível?
func sex_icon_visible() -> bool:
	return visible and _sex_icon.visible


func sex_icon_texture() -> Texture2D:
	return _sex_icon.texture
