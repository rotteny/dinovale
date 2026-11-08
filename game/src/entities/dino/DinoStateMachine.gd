# SPDX-License-Identifier: MIT
class_name DinoStateMachine
extends Node
## Cérebro da criatura. Não conhece física nem sprite: publica `desired_direction`
## para o corpo e `state_changed` para a apresentação, então roda igual em
## servidor headless.
##
##   IDLE <-> WANDER
##   IDLE/WANDER -> CHASE -> IDLE     (agressivo avista o alvo; desiste por distância, tempo ou sem alvo)
##   qualquer estado -> UNCONSCIOUS   (TorporComponent.knocked_out)
##   UNCONSCIOUS -> IDLE              (acordou selvagem)
##   UNCONSCIOUS -> TAMED             (mark_tamed, ou acordou já domesticado)
##
## Domesticado e acordado, o estado TAMED obedece à ordem (`Enums.DinoOrder`): STAY fica parado e
## FOLLOW anda até o dono. A máquina não vê o mundo: o corpo informa as posições por `observe`.

signal state_changed(previous: Enums.DinoStateId, current: Enums.DinoStateId)
## A ordem do domado mudou (a apresentação mostra o texto). Restaurar um save não emite.
signal order_changed(order: Enums.DinoOrder)

@export var torpor: TorporComponent
## Duração mínima e máxima, em segundos, de cada estado.
@export var idle_seconds := Vector2(1.0, 3.0)
@export var wander_seconds := Vector2(1.0, 4.0)
@export var order_rules: DinoOrderRules = preload("res://data/balance/dino_order_rules.tres")

## Fixe `rng.seed` para ter um comportamento reproduzível.
var rng := RandomNumberGenerator.new()
var is_tamed := false
var desired_direction := Vector2.ZERO
var current_id := Enums.DinoStateId.IDLE
## Ordem atual. Só vale para o domesticado; vai no save pelo nome.
var order := Enums.DinoOrder.STAY
## Multiplicador da velocidade de andar que a ordem pede (1 = normal).
var speed_multiplier := 1.0
## Onde a criatura e o dono estão, informado pelo corpo a cada quadro (`observe`).
var self_position := Vector2.ZERO
var owner_position := Vector2.ZERO
var owner_known := false
## Atributos da espécie (percepção e perseguição); só o agressivo os usa. Preenchido por `configure`.
var stats: DinoBaseStats = null
## Velocidade de andar do corpo, em pixels por segundo, e lado do tile: a perseguição vira multiplicador sobre ela.
var walk_speed := 40.0
var tile_px := 16.0
## Alvo da perseguição (o corpo informa por `observe_target`); `target_known` falso = nenhum à vista.
var target_position := Vector2.ZERO
var target_known := false
var _alert_left := 0.0

var _states: Dictionary = {}


func _ready() -> void:
	start()


func _physics_process(delta: float) -> void:
	tick(delta)


## Chamado pelo `_ready`. Pode ser chamado antes, por testes ou ao restaurar um save.
func start() -> void:
	if not _states.is_empty():
		return
	_states = {
		Enums.DinoStateId.IDLE: DinoIdleState.new(),
		Enums.DinoStateId.WANDER: DinoWanderState.new(),
		Enums.DinoStateId.UNCONSCIOUS: DinoUnconsciousState.new(),
		Enums.DinoStateId.TAMED: DinoTamedState.new(),
		Enums.DinoStateId.CHASE: DinoChaseState.new(),
	}
	for state: DinoState in _states.values():
		state.machine = self
	torpor.knocked_out.connect(_on_knocked_out)
	torpor.woke_up.connect(_on_woke_up)
	current_id = Enums.DinoStateId.UNCONSCIOUS if torpor.is_unconscious else _awake_state()
	_states[current_id].enter()


func tick(delta: float) -> void:
	_alert_left = maxf(_alert_left - delta, 0.0)
	if _can_start_chase():
		transition_to(Enums.DinoStateId.CHASE)
	_states[current_id].tick(delta)


## Dados da espécie e do corpo para a percepção e a perseguição.
func configure(species: DinoBaseStats, body_speed: float, tile_size: float) -> void:
	stats = species
	walk_speed = maxf(body_speed, 1.0)
	tile_px = tile_size


