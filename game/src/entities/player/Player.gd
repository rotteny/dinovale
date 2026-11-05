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
## O item em mãos mudou (`iid` do equipado, "" = mãos livres).
signal equipped_changed(iid: String)

@export var walk_speed: float = 70.0
@export var sprint_speed: float = 120.0
## Números do jogador (fome, recarga de comida e de troca, ofego) vindos dos dados.
@export var rules: PlayerRules = preload("res://data/balance/player_rules.tres")
## Golpe de mãos livres (Soco): dano, torpor e recarga vêm dos dados (`res://data/weapons/`).
@export var unarmed: WeaponDef = preload("res://data/weapons/punch.tres")
## Equipamento inicial (item individual, sem receita no M1): nasce no inventário e na barra.
@export var starting_equipment: Array[String] = [Items.SLEEP_STAFF]
## Comida inicial para poder testar o ciclo de domesticação (id -> quantidade).
@export var starting_items: Dictionary = {Items.BERRY: 10, Items.MEAT: 4, Items.FERN: 3}

var target: InteractableArea = null
## `iid` do item em mãos; "" = mãos livres (Soco). Sempre aponta para um item do inventário.
var equipped_iid: String = ""
var input_locked: bool = false:
	set(value):
		if input_locked != value:
			input_locked = value
			input_lock_changed.emit(value)

var _in_range: Array[InteractableArea] = []
var _attack_timer: float = 0.0
var _eat_timer: float = 0.0
var _equip_timer: float = 0.0

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
	for item_id in starting_equipment:
		if inventory.add(item_id, 1) == 0:
			hotbar.assign_iid(hotbar.first_free(), _newest_iid(item_id), item_id)
	inventory.changed.connect(_on_inventory_changed)
	hotbar.changed.connect(_on_inventory_changed)


func _physics_process(delta: float) -> void:
	tick(delta)
	var direction := Vector2.ZERO if input_locked else read_direction()
	velocity = apply_input(direction, Input.is_action_pressed("sprint"), delta)
	move_and_slide()


## Passo de tempo da parte de interação: recarga do golpe e escolha do alvo.
func tick(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_eat_timer = maxf(_eat_timer - delta, 0.0)
	_equip_timer = maxf(_equip_timer - delta, 0.0)
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
	var weapon := current_weapon()
	if dino == null or not dino.receive_hit(weapon.damage, weapon.torpor, TamingRules.ATTACKER_PLAYER):
		return false
	_attack_timer = weapon.cooldown
	attacked.emit()
	return true


## Arma em mãos: a do item equipado, ou o Soco com as mãos livres.
func current_weapon() -> WeaponDef:
	var item := inventory.find_iid(equipped_iid)
	var weapon := Items.weapon_of(str(item.get("id", "")))
	return weapon if weapon != null else unarmed


## Intenção "usar o atalho `slot`" (0 a 8): quem lê a tecla só pede, e as regras decidem
## aqui. Comida: o jogador SEMPRE a consome (come 1 e recupera fome), mesmo com uma criatura
## dormindo ao alcance (decisão do dono); não gasta se a fome está cheia; a criatura recebe
## comida só pela tela do inventário dela. Equipamento (atalho por `iid`): SELECIONA; apertar
## a tecla do que já está em mãos desequipa (mãos livres, Soco). Só arma troca o equipado;
## comer não mexe nele. Sem estoque, sem efeito.
## Retorna true se algo foi consumido ou trocado. Vira `request_use_item(actor_id, slot)` no
## NET-01 (ADR-001).
func request_use_item(slot: int) -> bool:
	if input_locked or health.is_dead():
		return false
	var iid := hotbar.iid_at(slot)
	if iid != "":
		return _equip_timer <= 0.0 and _toggle_equipped(iid)
	if _eat_timer > 0.0:
		return false
	var item_id := hotbar.item_at(slot)
	var restore := rules.hunger_restore_of(item_id)
	if restore <= 0.0 or hunger.current_hunger >= hunger.max_hunger or inventory.remove(item_id, 1) < 1:
		return false
	hunger.eat(restore)
	ate.emit(item_id)
	_eat_timer = rules.food_cooldown
	return true


func _toggle_equipped(iid: String) -> bool:
	var item := inventory.find_iid(iid)
	if item.is_empty() or Items.weapon_of(item["id"]) == null:
		return false
	_set_equipped("" if equipped_iid == iid else iid)
	_equip_timer = rules.equip_cooldown
	return true


func _set_equipped(iid: String) -> void:
	if iid == equipped_iid:
		return
	equipped_iid = iid
	equipped_changed.emit(iid)


## O item em mãos saiu do inventário (movido, entregue) ou do atalho (limpo, trocado de lugar
## é outra coisa: continua na barra): volta a mãos livres. Só se equipa pela barra.
func _on_inventory_changed() -> void:
	if equipped_iid != "" and (not inventory.has_iid(equipped_iid) or hotbar.slot_of_iid(equipped_iid) < 0):
		_set_equipped("")


func _newest_iid(item_id: String) -> String:
	for i in range(inventory.slot_count() - 1, -1, -1):
		var slot := inventory.get_slot(i)
		if slot.get("id", "") == item_id and slot.has("iid"):
			return slot["iid"]
	return ""


func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"health": health.to_dict(),
		"stamina": stamina.to_dict(),
		"hunger": hunger.to_dict(),
		"inventory": inventory.to_dict(),
		"hotbar": hotbar.to_dict(),
		"equipped": equipped_iid,
	}


