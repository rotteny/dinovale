# SPDX-License-Identifier: MIT
class_name GridPathProvider
extends PathProvider
## Navegação por grade com o A* nativo (`AStarGrid2D`). A grade do mapa (256x256) bloqueia água funda, árvore e rocha
## que ainda existem e cenário sólido. Há uma grade de busca por valor de folga (0, 1, 2 e, sob pedido, 3): a célula
## fica sólida se há bloqueio a até `folga` tiles dela. Movimento em 8 direções, sem cortar quina, heurística octogonal.
##
## Bloqueios que mudam (nó que cai ou renasce) entram por `add_obstacle`/`remove_obstacle`: só as células tocadas
## são refeitas e cada uma emite `cell_invalidated`. Nunca se recalcula o mapa inteiro.

## Lado da grade, em células, e bloqueio fixo (terreno), 1 por célula bloqueada.
var size: int = 0
## Contadores para teste e diagnóstico.
var requests_total: int = 0
var peak_requests_in_frame: int = 0
var deferred_total: int = 0

var _static_blocked: PackedByteArray = PackedByteArray()
## Quantos obstáculos móveis cobrem cada célula (árvore, rocha, cenário, bloqueio temporário).
var _obstacles: PackedInt32Array = PackedInt32Array()
var _grids: Dictionary = {}  # folga -> AStarGrid2D
var _temporary: Array[Dictionary] = []  # {cell, until}
var _time: float = 0.0
var _requests_this_frame: int = 0
var _bulk: bool = false


## Grade `side` x `side`, com `blocked` (1 = bloqueada, tamanho `side * side`). Não monta as grades de busca: elas nascem
## no `end_bulk` (carga) ou, se ninguém abriu carga, no primeiro pedido.
func setup(side: int, blocked: PackedByteArray) -> void:
	size = side
	_static_blocked = blocked.duplicate()
	_static_blocked.resize(side * side)
	_obstacles = PackedInt32Array()
	_obstacles.resize(side * side)
	_grids.clear()


## Terreno e cenário do mapa. Os nós de recurso entram depois, um a um, por `add_obstacle`. Com `finish_load` falso a
## carga em massa continua aberta (quem chama soma mais obstáculos e fecha com `end_bulk`, uma vez só).
static func from_map(map: IslandMap, world_rules: WorldRules, nav_rules: NavigationRules,
		finish_load: bool = true) -> GridPathProvider:
	var provider := GridPathProvider.new()
	provider.rules = nav_rules
	var blocked := PackedByteArray()
	blocked.resize(map.size * map.size)
	for y in map.size:
		for x in map.size:
			if not map.is_walkable(Vector2i(x, y)):
				blocked[y * map.size + x] = 1
	provider.size = map.size
	provider.setup(map.size, blocked)
	provider.begin_bulk()
	for def in world_rules.scenery:
		var cells: Array = map.scenery.get(def.id, [])
		for cell: Vector2i in cells:
			provider.add_obstacle(obstacle_rect(def.foot_size, map.center_of(cell)))
	if finish_load:
		provider.end_bulk()
	return provider


## Retângulo dos pés de algo cuja origem (os pés) está em `feet`: a caixa fica apoiada na origem.
static func obstacle_rect(foot_size: Vector2, feet: Vector2) -> Rect2:
	return Rect2(feet.x - foot_size.x * 0.5, feet.y - foot_size.y, foot_size.x, foot_size.y)


## Carga em massa (o mapa inteiro de uma vez): as mudanças só contam e as grades são refeitas uma vez no `end_bulk`.
func begin_bulk() -> void:
	_bulk = true


func end_bulk() -> void:
	_bulk = false
	_build_grids()


## Monta todas as grades de busca na carga: a de cada porte e a de folga +1 (o replanejamento de 2 s), para nenhuma
## nascer no meio do jogo.
func _build_grids() -> void:
	_grids.clear()
	for porte: Enums.DinoSize in [Enums.DinoSize.SMALL, Enums.DinoSize.MEDIUM, Enums.DinoSize.LARGE]:
		_grid_for(rules.clearance_of(porte))
		_grid_for(rules.clearance_of(porte, 1))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


