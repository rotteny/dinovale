# SPDX-License-Identifier: MIT
class_name ShelterTests
extends PredationTests
## E8b: o abrigo protege (MUN-04). Um anel de 8 peças (7 paredes e uma porta) em volta do jogador, o Utahraptor DO JOGO com a
## predação e a agressão reais, e uma simulação em que o corpo não atravessa peça sólida (o que a física faria). Prova que o
## carnívoro não alcança nem morde quem está dentro, que não fica batendo na parede (desiste), que a porta aberta deixa passar e
## que a mordida não atravessa parede mesmo com a distância ao alcance.

const CENTER := Vector2i(20, 20)
const DOOR := CENTER + Vector2i(1, 0)
const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
## Meio lado do corpo na simulação (o do dino é 14 x 14).
const HALF_BODY := 7.0
const RING_SECONDS := 20.0


func run() -> void:
	_test_line_helpers()
	_test_ring_blocks_the_raptor()
	_test_raptor_next_to_the_wall()
	_test_open_door_lets_it_in()
	_test_bite_does_not_cross_the_wall()
	_test_raptor_gives_up_and_stays_out()
	_release_worlds()


func _px(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Mundo com o jogador no centro do anel (7 paredes + a porta fechada, ou aberta) e a navegação ligada à grade.
func _shelter(door_open: bool, ring: bool = true) -> Dictionary:
	var world := _world()
	var player: Player = world["player"]
	player.global_position = _px(CENTER)
	var authority: WorldAuthority = world["authority"]
	var grid := authority.build.grid
	if ring:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell := CENTER + Vector2i(dx, dy)
				if cell != CENTER:
					grid.add(cell, "door" if cell == DOOR else "wall")
		grid.set_open(DOOR, door_open)
	var provider := GridPathProvider.new()
	provider.setup(64, PackedByteArray())
	provider.end_bulk()
	var navigation := NavigationWorld.new()
	_track.call(navigation)
	navigation.provider = provider
	navigation.watch_build(grid, TILE)
	world["grid"] = grid
	world["navigation"] = navigation
	return world


func _raptor(world: Dictionary, at: Vector2, with_navigation: bool = true) -> Dino:
	var dino := _dino(world, RAPTOR, at)
	dino.state_machine.rng.seed = 11
	if with_navigation:
		dino.state_machine.navigation = (world["navigation"] as NavigationWorld).provider
	return dino


func _blocked_at(grid: BuildGrid, point: Vector2) -> bool:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := point + corner * HALF_BODY
		if grid.blocks(Vector2i(floori(at.x / TILE), floori(at.y / TILE))):
			return true
	return false


## `_run` do predador mais a grade: o corpo não entra em célula sólida (desliza num eixo se o outro está livre).
func _walk(world: Dictionary, hunter: Dino, seconds: float) -> Dictionary:
	var authority: WorldAuthority = world["authority"]
	var zone: DinoZone = world["zone"]
	var system: PredationSystem = world["system"]
	var navigation: NavigationWorld = world["navigation"]
	var grid: BuildGrid = world["grid"]
	var player: Player = world["player"]
	var life := player.health.current_health
	var report := {"closest": INF, "lunged": false, "inside": false, "longest_aggressive": 0.0, "aggressive_time": 0.0,
			"damage": 0.0}
	var streak := 0.0
	for _i in roundi(seconds / DT):
		authority.clock.advance(DT)
		authority.tick_herd(DT)
		zone.reclassify()
		system.tick(DT)
		navigation.tick(DT)
		hunter.observe_owner()
		hunter.observe_targets()
		hunter.state_machine.tick(DT)
		var speed := hunter.move_speed * hunter.state_machine.speed_multiplier * hunter.state_machine.wound_multiplier()
		var step := hunter.state_machine.desired_direction * speed * DT
		for part: Vector2 in [step, Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
			if not _blocked_at(grid, hunter.global_position + part):
				hunter.global_position += part
				break
		var machine := hunter.state_machine
		var cycle := machine.threat_cycle
		report["lunged"] = report["lunged"] or (cycle != null and cycle.phase == Enums.ThreatPhase.LUNGE)
		report["closest"] = minf(report["closest"], hunter.global_position.distance_to(player.global_position))
		report["inside"] = report["inside"] or (Vector2i((hunter.global_position / TILE).floor()) - CENTER).length() < 1.0
		if machine.current_id == Enums.DinoStateId.AGGRESSIVE:
			streak += DT
			report["aggressive_time"] += DT
			report["longest_aggressive"] = maxf(report["longest_aggressive"], streak)
		else:
			streak = 0.0
	report["damage"] = life - player.health.current_health
	return report


func _test_line_helpers() -> void:
	var line := GridLine.cells(Vector2(8, 8), Vector2(40, 8), 16.0)
	_check(line == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "GridLine: reta horizontal passa por 3 células")
	var diagonal := GridLine.cells(Vector2(1, 1), Vector2(47, 31), 16.0)
	_check(diagonal.front() == Vector2i(0, 0) and diagonal.back() == Vector2i(2, 1) and diagonal.size() >= 4,
			"GridLine: diagonal visita as células que cruza, da primeira à última")
	_check(GridLine.cells(Vector2(NAN, 0), Vector2.ZERO, 16.0).is_empty() and GridLine.cells(Vector2.ZERO, Vector2(5, 5), 0.0).is_empty()
			and GridLine.cells(Vector2(3, 3), Vector2(3, 3), 16.0).size() == 1, "GridLine: ponto ruim vira lista vazia; ponto só uma célula")
	var grid := BuildGrid.new()
	grid.add(Vector2i(1, 0), "wall")
	_check(grid.segment_blocked(_px(Vector2i(0, 0)), _px(Vector2i(2, 0)))
			and not grid.segment_blocked(_px(Vector2i(0, 1)), _px(Vector2i(2, 1)))
			and not grid.segment_blocked(_px(Vector2i(0, 0)), _px(Vector2i(1, 0))),
			"segment_blocked: parede no meio bloqueia; fora do caminho não; a célula da ponta não conta")
	grid.add(Vector2i(1, 1), "door")
	var through_door := grid.segment_blocked(_px(Vector2i(0, 1)), _px(Vector2i(2, 1)))
	grid.set_open(Vector2i(1, 1), true)
	_check(through_door and not grid.segment_blocked(_px(Vector2i(0, 1)), _px(Vector2i(2, 1))),
			"segment_blocked: porta fechada bloqueia e aberta deixa passar")


func _test_ring_blocks_the_raptor() -> void:
	var world := _shelter(false)
	var player: Player = world["player"]
	var provider := (world["navigation"] as NavigationWorld).provider
	_check(provider.is_blocked(DOOR) and provider.is_blocked(CENTER + Vector2i(-1, -1)) and not provider.is_blocked(CENTER)
			and provider.request_path(CENTER + Vector2i(5, 0), CENTER, Enums.DinoSize.MEDIUM).status == PathResult.Status.NO_PATH,
			"MUN-04: as peças do grid valem no A*: o anel fechado não tem caminho para o centro")
	var raptor := _raptor(world, _px(CENTER + Vector2i(6, 0)))
	var report := _walk(world, raptor, RING_SECONDS)
	_check(report["aggressive_time"] > 0.0, "o raptor chegou a ficar bravo (a simulação provoca de verdade)")
	_check(report["damage"] == 0.0 and player.health.current_health == 100000.0, "o raptor não morde quem está dentro do anel")
	_check(report["closest"] > TILE * 1.5 and not report["inside"],
			"o raptor não alcança o jogador dentro do anel (mais perto: %.1f px)" % report["closest"])
	_check(not report["lunged"], "e nunca chega à investida contra a parede")


## O raptor já nasce colado no anel, dentro do raio do rodeio: sem rota não roda nem investe contra a parede, desiste.
func _test_raptor_next_to_the_wall() -> void:
	var world := _shelter(false)
	var raptor := _raptor(world, _px(CENTER + Vector2i(2, 0)))
	var report := _walk(world, raptor, 10.0)
	_check(report["aggressive_time"] > 0.0 and not report["lunged"] and report["damage"] == 0.0,
			"colado na parede e sem rota: não investe contra ela e não fere")
	_check(report["longest_aggressive"] <= 4.0, "e desiste em até 4 s (%.1f s)" % report["longest_aggressive"])


func _test_open_door_lets_it_in() -> void:
	var world := _shelter(true)
	var player: Player = world["player"]
	var provider := (world["navigation"] as NavigationWorld).provider
	_check(provider.request_path(CENTER + Vector2i(5, 0), CENTER, Enums.DinoSize.MEDIUM).is_ok(),
			"com a porta aberta há caminho até o centro")
	var raptor := _raptor(world, _px(CENTER + Vector2i(6, 0)))
	var report := _walk(world, raptor, RING_SECONDS)
	_check(report["damage"] > 0.0 and report["closest"] <= 32.0 + 4.0,
			"a porta aberta deixa passar: o raptor chega e morde (dano %.0f, mais perto %.1f px)" % [report["damage"], report["closest"]])
	_check(player.health.current_health < 100000.0, "o jogador levou a mordida")


## A distância sozinha deixaria morder: os dois corpos (14 px) encostados na parede de 16 px, um de cada lado, a 29,9 px um do
## outro (alcance do golpe 30). Sem navegação (anda em linha reta) e parado, para só a regra da mordida estar em jogo.
func _test_bite_does_not_cross_the_wall() -> void:
	var world := _shelter(false)
	var player: Player = world["player"]
	player.global_position = _px(CENTER) + Vector2(1.1, 0.0)
	var raptor := _raptor(world, player.global_position + Vector2(29.9, 0.0), false)
	var distance := raptor.global_position.distance_to(player.global_position)
	world["frozen"] = true
	var grid: BuildGrid = world["grid"]
	var behind_wall := grid.segment_blocked(raptor.global_position, player.global_position)
	var report := _walk_frozen(world, raptor, 6.0)
	_check(distance <= RAPTOR.threat_profile.attack_reach_px and behind_wall,
			"preparo: ao alcance pela distância (%.1f px) e com a porta fechada no meio" % distance)
	_check(report["lunged"] and report["damage"] == 0.0, "a investida parada na parede não fere: a mordida não atravessa")
	grid.set_open(DOOR, true)
	var open_world_player := player.health.current_health
	_walk_frozen(world, raptor, 6.0)
	_check(player.health.current_health < open_world_player,
			"controle: com a porta aberta, a mesma posição morde (o teste não é vazio)")


## `_walk` sem mover o corpo (a posição é a do teste).
func _walk_frozen(world: Dictionary, hunter: Dino, seconds: float) -> Dictionary:
	var player: Player = world["player"]
	var life := player.health.current_health
	var lunged := false
	var authority: WorldAuthority = world["authority"]
	var zone: DinoZone = world["zone"]
	var system: PredationSystem = world["system"]
	for _i in roundi(seconds / DT):
		authority.clock.advance(DT)
		zone.reclassify()
		system.tick(DT)
		hunter.observe_owner()
		hunter.observe_targets()
		hunter.state_machine.tick(DT)
		lunged = lunged or (hunter.state_machine.threat_cycle != null and hunter.state_machine.threat_cycle.phase == Enums.ThreatPhase.LUNGE)
	return {"lunged": lunged, "damage": life - player.health.current_health}


## Sem rota o carnívoro desiste em poucos segundos (não fica na parede até o tempo do episódio) e fica em alerta fora.
func _test_raptor_gives_up_and_stays_out() -> void:
	var world := _shelter(false)
	var raptor := _raptor(world, _px(CENTER + Vector2i(6, 0)))
	var report := _walk(world, raptor, 10.0)
	_check(report["longest_aggressive"] > 0.0 and report["longest_aggressive"] <= 4.0,
			"sem rota o bravo desiste em até 4 s (o mais longo foi %.1f s), sem insistir na parede" % report["longest_aggressive"])
	_check(report["aggressive_time"] <= 6.0, "e nem volta a insistir logo: o alerta segura (%.1f s bravo em 10 s)" % report["aggressive_time"])
