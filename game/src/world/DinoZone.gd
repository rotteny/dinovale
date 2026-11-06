# SPDX-License-Identifier: MIT
class_name DinoZone
extends Node
## Aplica a zona ativa (MUN-05) aos dinos do mundo: perto do jogador pensa e se move com física; no meio
## só anda em dado a cada `far_step_seconds` (sem física, sem desenho); longe dorme. Reclassifica de tempos
## em tempos, não a cada quadro. Quem não é selvagem em rotina (domado, desacordado, em doma) fica ativo
## pelo estado. `tick(delta)` é público (testável sem quadros); `_physics_process` só delega.
## O jogador é quem dá o foco; no co-op é a distância ao mais próximo (R43).

signal modes_changed
## Um dino mudou de modo (a apresentação liga e desliga o que é dele).
signal mode_applied(dino: Dino, mode: ActivityZone.Mode)

const STEP_DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
]

@export var rules: ZoneRules = preload("res://data/world/zone_rules.tres")

## Terra por onde o dino distante pode passear (sem ela, não anda). Vem do mundo.
var map: IslandMap = null
## Quem dá o foco (um por jogador). Morto ainda conta pela posição.
var foci: Array[Node2D] = []
var active_count: int = 0
var far_count: int = 0
var dormant_count: int = 0

var _dinos: Array[Dino] = []
var _modes: Dictionary = {}  # Dino -> ActivityZone.Mode
var _clock: float = 0.0
var _far_clock: float = 0.0
var _rng := SeededRng.new()


func _init() -> void:
	_rng.seed_from(["dino_zone"])


func _physics_process(delta: float) -> void:
	tick(delta)


## Põe o dino na zona. Já entra classificado (um dino que nasce longe não passa um quadro pensando).
## `reclassify_now` falso permite pôr muitos de uma vez e chamar `reclassify()` no fim.
func register(dino: Dino, reclassify_now: bool = true) -> void:
	if dino == null or _dinos.has(dino):
		return
	_dinos.append(dino)
	if reclassify_now:
		reclassify()


func unregister(dino: Dino) -> void:
	_dinos.erase(dino)
	_modes.erase(dino)


## Cópia da lista de dinos da zona.
func dinos() -> Array[Dino]:
	_prune()
	return _dinos.duplicate()


func dino_count() -> int:
	return _dinos.size()


## Modo atual do dino (ACTIVE se ele não está na zona).
func mode_of(dino: Dino) -> ActivityZone.Mode:
	return _modes.get(dino, ActivityZone.Mode.ACTIVE)


## Passo de tempo: reclassifica a cada `reevaluate_seconds` e faz os distantes passearem a cada `far_step_seconds`.
func tick(delta: float) -> void:
	_clock += delta
	if _clock >= rules.reevaluate_seconds:
		_clock = 0.0
		reclassify()
	_far_clock += delta
	if _far_clock >= rules.far_step_seconds:
		_far_clock = 0.0
		_step_far_dinos()


## Reclassifica todos agora e aplica o modo a cada um (só mexe em quem mudou).
func reclassify() -> void:
	_prune()
	var distances := PackedFloat32Array()
	var pinned := PackedByteArray()
	distances.resize(_dinos.size())
	pinned.resize(_dinos.size())
	for i in _dinos.size():
		distances[i] = _distance_to_focus(_dinos[i].global_position)
		pinned[i] = 1 if is_pinned(_dinos[i]) else 0
	var modes := ActivityZone.classify(distances, pinned, rules)
	var changed := false
	active_count = 0
	far_count = 0
	dormant_count = 0
	for i in _dinos.size():
		var dino := _dinos[i]
		match modes[i]:
			ActivityZone.Mode.ACTIVE:
				active_count += 1
			ActivityZone.Mode.FAR:
				far_count += 1
			_:
				dormant_count += 1
		if _modes.get(dino, -1) != modes[i]:
			_modes[dino] = modes[i]
			_apply(dino, modes[i])
			changed = true
	if changed:
		modes_changed.emit()


## Fica ativo pelo estado: tudo que não é selvagem acordado em rotina (andando ou parado). Domado, desacordado,
## em doma (progresso ou torpor) e o que tem dono precisam do relógio correndo.
func is_pinned(dino: Dino) -> bool:
	var machine := dino.state_machine
	if machine.is_tamed or dino.owner_player_id != "":
		return true
	if machine.current_id != Enums.DinoStateId.IDLE and machine.current_id != Enums.DinoStateId.WANDER:
		return true
	return dino.taming.taming_progress > 0.0 or dino.torpor.current_torpor > 0.0


func _apply(dino: Dino, mode: ActivityZone.Mode) -> void:
	var active := mode == ActivityZone.Mode.ACTIVE
	dino.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	dino.visible = active
	mode_applied.emit(dino, mode)


## Cada distante dá um passo de `far_step_tiles` numa direção sorteada, só se o destino for terra firme do
## mapa. Sem física: não há colisão contra árvore aqui (o dino não está sendo visto; ao voltar a ser ativo, a
## física o desencosta). Parte dos passos é pausa, para o grupo não marchar.
func _step_far_dinos() -> void:
	if map == null or not map.is_valid():
		return
	var step := rules.far_step_tiles * rules.tile_size
	for dino in _dinos:
		if _modes.get(dino, -1) != ActivityZone.Mode.FAR:
			continue
		var pick := _rng.next_below(STEP_DIRECTIONS.size() + 4)
		if pick >= STEP_DIRECTIONS.size():
			continue
		var target := dino.position + STEP_DIRECTIONS[pick].normalized() * step
		if map.is_land(map.cell_of(target)):
			dino.position = target


func _distance_to_focus(point: Vector2) -> float:
	var best := INF
	for focus in foci:
		if is_instance_valid(focus):
			best = minf(best, point.distance_to(focus.global_position))
	return best


func _prune() -> void:
	var alive: Array[Dino] = []
	for dino in _dinos:
		if is_instance_valid(dino) and not dino.is_queued_for_deletion():
			alive.append(dino)
		else:
			_modes.erase(dino)
	_dinos = alive
