# SPDX-License-Identifier: MIT
class_name NavigationTests
extends TestSuite
## M1, etapas 1 e 2: `PathProvider` e grade (A1, A2, A5, A6), folga por porte, e travar, replanejar e "ficou preso"
## (A3, A4). Tudo em lógica pura: o "corpo" dos testes anda pelo que o `PathFollower` manda e só entra em célula livre.

const RULES: NavigationRules = preload("res://data/balance/navigation_rules.tres")
const WORLD_RULES: WorldRules = preload("res://data/world/world_rules.tres")
const MAIN_SCENE: PackedScene = preload("res://src/world/Main.tscn")
const DT := 1.0 / 60.0
const TILE := 16.0
const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")


func run() -> void:
	_test_rules_data()
	_test_screen_geometry()
	_test_gap_clearance_by_size()
	_test_no_corner_cutting()
	_test_a1_goes_around_a_tree()
	_test_a1_sealed_goal_gives_up()
	_test_hidden_wall_timeline()
	_test_a5_felled_tree_replans()
	_test_a5_scene_tree_node_signal()
	_test_a6_thirty_two_dinos()
	_test_request_cap()
	_test_a3_tamed_stuck_far_offscreen()
	_test_stuck_leaves()
	_test_a4_tamed_stuck_on_screen()
	_test_stuck_episode_rearm()
	_test_stuck_save_roundtrip()
	await _test_body_passes_one_tile_gap()
	_test_follow_goes_around()
	_test_chase_around_and_give_up()


# ---------------------------------------------------------------- auxiliares

## O mundo da `Main`, com os selvagens e a zona paradas: o teste mexe só no que quer.
func _main(world: String) -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = world
	main.menu_scene = ""
	_root.add_child(main)
	_track.call(main)
	for node: Node in [main.player, main.player.hunger, main.player.stamina, main.dino, main.dino.torpor, main.dino.taming,
			main.dino.state_machine, main.scheduler]:
		node.set_physics_process(false)
	main.wild.process_mode = Node.PROCESS_MODE_DISABLED
	main.zone.set_physics_process(false)
	main.dino.process_mode = Node.PROCESS_MODE_INHERIT
	main.dino.visible = true
	return main


func _grid(side: int = 48) -> GridPathProvider:
	var provider := GridPathProvider.new()
	provider.setup(side, PackedByteArray())
	return provider


func _block(provider: GridPathProvider, cells: Array[Vector2i]) -> void:
	for cell in cells:
		provider.add_obstacle(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))


func _unblock(provider: GridPathProvider, cell: Vector2i) -> void:
	provider.remove_obstacle(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))


## Parede vertical na coluna `x`, de `y_from` a `y_to`, sem os vãos.
func _wall(x: int, y_from: int, y_to: int, gaps: Array[int] = []) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(y_from, y_to + 1):
		if not gaps.has(y):
			cells.append(Vector2i(x, y))
	return cells


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Corpo de teste: anda `speed` px/s pelo que o seguidor manda e só entra em célula que a grade (ou `hidden`) deixa.
## Devolve {pos, arrived_at, stuck_at} (-1 = não aconteceu).
func _simulate(provider: GridPathProvider, follower: PathFollower, start: Vector2, goal: Vector2, seconds: float,
		hidden: Dictionary = {}, speed: float = 40.0) -> Dictionary:
	var pos := start
	var elapsed := 0.0
	var result := {"pos": pos, "arrived_at": -1.0, "stuck_at": -1.0}
	while elapsed < seconds:
		provider.begin_frame(DT)
		var direction := follower.update(DT, pos, goal)
		elapsed += DT
		if follower.stuck:
			result["stuck_at"] = elapsed
			break
		var next := pos + direction * speed * DT
		var cell := provider.cell_of(next)
		if not provider.is_blocked(cell) and not hidden.has(cell):
			pos = next
		if pos.distance_to(goal) <= 10.0:
			result["arrived_at"] = elapsed
			break
	result["pos"] = pos
	return result


func _follower(provider: PathProvider, size: Enums.DinoSize = Enums.DinoSize.MEDIUM) -> PathFollower:
	var follower := PathFollower.new()
	follower.provider = provider
	follower.size_class = size
	return follower


# ---------------------------------------------------------------- dados e regras

