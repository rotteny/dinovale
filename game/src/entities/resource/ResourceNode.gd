# SPDX-License-Identifier: MIT
class_name ResourceNode
extends Node2D
## Nó de recurso no mundo (árvore, pedra, arbusto de baga, fibra). Junta o componente de estado, a área
## de interação e o desenho provisório. A regra é do `ResourceNodeComponent`; coletar é pedido do
## jogador (`Player.request_gather`).

## Id estável no mundo (chave no save). Único entre os nós.
@export var node_id: String = ""
@export var def: ResourceNodeDef

@onready var component: ResourceNodeComponent = $ResourceNodeComponent
@onready var interactable: InteractableArea = $InteractableArea


func _ready() -> void:
	component.def = def
	interactable.entity = self
	interactable.prompt = def.prompt if def != null else "colher"
	interactable.availability = component.is_available
	component.changed.connect(interactable.refresh)


func is_available() -> bool:
	return component.is_available()


## Colhe o nó e devolve as unidades (0 se esgotado).
func harvest() -> int:
	return component.harvest()