## O corpo informa o alvo mais próximo que pode ser perseguido (`known` falso = nenhum).
func observe_target(at: Vector2, known: bool) -> void:
	target_position = at
	target_known = known


## Distância efetiva ao alvo (elipse do GDD 4.2: o vertical pesa mais), em pixels.
func target_distance() -> float:
	var offset := target_position - self_position
	var weight := stats.perception_vertical_weight if stats != null else 1.0
	return Vector2(offset.x, offset.y * weight).length()


func chase_speed_multiplier() -> float:
	return stats.chase_speed / walk_speed if stats != null else 1.0


## Entra em alerta: não persegue de novo por `alert_seconds` (chamado ao sair da perseguição).
func start_alert() -> void:
	_alert_left = stats.alert_seconds if stats != null else 0.0


## Alcançou o alvo sem poder atacar: alerta mais longo que o da desistência comum (não persegue de novo logo).
func start_reached_alert() -> void:
	_alert_left = stats.reached_alert_seconds if stats != null else 0.0


func _can_start_chase() -> bool:
	if stats == null or not stats.aggressive or is_tamed or not target_known or _alert_left > 0.0:
		return false
	if current_id != Enums.DinoStateId.IDLE and current_id != Enums.DinoStateId.WANDER:
		return false
	return target_distance() <= stats.perception_tiles * tile_px


## O corpo informa onde a criatura está e onde o dono está (`known` falso = dono ausente do mundo).
func observe(self_at: Vector2, owner_at: Vector2, known: bool) -> void:
	self_position = self_at
	owner_position = owner_at
	owner_known = known


## Troca a ordem. Só o domesticado acordado obedece; devolve se a ordem passou a valer.
func set_order(next: Enums.DinoOrder) -> bool:
	if not is_tamed or current_id != Enums.DinoStateId.TAMED:
		return false
	if next != order:
		order = next
		_states[current_id].enter()  # reaplica a ordem à direção e à velocidade
		order_changed.emit(order)
	return true


func transition_to(next_id: Enums.DinoStateId) -> void:
	if next_id == current_id:
		return
	var previous := current_id
	_states[previous].exit()
	current_id = next_id
	_states[next_id].enter()
	state_changed.emit(previous, next_id)


## Conclui a domesticação e acorda a criatura. Só vale para uma criatura
## selvagem desmaiada; retorna false nos outros casos.
func mark_tamed() -> bool:
	if is_tamed or current_id != Enums.DinoStateId.UNCONSCIOUS:
		return false
	is_tamed = true
	torpor.reset()
	return true


func to_dict() -> Dictionary:
	return {
		"state": Enums.DinoStateId.find_key(current_id),
		"is_tamed": is_tamed,
		"order": Enums.DinoOrder.find_key(order),
	}


## Restaure o TorporComponent ANTES: ele é a fonte da verdade sobre a consciência,
## e um save inconsistente é corrigido a partir dele.
func from_dict(data: Dictionary) -> void:
	start()
	is_tamed = SafeRead.flag(data.get("is_tamed"), is_tamed)
	# Ordem só existe para o domado; nome desconhecido cai em STAY. Restaurar não emite `order_changed`.
	var saved_order: int = Enums.DinoOrder.get(SafeRead.text(data.get("order"), ""), Enums.DinoOrder.STAY)
	order = saved_order as Enums.DinoOrder if is_tamed else Enums.DinoOrder.STAY
	var saved_id: int = Enums.DinoStateId.get(SafeRead.text(data.get("state"), ""), -1)
	transition_to(_restored_state(saved_id))
	if current_id == Enums.DinoStateId.TAMED:
		_states[current_id].enter()  # a ordem restaurada vale já (direção e velocidade), sem evento


func _restored_state(saved_id: int) -> Enums.DinoStateId:
	if torpor.is_unconscious:
		return Enums.DinoStateId.UNCONSCIOUS
	if not is_tamed and saved_id == Enums.DinoStateId.WANDER:
		return Enums.DinoStateId.WANDER
	return _awake_state()


func _awake_state() -> Enums.DinoStateId:
	return Enums.DinoStateId.TAMED if is_tamed else Enums.DinoStateId.IDLE


func _on_knocked_out() -> void:
	transition_to(Enums.DinoStateId.UNCONSCIOUS)


func _on_woke_up() -> void:
	transition_to(_awake_state())
