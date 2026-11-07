# SPDX-License-Identifier: MIT
class_name ResourceNode
extends Node2D
## Nó de recurso no mundo (árvore, pedra, arbusto, pedra avulsa). Junta o componente de estado, a área de
## interação e a colisão dos pés (só quem a definição manda colidir). A regra é do `ResourceNodeComponent`;
## coletar é pedido do jogador (`Player.request_gather`, pela autoridade). A origem do nó são os PÉS: o
## desenho sobe dali e a colisão fica só ali (GDD 4.2).

## Mudou entre cheio e esgotado (o campo reage: só ele acorda o nó esgotado, por prazo).
signal state_changed(node: ResourceNode)

## Lado do tile do mapa, em pixels (a pegada do nó na consulta de ocupação).
const TILE_PX := 16.0

## Id estável no mundo (chave no save). Único entre os nós.
@export var node_id: String = ""
@export var def: ResourceNodeDef
## Tempo de volta próprio (0 = o do tipo); vai para o componente ao nascer.
@export var respawn_override: float = 0.0
## Regras do servidor (`ServerRules`): multiplicador de coleta e velocidade de volta; 1,0 = as do dado.
@export var yield_multiplier: float = 1.0
@export var respawn_rate: float = 1.0

## Leitor do relógio do mundo (ADR-006), repassado ao componente ao nascer.
var clock: Callable = Callable()

## Consulta de ocupação do chão (o campo a entrega): o nó só volta se o lugar estiver livre.
var occupancy: TileOccupancy = null

var _body: StaticBody2D = null
var _shape: CollisionShape2D = null

@onready var component: ResourceNodeComponent = $ResourceNodeComponent
@onready var interactable: InteractableArea = $InteractableArea


func _ready() -> void:
	component.def = def
	component.clock = clock
	component.respawn_override = respawn_override
	component.yield_multiplier = yield_multiplier
	component.respawn_rate = respawn_rate
	component.can_return = _place_is_free
	interactable.entity = self
	interactable.prompt = def.prompt if def != null else "colher"
	interactable.availability = component.is_available
	component.changed.connect(interactable.refresh)
	_build_body()
	component.changed.connect(_refresh_body)
	component.changed.connect(func() -> void: state_changed.emit(self))


func is_available() -> bool:
	return component.is_available()


## O corpo de colisão dos pés está ligado agora? (teste e diagnóstico)
func blocks_movement() -> bool:
	return _shape != null and not _shape.disabled


## Colhe o nó e devolve as unidades do item principal (0 se esgotado).
func harvest() -> int:
	return component.harvest()


## O tile do nó (lado `TILE_PX`, centrado nos pés) está livre de jogador e dinos?
func _place_is_free() -> bool:
	return occupancy == null or occupancy.is_free(Rect2(global_position - Vector2(TILE_PX, TILE_PX) * 0.5, Vector2(TILE_PX, TILE_PX)))


func _build_body() -> void:
	if def == null or def.foot_size == Vector2.ZERO:
		return
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = def.foot_size
	_shape = CollisionShape2D.new()
	_shape.shape = rect
	_shape.position = Vector2(0.0, -def.foot_size.y * 0.5)  # apoiada na origem (os pés)
	_body.add_child(_shape)
	add_child(_body)
	_refresh_body()


## Esgotado some por inteiro (desenho, colisão e alvo): o tile fica livre. A colheita parcial não esgota, então
## o nó segue ali.
func _refresh_body() -> void:
	visible = component.is_available()
	if _shape == null:
		return
	_shape.set_deferred("disabled", not (component.is_available() and def.blocks_when_full))
