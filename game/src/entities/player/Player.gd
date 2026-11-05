# SPDX-License-Identifier: MIT
class_name Player
extends CharacterBody2D
## Corpo do jogador: lê o input, aplica a velocidade à física e compõe os atributos.
## As regras ficam nos componentes. Só este corpo conhece `Input`; a regra de
## movimento (`apply_input`) recebe a direção pronta e é testável sem input real.
##
## Interação: o detector (Area2D) enxerga as `InteractableArea` no alcance e o
## `target` é a mais próxima. `try_interact` e `attack` são as ações em si, chamáveis
## sem teclado. `input_locked` (ligado pela tela de inventário) congela o jogador.

## Alvo mudou (ou null). Serve ao prompt e ao painel da criatura.
signal target_changed(target: InteractableArea)
## O jogador interagiu com um alvo disponível; quem abre a tela é o mundo.
signal interacted(target: InteractableArea)
signal input_lock_changed(locked: bool)
## O golpe acertou uma criatura (a apresentação anima e toca o som).
signal attacked
## Comeu um item (quem mostra o efeito é a apresentação).
signal ate(item_id: String)

@export var walk_speed: float = 70.0
@export var sprint_speed: float = 120.0
## Arma equipada: dano, torpor e recarga vêm dos dados (`res://data/weapons/`).
## Números do jogador (fome, recarga de comida, ofego) vindos dos dados.
@export var rules: PlayerRules = preload("res://data/balance/player_rules.tres")
@export var weapon: WeaponDef = preload("res://data/weapons/sleep_staff.tres")
## Comida inicial para poder testar o ciclo de domesticação (id -> quantidade).
@export var starting_items: Dictionary = {Items.BERRY: 10, Items.MEAT: 4, Items.FERN: 3}

var target: InteractableArea = null
var input_locked: bool = false:
	set(value):
		if input_locked != value:
			input_locked = value
			input_lock_changed.emit(value)

var _in_range: Array[InteractableArea] = []
var _attack_timer: float = 0.0
var _use_timer: float = 0.0

## Sprite: só a apresentação (`PlayerView`) escolhe o quadro.
@onready var visual: Sprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hunger: HungerComponent = $HungerComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var hotbar: HotbarComponent = $HotbarComponent
@onready var detector: Area2D = $InteractionDetector


func _ready() -> void:
	hunger.decay_per_second = rules.hunger_decay_per_second
	stamina.rules = rules
	hunger.starved.connect(health.take_damage)
	detector.area_entered.connect(_on_area_entered)
	detector.area_exited.connect(_on_area_exited)
	# O save é restaurado depois do _ready (from_dict exige o nó na árvore) e sobrescreve isto.
	for item_id: Variant in starting_items:
		if item_id is String:
			inventory.add(item_id, int(starting_items[item_id]))
			hotbar.assign(hotbar.first_free(), item_id)


func _physics_process(delta: float) -> void:
	tick(delta)
	var direction := Vector2.ZERO if input_locked else read_direction()
	velocity = apply_input(direction, Input.is_action_pressed("sprint"), delta)
	move_and_slide()


## Passo de tempo da parte de interação: recarga do golpe e escolha do alvo.
func tick(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_use_timer = maxf(_use_timer - delta, 0.0)
	update_target()


## Única leitura de input de ações. Só dispara fora de telas.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("attack"):
		attack()
	else:
		for slot in HotbarComponent.SLOT_COUNT:
			if event.is_action_pressed("hotbar_%d" % (slot + 1)):
				request_use_item(slot)
				break


## Única leitura de input. `get_vector` já devolve comprimento no máximo 1, então
## a diagonal não é mais rápida que o eixo.
func read_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Regra de movimento: converte direção + pedido de corrida na velocidade do frame
## e gasta/regenera a stamina. Só corre quem está se movendo e tem stamina.
func apply_input(direction: Vector2, wants_sprint: bool, delta: float) -> Vector2:
	if health.is_dead():
		return Vector2.ZERO
	direction = direction.limit_length(1.0)
	var moving := direction != Vector2.ZERO
	var sprinting := wants_sprint and moving and stamina.can_sprint()
	stamina.tick(delta, sprinting)
	return direction * (sprint_speed if sprinting else walk_speed)


## Escolhe o interagível mais próximo no alcance e avisa se mudou.
func update_target() -> void:
	var best: InteractableArea = null
	var best_distance := INF
	for area in _in_range:
		if not is_instance_valid(area):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			best = area
	if best != target:
		target = best
		target_changed.emit(target)


## Interage com o alvo se a regra da entidade permitir. Retorna true se interagiu.
func try_interact() -> bool:
	if input_locked or health.is_dead() or target == null or not target.can_interact():
		return false
	interacted.emit(target)
	return true


## Golpe da arma equipada na criatura selvagem ao alcance (dano e torpor). Retorna true se acertou.
func attack() -> bool:
	if input_locked or health.is_dead() or _attack_timer > 0.0 or target == null:
		return false
	var dino := target.entity as Dino
	if dino == null or not dino.receive_hit(weapon.damage, weapon.torpor, TamingRules.ATTACKER_PLAYER):
		return false
	_attack_timer = weapon.cooldown
	attacked.emit()
	return true


## Intenção "usar o atalho `slot`" (0 a 8): quem lê a tecla só pede, e as regras decidem
## aqui. Comida: o jogador SEMPRE a consome (come 1 e recupera fome), mesmo com uma criatura
## dormindo ao alcance (decisão do dono); não gasta se a fome está cheia. A criatura recebe
## comida só pela tela do inventário dela. Sem estoque, sem efeito.
## Arma/ferramenta: não há equipamento trocável no modelo atual (`weapon` é fixo).
## Retorna true se algo foi consumido. Vira `request_use_item(actor_id, slot)` no NET-01 (ADR-001).
func request_use_item(slot: int) -> bool:
	if input_locked or health.is_dead() or _use_timer > 0.0:
		return false
	var item_id := hotbar.item_at(slot)
	var restore := Items.hunger_restore_of(item_id)
	if item_id == "" or restore <= 0.0 or hunger.current_hunger >= hunger.max_hunger or inventory.remove(item_id, 1) < 1:
		return false
	hunger.eat(restore)
	ate.emit(item_id)
	_use_timer = rules.food_cooldown
	return true


func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"health": health.to_dict(),
		"stamina": stamina.to_dict(),
		"hunger": hunger.to_dict(),
		"inventory": inventory.to_dict(),
		"hotbar": hotbar.to_dict(),
	}


## Chame depois de adicionar à árvore. Silencioso: não emite `died` nem `starved`.
func from_dict(data: Dictionary) -> void:
	var saved_position := SafeRead.dict(data.get("position"))
	position = Vector2(
		SafeRead.number(saved_position.get("x"), position.x, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), position.y, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT)
	)
	health.from_dict(SafeRead.dict(data.get("health")))
	stamina.from_dict(SafeRead.dict(data.get("stamina")))
	hunger.from_dict(SafeRead.dict(data.get("hunger")))
	inventory.from_dict(SafeRead.dict(data.get("inventory")))
	hotbar.from_dict(SafeRead.dict(data.get("hotbar")))


func _on_area_entered(area: Area2D) -> void:
	if area is InteractableArea and not _in_range.has(area):
		_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	_in_range.erase(area)