func _test_rules_data() -> void:
	_check(RULES.tile_px == 16 and RULES.clearance_of(Enums.DinoSize.SMALL) == 0 and RULES.clearance_of(Enums.DinoSize.MEDIUM) == 0
			and RULES.clearance_of(Enums.DinoSize.LARGE) == 1 and RULES.clearance_of(Enums.DinoSize.MEDIUM, 1) == 1,
			"NavigationRules: tile 16 e folgas 0, 0 e 1 por porte (+ extra) [provisório 08/11]")
	_check(RULES.max_request_tiles == 48 and RULES.max_requests_per_frame == 3 and is_equal_approx(RULES.repath_interval_s, 0.5)
			and is_equal_approx(RULES.stuck_check_seconds, 1.0) and is_equal_approx(RULES.stuck_min_progress_px, 6.0)
			and is_equal_approx(RULES.stuck_give_up_seconds, 3.0) and is_equal_approx(RULES.blocked_cell_seconds, 5.0)
			and is_equal_approx(RULES.stuck_far_tiles, 14.0) and is_equal_approx(RULES.stuck_offscreen_margin_tiles, 2.0)
			and is_equal_approx(RULES.stuck_retry_min_seconds, 5.0) and is_equal_approx(RULES.stuck_clear_tiles, 4.0),
			"NavigationRules: números da spec (48 tiles, 3 por quadro, 1 s / 6 px / 3 s, 14 tiles, 5 s)")
	var real := GridPathProvider.from_map(IslandMap.default_map(), WORLD_RULES, RULES)
	_check(real.size == 256 and real.is_blocked(Vector2i(0, 0)) and real.is_blocked(Vector2i(-1, 0)),
			"a grade do mapa é 256x256 e a água funda bloqueia")


func _test_screen_geometry() -> void:
	var owner_at := Vector2(1000, 1000)
	_check(not RULES.is_far_and_offscreen(owner_at + Vector2(13.0 * TILE, 0), owner_at), "13 tiles: perto demais para desistir")
	_check(RULES.is_far_and_offscreen(owner_at + Vector2(15.0 * TILE, 0), owner_at), "15 tiles na horizontal: longe e fora da tela")
	_check(not RULES.is_far_and_offscreen(owner_at + Vector2(12.0 * TILE, 7.5 * TILE), owner_at),
			"canto da tela com a margem (12 x 7,5 tiles, 14,2 de distância): longe mas ainda à vista")
	_check(RULES.is_far_and_offscreen(owner_at + Vector2(0, 15.0 * TILE), owner_at), "15 tiles na vertical: fora da tela")


# ---------------------------------------------------------------- A2 e a grade

func _test_gap_clearance_by_size() -> void:
	var gap1 := _grid(40)
	_block(gap1, _wall(20, 0, 39, [20]))
	var from := Vector2i(10, 20)
	var to := Vector2i(30, 20)
	_check(gap1.request_path(from, to, Enums.DinoSize.SMALL).is_ok(), "A2: vão de 1 tile, o Pequeno passa")
	gap1.begin_frame(DT)
	_check(gap1.request_path(from, to, Enums.DinoSize.MEDIUM).is_ok(),
			"A2: vão de 1 tile, o Médio passa (é do tamanho do humano: passa onde o jogador passa)")
	gap1.begin_frame(DT)
	_check(gap1.request_path(from, to, Enums.DinoSize.LARGE).status == PathResult.Status.NO_PATH, "A2: vão de 1 tile, o Grande recusa")
	_check(RULES.clearance_of(Enums.DinoSize.MEDIUM) == RULES.clearance_of(Enums.DinoSize.SMALL),
			"A2: o Médio usa a mesma folga do jogador (e do Pequeno)")
	var gap2 := _grid(40)
	_block(gap2, _wall(20, 0, 39, [20, 21]))
	_check(gap2.request_path(from, to, Enums.DinoSize.MEDIUM).is_ok(), "vão de 2 tiles: o Médio passa")
	gap2.begin_frame(DT)
	_check(gap2.request_path(from, to, Enums.DinoSize.LARGE).status == PathResult.Status.NO_PATH,
			"vão de 2 tiles: o Grande (folga 1) recusa")
	var gap3 := _grid(40)
	_block(gap3, _wall(20, 0, 39, [19, 20, 21]))
	_check(gap3.request_path(from, to, Enums.DinoSize.LARGE).is_ok(), "vão de 3 tiles: o Grande passa")
	var far := _grid(120)
	_check(far.request_path(Vector2i(2, 2), Vector2i(2, 60), Enums.DinoSize.SMALL).status == PathResult.Status.TOO_FAR,
			"pedido acima de 48 tiles é recusado (anda em linha reta)")


