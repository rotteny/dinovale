# SPDX-License-Identifier: MIT
class_name Dino
extends CharacterBody2D
## Corpo da criatura: compõe os componentes e aplica `desired_direction` à física.
## As regras ficam nos componentes e na máquina de estados.
## O `inventory` é o inventário compartilhado: o jogador deposita a comida nele
## e o `TamingComponent` consome dele.
##
## Nível: vida máxima, dano, torpor máximo e refeições para domesticar derivam de
## `level` e dos atributos base (`stats`), pelas fórmulas de `level_rules`. Ao
## domesticar, o `TamingComponent` entrega o nível final e o dino o assume.

signal level_changed(level: int)
## Limite de sanidade para uma coordenada vinda de save.
const COORD_LIMIT := 1.0e6
const LEVEL_SANITY := 1000000
## Tamanho máximo de um `player_id` vindo de save (maior que isso não é id: é lixo).
const MAX_PLAYER_ID_LENGTH := 64

@export var move_speed: float = 40.0
@export var stats: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
@export var level_rules: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
## Nível da criatura. Selvagem: o do mundo; domesticado: o final da domesticação.
@export var level: int = 10:
	set(value):
		level = level_rules.clamp_level(value)
		if is_node_ready():
			_apply_level()

## Sexo ("f" ou "m", `DinoBaseStats.SEX_*`): decidido ao nascer e imutável; sem efeito em atributo nem dieta (ADR-007).
var sex: String = DinoBaseStats.SEX_FEMALE
## Dano do ataque do dino, derivado do nível (sem uso até existir carnívoro).
var attack_damage: float = 0.0

## Dono (`player_id` do personagem, ADR-003; "" = sem dono): aponta para o personagem, que existe com o
## dono offline. Vira o último a depositar a comida ideal quando a domesticação termina (ADR-001,
## "Taming"). Vai no save como `owner_player_id`.
var owner_player_id: String = ""
## Quem depositou a comida ideal por último (`request_transfer_slot`), por `player_id`. Vai no save, porque a
## domesticação pode ser salva no meio.
var feeder_player_id: String = ""
## Resolve um `player_id` no corpo do jogador no mundo (ou null se não está). A autoridade o preenche ao
## registrar a criatura; sem ele a ordem Seguir não encontra o dono e o dino fica parado.
var player_locator: Callable = Callable()
## Devolve os corpos que o agressivo pode perseguir (`Array` de `Node2D`; o mundo preenche). Sem ele, ninguém é alvo.
var target_locator: Callable = Callable()

var _restoring: bool = false

@onready var health: HealthComponent = $HealthComponent
@onready var torpor: TorporComponent = $TorporComponent
@onready var taming: TamingComponent = $TamingComponent
@onready var state_machine: DinoStateMachine = $StateMachine
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interactable: InteractableArea = $InteractableArea
## Sprite (placeholder do pacote): só a camada de apresentação o move, gira ou pinta.
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	_apply_hitbox()
	health.died.connect(queue_free)
	# Fase da pausa: valor definido na cena vale. Senão, deriva do ponto de nascimento.
	# Limite conhecido: dois dinos que nascem no mesmo ponto compartilham a fase. Troca para
	# o id de entidade (ADR-003) quando ele existir. Vai no save, então a carga não a muda.
	if torpor.pause_phase == 0.0:
		torpor.pause_phase = fposmod(position.x * 0.37 + position.y * 0.61, torpor.band_rules.pause_period)
	taming.level_finalized.connect(_on_level_finalized)
	taming.taming_reset.connect(_on_taming_reset)
	_apply_level()
	interactable.availability = can_interact
	interactable.prompt_availability = can_command
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.order_changed.connect(_on_order_changed)
	_refresh_prompt()
	interactable.refresh()


func _physics_process(_delta: float) -> void:
	observe_owner()
	observe_targets()
	velocity = state_machine.desired_direction * move_speed * state_machine.speed_multiplier \
			* torpor.movement_multiplier()
	move_and_slide()


## Informa à máquina onde o dono está (a máquina não vê o mundo). Dono fora do mundo ou MORTO conta como
## ausente: o dino fica onde está, a ordem se mantém e ele volta a seguir quando o dono renascer.
## Público para testar sem quadros.
func observe_owner() -> void:
	var owner_body: Node2D = null
	if owner_player_id != "" and player_locator.is_valid():
		owner_body = player_locator.call(owner_player_id) as Node2D
	var present := owner_body != null and not _is_dead_body(owner_body)
	state_machine.observe(global_position, owner_body.global_position if present else Vector2.ZERO, present)


