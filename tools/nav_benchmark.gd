# SPDX-License-Identifier: MIT
extends SceneTree
## Benchmark da navegação (M1, etapa 1): A* nativo (`GridPathProvider`) contra um A* em GDScript, no mapa real.
##   godot --headless --path game --script <caminho absoluto de tools/nav_benchmark.gd>
## Mede: carga da grade, consulta de 48 tiles, e o custo de 32 dinos pedindo a cada 0,5 s. Não faz parte do jogo.

const PAIRS := 400
const SQRT2 := 1.41421356

var _size := 0
var _blocked := PackedByteArray()


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var map := IslandMap.default_map()
	var world_rules: WorldRules = load("res://data/world/world_rules.tres")
	var rules: NavigationRules = load("res://data/balance/navigation_rules.tres")
	rules = rules.duplicate()
	rules.max_requests_per_frame = 1000
	var t0 := Time.get_ticks_usec()
	var provider := GridPathProvider.from_map(map, world_rules, rules, false)
	# Árvores e rochas entram como obstáculos (todas as posições do mapa).
	var obstacles := 0
	for kind: String in map.nodes:
		var def := world_rules.node_def_of(kind)
		if def == null or not def.blocks_when_full or def.foot_size == Vector2.ZERO:
			continue
		for cell: Vector2i in map.nodes[kind]:
			provider.add_obstacle(GridPathProvider.obstacle_rect(def.foot_size, map.center_of(cell)))
			obstacles += 1
	provider.end_bulk()
	print("carga única (terreno, cenário, %d nós de recurso, grades de folga 0, 1 e 2): %.1f ms" % [obstacles, (Time.get_ticks_usec() - t0) / 1000.0])
	_size = map.size
	_blocked.resize(_size * _size)
	for y in _size:
		for x in _size:
			_blocked[y * _size + x] = 1 if provider.is_blocked(Vector2i(x, y)) else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pairs := _pairs(provider, rng, 48)
	print("pares de 48 tiles (maior eixo) com caminho: %d" % pairs.size())
	_bench_native(provider, pairs, "consulta de 48 tiles")
	_bench_script(pairs, "consulta de 48 tiles")
	var near := _pairs(provider, rng, 20)
	_bench_native(provider, near, "consulta de 20 tiles")
	_bench_script(near, "consulta de 20 tiles")
	_bench_frames(provider, rng)
	quit(0)


func _pairs(provider: GridPathProvider, rng: RandomNumberGenerator, distance: int) -> Array:
	var result: Array = []
	var tries := 0
	while result.size() < PAIRS and tries < 200000:
		tries += 1
		var a := Vector2i(rng.randi_range(8, _size - 9), rng.randi_range(8, _size - 9))
		var b := a + Vector2i(rng.randi_range(-distance, distance), rng.randi_range(-distance, distance))
		if maxi(absi(b.x - a.x), absi(b.y - a.y)) < distance - 4 or not provider.in_bounds(b):
			continue
		if provider.is_solid(a, Enums.DinoSize.MEDIUM) or provider.is_solid(b, Enums.DinoSize.MEDIUM):
			continue
		if provider.request_path(a, b, Enums.DinoSize.MEDIUM).is_ok():
			result.append([a, b])
	return result


func _bench_native(provider: GridPathProvider, pairs: Array, label: String) -> void:
	var worst := 0
	var total := 0
	for pair: Array in pairs:
		var t := Time.get_ticks_usec()
		provider.begin_frame(0.0)
		provider.request_path(pair[0], pair[1], Enums.DinoSize.MEDIUM)
		var spent := Time.get_ticks_usec() - t
		total += spent
		worst = maxi(worst, spent)
	print("nativo   %s: média %.3f ms, pior %.3f ms (%d pedidos)" % [label, total / 1000.0 / pairs.size(), worst / 1000.0, pairs.size()])


func _bench_script(pairs: Array, label: String) -> void:
	var worst := 0
	var total := 0
	var nodes := 0
	for pair: Array in pairs:
		var t := Time.get_ticks_usec()
		nodes += _astar(pair[0], pair[1])
		var spent := Time.get_ticks_usec() - t
		total += spent
		worst = maxi(worst, spent)
	print("GDScript %s: média %.3f ms, pior %.3f ms, %.0f nós expandidos em média" % [label, total / 1000.0 / pairs.size(), worst / 1000.0, float(nodes) / pairs.size()])


