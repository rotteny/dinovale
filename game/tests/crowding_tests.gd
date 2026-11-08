# SPDX-License-Identifier: MIT
class_name CrowdingTests
extends AuthorityTests
## Jogador espremido por dinos (bug do playtest de 08/11: dois selvagens grudados e o jogador sem andar). Garante que ele
## sai em qualquer direção livre, com os dinos parados ou perseguindo encostados, e que a IA para na distância mínima.

const RAPTOR: DinoBaseStats = preload("res://data/dino/utahraptor.tres")
const STEPS := 30  # meio segundo a 60 quadros
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]


func run() -> void:
	await _test_escape_between_still_dinos()
	_release_worlds()
	await _test_escape_while_chased()
	_release_worlds()
	_test_chase_keeps_distance()
	_test_collision_returns_when_free()
	_release_worlds()


## Dois dinos encostados no jogador (um de cada lado, e outro par em cima e embaixo), ambos sobrepostos.
func _pinch(vertical: bool) -> Dictionary:
	var player := _player_at(Vector2(400, 400))
	var offset := Vector2(0, 8) if vertical else Vector2(10, 0)  # pés de 14x14: ainda sobrepostos ao jogador (12x8)
	var first := _dino_at(player.position + offset)
	var second := _dino_at(player.position - offset)
	return {"player": player, "dinos": [first, second]}


## Libera os dinos e jogadores soltos de uma montagem anterior (o grupo de dinos é global na árvore).
func _free_dinos() -> void:
	for node in _root.get_tree().get_nodes_in_group(Dino.GROUP):
		node.free()
	for child in _root.get_children():
		if child is Player:
			child.free()


## Um passo de física do jogador, andando em `direction` à velocidade de caminhada.
func _walk(player: Player, direction: Vector2) -> void:
	await _root.get_tree().physics_frame
	player.velocity = direction.normalized() * player.walk_speed
	player.update_dino_collision()
	player.move_and_slide()


## Um passo do dino perseguindo o jogador na velocidade de perseguição, parando na distância mínima dos dados (como a IA).
func _chase(dino: Dino, player: Player) -> void:
	var away := player.global_position - dino.global_position
	var stop: float = RAPTOR.chase_stop_px
	dino.velocity = Vector2.ZERO if away.length() <= stop else away.normalized() * 90.0
	dino.move_and_slide()


func _test_escape_between_still_dinos() -> void:
	for vertical: bool in [false, true]:
		for direction in DIRECTIONS:
			_free_dinos()
			var pair := _pinch(vertical)
			var player: Player = pair["player"]
			var start := player.position
			for step in STEPS:
				await _walk(player, direction)
			var gone := (player.position - start).dot(direction.normalized())
			_check(gone > 20.0, "preso entre dinos parados (%s): sai para %s (%.0f px)" % [
					"em cima e embaixo" if vertical else "dos lados", direction, gone])
			_release_worlds()


func _test_escape_while_chased() -> void:
	for direction in DIRECTIONS:
		_free_dinos()
		var pair := _pinch(false)
		var player: Player = pair["player"]
		var start := player.position
		for step in STEPS * 2:
			await _walk(player, direction)
			for dino: Dino in pair["dinos"]:
				_chase(dino, player)
		var gone := (player.position - start).dot(direction.normalized())
		_check(gone > 30.0, "perseguido por dois dinos encostados: sai para %s (%.0f px)" % [direction, gone])
		_release_worlds()


## A perseguição para a `chase_stop_px` do alvo: não empurra para dentro do jogador.
func _test_chase_keeps_distance() -> void:
	var stats: DinoBaseStats = RAPTOR
	var machine: DinoStateMachine = _track.call(DinoStateMachine.new())
	machine.torpor = _track.call(TorporComponent.new())
	machine.rng.seed = 42
	machine.start()
	machine.configure(stats, 40.0, 16.0)
	machine.observe(Vector2.ZERO, Vector2.ZERO, false)
	machine.observe_target(Vector2(5.0 * 16.0, 0.0), true)
	machine.tick(0.1)
	_check(machine.current_id == Enums.DinoStateId.AGGRESSIVE and machine.desired_direction.x > 0.9, "longe, o dino persegue")
	machine.observe_target(Vector2(stats.chase_stop_px - 2.0, 0.0), true)
	machine.tick(0.1)
	_check(machine.desired_direction == Vector2.ZERO, "na distância mínima ele para de empurrar")
	_check(machine.current_id != Enums.DinoStateId.AGGRESSIVE, "sem ataque, ao alcançar ele desiste")
	machine.observe_target(Vector2(5.0 * 16.0, 0.0), true)
	machine.tick(10.0)
	_check(machine.current_id != Enums.DinoStateId.AGGRESSIVE, "em alerta longo ele não volta a perseguir logo (10 s)")
	for i in 111:  # quadros pequenos: um tick de 11 s já contaria como 11 s de perseguição (o relógio de 8 s acalmaria)
		machine.tick(0.1)
	_check(machine.current_id == Enums.DinoStateId.AGGRESSIVE, "passado o alerta, volta a perseguir")
	_check(stats.chase_stop_px >= 28.0, "a distância mínima vem do dado e passa dos raios dos corpos")


## Livre de dinos, o jogador volta a ser barrado por eles (a colisão não foi apagada).
func _test_collision_returns_when_free() -> void:
	_free_dinos()
	var player := _player_at(Vector2(400, 400))
	var dino := _dino_at(Vector2(440, 400))
	player.update_dino_collision()
	_check((player.collision_mask & Dino.BODY_LAYER) != 0, "afastado, o jogador colide com dinos")
	dino.position = player.position + Vector2(6, 0)
	player.update_dino_collision()
	_check((player.collision_mask & Dino.BODY_LAYER) == 0 and (player.collision_mask & 1) != 0,
			"sobreposto, ele atravessa dinos mas o terreno segue valendo")
