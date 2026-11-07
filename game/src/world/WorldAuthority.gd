# SPDX-License-Identifier: MIT
class_name WorldAuthority
extends Node
## Autoridade do mundo (ADR-001): ponto de passagem de todo ato do jogador que muda o mundo. O cliente
## manda intenção (`request_*`) com ids de entidade; aqui se valida e se delega às regras que continuam
## nas entidades e nos componentes. No single-player é o host local, pelo mesmo caminho.
##
## Contrato de cada `request_*`: assinatura só com `int`, `String`, `float`, `bool` ou `Vector2`, nunca
## nó. Ordem da validação: ator existe e está vivo, argumentos válidos, alvo existe (por id), alcance
## pela distância real, regra de domínio (recarga, posse, estado). Negada: NADA muda, devolve o
## `Enums.ActionResult` e emite `action_denied`. O retorno serve a teste e log; a UI não atualiza estado por ele.
##
## Os ids vêm do registro (`register`): o jogador e a criatura da cena têm os ids do save
## (`WorldSnapshot`), e o resto recebe o próximo livre. Nó que morreu deixa de ser resolvido.

## Um pedido foi negado; nada mudou.
signal action_denied(actor_id: int, action: String, result: Enums.ActionResult)
## O alvo aceitou a interação; quem abre a tela ou colhe é o mundo (`Main`).
signal interaction_granted(actor_id: int, target_id: int)

const ACTION_ATTACK := "attack"
const ACTION_INTERACT := "interact"
const ACTION_TRANSFER := "transfer_slot"
const ACTION_COMMAND := "command_dino"
const ACTION_USE_ITEM := "use_item"
const ACTION_EQUIP := "equip"
const ACTION_UNEQUIP := "unequip"
const ACTION_GATHER := "gather"
## Tamanho máximo de `iid` e de nome de vaga aceitos (dado vindo de fora não é confiável).
const MAX_ID_LENGTH := 32
## Nome da ordem mais longo aceito (`Enums.DinoOrder`): corta lixo antes de procurar o nome.
const MAX_ORDER_NAME := 16

@export var rules: ActionRules = preload("res://data/balance/action_rules.tres")

var _entities: Dictionary = {}
var _next_id: int = 1


## Registra `node` no mundo. `entity_id` 0 = o próximo livre. Devolve o id usado, ou 0 se o id pedido já
## é de outro nó. Criatura registrada passa a achar o dono por este registro (`Dino.player_locator`).
func register(node: Node, entity_id: int = 0) -> int:
	if node == null:
		return 0
	var used := entity_id if entity_id > 0 else _next_id
	var holder := entity(used)
	if holder != null and holder != node:
		return 0  # só acontece com id pedido: o próximo livre nunca está em uso
	_entities[used] = node
	_next_id = maxi(_next_id, used + 1)
	if node is Dino:
		(node as Dino).player_locator = player_body
	return used


## Próximo `entity_id` livre (vai no save: o contador nunca recua nem reutiliza id).
func next_entity_id() -> int:
	return _next_id


## Garante que o próximo id livre não seja menor que `minimum` (ao carregar um save).
func ensure_next_id(minimum: int) -> void:
	_next_id = maxi(_next_id, minimum)


## Corpo do jogador com esse `player_id` no mundo (ou null se não está).
func player_body(player_id: String) -> Node:
	for node: Variant in _entities.values():
		if not is_instance_valid(node):
			continue
		var candidate := node as Player
		if candidate != null and candidate.player_id == player_id and not candidate.is_queued_for_deletion():
			return candidate
	return null


## `player_id` do jogador registrado como `entity_id` ("" se não for jogador).
func player_id_of(entity_id: int) -> String:
	var candidate := entity(entity_id) as Player
	return candidate.player_id if candidate != null else ""


func unregister(entity_id: int) -> void:
	_entities.erase(entity_id)


## Nó vivo do `entity_id`, ou null (id desconhecido, nó liberado ou já saindo do mundo).
func entity(entity_id: int) -> Node:
	var node: Variant = _entities.get(entity_id)
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return null
	return node as Node


