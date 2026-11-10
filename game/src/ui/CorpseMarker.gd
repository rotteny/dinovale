# SPDX-License-Identifier: MIT
class_name CorpseMarker
extends Control
## Marcador do corpo na borda da tela (E12, SOB-13): uma seta amarela na borda, apontando para cada corpo do jogador local que
## está fora da vista (até o limite de corpos por jogador). Só apresentação: lê o `CorpseField` e a câmera, não decide nada. Vive
## no `CanvasLayer` da interface (coordenadas de tela) e ignora o mouse.

const MARGIN := 8.0
const ARROW_SIZE := 5.0
const COLOR := Color("#ffe27a")
const OUTLINE := Color(0.1, 0.05, 0.05, 0.9)

@export var corpses: CorpseField
@export var viewer: Player

var _markers: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20


func _process(_delta: float) -> void:
	refresh()


## Recalcula onde ficam as setas agora e redesenha se mudou.
func refresh() -> void:
	var before := _markers
	_markers = markers(get_viewport_rect().size, get_viewport().get_canvas_transform())
	if _markers != before:
		queue_redraw()


## As setas do instante: `{position, angle}` de cada corpo do jogador fora da tela. `world_to_screen` é a transformação do canvas do
## mundo (a câmera). Sem campo ou jogador, nenhuma.
func markers(view_size: Vector2, world_to_screen: Transform2D) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if corpses == null or viewer == null or not is_instance_valid(corpses):
		return list
	for corpse in corpses.corpses():
		if corpse.owner_player_id != viewer.player_id:
			continue
		var placed := EdgeMarker.place(world_to_screen * corpse.global_position, view_size, MARGIN)
		if bool(placed["visible"]):
			list.append({"position": placed["position"], "angle": placed["angle"]})
	return list


func _draw() -> void:
	for marker in _markers:
		var at: Vector2 = marker["position"]
		var angle: float = marker["angle"]
		var points := PackedVector2Array([
			at + Vector2(ARROW_SIZE, 0.0).rotated(angle),
			at + Vector2(-ARROW_SIZE, ARROW_SIZE * 0.8).rotated(angle),
			at + Vector2(-ARROW_SIZE * 0.5, 0.0).rotated(angle),
			at + Vector2(-ARROW_SIZE, -ARROW_SIZE * 0.8).rotated(angle)])
		draw_colored_polygon(points, COLOR)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), OUTLINE, 1.0)