func _test_no_corner_cutting() -> void:
	var provider := _grid(16)
	_block(provider, [Vector2i(6, 5), Vector2i(5, 6)])
	_check(not provider.has_line(Vector2i(5, 5), Vector2i(6, 6), Enums.DinoSize.SMALL), \
			"linha na diagonal entre duas quinas bloqueadas não passa")
	var path := provider.request_path(Vector2i(5, 5), Vector2i(6, 6), Enums.DinoSize.SMALL)
	_check(path.is_ok() and path.cells.size() > 1, "o caminho contorna em vez de cortar a quina")


# ---------------------------------------------------------------- A1

func _test_a1_goes_around_a_tree() -> void:
	var provider := _grid()
	_block(provider, [Vector2i(20, 20)])
	var follower := _follower(provider)
	var start := _center(Vector2i(15, 20))
	var goal := _center(Vector2i(25, 20))  # 10 tiles, com a árvore bem no meio
	var run := _simulate(provider, follower, start, goal, 15.0)
	_check(float(run["arrived_at"]) > 0.0 and not follower.stuck, "A1: 10 tiles com uma árvore no meio: contorna e chega")
	_check(follower.replans >= 1, "A1: o contorno veio do `PathProvider`")


func _test_a1_sealed_goal_gives_up() -> void:
	var provider := _grid()
	var ring: Array[Vector2i] = []
	for x in range(23, 28):
		for y in range(18, 23):
			if x == 23 or x == 27 or y == 18 or y == 22:
				ring.append(Vector2i(x, y))
	_block(provider, ring)
	var follower := _follower(provider)
	var start := _center(Vector2i(15, 20))
	var run := _simulate(provider, follower, start, _center(Vector2i(25, 20)), 10.0)
	_check(follower.stuck and float(run["stuck_at"]) <= RULES.stuck_give_up_seconds, \
			"A1: sem caminho, desiste em até 3 s (%.2f s)" % float(run["stuck_at"]))
	_check((run["pos"] as Vector2).distance_to(start) < 4.0, "A1: desistiu sem ficar colado em obstáculo (parado onde estava)")


## Corpo que não anda (preso por algo que a grade não conhece): sem progresso, aos 1 s replaneja e bloqueia 5 s a célula
## à frente, aos 2 s replaneja com folga +1 e aos 3 s está preso.
func _test_hidden_wall_timeline() -> void:
	var provider := _grid()
	var follower := _follower(provider)
	var pos := _center(Vector2i(10, 20))
	var goal := _center(Vector2i(30, 20))
	var elapsed := 0.0
	var replanned_at: Array[float] = []
	var blocked_at := -1.0
	while elapsed < 6.0 and not follower.stuck:
		provider.begin_frame(DT)
		follower.update(DT, pos, goal)  # `pos` nunca muda: o corpo está preso
		elapsed += DT
		if blocked_at < 0.0 and provider.is_blocked(Vector2i(11, 20)):
			blocked_at = elapsed
		if follower.requests > replanned_at.size():
			replanned_at.append(elapsed)
	_check(blocked_at > 0.9 and blocked_at < 1.2, "1 s sem progresso: a célula à frente fica bloqueada (%.2f s)" % blocked_at)
	_check(replanned_at.size() == 2 and absf(replanned_at[0] - 1.0) < 0.1 and absf(replanned_at[1] - 2.0) < 0.1,
			"replaneja aos 1 s e aos 2 s (%s)" % [replanned_at])
	_check(follower.stuck and elapsed > 2.9 and elapsed < 3.2, "3 s sem progresso: preso (%.2f s)" % elapsed)
	for step in int(RULES.blocked_cell_seconds / DT) + 5:
		provider.begin_frame(DT)
	_check(not provider.is_blocked(Vector2i(11, 20)), "o bloqueio temporário some depois de 5 s")


# ---------------------------------------------------------------- A5

