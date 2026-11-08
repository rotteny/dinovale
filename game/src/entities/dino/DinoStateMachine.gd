# SPDX-License-Identifier: MIT
class_name DinoStateMachine
extends Node
## Cérebro da criatura. Não conhece física nem sprite: publica `desired_direction`
## para o corpo e `state_changed` para a apresentação, então roda igual em
## servidor headless.
##
##   IDLE <-> WANDER
##   IDLE/WANDER -> AGGRESSIVE -> IDLE (bravo: leva golpe do jogador, ou o Agressivo avista o alvo; acalma sem
##                                      dano por 8 s, por distância ou tempo; sem rancor e fora do save)
##   qualquer estado -> UNCONSCIOUS   (TorporComponent.knocked_out)
##   UNCONSCIOUS -> IDLE              (acordou selvagem)
##   UNCONSCIOUS -> TAMED             (mark_tamed, ou acordou já domesticado)
##   TAMED -> STUCK -> TAMED          (domado em Seguir travou longe do dono e fora da tela: desiste SEM teleporte;
##                                     tenta de novo com ordem nova, ou com o dono perto/à vista depois de um intervalo)
##
## Domesticado e acordado, o estado TAMED obedece à ordem (`Enums.DinoOrder`): STAY fica parado e
## FOLLOW anda até o dono. A máquina não vê o mundo: o corpo informa as posições por `observe`.

signal state_changed(previous: Enums.DinoStateId, current: Enums.DinoStateId)
## A ordem do domado mudou (a apresentação mostra o texto). Restaurar um save não emite.
signal order_changed(order: Enums.DinoOrder)
## O domado desistiu de seguir (episódio novo de "ficou preso"). Emitido UMA vez por episódio: só rearma depois de
## o dino andar `stuck_clear_tiles`. A autoridade o anuncia no log (`tamed_stuck`).
signal got_stuck
## Ficou bravo ou se acalmou (a apresentação mostra ou apaga o "!"). Presentação apenas: não é evento de jogo.
signal aggression_changed(aggressive: bool)

@export var torpor: TorporComponent
## Duração mínima e máxima, em segundos, de cada estado.
@export var idle_seconds := Vector2(1.0, 3.0)
@export var wander_seconds := Vector2(1.0, 4.0)
@export var order_rules: DinoOrderRules = preload("res://data/balance/dino_order_rules.tres")
@export var nav_rules: NavigationRules = preload("res://data/balance/navigation_rules.tres")
@export var aggression: AggressionRules = preload("res://data/balance/aggression_rules.tres")

## Fixe `rng.seed` para ter um comportamento reproduzível.
var rng := RandomNumberGenerator.new()
var is_tamed := false
var desired_direction := Vector2.ZERO
var current_id := Enums.DinoStateId.IDLE
## Bravo agora? Vem do estado (não tem campo próprio, para nunca divergir) e nunca vai para o save.
var is_aggressive: bool:
	get:
		return current_id == Enums.DinoStateId.AGGRESSIVE
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
## Quem guia o corpo pelo mapa (`PathProvider`); sem ele anda em linha reta. A zona o entrega ao registrar o dino.
var navigation: PathProvider = null:
	set(value):
		navigation = value
		follower.provider = value
## Segue um destino e percebe quando trava (perseguição e Seguir do domado).
var follower := PathFollower.new()

var _alert_left := 0.0
var _aggression_signaled := false
var _stuck_episode_open := false
var _stuck_origin := Vector2.ZERO

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
		Enums.DinoStateId.AGGRESSIVE: DinoAggressiveState.new(),
		Enums.DinoStateId.STUCK: DinoStuckState.new(),
	}
	follower.rules = nav_rules
	for state: DinoState in _states.values():
		state.machine = self
	torpor.knocked_out.connect(_on_knocked_out)
	torpor.woke_up.connect(_on_woke_up)
	current_id = Enums.DinoStateId.UNCONSCIOUS if torpor.is_unconscious else _awake_state()
	_states[current_id].enter()


