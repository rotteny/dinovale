# SPDX-License-Identifier: MIT
class_name CampPiece
extends BuildPiece
## Peça da base no mundo (E12): Fogueira (assa), Cama (deita e salva) e Saco de dormir (só marca o ponto). É entidade
## registrada na autoridade, com uma área de interação (a Fogueira e a Cama; o Saco não é alvo de nada). Não tem regra: assar
## é do `CampService`, renascer é do `RespawnPointService` e o dono vive na `BuildGrid`.

const INTERACT_RADIUS := 10.0
const PROMPTS: Dictionary[String, String] = {"campfire": "assar carne", "bed": "deitar"}

var interactable: InteractableArea = null


## Peça da base cria o nó: é a que tem área de interação (o Saco não).
static func handles(piece_id: String) -> bool:
	return piece_id == "campfire" or piece_id == "bed" or piece_id == "sleeping_bag"


func is_fire() -> bool:
	return piece_id == "campfire"


func is_bed() -> bool:
	return piece_id == "bed"


## Cria a área que o jogador alcança (só se a peça tem o que oferecer).
func attach_interaction() -> void:
	if not PROMPTS.has(piece_id):
		return
	interactable = InteractableArea.new()
	interactable.entity = self
	interactable.prompt = PROMPTS[piece_id]
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)
