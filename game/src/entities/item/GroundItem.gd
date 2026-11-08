# SPDX-License-Identifier: MIT
class_name GroundItem
extends Node2D
## Item solto no chão: uma pilha de `amount` unidades de `item_id` num ponto. Entidade de mundo com id da autoridade
## (`WorldAuthority.register`); recolher é `request_pickup`. Lógica pura: sem desenho (o `GroundItemView` desenha).
## Some em `due_at` (instante do relógio do mundo, ADR-006).

## A pilha esvaziou (tudo foi recolhido): o campo a remove.
signal depleted(item: GroundItem)
## A quantidade mudou (recolhida em parte).
signal changed

const INTERACT_RADIUS := 8.0

var item_id: String = ""
var amount: int = 0
## Instante (relógio do mundo) em que o item some.
var due_at: float = 0.0
## Gancho do co-op: quem largou/derrubou e até quando só ele recolhe (`owner_until`, relógio do mundo). "" = qualquer um.
var owner_player_id: String = ""
var owner_until: float = 0.0
## Área que o jogador enxerga (dica "pegar X"). Criada no `_init` e filha deste nó.
var interactable: InteractableArea = null


func _init() -> void:
	interactable = InteractableArea.new()
	interactable.entity = self
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)


## Põe item e quantidade (e o texto da dica). Chamado ao criar o nó.
func setup(new_item_id: String, new_amount: int) -> void:
	item_id = new_item_id
	amount = new_amount
	_refresh_prompt()


## Retira até `wanted` unidades e devolve quantas saíram. Esvaziou: avisa o campo.
func take(wanted: int) -> int:
	var taken := clampi(wanted, 0, amount)
	if taken <= 0:
		return 0
	amount -= taken
	_refresh_prompt()
	changed.emit()
	if amount <= 0:
		depleted.emit(self)
	return taken


## Outro jogador está impedido de recolher agora? (só vale com o gancho de dono ligado.)
func reserved_against(player_id: String, now: float) -> bool:
	return owner_player_id != "" and owner_player_id != player_id and now < owner_until


## Texto da dica e do rótulo ("Madeira x3").
func label_text() -> String:
	return "%s x%d" % [Items.display_name(item_id), amount]


func _refresh_prompt() -> void:
	interactable.prompt = "pegar %s" % label_text()
