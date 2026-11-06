# SPDX-License-Identifier: MIT
class_name ResourceNode
extends Node2D
## Nó de recurso no mundo (árvore, pedra, arbusto, pedra avulsa). Junta o componente de estado, a área de
## interação e a colisão dos pés (só quem a definição manda colidir). A regra é do `ResourceNodeComponent`;
## coletar é pedido do jogador (`Player.request_gather`, pela autoridade). A origem do nó são os PÉS: o
## desenho sobe dali e a colisão fica só ali (GDD 4.2).

## Id estável no mundo (chave no save). Único entre os nós.
@export var node_id: String = ""
@export var def: ResourceNodeDef
## Tempo de volta próprio (0 = o do tipo); vai para o componente ao nascer.
@export var respawn_override: float = 0.0

var _body: StaticBody2D = null
var _shape: CollisionShape2D = null

@onready var component: ResourceNodeComponent = $ResourceNodeComponent
@onready var interactable: InteractableArea = $InteractableArea


func _ready() -> void:
	component.def = def
	component.respawn_override = respawn_override
	interactable.entity = self
	interactable.prompt = def.prompt if def != null else "colher"
	interactable.availability = component.is_available
	component.changed.connect(interactable.refresh)
	_build_body()
	component.changed.connect(_refresh_body)


func is_available() -> bool:
	return component.is_available()


## O corpo de colisão dos pés está ligado agora? (teste e diagnóstico)
func blocks_movement() -> bool:
	return _shape != null and not _shape.disabled


## Colhe o nó e devolve as unidades do item principal (0 se esgotado).
func harvest() -> int:
	return component.harvest()


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


func _refresh_body() -> void:
	if _shape == null:
		return
	var blocks := def.blocks_when_full if component.is_available() else def.blocks_when_depleted
	_shape.set_deferred("disabled", not blocks)
