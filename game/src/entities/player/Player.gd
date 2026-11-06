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
## O item na vaga Arma mudou (`iid` do equipado, "" = mãos livres).
signal equipped_changed(iid: String)
## Um pedido de equipar ou tirar foi recusado (`EquipmentComponent.REFUSED_*`); a tela mostra o aviso.
signal equip_refused(reason: String)
## Coletou de um nó de recurso (a apresentação mostra o ganho).
signal gathered(item_id: String, amount: int)
## Um pedido de coleta foi recusado (`GATHER_*`); recarga é silenciosa.
signal gather_refused(reason: String)

## Versão do formato do save do jogador. 1 = antigo (sem campo; item em mãos em `equipped`, na grade);
## 2 = vagas de equipamento (`equipment`).
const FORMAT_VERSION := 2
const COOLDOWN := "cooldown"
## Motivos de recusa de `request_gather`.
const GATHER_NO_TARGET := "no_target"
const GATHER_DEPLETED := "depleted"
const GATHER_FULL := "full"
const GATHER_BLOCKED := "blocked"
const GATHER_TOO_FAR := "too_far"

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
## `iid` do item na vaga Arma; "" = mãos livres (Soco). O item equipado NÃO está na grade.
var equipped_iid: String:
	get:
		return equipment.iid_in(EquipmentLayout.WEAPON)
var input_locked: bool = false:
	set(value):
		if input_locked != value:
			input_locked = value
			input_lock_changed.emit(value)

var _in_range: Array[InteractableArea] = []
var _attack_timer: float = 0.0
var _eat_timer: float = 0.0
var _equip_timer: float = 0.0
var _gather_timer: float = 0.0
var _last_equipped: String = ""

## Sprite: só a apresentação (`PlayerView`) escolhe o quadro.
@onready var visual: Sprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hunger: HungerComponent = $HungerComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var hotbar: HotbarComponent = $HotbarComponent
@onready var equipment: EquipmentComponent = $EquipmentComponent
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
	equipment.changed.connect(_on_equipment_changed)


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
	_gather_timer = maxf(_gather_timer - delta, 0.0)
	health.tick(delta)
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
		if not is_instance_valid(area) or _is_spent_resource(area):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			best = area
	if best != target:
		target = best
		target_changed.emit(target)


## Nó de recurso esgotado não disputa o alvo: o dino ou o nó cheio ao lado continuam alcançáveis.
func _is_spent_resource(area: InteractableArea) -> bool:
	return area.entity is ResourceNode and not area.can_interact()


## Criatura mais próxima no alcance (o golpe não depende de qual interagível é o alvo).
func _nearest_dino() -> Dino:
	var best: Dino = null
	var best_distance := INF
	for area in _in_range:
		if not is_instance_valid(area) or not (area.entity is Dino):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			best = area.entity as Dino
	return best


## Interage com o alvo se a regra da entidade permitir. Retorna true se interagiu.
func try_interact() -> bool:
	if input_locked or health.is_dead() or target == null or not target.can_interact():
		return false
	interacted.emit(target)
	return true


## Golpe da arma equipada na criatura selvagem ao alcance (dano e torpor). Retorna true se acertou.
func attack() -> bool:
	if input_locked or health.is_dead() or _attack_timer > 0.0:
		return false
	var dino := _nearest_dino()
	var weapon := current_weapon()
	if dino == null or not dino.receive_hit(weapon.damage, weapon.torpor, TamingRules.ATTACKER_PLAYER):
		return false
	_attack_timer = weapon.cooldown
	attacked.emit()
	return true


## Intenção "colher o nó de recurso em alcance": o jogador só pede, as regras decidem aqui. Devolve ""
## se coletou ou o motivo da recusa (`GATHER_*`, ou "cooldown", silenciosa). Recusa por falta de
## espaço NÃO gasta o nó. A recarga é o tempo de ação do tipo de nó (`gather_seconds`).
func request_gather() -> String:
	if input_locked or health.is_dead():
		return GATHER_BLOCKED
	if _gather_timer > 0.0:
		return COOLDOWN
	var node := target.entity as ResourceNode if target != null else null
	var reason := _gather_refusal(node)
	if reason != "":
		return _refuse_gather(reason)
	var amount := node.harvest()
	inventory.add(node.def.item_id, amount)
	_gather_timer = node.def.gather_seconds
	gathered.emit(node.def.item_id, amount)
	return ""


## Motivo de o nó não poder ser colhido agora ("" = pode): alvo, esgotado, alcance e espaço inteiro.
func _gather_refusal(node: ResourceNode) -> String:
	if node == null:
		return GATHER_NO_TARGET
	if not node.is_available():
		return GATHER_DEPLETED
	if global_position.distance_to(node.global_position) > node.def.reach:
		return GATHER_TOO_FAR
	if inventory.room_for(node.def.item_id) < node.def.yield_amount:
		return GATHER_FULL
	return ""


func _refuse_gather(reason: String) -> String:
	gather_refused.emit(reason)
	return reason


