# SPDX-License-Identifier: MIT
class_name Chest
extends BuildPiece
## Baú no mundo (E8b, PRO-06): uma peça sólida que também é entidade registrada na autoridade, com um `InventoryComponent` e uma
## área de interação. O inventário pertence à `BuildGrid` (que o guarda no save e o libera com a peça); o nó só aponta para ele.
## Abrir e mover itens são `request_*` da autoridade (alcance e espaço); aqui não há regra, só a ligação.

const INTERACT_RADIUS := 10.0
const PROMPT := "abrir o baú"

## O conteúdo. Pertence à grade: não liberar daqui.
var inventory: InventoryComponent = null
var interactable: InteractableArea = null


## Liga o nó ao inventário da célula e cria a área que o jogador alcança.
func attach_box(box: InventoryComponent) -> void:
	inventory = box
	interactable = InteractableArea.new()
	interactable.entity = self
	interactable.prompt = PROMPT
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)
