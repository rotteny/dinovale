# SPDX-License-Identifier: MIT
class_name Dino
extends CharacterBody2D
## Corpo da criatura: compõe os componentes e aplica `desired_direction` à física.
## As regras ficam nos componentes e na máquina de estados.
## O `inventory` é o inventário compartilhado: o jogador deposita a comida nele
## e o `TamingComponent` consome dele.

@export var move_speed: float = 40.0

@onready var health: HealthComponent = $HealthComponent
@onready var torpor: TorporComponent = $TorporComponent
@onready var taming: TamingComponent = $TamingComponent
@onready var state_machine: DinoStateMachine = $StateMachine
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interactable: InteractableArea = $InteractableArea


func _ready() -> void:
	health.died.connect(queue_free)
	interactable.availability = can_interact
	state_machine.state_changed.connect(_on_state_changed)
	interactable.refresh()


func _physics_process(_delta: float) -> void:
	velocity = state_machine.desired_direction * move_speed
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


func _on_state_changed(_previous: Enums.DinoStateId, _current: Enums.DinoStateId) -> void:
	interactable.refresh()


func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"health": health.to_dict(),
		"torpor": torpor.to_dict(),
		"inventory": inventory.to_dict(),
		"taming": taming.to_dict(),
		"state_machine": state_machine.to_dict(),
	}


## Chame depois de adicionar à árvore. A ordem importa: inventário, torpor e domesticação antes da máquina.
func from_dict(data: Dictionary) -> void:
	var saved_position: Dictionary = data.get("position", {})
	position = Vector2(
		float(saved_position.get("x", position.x)),
		float(saved_position.get("y", position.y))
	)
	health.from_dict(data.get("health", {}))
	inventory.from_dict(data.get("inventory", {}))
	torpor.from_dict(data.get("torpor", {}))
	taming.from_dict(data.get("taming", {}))
	state_machine.from_dict(data.get("state_machine", {}))
	taming.reconcile()
