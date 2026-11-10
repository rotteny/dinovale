# SPDX-License-Identifier: MIT
class_name LootService
extends Node
## Largar, recolher e recuperar o corpo (E7 e E11), filho da `WorldAuthority` (que mantém o contrato `request_*`: valida o
## pedido e fecha a resposta com o motivo daqui). Cada pedido devolve `{result, reason}`. Os sinais `items_dropped` e
## `item_discarded` continuam na autoridade: quem escuta o mundo não muda.

const RESULT := Enums.ActionResult

var authority: WorldAuthority = null


## Recolher o item de chão `target_id`: vai ao inventário de `actor_id` o que couber; o resto fica no chão. Valida ator,
## alcance, dono (gancho do co-op) e espaço (Peso e posições). Dois pedidos do mesmo item: o primeiro leva.
func pickup(actor_id: int, target_id: int) -> Dictionary:
	var actor := _actor(actor_id)
	var item := authority.entity(target_id) as GroundItem
	if actor == null:
		return _no_actor(actor_id)
	if item == null:
		return _outcome(RESULT.UNKNOWN_TARGET)
	if not _within(actor, item):
		return _outcome(RESULT.OUT_OF_RANGE)
	if item.reserved_against(actor.player_id, authority.clock.now()):
		return _outcome(RESULT.NOT_OWNER)
	if actor.inventory.room_for(item.item_id) <= 0:
		return _outcome(RESULT.REFUSED, actor.inventory.refusal_for(item.item_id))  # Peso máximo ou inventário cheio (o Peso vem primeiro)
	var item_id := item.item_id
	var entry := item.entry.duplicate(true)  # individual: volta com a durabilidade que tinha
	var taken := item.take(actor.inventory.room_for(item_id))
	if entry.is_empty():
		actor.inventory.add(item_id, taken)
	elif taken > 0:
		actor.inventory.add_entry(entry)
	authority.announce("item_collected", {"item": Items.display_name(item_id), "amount": taken})
	return _outcome(RESULT.OK)


## Recuperar os itens do corpo `corpse_id`: vai ao inventário de `actor_id` o que couber; o resto fica no corpo (que some quando
## esvazia). Valida ator vivo e de pé, alcance de coleta e dono (só o dono). Corpo cheio demais para o inventário: recusa.
func recover_corpse(actor_id: int, corpse_id: int) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var corpse := authority.entity(corpse_id) as PlayerCorpse
	var problem := corpse_problem(actor, corpse)
	if problem != RESULT.OK:
		return _outcome(problem)
	var moved := corpse.recover_into(actor.inventory, actor.equipment)
	if moved <= 0:
		return _outcome(RESULT.REFUSED, corpse.refusal_for(actor.inventory))
	corpse.restore_hotbar(actor.hotbar, actor.inventory)  # os atalhos voltam para onde estavam
	authority.announce("corpse_recovered", {"amount": moved, "left": corpse.item_count()})
	return _outcome(RESULT.OK)


## O ator pode recuperar este corpo? (alcance e dono). OK = pode.
func corpse_problem(actor: Player, corpse: PlayerCorpse) -> RESULT:
	if corpse == null:
		return RESULT.UNKNOWN_TARGET
	if not _within(actor, corpse):
		return RESULT.OUT_OF_RANGE
	return RESULT.OK if corpse.owner_player_id == actor.player_id else RESULT.NOT_OWNER


## Largar no chão `amount` (TRANSFER_ALL = tudo) do slot `index` do inventário, aos pés do ator. Só pilha (equipamento
## individual não se larga por aqui). Nada some: o que sai do inventário vira item de chão. `expected_id` e `expected_count`
## (opcionais) são o que a tela confirmou: se a pilha já mudou, o pedido é recusado sem largar nada.
func drop(actor_id: int, index: int, amount: int, expected_id: String, expected_count: int) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	if not authority.drops_enabled:
		return _outcome(RESULT.REFUSED)
	var slot := actor.inventory.get_slot(index)
	if slot.is_empty() or slot.has("iid"):
		return _outcome(RESULT.INVALID_ARGUMENT)
	if amount != WorldAuthority.TRANSFER_ALL and (amount < 1 or amount > int(slot["count"])):
		return _outcome(RESULT.INVALID_ARGUMENT)
	if (expected_id != "" and str(slot["id"]) != expected_id) or (expected_count >= 0 and int(slot["count"]) != expected_count):
		return _outcome(RESULT.WRONG_STATE)  # a pilha mudou depois da confirmação
	var item_id := str(slot["id"])
	var count := int(slot["count"]) if amount == WorldAuthority.TRANSFER_ALL else amount
	var removed := actor.inventory.take_from_slot(index, count)
	authority.items_dropped.emit(item_id, removed, actor.global_position, actor.player_id)
	authority.item_discarded.emit(actor.player_id)
	return _outcome(RESULT.OK)


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}


## Jogador vivo e de pé com esse id, ou null.
func _actor(actor_id: int) -> Player:
	var actor := authority.entity(actor_id) as Player
	return actor if actor != null and not actor.is_incapacitated() else null


func _no_actor(actor_id: int) -> Dictionary:
	return _outcome(RESULT.ACTOR_DEAD if authority.entity(actor_id) is Player else RESULT.UNKNOWN_ACTOR)


func _within(actor: Node2D, target: Node) -> bool:
	var other := target as Node2D
	return other != null and actor.global_position.distance_to(other.global_position) <= authority.rules.reach_px()