func _test_a5_felled_tree_replans() -> void:
	var provider := _grid()
	_block(provider, _wall(20, 5, 35))
	var follower := _follower(provider, Enums.DinoSize.SMALL)  # o Pequeno cabe no vão de 1 tile que a árvore caída abre
	var from := _center(Vector2i(10, 20))
	var goal := _center(Vector2i(30, 20))
	follower.update(DT, from, goal)
	var before := follower.current_path()
	_check(before.size() > 25 and before.has(Vector2i(20, 20)) == false,
			"preparo: o caminho contorna a parede (%d células)" % before.size())
	var requests_before := follower.requests
	follower.update(DT, from, goal)
	_check(follower.requests == requests_before and follower.current_path() == before, "sem aviso, o caminho não é refeito")
	var invalidated: Array[Vector2i] = []
	provider.cell_invalidated.connect(func(cell: Vector2i) -> void: invalidated.append(cell))
	_unblock(provider, Vector2i(20, 20))
	_check(invalidated == [Vector2i(20, 20)], "A5: derrubar libera a célula e avisa só ela (`invalidate`)")
	follower.update(DT, from, goal)
	var after := follower.current_path()
	_check(after.size() < before.size(),
			"A5: o caminho velho é replanejado na hora, sem esperar o intervalo (era %d células, agora %d)" % [before.size(), after.size()])
	_block(provider, [Vector2i(20, 20)])
	_check(invalidated.size() == 2 and provider.is_blocked(Vector2i(20, 20)), "renascer bloqueia de novo e avisa")


## Pela cena: o nó de recurso derrubado libera a célula na grade do mundo; ao renascer, bloqueia de novo.
func _test_a5_scene_tree_node_signal() -> void:
	var main := _main("nav_tree")
	var tree_node: ResourceNode = null
	for node in main.resources.nodes():
		if node.def.id == "tree":
			tree_node = node
			break
	var provider := main.navigation.provider
	var cell := provider.cell_of(tree_node.global_position)
	_check(tree_node.blocks_movement() and provider.is_blocked(cell), "A5 (cena): a árvore em pé bloqueia a célula dela")
	var invalidated: Array[Vector2i] = []
	provider.cell_invalidated.connect(func(changed: Vector2i) -> void: invalidated.append(changed))
	tree_node.component.harvest()
	_check(not tree_node.is_available() and not provider.is_blocked(cell) and invalidated.has(cell),
			"A5 (cena): a árvore caída libera a célula e avisa por sinal")
	main.player.global_position = Vector2.ZERO  # ninguém sobre o tile: o nó pode voltar
	TestWorld.pass_time(main, tree_node.def.respawn_seconds + 1.0)
	_check(tree_node.is_available() and provider.is_blocked(cell), "A5 (cena): ao renascer a célula bloqueia de novo")
	var count_before := invalidated.size()
	tree_node.component.register_damage(0.01)  # golpe que não derruba: a grade não muda
	_check(invalidated.size() == count_before, "golpe que não derruba não mexe na grade")
	main.free()


# ---------------------------------------------------------------- A6