## 32 dinos pedindo a cada 0,5 s: simula 10 s a 60 quadros e mede o custo por quadro (só o que a navegação gasta).
func _bench_frames(provider: GridPathProvider, rng: RandomNumberGenerator) -> void:
	var dinos: Array = _pairs(provider, rng, 30).slice(0, 32)
	provider.requests_total = 0
	provider.peak_requests_in_frame = 0
	var frame_costs: Array[int] = []
	var frame := 0
	var native_total := 0
	var script_total := 0
	for step in 600:
		provider.begin_frame(1.0 / 60.0)
		var spent := 0
		for i in dinos.size():
			if (step + i * 2) % 30 == 0:  # cada dino pede a cada 30 quadros (0,5 s), fases diferentes
				var t := Time.get_ticks_usec()
				provider.request_path(dinos[i][0], dinos[i][1], Enums.DinoSize.MEDIUM)
				spent += Time.get_ticks_usec() - t
		native_total += spent
		frame_costs.append(spent)
		frame += 1
	frame_costs.sort()
	print("32 dinos, nativo: total em 10 s %.2f ms; por quadro: média %.3f ms, p99 %.3f ms, pior %.3f ms; pedidos %d, pico por quadro %d" % [
			native_total / 1000.0, native_total / 1000.0 / 600.0, frame_costs[int(frame_costs.size() * 0.99)] / 1000.0,
			frame_costs[-1] / 1000.0, provider.requests_total, provider.peak_requests_in_frame])
	var script_costs: Array[int] = []
	for step in 600:
		var spent := 0
		for i in dinos.size():
			if (step + i * 2) % 30 == 0:
				var t := Time.get_ticks_usec()
				_astar(dinos[i][0], dinos[i][1])
				spent += Time.get_ticks_usec() - t
		script_total += spent
		script_costs.append(spent)
	script_costs.sort()
	print("32 dinos, GDScript: total em 10 s %.2f ms; por quadro: média %.3f ms, p99 %.3f ms, pior %.3f ms" % [
			script_total / 1000.0, script_total / 1000.0 / 600.0, script_costs[int(script_costs.size() * 0.99)] / 1000.0,
			script_costs[-1] / 1000.0])


## A* em GDScript (8 direções, sem cortar quina, heurística octogonal, heap binário). Devolve os nós expandidos.
func _astar(from: Vector2i, to: Vector2i) -> int:
	var g := {}
	var heap: Array = []  # [f, index]
	var start := from.y * _size + from.x
	var goal := to.y * _size + to.x
	g[start] = 0.0
	_push(heap, [_h(from, to), start])
	var closed := {}
	var expanded := 0
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var index: int = top[1]
		if closed.has(index):
			continue
		closed[index] = true
		expanded += 1
		if index == goal:
			break
		var cx := index % _size
		var cy := index / _size
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if nx < 0 or ny < 0 or nx >= _size or ny >= _size or _blocked[ny * _size + nx] != 0:
					continue
				if dx != 0 and dy != 0 and (_blocked[cy * _size + nx] != 0 or _blocked[ny * _size + cx] != 0):
					continue
				var next := ny * _size + nx
				var cost: float = float(g[index]) + (SQRT2 if dx != 0 and dy != 0 else 1.0)
				if not g.has(next) or cost < float(g[next]):
					g[next] = cost
					_push(heap, [cost + _h(Vector2i(nx, ny), to), next])
	return expanded


func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return float(maxi(dx, dy)) + (SQRT2 - 1.0) * float(mini(dx, dy))


func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if float(heap[parent][0]) <= float(heap[i][0]):
			break
		var tmp: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent


func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var left := i * 2 + 1
			var right := left + 1
			var smallest := i
			if left < heap.size() and float(heap[left][0]) < float(heap[smallest][0]):
				smallest = left
			if right < heap.size() and float(heap[right][0]) < float(heap[smallest][0]):
				smallest = right
			if smallest == i:
				break
			var tmp: Array = heap[smallest]
			heap[smallest] = heap[i]
			heap[i] = tmp
			i = smallest
	return top