func tick(delta: float) -> void:
	_alert_left = maxf(_alert_left - delta, 0.0)
	if _can_start_chase():
		transition_to(Enums.DinoStateId.AGGRESSIVE)
	_states[current_id].tick(delta)


## Dados da espécie e do corpo para a percepção e a perseguição.
func configure(species: DinoBaseStats, body_speed: float, tile_size: float) -> void:
	stats = species
	walk_speed = maxf(body_speed, 1.0)
	tile_px = tile_size
	follower.size_class = species.size


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


## O dino levou golpe do jogador (a autoridade só chama com o golpe aplicado e o alvo já informado por
## `observe_target`). Selvagem acordado fica bravo; já bravo, só zera o relógio de calma. Dormindo, domado ou
## preso não reage. A etapa 4 chama `reset_calm` também quando o dino ataca.
func provoke() -> void:
	if is_tamed or torpor.is_unconscious:
		return
	if current_id == Enums.DinoStateId.AGGRESSIVE:
		reset_calm()
	elif current_id == Enums.DinoStateId.IDLE or current_id == Enums.DinoStateId.WANDER:
		transition_to(Enums.DinoStateId.AGGRESSIVE)


## Dano dado ou recebido: o relógio de calma recomeça. Sem efeito fora do estado bravo.
func reset_calm() -> void:
	if is_aggressive:
		(_states[Enums.DinoStateId.AGGRESSIVE] as DinoAggressiveState).reset_calm()


## Segundos que faltam para acalmar sem novo dano (0 se não está bravo). Para teste e diagnóstico.
func calm_left() -> float:
	if not is_aggressive:
		return 0.0
	return (_states[Enums.DinoStateId.AGGRESSIVE] as DinoAggressiveState).calm_left()


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
	if not is_tamed or (current_id != Enums.DinoStateId.TAMED and current_id != Enums.DinoStateId.STUCK):
		return false
	if current_id == Enums.DinoStateId.STUCK:
		# Ordem nova (ou o G, mesmo igual à atual) é o jogador pedindo de novo: sai do preso e tenta.
		if next != order:
			order = next
			order_changed.emit(order)
		transition_to(Enums.DinoStateId.TAMED)
		return true
	if next != order:
		order = next
		_states[current_id].enter()  # reaplica a ordem à direção e à velocidade
		order_changed.emit(order)
	return true


## Abre o episódio de "ficou preso" (o `got_stuck` sai uma vez por episódio). Chamado ao entrar em STUCK.
func begin_stuck_episode() -> void:
	if _stuck_episode_open:
		return
	_stuck_episode_open = true
	_stuck_origin = self_position
	got_stuck.emit()


## Anda `stuck_clear_tiles` do ponto onde ficou preso: o episódio acaba e o próximo volta a avisar.
func update_stuck_episode() -> void:
	if _stuck_episode_open and self_position.distance_to(_stuck_origin) >= nav_rules.stuck_clear_tiles * tile_px:
		_stuck_episode_open = false


func transition_to(next_id: Enums.DinoStateId) -> void:
	if next_id == current_id:
		return
	var previous := current_id
	_states[previous].exit()
	current_id = next_id
	_states[next_id].enter()
	state_changed.emit(previous, next_id)
	if is_aggressive != _aggression_signaled:
		_aggression_signaled = is_aggressive
		aggression_changed.emit(is_aggressive)


## Conclui a domesticação e acorda a criatura. Só vale para uma criatura
## selvagem desmaiada; retorna false nos outros casos.
func mark_tamed() -> bool:
	if is_tamed or current_id != Enums.DinoStateId.UNCONSCIOUS:
		return false
	is_tamed = true
	torpor.reset()
	return true


func to_dict() -> Dictionary:
	# Bravo não vai para o save: quem foi salvo bravo volta calmo (Idle), sem rancor.
	var saved_id := Enums.DinoStateId.IDLE if is_aggressive else current_id
	return {
		"state": Enums.DinoStateId.find_key(saved_id),
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