## A célula está bloqueada por terreno ou obstáculo (sem folga)?
func is_blocked(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	var index := cell.y * size + cell.x
	return _static_blocked[index] != 0 or _obstacles[index] > 0


## A célula é sólida para o porte (há bloqueio a até a folga dele)?
func is_solid(cell: Vector2i, size_class: Enums.DinoSize, extra_clearance: int = 0) -> bool:
	return in_bounds(cell) and _grid_for(rules.clearance_of(size_class, extra_clearance)).is_point_solid(cell)


## Cobre as células tocadas pelo retângulo (em pixels do mundo). Cada célula que passa de livre a bloqueada emite `cell_invalidated`.
func add_obstacle(rect: Rect2) -> void:
	for cell in _cells_of(rect):
		_change(cell, 1)


## Desfaz um `add_obstacle` do mesmo retângulo.
func remove_obstacle(rect: Rect2) -> void:
	for cell in _cells_of(rect):
		_change(cell, -1)


func block_temporarily(cell: Vector2i, seconds: float) -> void:
	if not in_bounds(cell):
		return
	_temporary.append({"cell": cell, "until": _time + seconds})
	_change(cell, 1)


func begin_frame(delta: float) -> void:
	_time += delta
	_requests_this_frame = 0
	var index := 0
	while index < _temporary.size():
		if float(_temporary[index]["until"]) <= _time:
			_change(_temporary[index]["cell"] as Vector2i, -1)
			_temporary.remove_at(index)
		else:
			index += 1


func request_path(from: Vector2i, to: Vector2i, size_class: Enums.DinoSize, extra_clearance: int = 0) -> PathResult:
	var result := PathResult.new()
	if not in_bounds(from) or not in_bounds(to):
		return result
	if maxi(absi(to.x - from.x), absi(to.y - from.y)) > rules.max_request_tiles:
		result.status = PathResult.Status.TOO_FAR
		return result
	if _requests_this_frame >= rules.max_requests_per_frame:
		result.status = PathResult.Status.DEFERRED
		deferred_total += 1
		return result
	_requests_this_frame += 1
	requests_total += 1
	peak_requests_in_frame = maxi(peak_requests_in_frame, _requests_this_frame)
	var grid := _grid_for(rules.clearance_of(size_class, extra_clearance))
	# Quem está colado num obstáculo (ou o alvo que está) cai numa célula sólida da folga: troca pela livre mais próxima.
	var start := _nearest_open(grid, from)
	var goal := _nearest_open(grid, to)
	if not in_bounds(start) or not in_bounds(goal):
		return result
	var path: Array[Vector2i] = grid.get_id_path(start, goal)
	if path.is_empty():
		return result
	result.status = PathResult.Status.OK
	result.goal_cell = goal
	path.remove_at(0)
	if start != from:
		path.insert(0, start)
	result.cells = path
	return result


func has_line(from: Vector2i, to: Vector2i, size_class: Enums.DinoSize, extra_clearance: int = 0) -> bool:
	if not in_bounds(from) or not in_bounds(to):
		return false
	var grid := _grid_for(rules.clearance_of(size_class, extra_clearance))
	if grid.is_point_solid(from) or grid.is_point_solid(to):
		return false
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	var previous := from
	for step in range(1, steps + 1):
		var cell := from + Vector2i((Vector2(delta) * float(step) / float(steps)).round())
		if grid.is_point_solid(cell):
			return false
		# Passo na diagonal: as duas células ortogonais também precisam estar livres (sem cortar quina).
		if cell.x != previous.x and cell.y != previous.y \
				and (grid.is_point_solid(Vector2i(cell.x, previous.y)) or grid.is_point_solid(Vector2i(previous.x, cell.y))):
			return false
		previous = cell
	return true


func _nearest_open(grid: AStarGrid2D, cell: Vector2i, max_radius: int = 3) -> Vector2i:
	if not in_bounds(cell):
		return Vector2i(-1, -1)
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if in_bounds(candidate) and not grid.is_point_solid(candidate) and float(dx * dx + dy * dy) < best_distance:
					best = candidate
					best_distance = float(dx * dx + dy * dy)
		if in_bounds(best):
			return best
	return Vector2i(-1, -1)


## Células com sobreposição de área positiva com o retângulo (em pixels).
func _cells_of(rect: Rect2) -> Array[Vector2i]:
	var tile := float(rules.tile_px)
	var first_x := floori(rect.position.x / tile)
	var first_y := floori(rect.position.y / tile)
	var last_x := ceili(rect.end.x / tile - 0.0001) - 1
	var last_y := ceili(rect.end.y / tile - 0.0001) - 1
	var cells: Array[Vector2i] = []
	for y in range(first_y, last_y + 1):
		for x in range(first_x, last_x + 1):
			if in_bounds(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


## Soma `step` à contagem da célula. Só a passagem livre/bloqueada mexe nas grades e emite o aviso.
func _change(cell: Vector2i, step: int) -> void:
	var index := cell.y * size + cell.x
	var was_blocked := is_blocked(cell)
	if _obstacles[index] + step < 0 and OS.is_debug_build():
		push_warning("GridPathProvider: remove_obstacle sem par na célula %s (contagem ficaria negativa)." % cell)
	_obstacles[index] = maxi(_obstacles[index] + step, 0)
	if _bulk or was_blocked == is_blocked(cell):
		return
	for clearance: int in _grids:
		_refresh_around(_grids[clearance] as AStarGrid2D, clearance, cell)
	invalidate(cell)


## Refaz a solidez das células a até `clearance` da que mudou.
func _refresh_around(grid: AStarGrid2D, clearance: int, changed: Vector2i) -> void:
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			var cell := changed + Vector2i(dx, dy)
			if not in_bounds(cell):
				continue
			var solid := _is_solid_by_scan(cell, clearance)
			if grid.is_point_solid(cell) != solid:
				grid.set_point_solid(cell, solid)


func _is_solid_by_scan(cell: Vector2i, clearance: int) -> bool:
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			var neighbor := cell + Vector2i(dx, dy)
			if in_bounds(neighbor) and is_blocked(neighbor):
				return true
	return false


func _grid_for(clearance: int) -> AStarGrid2D:
	if _grids.has(clearance):
		return _grids[clearance] as AStarGrid2D
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, size, size)
	grid.cell_size = Vector2(rules.tile_px, rules.tile_px)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	_grids[clearance] = grid
	_fill_solids(grid, clearance)
	return grid


## Marca a solidez inicial por dilatação separável (horizontal e depois vertical) do que está bloqueado.
func _fill_solids(grid: AStarGrid2D, clearance: int) -> void:
	var blocked := PackedByteArray()
	blocked.resize(size * size)
	for index in size * size:
		if _static_blocked[index] != 0 or _obstacles[index] > 0:
			blocked[index] = 1
	var wide := blocked
	if clearance > 0:
		wide = PackedByteArray()
		wide.resize(size * size)
		for y in size:  # horizontal
			var row := y * size
			for x in size:
				if blocked[row + x] != 0:
					for nx in range(maxi(x - clearance, 0), mini(x + clearance, size - 1) + 1):
						wide[row + nx] = 1
		var tall := PackedByteArray()
		tall.resize(size * size)
		for y in size:  # vertical
			for x in size:
				if wide[y * size + x] != 0:
					for ny in range(maxi(y - clearance, 0), mini(y + clearance, size - 1) + 1):
						tall[ny * size + x] = 1
		wide = tall
	for y in size:
		var x := 0
		while x < size:
			if wide[y * size + x] == 0:
				x += 1
				continue
			var run_end := x
			while run_end < size and wide[y * size + run_end] != 0:
				run_end += 1
			grid.fill_solid_region(Rect2i(x, y, run_end - x, 1), true)
			x = run_end
