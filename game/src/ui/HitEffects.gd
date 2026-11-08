# SPDX-License-Identifier: MIT
class_name HitEffects
extends Node2D
## Efeito rápido de golpe, só desenho: lascas que saltam e somem, ou o "impacto" de 3 quadros no ponto do golpe.
## Cada efeito é um nó que se apaga sozinho no fim. Pixel inteiro, sem texto.

enum Kind { CHIPS, SPARK }

const CHIP_SIZE := 2.0
const CHIP_LIFE := 0.45
const SPARK_FRAME := 0.05
const SPARK_FRAMES := 3
const GRAVITY := 90.0

var kind: Kind = Kind.CHIPS
var color: Color = Color.WHITE
## Lascas: posição de saída e velocidade de cada uma.
var _chips: Array[Dictionary] = []
var _t: float = 0.0


## Nuvem de lascas (3 a 6 no golpe, mais na queda) saindo de `at`, na cor do material. `rng` é do chamador (semeável).
static func chips(parent: Node, at: Vector2, tint: Color, count: int, rng: SeededRng) -> HitEffects:
	var fx := HitEffects.new()
	fx.kind = Kind.CHIPS
	fx.color = tint
	fx.position = at
	for index in count:
		fx._chips.append({"vel": Vector2(rng.next_range(-26.0, 26.0), rng.next_range(-48.0, -18.0)),
				"from": Vector2(rng.next_below(5) - 2, rng.next_below(5) - 2)})
	parent.add_child(fx)
	fx._run(CHIP_LIFE)
	return fx


## Impacto de 3 quadros (cruz, X, pontinhos) em `at`.
static func spark(parent: Node, at: Vector2, tint: Color) -> HitEffects:
	var fx := HitEffects.new()
	fx.kind = Kind.SPARK
	fx.color = tint
	fx.position = at
	parent.add_child(fx)
	fx._run(SPARK_FRAME * SPARK_FRAMES)
	return fx


func chip_count() -> int:
	return _chips.size()


func _run(life: float) -> void:
	var tween := create_tween()
	tween.tween_method(_advance, 0.0, life, life)
	tween.tween_callback(queue_free)


func _advance(value: float) -> void:
	_t = value
	queue_redraw()


func _draw() -> void:
	if kind == Kind.SPARK:
		_draw_spark(mini(int(_t / SPARK_FRAME), SPARK_FRAMES - 1))
		return
	var fade := clampf((CHIP_LIFE - _t) / (CHIP_LIFE * 0.4), 0.0, 1.0)  # some nos últimos 40%
	for chip in _chips:
		var at: Vector2 = chip["from"] + (chip["vel"] as Vector2) * _t + Vector2(0.0, GRAVITY * _t * _t)
		draw_rect(Rect2(at.round(), Vector2(CHIP_SIZE, CHIP_SIZE)), Color(color, fade))


func _draw_spark(frame: int) -> void:
	var white := Color(1.0, 0.97, 0.8)
	match frame:
		0:  # cruz
			draw_rect(Rect2(-1, -3, 2, 6), white)
			draw_rect(Rect2(-3, -1, 6, 2), white)
		1:  # X maior, na cor do material
			for step in [-3, -2, 2, 3]:
				draw_rect(Rect2(step, step, 1, 1), color)
				draw_rect(Rect2(step, -step, 1, 1), color)
		_:  # pontinhos soltos
			for spot in [Vector2(-4, -2), Vector2(4, -3), Vector2(-3, 3), Vector2(4, 2)]:
				draw_rect(Rect2(spot, Vector2(1, 1)), Color(color, 0.7))
