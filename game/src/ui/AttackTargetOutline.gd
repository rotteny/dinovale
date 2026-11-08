# SPDX-License-Identifier: MIT
class_name AttackTargetOutline
extends Node2D
## Contorno de 1 px no dino que o próximo golpe vai atingir (`Player.attack_target`, a mesma escolha que o
## ataque usa). Só apresentação: ouve `attack_target_changed` e pendura 4 cópias da silhueta (uma por lado)
## atrás do sprite do dino-alvo, como `DinoMarker`; nunca decide nem altera o dino além dessas cópias.

## Laranja-avermelhado: lê-se sobre campina e pedra e difere do verde do domado e do amarelo dos recursos.
const OUTLINE_COLOR := Color(1.0, 0.55, 0.35)
const SILHOUETTE: Shader = preload("res://src/ui/silhouette.gdshader")
const STEPS: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

@export var player: Player

var _target: Dino = null
var _copies: Array[Sprite2D] = []


func _ready() -> void:
	if player != null:
		player.attack_target_changed.connect(_set_target)
		_set_target(player.attack_target)


func _process(_delta: float) -> void:
	tick()


## Mantém as cópias no quadro do sprite do alvo (chamável sem esperar frame).
func tick() -> void:
	if _target != null and not is_instance_valid(_target):
		_set_target(null)
	if _target == null:
		return
	var source := _target.visual
	for copy in _copies:
		copy.texture = source.texture
		copy.hframes = source.hframes
		copy.vframes = source.vframes
		copy.frame_coords = source.frame_coords
		copy.flip_h = source.flip_h
		copy.offset = source.offset
		copy.centered = source.centered


## Dino destacado agora (null se nenhum).
func highlighted() -> Dino:
	return _target


func outline_visible() -> bool:
	return _target != null and not _copies.is_empty() and _copies[0].visible


func _set_target(dino: Dino) -> void:
	_clear()
	_target = dino if is_instance_valid(dino) else null
	if _target == null:
		return
	var material := ShaderMaterial.new()
	material.shader = SILHOUETTE
	material.set_shader_parameter("tint", OUTLINE_COLOR)
	for step in STEPS:
		var copy := Sprite2D.new()
		copy.material = material
		copy.show_behind_parent = true
		copy.position = step
		_target.visual.add_child(copy)
		_copies.append(copy)
	tick()


func _clear() -> void:
	for copy in _copies:
		if is_instance_valid(copy):
			copy.queue_free()
	_copies.clear()


func _exit_tree() -> void:
	_clear()
