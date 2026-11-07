# SPDX-License-Identifier: MIT
class_name DinoMarker
extends Node2D
## Marca o dino DOMADO do jogador local, para não se confundir com um selvagem: silhueta de contorno claro em volta
## do sprite (sempre visível) e, acima dele, o nome da espécie, o nível e a barra de vida. O selvagem não ganha
## nada daqui (ele só mostra as barras de doma e de combate, em `DinoStatusBars`). Só apresentação: lê o dino e
## nunca o altera, exceto os irmãos de contorno que ele mesmo pendura no sprite. Instancie FORA do `Dino.tscn`.

## Verde-claro: lê-se sobre campina, mata e pedra, e difere do amarelo do destaque dos recursos.
const OUTLINE_COLOR := Color(0.6, 1.0, 0.75)
const SILHOUETTE: Shader = preload("res://src/ui/silhouette.gdshader")
const BAR_COLOR := Color(0.4, 0.85, 0.45)
const BAR_SIZE := Vector2(30.0, 4.0)
## Posição da placa em relação aos pés do dino: nome e barra logo acima da cabeça (quadro de 32 px, pés em +8).
const LABEL_OFFSET := Vector2(-40.0, -38.0)
const BAR_OFFSET := Vector2(-15.0, -26.0)
const LABEL_WIDTH := 80.0

@export var dino: Dino
## O jogador local: o `player_id` dele pode mudar (mundo novo gera um; o Continuar traz o salvo), então se lê na hora.
@export var viewer: Player
@export var local_player_id: String = Player.LOCAL_PLAYER_ID

var _copies: Array[Sprite2D] = []
var _label := Label.new()
var _bar := StatBar.new("", BAR_COLOR, BAR_SIZE)


func _ready() -> void:
	z_index = 10
	_label.theme = UiTheme.get_theme()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(LABEL_WIDTH, 10.0)
	_label.position = LABEL_OFFSET
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_bar.position = BAR_OFFSET
	add_child(_label)
	add_child(_bar)
	visible = false
	if dino != null:
		dino.health.health_changed.connect(_bar.set_values)
		dino.level_changed.connect(func(_level: int) -> void: _refresh_label())
	_sync()


func _process(_delta: float) -> void:
	_sync()


## O dino é domado e dono é o jogador local, e está vivo?
func is_marked() -> bool:
	return is_instance_valid(dino) and not dino.is_queued_for_deletion() and dino.state_machine.is_tamed \
			and dino.owner_player_id == (viewer.player_id if viewer != null else local_player_id) and not dino.health.is_dead()


func outline_visible() -> bool:
	return not _copies.is_empty() and _copies[0].visible


func plate_text() -> String:
	return _label.text


func _sync() -> void:
	if not is_instance_valid(dino) or dino.is_queued_for_deletion():
		queue_free()
		return
	var marked := is_marked()
	visible = marked
	_set_outline(marked)
	if not marked:
		return
	global_position = dino.global_position
	_refresh_label()
	_bar.set_values(dino.health.current_health, dino.health.max_health)
	_follow_sprite()


func _refresh_label() -> void:
	_label.text = "%s Nv %d" % [dino.stats.display_name, dino.level]


## O contorno é de 4 cópias da silhueta, uma para cada lado, atrás do sprite (filhas dele: giram com ele).
func _set_outline(on: bool) -> void:
	if on and _copies.is_empty():
		var material := ShaderMaterial.new()
		material.shader = SILHOUETTE
		material.set_shader_parameter("tint", OUTLINE_COLOR)
		for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			var copy := Sprite2D.new()
			copy.material = material
			copy.show_behind_parent = true
			copy.position = step
			dino.visual.add_child(copy)
			_copies.append(copy)
	for copy in _copies:
		copy.visible = on


func _follow_sprite() -> void:
	var source := dino.visual
	for copy in _copies:
		copy.texture = source.texture
		copy.hframes = source.hframes
		copy.vframes = source.vframes
		copy.frame_coords = source.frame_coords
		copy.flip_h = source.flip_h
		copy.offset = source.offset
		copy.centered = source.centered


func _exit_tree() -> void:
	for copy in _copies:
		if is_instance_valid(copy):
			copy.queue_free()
