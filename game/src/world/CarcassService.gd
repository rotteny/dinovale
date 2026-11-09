# SPDX-License-Identifier: MIT
class_name CarcassService
extends Node
## Esfolar carcaça (E10, SOB-06), filho da `WorldAuthority` (que mantém o contrato `request_skin` e fecha a resposta com o
## motivo daqui). Cada pedido devolve `{result, reason}`. Valida: ator vivo e de pé, carcaça existente, alcance, LINHA LIVRE
## (parede no meio recusa) e QUEM PODE: a carcaça do dino domado é só do dono por `CarcassRules.owner_exclusive_seconds`
## (GDD 5.6); a de selvagem e, passado o prazo, a de domado são de todos (co-op, sem PvP). Quem entrega é o `Player`: carne e
## couro que couberem no Peso e nos slots, o resto fica na carcaça (sem sacolinha). Esfolar não dá XP (não é nó).

const RESULT := Enums.ActionResult

var authority: WorldAuthority = null


## Esfola `node` (a carcaça do pedido) para `actor_id`.
func skin(actor_id: int, node: ResourceNode) -> Dictionary:
	var actor := authority.entity(actor_id) as Player
	if actor == null:
		return _outcome(RESULT.UNKNOWN_ACTOR)
	if actor.is_incapacitated():
		return _outcome(RESULT.ACTOR_DEAD)
	var problem := _problem(actor, node)
	if problem["result"] != RESULT.OK:
		return problem
	var life_before := actor.health.current_health
	var reason := actor.perform_gather(node)
	if reason != "":
		return _refusal(reason)
	_report(actor, node, life_before)
	return _outcome(RESULT.OK)


## Por que `actor` não pode esfolar `node` agora (`result` OK = pode). Esgotada e carcaça de outro dono vêm antes do alcance
## só na ordem da mensagem: o que o jogador consegue corrigir sozinho (chegar perto, tirar a parede) vem primeiro.
func _problem(actor: Player, node: ResourceNode) -> Dictionary:
	if node == null:
		return _outcome(RESULT.UNKNOWN_TARGET)
	if node.def == null or not node.def.is_carcass:
		return _outcome(RESULT.INVALID_TARGET, "not_a_carcass")
	var access := _access_problem(actor, node)
	if access["result"] != RESULT.OK:
		return access
	if not node.is_available():
		return _outcome(RESULT.WRONG_STATE, "depleted")
	if is_reserved_against(node, actor.player_id):
		return _outcome(RESULT.NOT_OWNER, "carcass_reserved")
	return _outcome(RESULT.OK)


## Alcance e linha livre (parede no meio recusa).
func _access_problem(actor: Player, node: ResourceNode) -> Dictionary:
	if actor.global_position.distance_to(node.global_position) > node.def.reach:
		return _outcome(RESULT.OUT_OF_RANGE)
	if authority.build.grid.segment_blocked(actor.global_position, node.global_position):
		return _outcome(RESULT.OUT_OF_RANGE, BuildService.REASON_LINE)
	return _outcome(RESULT.OK)


## A carcaça ainda é só do dono e `player_id` não é ele?
func is_reserved_against(node: ResourceNode, player_id: String) -> bool:
	return node.carcass_owner != "" and node.carcass_owner != player_id and authority.clock.now() < node.exclusive_until


## Resposta para o motivo de recusa do jogador (`Player.GATHER_*`).
func _refusal(reason: String) -> Dictionary:
	match reason:
		Player.COOLDOWN:
			return _outcome(RESULT.COOLDOWN)  # ainda esfolando o pedaço anterior: recusa silenciosa na HUD
		Player.GATHER_WEIGHT:
			return _outcome(RESULT.REFUSED, "weight_limit")
		Player.GATHER_FULL:
			return _outcome(RESULT.REFUSED, "inventory_full")
		Player.GATHER_DEPLETED:
			return _outcome(RESULT.WRONG_STATE, "depleted")
	return _outcome(RESULT.REFUSED)


## Registro do que entrou e do que ficou na carcaça (`carcass_skinned`) e da vida que a mão custou.
func _report(actor: Player, node: ResourceNode, life_before: float) -> void:
	var taken: Array[String] = []
	for item_id: String in actor.last_gather:
		taken.append("%d %s" % [int(actor.last_gather[item_id]), Items.display_name(item_id)])
	var left: Array[String] = []
	var pending := node.component.pending_yields()
	for item_id: String in pending:
		left.append("%d %s" % [int(pending[item_id]), Items.display_name(item_id)])
	authority.announce("carcass_skinned", {
		"carcass": node.def.display_name, "taken": ", ".join(taken),
		"left": " (ficou na carcaça: %s)" % ", ".join(left) if not left.is_empty() else ""})
	var hurt := life_before - actor.health.current_health
	if hurt > 0.0:
		authority.announce("hands_hurt", {"amount": snappedf(hurt, 0.1)})


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}