## Renasce em `point` (GDD 12.4): vida e fome nas frações das regras, fôlego cheio, proteção por
## alguns segundos. O inventário, a barra e as vagas ficam como estavam (o corpo com os itens é
## SOB-02, M2). Só vale para quem está morto; devolve se renasceu.
func respawn_at(point: Vector2, respawn_rules: RespawnRules) -> bool:
	if not health.is_dead():
		return false
	position = point
	velocity = Vector2.ZERO
	health.revive(respawn_rules.health_ratio)
	hunger.set_ratio(respawn_rules.hunger_ratio)
	stamina.from_dict({"current": stamina.max_stamina, "is_exhausted": false})
	health.grant_protection(respawn_rules.protection_seconds)
	# `_in_range` fica: o detector devolve o que continuar sobreposto e o `area_exited` tira o resto.
	if target != null:
		target = null
		target_changed.emit(null)
	return true


## Arma em mãos: a do item equipado, ou o Soco com as mãos livres.
func current_weapon() -> WeaponDef:
	var weapon := Items.weapon_of(str(equipment.item_in(EquipmentLayout.WEAPON).get("id", "")))
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


## Item pelo `iid`, na grade ou em uma vaga de equipamento; `{}` se não existe.
func find_item(iid: String) -> Dictionary:
	var item := inventory.find_iid(iid)
	return item if not item.is_empty() else equipment.find_iid(iid)


## Pedido de equipar o item `iid` da grade (vaga "" = a do item). Recarga de 0,3 s. Devolve "" se
## equipou ou o motivo da recusa (`EquipmentComponent.REFUSED_*`, ou "cooldown"); recusa avisa por
## `equip_refused`, exceto a recarga, que é silenciosa.
func request_equip(iid: String, slot_id: String = "") -> String:
	var reason := _after_equip_request(equipment.equip(iid, slot_id) if _can_equip_now() else COOLDOWN)
	if reason == "":
		_ensure_hotbar_slot(iid)
	return reason


## O equipado precisa de atalho para ter o destaque na barra: sem atalho, vai ao primeiro livre
## (barra cheia: fica sem; o que já tem atalho não muda).
func _ensure_hotbar_slot(iid: String) -> void:
	var item := find_item(iid)
	if item.is_empty() or hotbar.slot_of_iid(iid) >= 0 or hotbar.first_free() < 0:
		return
	hotbar.assign_iid(hotbar.first_free(), iid, item["id"])


## Pedido de tirar o item da vaga para a grade (grade sem posição livre: recusa "full").
func request_unequip(slot_id: String) -> String:
	return _after_equip_request(equipment.unequip(slot_id) if _can_equip_now() else COOLDOWN)


func _can_equip_now() -> bool:
	return not input_locked_for_equip() and _equip_timer <= 0.0


## A tela de inventário trava o corpo (`input_locked`), mas é por ela que se equipa: só a morte impede.
func input_locked_for_equip() -> bool:
	return health.is_dead()


func _after_equip_request(reason: String) -> String:
	if reason == "":
		_equip_timer = rules.equip_cooldown
	elif reason != COOLDOWN:
		equip_refused.emit(reason)
	return reason


## A tecla do atalho: o que está na vaga é tirado; o que está na grade é equipado (troca).
func _toggle_equipped(iid: String) -> bool:
	var item := find_item(iid)
	if item.is_empty() or Items.slot_of(item["id"]) != EquipmentLayout.WEAPON:
		return false
	var reason := request_unequip(EquipmentLayout.WEAPON) if equipment.has_iid(iid) else request_equip(iid)
	return reason == ""


func _on_equipment_changed() -> void:
	var now := equipped_iid
	if now != _last_equipped:
		_last_equipped = now
		equipped_changed.emit(now)


func _newest_iid(item_id: String) -> String:
	for i in range(inventory.slot_count() - 1, -1, -1):
		var slot := inventory.get_slot(i)
		if slot.get("id", "") == item_id and slot.has("iid"):
			return slot["iid"]
	return ""


func to_dict() -> Dictionary:
	var data := {
		"version": FORMAT_VERSION,
		"position": {"x": position.x, "y": position.y},
		"health": health.to_dict(),
		"stamina": stamina.to_dict(),
		"hunger": hunger.to_dict(),
		"inventory": inventory.to_dict(),
		"hotbar": hotbar.to_dict(),
		"equipment": equipment.to_dict(),
	}
	if health.protection_left > 0.0:  # só o jogador faz a proteção correr: só ele a salva
		data["protection"] = health.protection_left
	return data