## Informa à máquina o alvo vivo mais próximo (só o agressivo procura). Público para testar sem quadros.
func observe_targets() -> void:
	if not stats.aggressive or state_machine.is_tamed or not target_locator.is_valid():
		state_machine.observe_target(Vector2.ZERO, false)
		return
	var best: Node2D = null
	var best_distance := INF
	for candidate: Variant in target_locator.call():
		var body := candidate as Node2D
		if body == null or not is_instance_valid(body) or _is_dead_body(body):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < best_distance:
			best = body
			best_distance = distance
	state_machine.observe_target(best.global_position if best != null else Vector2.ZERO, best != null)


## Reavalia o prompt depois de o dono mudar fora do fluxo normal (ex.: dono corrigido ao carregar).
func refresh_command_state() -> void:
	_refresh_prompt()
	interactable.refresh()


func _is_dead_body(body: Node2D) -> bool:
	var owner_health := body.get("health") as HealthComponent
	return owner_health != null and owner_health.is_dead()


## Caixa de colisão vinda dos dados (`DinoBaseStats.hitbox_size`), nunca da cena.
func _apply_hitbox() -> void:
	var shape := RectangleShape2D.new()
	shape.size = stats.hitbox_size
	$CollisionShape2D.shape = shape


## Tem dono e já é domesticado: a tecla de interação manda seguir ou ficar em vez de abrir a tela.
func can_command() -> bool:
	return state_machine.is_tamed and owner_player_id != "" and not health.is_dead()


## Regra de interação: só dá para abrir o inventário de uma criatura selvagem inconsciente.
func can_interact() -> bool:
	return state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not state_machine.is_tamed


## Aplica torpor (ex.: ataque do jogador). Domesticados não são afetados.
## Retorna true se o torpor foi aplicado.
func apply_torpor(amount: float) -> bool:
	if state_machine.is_tamed or amount <= 0.0:
		return false
	torpor.add_torpor(amount)
	return true


## Ataque recebido: dano primeiro, torpor depois, para que o golpe que derruba a
## criatura acordada não conte como ataque ao dormindo. Domesticado não é alvo.
## Retorna true se algo foi aplicado.
## `attacker_id` é o `player_id` de quem bate (""= não é jogador): golpe de jogador que não é o que
## reservou a doma tira vida e põe torpor, mas não derruba a Eficiência.
func receive_hit(damage: float, torpor_amount: float, attacker_kind: String, attacker_id: String = "") -> bool:
	if state_machine.is_tamed or not taming.rules.knows_attacker(attacker_kind):
		return false
	var hit := take_damage(damage, attacker_kind, _spares_efficiency(attacker_kind, attacker_id))
	if not health.is_dead() and apply_torpor(torpor_amount):
		hit = true
	return hit


## Dano de um atacante (`TamingRules.ATTACKER_*`). Acordada, só tira vida. Dormindo e
## selvagem, também derruba a Eficiência. Se a vida zera, a criatura morre e uma
## domesticação em curso falha. Retorna true se causou dano.
func take_damage(amount: float, attacker_kind: String, spare_efficiency: bool = false) -> bool:
	if amount < 0.0 or health.is_dead() or not taming.rules.knows_attacker(attacker_kind):
		return false
	var was_taming := taming.is_active()
	var before := health.current_health
	health.take_damage(amount)
	if was_taming and not spare_efficiency:
		# Dano 0 também conta: o fixo de Eficiência do atacante vale por golpe.
		taming.apply_attack(attacker_kind, (before - health.current_health) / health.max_health * 100.0)
	return amount > 0.0 or was_taming


func _spares_efficiency(attacker_kind: String, attacker_id: String) -> bool:
	return attacker_kind == TamingRules.ATTACKER_PLAYER and feeder_player_id != "" and attacker_id != feeder_player_id


## Vida e torpor máximos e dano pelas fórmulas do nível. O que a criatura já perdeu
## de vida continua perdido; quem estava com a vida cheia continua cheio.
func _apply_level() -> void:
	health.set_max_keeping_lost(level_rules.max_health(stats.base_health, level))
	if _restoring:
		torpor.set_max_quietly(level_rules.max_torpor(stats.base_torpor, level))
	else:
		torpor.max_torpor = level_rules.max_torpor(stats.base_torpor, level)
	attack_damage = level_rules.damage(stats.base_damage, level)
	taming.level = level
	taming.stats = stats
	taming.ideal_food = stats.ideal_food
	state_machine.configure(stats, move_speed, float(level_rules.tile_size))
	taming.level_rules = level_rules
	if not _restoring:
		level_changed.emit(level)


