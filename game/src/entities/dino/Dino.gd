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

@export var move_speed: float = 40.0
@export var stats: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
@export var level_rules: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
## Nível da criatura. Selvagem: o do mundo; domesticado: o final da domesticação.
@export var level: int = 10:
	set(value):
		level = level_rules.clamp_level(value)
		if is_node_ready():
			_apply_level()

## Dano do ataque do dino, derivado do nível (sem uso até existir carnívoro).
var attack_damage: float = 0.0

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
	health.died.connect(queue_free)
	# Fase da pausa: valor definido na cena vale. Senão, deriva do ponto de nascimento.
	# Limite conhecido: dois dinos que nascem no mesmo ponto compartilham a fase. Troca para
	# o id de entidade (ADR-003) quando ele existir. Vai no save, então a carga não a muda.
	if torpor.pause_phase == 0.0:
		torpor.pause_phase = fposmod(position.x * 0.37 + position.y * 0.61, torpor.band_rules.pause_period)
	taming.level_finalized.connect(_on_level_finalized)
	_apply_level()
	interactable.availability = can_interact
	state_machine.state_changed.connect(_on_state_changed)
	interactable.refresh()


func _physics_process(_delta: float) -> void:
	velocity = state_machine.desired_direction * move_speed * torpor.movement_multiplier()
	move_and_slide()


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
func receive_hit(damage: float, torpor_amount: float, attacker_kind: String) -> bool:
	if state_machine.is_tamed or not taming.rules.knows_attacker(attacker_kind):
		return false
	var hit := take_damage(damage, attacker_kind)
	if not health.is_dead() and apply_torpor(torpor_amount):
		hit = true
	return hit


## Dano de um atacante (`TamingRules.ATTACKER_*`). Acordada, só tira vida. Dormindo e
## selvagem, também derruba a Eficiência. Se a vida zera, a criatura morre e uma
## domesticação em curso falha. Retorna true se causou dano.
func take_damage(amount: float, attacker_kind: String) -> bool:
	if amount < 0.0 or health.is_dead() or not taming.rules.knows_attacker(attacker_kind):
		return false
	var was_taming := taming.is_active()
	var before := health.current_health
	health.take_damage(amount)
	if was_taming:
		# Dano 0 também conta: o fixo de Eficiência do atacante vale por golpe.
		taming.apply_attack(attacker_kind, (before - health.current_health) / health.max_health * 100.0)
	return amount > 0.0 or was_taming


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
	taming.level_rules = level_rules
	if not _restoring:
		level_changed.emit(level)


func _on_level_finalized(final_level: int) -> void:
	level = final_level


func _on_state_changed(_previous: Enums.DinoStateId, _current: Enums.DinoStateId) -> void:
	interactable.refresh()


func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"level": level,
		"health": health.to_dict(),
		"torpor": torpor.to_dict(),
		"inventory": inventory.to_dict(),
		"taming": taming.to_dict(),
		"state_machine": state_machine.to_dict(),
	}


## Chame depois de adicionar à árvore. A ordem importa: inventário, torpor e domesticação antes da máquina.
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou. Valida
## o inventário (versão e se cabe, inclusive equipamento, que a criatura não guarda) ANTES de
## tocar em qualquer campo; o SaveManager trata `false` como save inválido, sem carga parcial.
func from_dict(data: Dictionary) -> bool:
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	if SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 0:
		return false
	if typeof(saved_inventory.get("slots")) == TYPE_ARRAY and not inventory.can_load(saved_inventory):
		return false
	# Restaurar não é evento de jogo: `level_changed` fica quieto (a UI lê o estado).
	_restoring = true
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
	taming.reconcile()
	# Os máximos vêm do nível, não do save: dado salvo não é confiável.
	_apply_level()
	_restoring = false
	# Vida 0 no save: morta na carga, sem emitir `died` (não é evento de jogo).
	if health.is_dead():
		queue_free()
	return true