## Chame depois de adicionar à árvore. Silencioso: não emite `died` nem `starved`.
##
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou
## (posição, vida, fome, inventário, barra, vagas). O SaveManager deve tratar `false` como save
## inválido ou incompatível, nunca seguir com carga parcial. Carga em duas fases: primeiro valida
## sem aplicar; só depois toca em qualquer campo. Recusa: versão do jogador, do inventário, da barra
## ou das vagas inválida ou maior; bloco `inventory`, `hotbar` ou `equipment` que existe e não é
## dicionário, ou com `version` e sem `slots` (corrupção); `slots` que não é do tipo certo;
## inventário que não cabe; vagas inválidas; e a migração de formato antigo (inventário v1) cujo
## inventário está cheio demais para receber o equipamento inicial. Essa última recusa é PERMANENTE
## para o arquivo (só migração fora do jogo, ou o dono do arquivo, resolve): abrir espaço
## descartaria itens do jogador. `{}` é save parcial válido e não muda nada.
## Save parcial: sem `inventory` mantém inventário e barra; com `inventory` e sem `hotbar`, a barra
## é esvaziada (os `iid` antigos não valem). Vagas: com `equipment` valem as dele; sem `equipment`
## e com `inventory`, ficam vazias (o item equipado de um save antigo vem de `equipped`, que está na
## grade: MIGRAÇÃO, move para a vaga Arma se for arma); sem os dois, não mudam.
func from_dict(data: Dictionary) -> bool:
	if not _shape_is_valid(data):
		return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var replaces_inventory := saved_inventory.has("slots")
	var legacy := replaces_inventory and SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 1
	var has_equipment := data.has("equipment")
	if not _load_is_valid(saved_inventory, saved_equipment, replaces_inventory, has_equipment, legacy):
		return false
	var saved_position := SafeRead.dict(data.get("position"))
	position = Vector2(
		SafeRead.number(saved_position.get("x"), position.x, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), position.y, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT)
	)
	health.from_dict(SafeRead.dict(data.get("health")))
	health.protection_left = SafeRead.number(data.get("protection"), 0.0, 0.0, HealthComponent.MAX_PROTECTION)
	stamina.from_dict(SafeRead.dict(data.get("stamina")))
	hunger.from_dict(SafeRead.dict(data.get("hunger")))
	if replaces_inventory:
		inventory.from_dict(saved_inventory)
	if has_equipment:
		equipment.from_dict(saved_equipment)
	elif replaces_inventory:
		equipment.from_dict({"slots": {}})
	if not hotbar.from_dict(saved_hotbar) and replaces_inventory:
		hotbar.from_dict({"slots": []})
	# Migração: o item "em mãos" do save antigo está na grade; vai para a vaga Arma se for arma.
	if not has_equipment and data.has("equipped"):
		var migrated := SafeRead.text(data["equipped"], "")
		if equipment.equip(migrated, EquipmentLayout.WEAPON) == "":
			_ensure_hotbar_slot(migrated)
	if legacy:
		_grant_starting_equipment()
	return true


## Forma do save: versões conhecidas, blocos que são dicionários, `slots` da barra no tipo certo e
## vagas sempre junto do inventário (vagas sozinhas tirariam da vaga um item que a grade não recebe).
func _shape_is_valid(data: Dictionary) -> bool:
	if SafeRead.format_version(data, FORMAT_VERSION) == 0:
		return false
	for key in ["inventory", "hotbar", "equipment"]:
		if not SafeRead.block_valid(data, key):
			return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var versions_ok := SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_hotbar, HotbarComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_equipment, EquipmentComponent.FORMAT_VERSION) != 0
	var hotbar_ok := not saved_hotbar.has("slots") or typeof(saved_hotbar["slots"]) == TYPE_ARRAY
	return versions_ok and hotbar_ok and (not data.has("equipment") or saved_inventory.has("slots"))


## Primeira fase: o inventário do save cabe, as vagas valem contra esse inventário e, no formato
## antigo, ainda sobra espaço para o equipamento inicial. Não muda nada.
func _load_is_valid(saved_inventory: Dictionary, saved_equipment: Dictionary, replaces_inventory: bool,
		has_equipment: bool, legacy: bool) -> bool:
	var scratch := inventory.preview()
	var ok := true
	if replaces_inventory:
		ok = scratch.from_dict(saved_inventory)
	else:
		ok = scratch.from_dict(inventory.to_dict())
	if ok and has_equipment:
		ok = equipment.can_load(saved_equipment, scratch)
	if ok and legacy:
		for item_id in starting_equipment:
			var owned := scratch.count(item_id) + (equipment.count(item_id) if not replaces_inventory else 0)
			if owned == 0 and scratch.add(item_id, 1) > 0:
				ok = false
	scratch.free()
	return ok


## Save de formato antigo: garante o equipamento inicial no inventário e na barra. O que já
## existe (na grade ou na vaga) não é duplicado. Sem espaço, o item não entra.
func _grant_starting_equipment() -> void:
	for item_id in starting_equipment:
		if inventory.count(item_id) + equipment.count(item_id) == 0:
			inventory.add(item_id, 1)
		var iid := _newest_iid(item_id)
		if iid != "" and hotbar.slot_of_iid(iid) < 0 and hotbar.first_free() >= 0:
			hotbar.assign_iid(hotbar.first_free(), iid, item_id)


func _on_area_entered(area: Area2D) -> void:
	if area is InteractableArea and not _in_range.has(area):
		_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	_in_range.erase(area)