## Chame depois de adicionar à árvore. Silencioso: não emite `died` nem `starved`.
##
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou
## (posição, vida, fome, inventário, barra, mãos). O SaveManager deve tratar `false` como save
## inválido ou incompatível, nunca seguir com carga parcial. Carga em duas fases: primeiro valida
## sem aplicar (versões do inventário e da barra, e se o inventário cabe em `inventory`, via
## `can_load`); só depois toca em qualquer campo. Recusa também a migração de formato antigo
## (versão 1 ou ausente) cujo inventário está cheio demais para receber o equipamento inicial:
## abrir espaço descartaria itens do jogador, então o save fica de fora até haver espaço.
## Save parcial é consistente: sem `inventory` mantém inventário e barra; com `inventory` e sem
## `hotbar`, a barra é esvaziada (os `iid` antigos não valem); sem `equipped` as mãos não mudam.
## Save de formato antigo ganha o equipamento inicial que não tinha, e seu atalho.
func from_dict(data: Dictionary) -> bool:
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	if SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 0 \
			or SafeRead.format_version(saved_hotbar, HotbarComponent.FORMAT_VERSION) == 0:
		return false
	var replaces_inventory := typeof(saved_inventory.get("slots")) == TYPE_ARRAY
	var legacy := replaces_inventory and SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 1
	if replaces_inventory and not _inventory_accepts(saved_inventory, legacy):
		return false
	var saved_position := SafeRead.dict(data.get("position"))
	position = Vector2(
		SafeRead.number(saved_position.get("x"), position.x, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), position.y, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT)
	)
	health.from_dict(SafeRead.dict(data.get("health")))
	stamina.from_dict(SafeRead.dict(data.get("stamina")))
	hunger.from_dict(SafeRead.dict(data.get("hunger")))
	if replaces_inventory:
		inventory.from_dict(saved_inventory)
	if not hotbar.from_dict(saved_hotbar) and replaces_inventory:
		hotbar.from_dict({"slots": []})
	if legacy:
		_grant_starting_equipment()
	if data.has("equipped"):
		# Só vale se o item existe, é arma e está na barra; silencioso (sem golpe nem recarga).
		var saved_iid := SafeRead.text(data["equipped"], "")
		var saved_item := inventory.find_iid(saved_iid)
		var valid := not saved_item.is_empty() and Items.weapon_of(saved_item["id"]) != null
		_set_equipped(saved_iid if valid and hotbar.slot_of_iid(saved_iid) >= 0 else "")
	return true


## Primeira fase: o inventário do save cabe (e, no formato antigo, ainda sobra espaço para o
## equipamento inicial que ele não tem)? Não muda nada.
func _inventory_accepts(saved: Dictionary, legacy: bool) -> bool:
	var scratch := inventory.preview()
	var ok := scratch.from_dict(saved)
	if ok and legacy:
		for item_id in starting_equipment:
			if scratch.count(item_id) == 0 and scratch.add(item_id, 1) > 0:
				ok = false
	scratch.free()
	return ok


## Save de formato antigo: garante o equipamento inicial no inventário e na barra. O que já
## existe não é duplicado. Sem espaço, o item não entra (o inventário não perde nada por isso).
func _grant_starting_equipment() -> void:
	for item_id in starting_equipment:
		if inventory.count(item_id) == 0:
			inventory.add(item_id, 1)
		var iid := _newest_iid(item_id)
		if iid != "" and hotbar.slot_of_iid(iid) < 0 and hotbar.first_free() >= 0:
			hotbar.assign_iid(hotbar.first_free(), iid, item_id)


func _on_area_entered(area: Area2D) -> void:
	if area is InteractableArea and not _in_range.has(area):
		_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	_in_range.erase(area)