## Doma cancelada ou reiniciada: a reserva do primeiro alimentador acaba (a próxima refeição ideal reserva de novo).
func _on_taming_reset() -> void:
	feeder_player_id = ""


func _on_level_finalized(final_level: int) -> void:
	level = final_level
	owner_player_id = feeder_player_id
	_refresh_prompt()


func _on_state_changed(_previous: Enums.DinoStateId, _current: Enums.DinoStateId) -> void:
	_refresh_prompt()
	interactable.refresh()


func _on_order_changed(_order: Enums.DinoOrder) -> void:
	_refresh_prompt()


## Texto do prompt: o do domado diz a ordem que a tecla vai dar; o do selvagem fica o padrão.
func _refresh_prompt() -> void:
	if can_command():
		var verb := "ficar" if state_machine.order == Enums.DinoOrder.FOLLOW else "seguir"
		interactable.prompt = "mandar %s %s" % [stats.display_name, verb]
	else:
		interactable.prompt = "interagir"


func to_dict() -> Dictionary:
	return {
		"species": stats.id,
		"sex": sex,
		"position": {"x": position.x, "y": position.y},
		"level": level,
		"health": health.to_dict(),
		"torpor": torpor.to_dict(),
		"inventory": inventory.to_dict(),
		"taming": taming.to_dict(),
		"state_machine": state_machine.to_dict(),
		"owner_player_id": owner_player_id,
		"feeder_player_id": feeder_player_id,
	}


## `player_id` vindo de save: texto de tamanho razoável, ou "" (sem dono).
func _saved_player_id(value: Variant) -> String:
	var text := SafeRead.text(value, "")
	return text if text.length() <= MAX_PLAYER_ID_LENGTH else ""


## Chame depois de adicionar à árvore. A ordem importa: inventário, torpor e domesticação antes da máquina.
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou. Valida
## o inventário (versão e se cabe, inclusive equipamento, que a criatura não guarda) ANTES de
## tocar em qualquer campo; o SaveManager trata `false` como save inválido, sem carga parcial.
func from_dict(data: Dictionary) -> bool:
	var saved_species := SafeRead.text(data.get("species"), "")
	if saved_species != "" and saved_species != stats.id:
		return false  # estado de outra espécie não se aplica (ADR-007); sem `species` (save antigo) segue aceito
	if not SafeRead.block_valid(data, "inventory"):
		return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	if SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 0:
		return false
	if saved_inventory.has("slots") and not inventory.can_load(saved_inventory):
		return false
	# Restaurar não é evento de jogo: `level_changed` fica quieto (a UI lê o estado).
	_restoring = true
	var saved_sex := SafeRead.text(data.get("sex"), "")
	if saved_sex == DinoBaseStats.SEX_FEMALE or saved_sex == DinoBaseStats.SEX_MALE:
		sex = saved_sex  # gravado e derivado diferentes: vale o gravado
	var saved_position := SafeRead.dict(data.get("position"))
	position = Vector2(
		SafeRead.number(saved_position.get("x"), position.x, -COORD_LIMIT, COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), position.y, -COORD_LIMIT, COORD_LIMIT)
	)
	# Ausente ou não numérico: nível padrão. Número legítimo fora da faixa: limitado.
	level = level_rules.clamp_level(SafeRead.integer(data.get("level"), level_rules.base_level, -LEVEL_SANITY, LEVEL_SANITY))
	health.from_dict(SafeRead.dict(data.get("health")))
	inventory.from_dict(saved_inventory)
	torpor.from_dict(SafeRead.dict(data.get("torpor")))
	taming.from_dict(SafeRead.dict(data.get("taming")))
	state_machine.from_dict(SafeRead.dict(data.get("state_machine")))
	owner_player_id = _saved_player_id(data.get("owner_player_id")) if state_machine.is_tamed else ""
	feeder_player_id = _saved_player_id(data.get("feeder_player_id"))
	_refresh_prompt()
	taming.reconcile()
	# Os máximos vêm do nível, não do save: dado salvo não é confiável.
	_apply_level()
	if not state_machine.is_tamed and not torpor.is_unconscious:
		feeder_player_id = ""  # selvagem acordado não tem reserva (acordar a zera); save que traz uma não a prende
	_restoring = false
	# Vida 0 no save: morta na carga, sem emitir `died` (não é evento de jogo).
	if health.is_dead():
		queue_free()
	return true


