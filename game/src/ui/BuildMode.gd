# SPDX-License-Identifier: MIT
class_name BuildMode
extends Node2D
## Modo construção (E8a, CON-03), tecla B: o ghost da peça escolhida segue o mouse na célula (verde = a autoridade aceitaria,
## vermelho = recusaria), R gira, clique esquerdo constrói, direito remove, T abre e fecha a porta mais próxima. SÓ observa:
## pergunta `BuildService.problem` (o mesmo teste do pedido) para pintar o ghost, e o que o jogador quer sai por sinal
## (`build_requested`, `remove_requested`, `door_requested`); a `Main` o transforma em `request_*` e a autoridade decide.
## As ações são criadas por código, sem mexer no `project.godot`.

signal build_requested(piece_id: String, cell: Vector2i, rotation: int)
signal remove_requested(cell: Vector2i)
signal door_requested(cell: Vector2i)
signal mode_changed(active: bool)
signal selection_changed(piece_id: String)

const TOGGLE_MODE := &"build_mode"
const ROTATE := &"build_rotate"
const TOGGLE_DOOR := &"build_door"
const OK_COLOR := Color(0.35, 0.9, 0.35, 0.6)
const NO_COLOR := Color(0.95, 0.25, 0.25, 0.6)
## "Nenhuma porta" (`door_near`): célula que nenhum mapa tem.
const NO_CELL := Vector2i(-2147483648, -2147483648)

var authority: WorldAuthority = null
var player: Player = null
var menu: BuildMenu = null

var active: bool = false
var selected: String = ""
var rotation_steps: int = 0
## Ponto do mundo sob o mouse. Em jogo vem do viewport a cada quadro; um teste o define direto.
var mouse_world: Vector2 = Vector2.ZERO
var follow_mouse: bool = true

var _ghost_ok: bool = false


static func ensure_actions() -> void:
	for entry: Array in [[TOGGLE_MODE, KEY_B], [ROTATE, KEY_R], [TOGGLE_DOOR, KEY_T]]:
		if InputMap.has_action(entry[0]):
			continue
		InputMap.add_action(entry[0])
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0], event)


func _ready() -> void:
	z_index = 10
	if menu != null:
		menu.piece_chosen.connect(select)


func _unhandled_input(event: InputEvent) -> void:
	ensure_actions()
	if event.is_action_pressed(TOGGLE_MODE):
		set_active(not active)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(TOGGLE_DOOR) and player != null and not player.is_incapacitated():
		var door := door_near(mouse_world if active else player.global_position)
		if door != NO_CELL:
			door_requested.emit(door)
		get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed(ROTATE):
		rotate_ghost()
		get_viewport().set_input_as_handled()


## Clique do mouse com o modo ligado (antes do controlador do jogador, que o trataria como golpe). Sobre a UI não faz nada.
func _input(event: InputEvent) -> void:
	if not active or not (event is InputEventMouseButton) or not event.pressed:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	if click((event as InputEventMouseButton).button_index, mouse_world):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not active:
		return
	if follow_mouse:
		mouse_world = get_global_mouse_position()
	_ghost_ok = selected != "" and _ghost_problem() == Enums.ActionResult.OK
	queue_redraw()


func set_active(on: bool) -> void:
	if on and (player == null or player.is_incapacitated()):
		on = false
	if on == active:
		return
	active = on
	if menu != null:
		menu.visible = on
		menu.refresh(true)
	if not on:
		queue_redraw()
	mode_changed.emit(on)


## Escolhe a peça (id do catálogo; "" = nenhuma). Peça desconhecida é ignorada.
func select(piece_id: String) -> void:
	if piece_id != "" and (authority == null or authority.build.grid.catalog.find(piece_id) == null):
		return
	selected = "" if piece_id == selected else piece_id  # escolher a mesma de novo desliga
	if menu != null:
		menu.show_selected(selected)
	selection_changed.emit(selected)


func rotate_ghost() -> void:
	rotation_steps = (rotation_steps + 1) % 4
	queue_redraw()


## A célula sob o ponto do mundo.
func cell_at(point: Vector2) -> Vector2i:
	return authority.build.cell_of(point)


## Clique no mundo: esquerdo constrói a peça escolhida na célula do ponto (ou abre a porta que estiver ali e nenhuma peça
## está escolhida); direito remove a peça da célula. Só emite o pedido. Devolve se tratou o clique.
func click(button: int, world_point: Vector2) -> bool:
	if not active or authority == null or player == null:
		return false
	var cell := cell_at(world_point)
	if button == MOUSE_BUTTON_LEFT:
		if selected != "":
			build_requested.emit(selected, cell, rotation_steps)
		elif authority.build.grid.def_at(cell) != null and authority.build.grid.def_at(cell).toggleable:
			door_requested.emit(cell)
		else:
			return false
		return true
	if button == MOUSE_BUTTON_RIGHT:
		if not authority.build.grid.has_piece(cell):
			return false
		remove_requested.emit(cell)
		return true
	return false


## A porta mais próxima de `point` dentro do alcance de porta do jogador (a partir dele), ou `NO_CELL`.
func door_near(point: Vector2) -> Vector2i:
	var service := authority.build
	var center := service.cell_of(player.global_position)
	var span := ceili(service.rules.door_reach_tiles) + 1
	var best := NO_CELL
	var best_distance := INF
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := center + Vector2i(dx, dy)
			var def := service.grid.def_at(cell)
			if def == null or not def.toggleable:
				continue
			if player.global_position.distance_to(service.center_of(cell)) > service.rules.door_reach_tiles * service.rules.tile_px:
				continue
			var distance := point.distance_to(service.center_of(cell))
			if distance < best_distance:
				best = cell
				best_distance = distance
	return best


## A cor que o ghost tem agora (verde = serve): o que `_draw` usa.
func ghost_color() -> Color:
	return OK_COLOR if _ghost_ok else NO_COLOR


func _ghost_problem() -> Enums.ActionResult:
	var outcome := authority.build.problem(authority.id_of(player), selected, cell_at(mouse_world), rotation_steps)
	return outcome["result"] as Enums.ActionResult


func _draw() -> void:
	if not active or authority == null or selected == "":
		return
	var tile := authority.build.rules.tile_px
	var cell := cell_at(mouse_world)
	var center := authority.build.center_of(cell)
	var texture := BuildPieceView.texture_for(selected)
	draw_set_transform(center, float(rotation_steps) * PI * 0.5, Vector2.ONE)
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2(-tile, -tile) * 0.5, Vector2(tile, tile)), false, ghost_color())
	draw_rect(Rect2(Vector2(-tile, -tile) * 0.5, Vector2(tile, tile)), ghost_color(), false, 1.0)
