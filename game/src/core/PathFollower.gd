# SPDX-License-Identifier: MIT
class_name PathFollower
extends RefCounted
## Segue um destino pelo `PathProvider` e percebe quando trava (M1, seção 1). Lógica pura: recebe a posição e o destino
## a cada `update` e devolve a direção; o corpo continua colidindo de verdade, o caminho só guia.
##
## Replaneja a cada `repath_interval_s` (só se o alvo andou), na hora se um `invalidate` toca o caminho e quando trava.
## Linha do tempo sem progresso (`NavigationRules`): 1 s replaneja e bloqueia 5 s a célula à frente; 2 s replaneja com
## folga +1; 3 s, `stuck`. Pedido sem caminho: tenta de novo 1 s depois e a segunda falha também é `stuck`.
## Sem provedor (teste de máquina, corpo sem mundo), anda em linha reta e não mede travada: quem mede é o mundo.

var provider: PathProvider = null:
	set(value):
		if provider != null and provider.cell_invalidated.is_connected(_on_cell_invalidated):
			provider.cell_invalidated.disconnect(_on_cell_invalidated)
		provider = value
		if provider != null:
			provider.cell_invalidated.connect(_on_cell_invalidated)
		_path = null
var rules: NavigationRules = preload("res://data/balance/navigation_rules.tres")
var size_class: Enums.DinoSize = Enums.DinoSize.MEDIUM
## Travou sem solução: quem chama decide (desiste, tenta de novo). `clear_stuck` ou `forget` limpam.
var stuck: bool = false
## Contadores para teste e diagnóstico.
var replans: int = 0
var requests: int = 0

var _path: PathResult = null
var _index: int = 0
var _planned_goal: Vector2i = Vector2i.ZERO
var _direct: bool = false
var _repath_in: float = 0.0
var _force_replan: bool = true
var _retry_wait: float = 0.0
var _no_path_failures: int = 0
var _extra_clearance: int = 0
var _stall_windows: int = 0
var _window_time: float = 0.0
var _window_progress: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _has_last: bool = false
var _last_direction: Vector2 = Vector2.ZERO


## Esquece tudo (caminho, travada, medição): o destino mudou de natureza ou o corpo foi reposto.
func forget() -> void:
	stuck = false
	_path = null
	_index = 0
	_direct = false
	_repath_in = 0.0
	_force_replan = true
	_retry_wait = 0.0
	_no_path_failures = 0
	_extra_clearance = 0
	_restart_measure()
	_has_last = false
	_last_direction = Vector2.ZERO


## Sai do estado preso e recomeça a linha do tempo do zero (o domado visível segue tentando, sem desistir).
func clear_stuck() -> void:
	forget()


## Células do caminho atual (vazio se anda em linha reta ou ainda não planejou). Para teste e diagnóstico.
func current_path() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _path != null:
		cells.append_array(_path.cells)
	return cells


## Uma volta: devolve a direção (comprimento 1, ou zero se parado) para ir de `at` até `goal`.
func update(delta: float, at: Vector2, goal: Vector2) -> Vector2:
	if stuck:
		return Vector2.ZERO
	_measure(delta, at)
	if stuck:
		_last_direction = Vector2.ZERO
		return Vector2.ZERO
	var direction := _steer(delta, at, goal)
	_last_direction = direction
	_last_position = at
	_has_last = true
	return direction


func _steer(delta: float, at: Vector2, goal: Vector2) -> Vector2:
	if provider == null:
		return _toward(at, goal)
	var from := provider.cell_of(at)
	var to := provider.cell_of(goal)
	if _retry_wait > 0.0:
		_retry_wait -= delta
		if _retry_wait > 0.0:
			return Vector2.ZERO
		_force_replan = true
	_repath_in -= delta
	if _force_replan or _repath_in <= 0.0:
		_replan(from, to)
		if stuck or _retry_wait > 0.0:
			return Vector2.ZERO
	if _direct or _path == null:
		return _toward(at, goal)
	while _index < _path.cells.size() and at.distance_to(provider.center_of(_path.cells[_index])) <= rules.waypoint_reach_px:
		_index += 1
	if _index >= _path.cells.size():
		return _toward(at, goal)  # fim do caminho: o resto é até o ponto exato
	return _toward(at, provider.center_of(_path.cells[_index]))


func _replan(from: Vector2i, to: Vector2i) -> void:
	var goal_moved := Vector2(to - _planned_goal).length() > rules.repath_target_moved_tiles
	if not _force_replan and _path != null and not _direct and not goal_moved:
		_repath_in = rules.repath_interval_s
		return
	_force_replan = false
	_repath_in = rules.repath_interval_s
	if provider.has_line(from, to, size_class, _extra_clearance):
		_path = null
		_direct = true
		_planned_goal = to
		_no_path_failures = 0
		return
	_direct = false
	var result := provider.request_path(from, to, size_class, _extra_clearance)
	requests += 1
	match result.status:
		PathResult.Status.OK:
			replans += 1
			_path = result
			_index = 0
			_planned_goal = to
			_no_path_failures = 0
		PathResult.Status.TOO_FAR:
			_path = null
			_direct = true  # longe demais para pedir: anda em linha reta até a distância cair
			_planned_goal = to
		PathResult.Status.DEFERRED:
			_repath_in = 0.0  # o teto do quadro estourou: pergunta de novo no próximo
			_force_replan = true
		_:
			_path = null
			_no_path_failures += 1
			if _no_path_failures >= 2:
				stuck = true
			else:
				_retry_wait = rules.no_path_retry_s


## Mede o avanço na direção em que mandou andar. Parado de propósito (sem direção) não conta como travado.
func _measure(delta: float, at: Vector2) -> void:
	if provider == null or not _has_last or _last_direction == Vector2.ZERO:
		_restart_measure()
		return
	_window_progress += maxf((at - _last_position).dot(_last_direction), 0.0)
	_window_time += delta
	if _window_time < rules.stuck_check_seconds:
		return
	if _window_progress >= rules.stuck_min_progress_px:
		_stall_windows = 0
		_extra_clearance = 0
	else:
		_stall_windows += 1
		_on_stall(at)
	_window_time = 0.0
	_window_progress = 0.0


func _on_stall(at: Vector2) -> void:
	if float(_stall_windows) * rules.stuck_check_seconds >= rules.stuck_give_up_seconds:
		stuck = true
		return
	_force_replan = true
	if _stall_windows == 1 and provider != null:
		var ahead := provider.cell_of(at + _last_direction * float(rules.tile_px))
		if ahead != provider.cell_of(at):
			provider.block_temporarily(ahead, rules.blocked_cell_seconds)
	elif _stall_windows >= 2:
		_extra_clearance = 1


func _restart_measure() -> void:
	_stall_windows = 0
	_window_time = 0.0
	_window_progress = 0.0


## Célula bloqueada: replaneja se o caminho passa por ela (ou pela folga em volta). Célula liberada (nó caiu, bloqueio
## temporário acabou): quem anda por um caminho replaneja, porque pode haver um atalho que o caminho velho não tinha.
func _on_cell_invalidated(cell: Vector2i) -> void:
	if _path == null:
		return
	if provider.is_blocked(cell):
		if _path.touches(cell, rules.clearance_of(size_class, _extra_clearance)):
			_force_replan = true
	else:
		_force_replan = true


func _toward(at: Vector2, point: Vector2) -> Vector2:
	var offset := point - at
	return offset.normalized() if offset.length() > 0.5 else Vector2.ZERO