## O `entity_id` está registrado (mesmo que o nó já tenha saído)? Serve para provar `unregister`.
func is_registered(entity_id: int) -> bool:
	return _entities.has(entity_id)


## `entity_id` registrado do nó, ou 0.
func id_of(node: Node) -> int:
	if node == null:
		return 0
	for entity_id: int in _entities:
		if _entities[entity_id] == node:
			return entity_id
	return 0


## Golpe da arma em mãos de `actor_id` na criatura `target_id` (dano e torpor vêm da arma).
func request_attack(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var dino := entity(target_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = _attack_problem(actor, dino)
	if problem == Enums.ActionResult.OK and not actor.strike(dino):
		problem = Enums.ActionResult.REFUSED
	return _answer(actor_id, ACTION_ATTACK, problem)


## Interagir com `target_id`. Concedida, emite `interaction_granted`; o efeito é de quem a ouve.
func request_interact(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var target := entity(target_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = _interact_problem(actor, target)
	if problem == Enums.ActionResult.OK:
		interaction_granted.emit(actor_id, target_id)
	return _answer(actor_id, ACTION_INTERACT, problem)


## Move o slot `index` do inventário de `from_id` para o de `to_id`. Um dos lados é o ator e o outro, uma
## criatura selvagem inconsciente (a tela compartilhada): do ator para ela é ALIMENTAR (a comida ideal
## faz do ator o candidato a dono); dela para o ator é recolher. O que não couber fica onde estava.
func request_transfer_slot(actor_id: int, from_id: int, index: int, to_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var feeding := from_id == actor_id and to_id != actor_id
	var taking := to_id == actor_id and from_id != actor_id
	var dino := entity(to_id if feeding else from_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = Enums.ActionResult.OK if feeding or taking else Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _transfer_problem(actor, dino, index, feeding)
	if problem == Enums.ActionResult.OK:
		var source := actor.inventory if feeding else dino.inventory
		var item_id := str(source.get_slot(index).get("id", ""))
		if source.transfer_slot(index, dino.inventory if feeding else actor.inventory) == 0:
			problem = Enums.ActionResult.REFUSED
		elif feeding and item_id == dino.taming.ideal_food:
			dino.feeder_player_id = actor.player_id
	return _answer(actor_id, ACTION_TRANSFER, problem)


## Manda o domado `target_id` obedecer a ordem `order` (nome em `Enums.DinoOrder`, ex.: "FOLLOW").
## Só o dono, perto, e só com a criatura domesticada e acordada.
func request_command(actor_id: int, target_id: int, order: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var dino := entity(target_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (order.length() > MAX_ORDER_NAME or not Enums.DinoOrder.has(order)):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _command_problem(actor, dino)
	if problem == Enums.ActionResult.OK and not dino.state_machine.set_order(Enums.DinoOrder[order] as Enums.DinoOrder):
		problem = Enums.ActionResult.WRONG_STATE
	return _answer(actor_id, ACTION_COMMAND, problem)


## Usar o atalho `slot` (0 a 8) do inventário de `actor_id`: comer ou equipar/desequipar.
func request_use_item(actor_id: int, slot: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (slot < 0 or slot >= HotbarComponent.SLOT_COUNT):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = actor.perform_use_item(slot)
	return _answer(actor_id, ACTION_USE_ITEM, problem)


## Equipar o item `iid` da grade de `actor_id` (`slot_id` "" = a vaga do item).
func request_equip(actor_id: int, iid: String, slot_id: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (iid == "" or iid.length() > MAX_ID_LENGTH or slot_id.length() > MAX_ID_LENGTH):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _equipment_result(actor.perform_equipment(iid, slot_id))
	return _answer(actor_id, ACTION_EQUIP, problem)


## Tirar o item da vaga `slot_id` de `actor_id` para a grade.
func request_unequip(actor_id: int, slot_id: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and slot_id.length() > MAX_ID_LENGTH:
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _equipment_result(actor.perform_equipment("", slot_id))
	return _answer(actor_id, ACTION_UNEQUIP, problem)


## Colher o nó de recurso `target_id` (o id do alvo, nunca a mira local de quem pede).
func request_gather(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var node := entity(target_id) as ResourceNode
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = Enums.ActionResult.OK if node != null else Enums.ActionResult.UNKNOWN_TARGET
	if problem == Enums.ActionResult.OK and not _within(actor, node, node.def.reach):
		problem = Enums.ActionResult.OUT_OF_RANGE
	if problem == Enums.ActionResult.OK:
		problem = _gather_result(actor.perform_gather(node))
	return _answer(actor_id, ACTION_GATHER, problem)


func _equipment_result(reason: String) -> Enums.ActionResult:
	if reason == "":
		return Enums.ActionResult.OK
	return Enums.ActionResult.COOLDOWN if reason == Player.COOLDOWN else Enums.ActionResult.REFUSED


func _gather_result(reason: String) -> Enums.ActionResult:
	match reason:
		"":
			return Enums.ActionResult.OK
		Player.COOLDOWN:
			return Enums.ActionResult.COOLDOWN
		Player.GATHER_DEPLETED:
			return Enums.ActionResult.WRONG_STATE
		Player.GATHER_NEEDS_TOOL:
			return Enums.ActionResult.OK  # o toque aconteceu (a mão doeu); só não coletou: a recusa vai no sinal do jogador
	return Enums.ActionResult.REFUSED


func _live_player(actor_id: int) -> Player:
	var actor := entity(actor_id) as Player
	return actor if actor != null and not actor.health.is_dead() else null


## Por que o ator não serve (OK = serve): não é um jogador registrado, ou está morto.
func _actor_problem(actor_id: int, actor: Player) -> Enums.ActionResult:
	if actor != null:
		return Enums.ActionResult.OK
	return Enums.ActionResult.ACTOR_DEAD if entity(actor_id) is Player else Enums.ActionResult.UNKNOWN_ACTOR


func _attack_problem(actor: Player, dino: Dino) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead() or dino.state_machine.is_tamed:
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, dino, rules.reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	return Enums.ActionResult.OK if actor.can_strike() else Enums.ActionResult.COOLDOWN


func _interact_problem(actor: Player, target: Node) -> Enums.ActionResult:
	if target == null or target == actor:
		return Enums.ActionResult.UNKNOWN_TARGET
	var area := target.get("interactable") as InteractableArea
	if area == null:
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, target, rules.reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	return Enums.ActionResult.OK if area.can_interact() else Enums.ActionResult.WRONG_STATE


func _transfer_problem(actor: Player, dino: Dino, index: int, feeding: bool) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead():
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, dino, rules.reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	if not dino.can_interact():  # só o selvagem inconsciente abre a tela
		return _closed_inventory_problem(dino, actor.player_id)
	var source := actor.inventory if feeding else dino.inventory
	return Enums.ActionResult.OK if index >= 0 and index < source.slot_count() else Enums.ActionResult.INVALID_ARGUMENT


func _command_problem(actor: Player, dino: Dino) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead():
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, dino, rules.command_reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	if not dino.state_machine.is_tamed:
		return Enums.ActionResult.WRONG_STATE
	if dino.owner_player_id != actor.player_id:
		return Enums.ActionResult.NOT_OWNER
	return Enums.ActionResult.OK


## O inventário da criatura não abre: é de outro (domesticada), ou a criatura está acordada.
func _closed_inventory_problem(dino: Dino, player_id: String) -> Enums.ActionResult:
	if dino.state_machine.is_tamed and dino.owner_player_id != player_id:
		return Enums.ActionResult.NOT_OWNER
	return Enums.ActionResult.WRONG_STATE


func _within(actor: Node2D, target: Node, reach: float) -> bool:
	var other := target as Node2D
	return other != null and actor.global_position.distance_to(other.global_position) <= reach


## Fecha o pedido: OK passa direto; o resto é negado e avisado.
func _answer(actor_id: int, action: String, result: Enums.ActionResult) -> Enums.ActionResult:
	if result != Enums.ActionResult.OK:
		action_denied.emit(actor_id, action, result)
	return result