func _test_a6_thirty_two_dinos() -> void:
	var map := IslandMap.default_map()
	var provider := GridPathProvider.from_map(map, WORLD_RULES, RULES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pairs: Array[Array] = []
	var guard := 0
	while pairs.size() < 32 and guard < 100000:
		guard += 1
		var a := Vector2i(rng.randi_range(20, 236), rng.randi_range(20, 236))
		var b := a + Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		if provider.in_bounds(b) and not provider.is_solid(a, Enums.DinoSize.MEDIUM) and not provider.is_solid(b, Enums.DinoSize.MEDIUM) \
				and maxi(absi(b.x - a.x), absi(b.y - a.y)) >= 20:
			provider.begin_frame(0.0)
			if provider.request_path(a, b, Enums.DinoSize.MEDIUM).is_ok():
				pairs.append([a, b])
	_check(pairs.size() == 32, "preparo: 32 pares com caminho no mapa real")
	provider.requests_total = 0
	provider.peak_requests_in_frame = 0
	var lots := [0, 0, 0]  # 3 lotes de 200 quadros: vale o menor (um pico de relógio não reprova)
	var served := 0
	for step in 600:  # 10 s a 60 quadros, cada dino pedindo a cada 0,5 s (fases diferentes)
		provider.begin_frame(DT)
		var started := Time.get_ticks_usec()
		for i in 32:
			if (step + i * 2) % 30 == 0:
				served += 1 if provider.request_path(pairs[i][0], pairs[i][1], Enums.DinoSize.MEDIUM).is_ok() else 0
		lots[step / 200] += Time.get_ticks_usec() - started
	_check(provider.peak_requests_in_frame <= RULES.max_requests_per_frame,
			"A6: pedidos por quadro nunca passam do teto (pico %d de %d)" % [provider.peak_requests_in_frame, RULES.max_requests_per_frame])
	_check(served == 32 * 20 and provider.deferred_total == 0, "A6: os 640 pedidos de 10 s foram atendidos (%d)" % served)
	var per_frame_ms: float = minf(lots[0], minf(lots[1], lots[2])) / 1000.0 / 200.0
	_check(per_frame_ms < 2.0, "A6: tick total abaixo de 2 ms por quadro (%.3f ms)" % per_frame_ms)


func _test_request_cap() -> void:
	var provider := _grid()
	provider.begin_frame(DT)
	var results: Array[PathResult.Status] = []
	for i in 10:
		results.append(provider.request_path(Vector2i(2, 2), Vector2i(10 + i, 10), Enums.DinoSize.SMALL).status)
	var served := results.count(PathResult.Status.OK)
	var deferred := results.count(PathResult.Status.DEFERRED)
	_check(served == RULES.max_requests_per_frame and deferred == 10 - served, \
			"o teto por quadro adia o excesso (%d atendidos, %d adiados)" % [served, deferred])
	provider.begin_frame(DT)
	_check(provider.request_path(Vector2i(2, 2), Vector2i(12, 12), Enums.DinoSize.SMALL).is_ok(), \
			"no quadro seguinte o pedido adiado passa")


# ---------------------------------------------------------------- A3 e A4

## Domado (Paquicéfalo, Seguir) a `tiles_apart` do dono, que está trancado num anel: sem caminho possível.
func _stuck_rig(tiles_apart: float) -> Dictionary:
	var player := _spawn_player()
	var dino := _spawn_dino()
	for node: Node in [player, dino, dino.state_machine]:
		node.set_physics_process(false)
	var provider := _grid(120)
	var center := Vector2i(60, 60)
	var ring: Array[Vector2i] = []
	for x in range(center.x - 2, center.x + 3):
		for y in range(center.y - 2, center.y + 3):
			if maxi(absi(x - center.x), absi(y - center.y)) == 2:
				ring.append(Vector2i(x, y))
	_block(provider, ring)
	player.global_position = _center(center)
	dino.global_position = player.global_position + Vector2(-tiles_apart * TILE, 0)
	dino.torpor.add_torpor(100.0)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = player.player_id
	var authority: WorldAuthority = player.authority
	authority.register(dino)
	dino.state_machine.navigation = provider
	dino.state_machine.set_order(Enums.DinoOrder.FOLLOW)
	var log := MessageLog.new()
	authority.game_event.connect(log.push_event)
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	return {"player": player, "dino": dino, "provider": provider, "log": log, "events": events, "authority": authority}


## Um quadro: o corpo informa o dono, a máquina pensa e o corpo anda (sem teleporte: devolve o salto do quadro).
func _step_dino(rig: Dictionary) -> float:
	var dino: Dino = rig["dino"]
	var provider: GridPathProvider = rig["provider"]
	provider.begin_frame(DT)
	dino.observe_owner()
	dino.state_machine.tick(DT)
	var before := dino.global_position
	var next := before + dino.state_machine.desired_direction * dino.move_speed * dino.state_machine.speed_multiplier * DT
	if not provider.is_blocked(provider.cell_of(next)):
		dino.global_position = next
	return before.distance_to(dino.global_position)


func _test_a3_tamed_stuck_far_offscreen() -> void:
	var rig := _stuck_rig(20.0)
	var dino: Dino = rig["dino"]
	var machine := dino.state_machine
	var events: Array[String] = rig["events"]
	_check(machine.current_id == Enums.DinoStateId.TAMED and machine.order == Enums.DinoOrder.FOLLOW, "preparo: domado em Seguir")
	var biggest_jump := 0.0
	var stuck_at := -1.0
	var elapsed := 0.0
	while elapsed < 12.0:
		biggest_jump = maxf(biggest_jump, _step_dino(rig))
		elapsed += DT
		if stuck_at < 0.0 and machine.current_id == Enums.DinoStateId.STUCK:
			stuck_at = elapsed
	_check(stuck_at > 0.0 and stuck_at <= RULES.stuck_give_up_seconds, \
			"A3: longe, fora da tela e sem caminho: fica preso em até 3 s (%.2f s)" % stuck_at)
	_check(events.count("tamed_stuck") == 1, "A3: o log escreve `tamed_stuck` uma única vez (%d)" % events.count("tamed_stuck"))
	var text := (rig["log"] as MessageLog).history()[-1]["text"] as String
	_check(text == "%s ficou preso." % dino.stats.display_name, "A3: texto do log: \"%s\"" % text)
	_check(biggest_jump <= dino.move_speed * machine.order_rules.follow_speed_multiplier * DT * 1.01,
			"A3: sem teleporte, o maior salto por quadro é de andar (%.2f px)" % biggest_jump)
	_check(machine.desired_direction == Vector2.ZERO and machine.current_id == Enums.DinoStateId.STUCK, \
			"A3: preso, fica parado (a ordem continua Seguir)")
	_check(machine.order == Enums.DinoOrder.FOLLOW, "A3: a ordem continua Seguir")
	_free_rig(rig)


## Preso e parado: o dono perto (depois de 5 s) ou uma ordem nova (mesmo igual) o fazem tentar de novo.
func _test_stuck_leaves() -> void:
	var rig := _stuck_rig(20.0)
	var dino: Dino = rig["dino"]
	var player: Player = rig["player"]
	var machine := dino.state_machine
	for step in 300:
		_step_dino(rig)
	_check(machine.current_id == Enums.DinoStateId.STUCK, "preparo: preso")
	var parked := dino.global_position
	for step in 600:  # 10 s com o dono longe: segue parado, sem teleporte e sem novo aviso
		_step_dino(rig)
	_check(machine.current_id == Enums.DinoStateId.STUCK and dino.global_position == parked, "longe e fora da tela, segue parado")
	_check((rig["events"] as Array[String]).count("tamed_stuck") == 1, "continua um único aviso")
	player.global_position = dino.global_position + Vector2(8.0 * TILE, 0)  # o dono volta a 8 tiles
	_step_dino(rig)
	_check(machine.current_id == Enums.DinoStateId.TAMED, "o dono a menos de 14 tiles (passado o intervalo): volta a seguir")
	# Ordem nova: preso de novo, G (Ficar) o solta como domado parado.
	player.global_position = dino.global_position + Vector2(20.0 * TILE, 0)
	for step in 480:
		_step_dino(rig)
	_check(machine.current_id == Enums.DinoStateId.STUCK, "preso de novo")
	_check(machine.set_order(Enums.DinoOrder.STAY) and machine.current_id == Enums.DinoStateId.TAMED
			and machine.order == Enums.DinoOrder.STAY, "ordem nova (Ficar) tira do preso")
	machine.set_order(Enums.DinoOrder.FOLLOW)
	for step in 480:
		_step_dino(rig)
	_check(machine.current_id == Enums.DinoStateId.STUCK, "Seguir de novo, longe: preso outra vez")
	_check(machine.set_order(Enums.DinoOrder.FOLLOW) and machine.current_id == Enums.DinoStateId.TAMED,
			"Seguir de novo (a mesma ordem, o G) também o faz tentar")
	_check((rig["events"] as Array[String]).count("tamed_stuck") == 1, "sem andar 4 tiles o episódio é o mesmo: nenhum aviso novo")
	_free_rig(rig)


func _test_a4_tamed_stuck_on_screen() -> void:
	var rig := _stuck_rig(9.0)
	var dino: Dino = rig["dino"]
	var machine := dino.state_machine
	var requests_start := machine.follower.requests
	var seen_stuck_state := false
	for step in 900:  # 15 s presos, mas à vista do dono
		_step_dino(rig)
		seen_stuck_state = seen_stuck_state or machine.current_id == Enums.DinoStateId.STUCK
	_check(not seen_stuck_state and machine.current_id == Enums.DinoStateId.TAMED, "A4: preso na tela, não desiste")
	_check((rig["events"] as Array[String]).count("tamed_stuck") == 0, "A4: não escreve `tamed_stuck`")
	_check(machine.follower.requests - requests_start >= 4, \
			"A4: segue tentando (%d pedidos de caminho)" % (machine.follower.requests - requests_start))
	_free_rig(rig)


func _test_stuck_episode_rearm() -> void:
	var machine := _make_machine()
	var count := [0]
	machine.got_stuck.connect(func() -> void: count[0] += 1)
	machine.observe(Vector2(100, 100), Vector2.ZERO, false)
	machine.begin_stuck_episode()
	machine.begin_stuck_episode()
	_check(count[0] == 1, "o aviso sai uma vez por episódio")
	machine.observe(Vector2(100 + 3.0 * TILE, 100), Vector2.ZERO, false)
	machine.update_stuck_episode()
	machine.begin_stuck_episode()
	_check(count[0] == 1, "andou só 3 tiles: o episódio segue aberto")
	machine.observe(Vector2(100 + 4.0 * TILE, 100), Vector2.ZERO, false)
	machine.update_stuck_episode()
	machine.begin_stuck_episode()
	_check(count[0] == 2, "andou 4 tiles: o episódio fecha e o próximo avisa de novo")


## Domado em STUCK salvo e restaurado: o estado vai pelo nome, volta como domado em Seguir e restaurar não é evento de jogo.
func _test_stuck_save_roundtrip() -> void:
	var rig := _stuck_rig(20.0)
	var dino: Dino = rig["dino"]
	for step in 300:
		_step_dino(rig)
	_check(dino.state_machine.current_id == Enums.DinoStateId.STUCK, "preparo: domado preso")
	var saved := JSON.parse_string(JSON.stringify(dino.to_dict())) as Dictionary
	_check((saved["state_machine"] as Dictionary)["state"] == "STUCK" and (saved["state_machine"] as Dictionary)["order"] == "FOLLOW",
			"o preso vai no save pelo nome (STUCK) e a ordem continua Seguir")
	var copy := _spawn_dino()
	copy.set_physics_process(false)
	copy.state_machine.set_physics_process(false)
	var stuck_events := [0]
	copy.state_machine.got_stuck.connect(func() -> void: stuck_events[0] += 1)
	var applied := copy.from_dict(saved)
	_check(applied and copy.state_machine.is_tamed and copy.state_machine.order == Enums.DinoOrder.FOLLOW,
			"restaurado: domado, em Seguir")
	_check(copy.state_machine.current_id == Enums.DinoStateId.TAMED, "restaurado: volta a seguir (tenta de novo), sem ficar preso")
	_check(stuck_events[0] == 0, "restaurar não dispara `got_stuck` (não é evento de jogo)")
	copy.free()
	_free_rig(rig)


## Corpo físico de verdade (não ponto): o Médio (pés 14x14) passa por vão de 1 tile (16 px) em parede horizontal e em
## parede vertical; o Grande (28x24) não passa. Mundo próprio num SubViewport (os outros testes deixam corpos na raiz).
func _test_body_passes_one_tile_gap() -> void:
	var tree := _root.get_tree()
	var viewport := SubViewport.new()
	_root.add_child(viewport)
	_track.call(viewport)
	for rect: Rect2 in [Rect2(0, 64, 92, 16), Rect2(108, 64, 300, 16), Rect2(300, 0, 16, 92), Rect2(300, 108, 16, 300)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.position = rect.get_center()
		wall.add_child(shape)
		viewport.add_child(wall)
	# O Paquicéfalo agora é Pequeno (GDD 4.2): o Médio do teste fixa o porte no dado duplicado.
	var medium := _spawn_dino()
	medium.stats = medium.stats.duplicate()
	medium.stats.size = Enums.DinoSize.MEDIUM
	medium._apply_hitbox()
	var large := _spawn_dino()
	large.stats = large.stats.duplicate()
	large.stats.size = Enums.DinoSize.LARGE
	large._apply_hitbox()
	var sideways := _spawn_dino()
	sideways.stats = sideways.stats.duplicate()
	sideways.stats.size = Enums.DinoSize.MEDIUM
	sideways._apply_hitbox()
	for body: Dino in [medium, large, sideways]:
		_root.remove_child(body)
		viewport.add_child(body)
		body.set_physics_process(false)
		body.state_machine.set_physics_process(false)
	medium.global_position = Vector2(100, 40)
	large.global_position = Vector2(100, 40)
	sideways.global_position = Vector2(280, 100)
	for frame in 150:
		await tree.physics_frame
		medium.velocity = Vector2(0, 40)
		medium.move_and_slide()
		large.velocity = Vector2(0, 40)
		large.move_and_slide()
		sideways.velocity = Vector2(40, 0)
		sideways.move_and_slide()
	_check(medium.global_position.y > 110.0,
			"corpo físico: o Médio (pés 14x14) atravessa o vão de 1 tile numa parede horizontal (y=%.0f)" % medium.global_position.y)
	_check(sideways.global_position.x > 330.0, "corpo físico: e numa parede vertical (x=%.0f)" % sideways.global_position.x)
	_check(large.global_position.y < 64.0, "corpo físico: o Grande (28x24) não passa o vão de 1 tile (y=%.0f)" % large.global_position.y)


# ---------------------------------------------------------------- Seguir e perseguir usam o caminho

func _test_follow_goes_around() -> void:
	var machine := _make_machine()
	machine.torpor.add_torpor(100.0)
	machine.mark_tamed()
	var provider := _grid()
	_block(provider, _wall(20, 10, 30))
	machine.navigation = provider
	machine.set_order(Enums.DinoOrder.FOLLOW)
	var pos := _center(Vector2i(15, 20))
	var owner_at := _center(Vector2i(26, 20))
	var arrived_at := -1.0
	var elapsed := 0.0
	while elapsed < 25.0:
		provider.begin_frame(DT)
		machine.observe(pos, owner_at, true)
		machine.tick(DT)
		elapsed += DT
		var next := pos + machine.desired_direction * 40.0 * machine.speed_multiplier * DT
		if not provider.is_blocked(provider.cell_of(next)):
			pos = next
		if machine.desired_direction == Vector2.ZERO and elapsed > 1.0:
			arrived_at = elapsed
			break
	_check(arrived_at > 0.0 and pos.distance_to(owner_at) <= machine.order_rules.follow_px()
			and machine.current_id == Enums.DinoStateId.TAMED,
			"Seguir: contorna a parede e chega perto do dono (%.1f s, %.0f px)" % [arrived_at, pos.distance_to(owner_at)])


func _chase_machine(provider: GridPathProvider) -> DinoStateMachine:
	var machine := _make_machine()
	machine.configure(_chase_only(), 40.0, TILE)
	machine.navigation = provider
	return machine


func _test_chase_around_and_give_up() -> void:
	var provider := _grid()
	_block(provider, [Vector2i(20, 20), Vector2i(20, 19), Vector2i(20, 21)])
	var machine := _chase_machine(provider)
	var pos := _center(Vector2i(16, 20))
	var target := _center(Vector2i(24, 20))
	var closest := INF
	var reached := false
	var elapsed := 0.0
	while elapsed < 10.0:
		provider.begin_frame(DT)
		machine.observe(pos, Vector2.ZERO, false)
		machine.observe_target(target, true)
		machine.tick(DT)
		elapsed += DT
		var next := pos + machine.desired_direction * 40.0 * machine.speed_multiplier * DT
		if not provider.is_blocked(provider.cell_of(next)):
			pos = next
		closest = minf(closest, pos.distance_to(target))
		if machine.current_id != Enums.DinoStateId.AGGRESSIVE and elapsed > 0.5:
			reached = true
			break
	_check(reached and closest <= RAPTOR.chase_stop_px + 2.0, \
			"perseguição: contorna a árvore e chega ao alvo (%.0f px, %.1f s)" % [closest, elapsed])
	# Alvo num anel fechado: o agressivo desiste e fica em alerta.
	var sealed := _grid()
	var ring: Array[Vector2i] = []
	for x in range(22, 27):
		for y in range(18, 23):
			if x == 22 or x == 26 or y == 18 or y == 22:
				ring.append(Vector2i(x, y))
	_block(sealed, ring)
	var chaser := _chase_machine(sealed)
	var start := _center(Vector2i(18, 20))
	var goal := _center(Vector2i(24, 20))
	var gave_up_at := -1.0
	var time := 0.0
	var chased := false
	while time < 5.5:  # o alerta é de 5 s, contados do momento em que desistiu
		sealed.begin_frame(DT)
		chaser.observe(start, Vector2.ZERO, false)
		chaser.observe_target(goal, true)
		chaser.tick(DT)
		time += DT
		chased = chased or chaser.current_id == Enums.DinoStateId.AGGRESSIVE
		if chased and chaser.current_id != Enums.DinoStateId.AGGRESSIVE and gave_up_at < 0.0:
			gave_up_at = time
	_check(chased and gave_up_at > 0.0 and gave_up_at <= RULES.stuck_give_up_seconds, \
			"perseguição sem caminho: desiste em até 3 s (%.2f s)" % gave_up_at)
	_check(chaser.current_id == Enums.DinoStateId.IDLE, "e não persegue de novo durante o alerta")


func _free_rig(rig: Dictionary) -> void:
	for key: String in ["dino", "player", "authority"]:
		(rig[key] as Node).free()


## Utahraptor só perseguidor (sem `threat_profile`): o comportamento da etapa 3, que estes testes de caminho medem.
func _chase_only() -> DinoBaseStats:
	var stats: DinoBaseStats = RAPTOR.duplicate()
	stats.threat_profile = null
	return stats
