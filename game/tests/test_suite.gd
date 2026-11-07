# SPDX-License-Identifier: MIT
class_name TestSuite
extends RefCounted
## Base dos grupos de teste de `run_tests.gd`: guarda a raiz da árvore, o registro de nós para liberar e o
## `_check` do runner, e traz os auxiliares que mais de um grupo usa. Não é um runner.

const DinoScene := preload("res://src/entities/dino/Dino.tscn")
const PlayerScene := preload("res://src/entities/player/Player.tscn")

var _root: Node
var _track: Callable
var _check_fn: Callable


func _init(root: Node, track: Callable, check: Callable) -> void:
	_root = root
	_track = track
	_check_fn = check


func _check(condition: bool, label: String) -> void:
	_check_fn.call(condition, label)


func _make_machine() -> DinoStateMachine:
	var machine: DinoStateMachine = _track.call(DinoStateMachine.new())
	machine.torpor = _track.call(TorporComponent.new())
	machine.rng.seed = 42
	machine.start()
	return machine


func _spawn_dino() -> Dino:
	var dino: Dino = DinoScene.instantiate()
	_root.add_child(dino)
	_track.call(dino)
	return dino


func _spawn_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	_root.add_child(player)
	_track.call(player)
	_root.add_child(TestWorld.arm(player, [], _track))  # o jogador age pela autoridade, como no jogo
	return player


## Dino selvagem já inconsciente, com comida ideal no estoque.
func _make_sleeping_dino(berries: int) -> Dino:
	var dino := _spawn_dino()
	dino.torpor.add_torpor(100.0)
	dino.inventory.add("berry", berries)
	return dino
