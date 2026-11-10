# SPDX-License-Identifier: MIT
class_name CarcassService
extends Node
## Esfolar carcaça (E10, SOB-06), filho da `WorldAuthority` (que mantém o contrato `request_skin` e fecha a resposta com o
## motivo daqui). Cada pedido devolve `{result, reason}`. Esfolar é AÇÃO COM TEMPO (como a fabricação): o pedido abre uma
## tarefa e cada unidade é entregue no FIM do seu tempo (carne 3 s, couro 6 s, metade com a Lança). Andar mais de
## `skin_walk_cancel_tiles` a partir de onde começou, tomar dano, cair ou a carcaça sumir interrompe; o que já foi entregue fica.
## A tarefa não vai ao save. Valida: ator vivo e de pé, carcaça existente, alcance, LINHA LIVRE
## (parede no meio recusa) e QUEM PODE: a carcaça do dino domado é só do dono por `CarcassRules.owner_exclusive_seconds`
## (GDD 5.6); a de selvagem e, passado o prazo, a de domado são de todos (co-op, sem PvP). Quem entrega é o `Player`: carne e
## couro que couberem no Peso e nos slots, o resto fica na carcaça (sem sacolinha). Esfolar não dá XP (não é nó).

## A esfola de `actor_id` começou, andou (fração de 0 a 1) ou acabou (entregou tudo, cancelou ou recusou). A HUD só escuta.
signal skin_started(actor_id: int)
signal skin_progress(actor_id: int, fraction: float)
signal skin_ended(actor_id: int)

const RESULT := Enums.ActionResult

var authority: WorldAuthority = null
var rules: CarcassRules = preload("res://data/balance/carcass_rules.tres")
## Por jogador: `{node, item, left, elapsed, taken, start, life, hurt, blade}`. `item` é a unidade em andamento, `left` o que
## falta dela e `blade` o `iid` em mãos ao começar (a Lança que gasta).
var _jobs: Dictionary = {}




## Começa a esfolar `node` para `actor_id`. A carne e o couro chegam ao longo do tempo (`tick`), não aqui.
func skin(actor_id: int, node: ResourceNode) -> Dictionary:
	var actor := authority.entity(actor_id) as Player
	if actor == null:
		return _outcome(RESULT.UNKNOWN_ACTOR)
	if actor.is_incapacitated():
		return _outcome(RESULT.ACTOR_DEAD)
	var problem := _start_problem(actor, node)
	if problem["result"] != RESULT.OK:
		return problem
	var item := actor.next_skin_item(node)
	if item == "":
		return _refusal(actor.skin_refusal(node))  # nada cabe: a carcaça fica como estava, sem custo
	_jobs[actor_id] = {"node": node, "item": item, "left": actor.skin_seconds(node, item), "elapsed": 0.0, "taken": {},
			"start": actor.global_position, "life": actor.health.current_health, "hurt": 0.0,
			"blade": actor.equipment.iid_in(EquipmentLayout.WEAPON)}
	authority.announce("skin_started", {"carcass": node.def.display_name})
	skin_started.emit(actor_id)
	return _outcome(RESULT.OK)


## Passo da esfola (público e testável sem quadros): confere se ainda dá e entrega o que o tempo completou.
func tick(delta: float) -> void:
	for actor_id: int in _jobs.keys():
		var why := _interruption(actor_id)
		if why != "":
			cancel(actor_id, why)
		else:
			_advance(actor_id, delta)


## Para a esfola de `actor_id` e avisa. O que já foi entregue fica com o jogador. Sem tarefa, não faz nada.
func cancel(actor_id: int, reason: String) -> void:
	if not _jobs.has(actor_id):
		return
	var job: Dictionary = _jobs[actor_id]
	_end(actor_id)
	var node := _node_of(job)
	authority.announce("skin_cancelled", {"carcass": _carcass_name(node), "reason": reason})
	_report(job, node)


## Esquece toda esfola em andamento, sem aviso (carregar um save na mesma sessão).
func clear_jobs() -> void:
	for actor_id: int in _jobs.keys():
		_end(actor_id)


## A esfola de `actor_id`: `{node, item, left, elapsed, taken, ...}` ou `{}`. A HUD só lê.
func job(actor_id: int) -> Dictionary:
	return _jobs.get(actor_id, {})


## Fração pronta (0 a 1) da esfola de `actor_id`: o tempo andado sobre o que já andou mais o que falta (a lâmina em mãos agora).
func progress(actor_id: int) -> float:
	if not _jobs.has(actor_id):
		return 0.0
	var current: Dictionary = _jobs[actor_id]
	var actor := authority.entity(actor_id) as Player
	var node := _node_of(current)
	if actor == null or not is_instance_valid(node):
		return 0.0
	var ahead := float(current["left"])
	var pending := node.component.pending_yields()
	for item_id: String in pending:
		var units := int(pending[item_id]) - (1 if item_id == current["item"] else 0)
		ahead += actor.skin_seconds(node, item_id) * float(maxi(units, 0))
	var done := float(current["elapsed"])
	return clampf(done / maxf(done + ahead, 0.001), 0.0, 1.0)


## Entrega as unidades que o tempo `delta` completou (pode ser mais de uma num passo grande).
func _advance(actor_id: int, delta: float) -> void:
	var current: Dictionary = _jobs[actor_id]
	var actor := authority.entity(actor_id) as Player
	var node := _node_of(current)
	if node == null:
		return
	current["elapsed"] = float(current["elapsed"]) + delta
	var budget := delta
	while budget > 0.0 and _jobs.has(actor_id):
		var left := float(current["left"])
		if budget < left:
			current["left"] = left - budget
			skin_progress.emit(actor_id, progress(actor_id))
			return
		budget -= left
		if not _deliver_unit(actor_id, actor, node, current):
			return
		current["left"] = actor.skin_seconds(node, str(current["item"]))


## Uma unidade chega. Devolve true se há próxima; senão encerra a tarefa (esvaziou, ou o resto não cabe).
func _deliver_unit(actor_id: int, actor: Player, node: ResourceNode, current: Dictionary) -> bool:
	var item := str(current["item"])
	var life := actor.health.current_health
	var delivered := actor.skin_unit(node, item)
	if delivered == Player.SKIN_NOTHING_LEFT:  # outro ator já levou esta unidade: nada é entregue; segue para a próxima ou encerra
		var other := actor.next_skin_item(node)
		if other == "" or not node.is_available():
			_finish(actor_id)
			return false
		current["item"] = other
		return true
	if delivered != "":
		_finish(actor_id)
		return false
	var taken: Dictionary = current["taken"]
	taken[item] = int(taken.get(item, 0)) + 1
	current["hurt"] = float(current["hurt"]) + maxf(life - actor.health.current_health, 0.0)
	current["life"] = actor.health.current_health  # a vida que a própria mão perdeu não é dano de fora
	if not node.is_available():
		_finish(actor_id)
		return false
	var next := actor.next_skin_item(node)
	if next == "":
		_finish(actor_id)  # o que resta não cabe no Peso nem nos slots: fica na carcaça
		return false
	current["item"] = next
	return true


## Conclui a esfola: abre o intervalo entre coletas e conta o que entrou.
func _finish(actor_id: int) -> void:
	var current: Dictionary = _jobs[actor_id]
	_end(actor_id)
	authority.start_gather_interval(actor_id)
	_report(current, _node_of(current))


func _end(actor_id: int) -> void:
	_jobs.erase(actor_id)
	skin_ended.emit(actor_id)


## Por que a esfola em curso não pode seguir ("" = segue): saiu, caiu, andou demais, apanhou ou a carcaça sumiu.
func _interruption(actor_id: int) -> String:
	var actor := authority.entity(actor_id) as Player
	if actor == null:
		return "disconnected"
	if actor.is_incapacitated():
		return "downed"
	var current: Dictionary = _jobs[actor_id]
	var node := _node_of(current)
	if not is_instance_valid(node) or not node.is_available():
		return "gone"
	var limit := authority.rules.tile_size * rules.skin_walk_cancel_tiles
	if actor.global_position.distance_to(current["start"] as Vector2) > limit:
		return "moved"
	var why := ""
	if actor.health.current_health < float(current["life"]) - 0.0001:
		why = "hurt"
	elif actor.equipment.iid_in(EquipmentLayout.WEAPON) != str(current["blade"]):
		why = "weapon_changed"  # trocar a lâmina no meio não esquiva o desgaste nem a mão ferida: a esfola é de quem começou
	current["life"] = maxf(float(current["life"]), actor.health.current_health)  # recuperar vida não esconde o próximo dano
	return why


## A carcaça da tarefa, ou null se já foi liberada (venceu ou foi comida): o nó some sem avisar a tarefa.
func _node_of(current: Dictionary) -> ResourceNode:
	var raw: Variant = current.get("node")
	return raw as ResourceNode if is_instance_valid(raw) else null


func _carcass_name(node: ResourceNode) -> String:
	return node.def.display_name if is_instance_valid(node) and node.def != null else ""


## Por que `actor` não pode começar agora: o `_problem` da carcaça, esfola já em curso e o intervalo entre coletas.
func _start_problem(actor: Player, node: ResourceNode) -> Dictionary:
	var problem := _problem(actor, node)
	if problem["result"] != RESULT.OK:
		return problem
	if _jobs.has(authority.id_of(actor)):
		return _outcome(RESULT.COOLDOWN)  # já esfolando: o pedido repetido não reinicia nem soma (recusa silenciosa)
	if authority.gather_wait_left(authority.id_of(actor)) > 0.0:
		return _outcome(RESULT.COOLDOWN, WorldAuthority.REASON_GATHER_INTERVAL)  # o intervalo entre coletas vale aqui também
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


## Registro do que entrou e do que ficou na carcaça (`carcass_skinned`) e da vida que a mão custou. Nada entrou: sem aviso.
func _report(current: Dictionary, node: ResourceNode) -> void:
	var taken: Array[String] = []
	var totals: Dictionary = current["taken"]
	for item_id: String in totals:
		taken.append("%d %s" % [int(totals[item_id]), Items.display_name(item_id)])
	if taken.is_empty():
		return
	var left: Array[String] = []
	var pending := node.component.pending_yields() if is_instance_valid(node) and node.is_available() else {}
	for item_id: String in pending:
		left.append("%d %s" % [int(pending[item_id]), Items.display_name(item_id)])
	authority.announce("carcass_skinned", {
		"carcass": _carcass_name(node), "taken": ", ".join(taken),
		"left": " (ficou na carcaça: %s)" % ", ".join(left) if not left.is_empty() else ""})
	if float(current["hurt"]) > 0.0:
		authority.announce("hands_hurt", {"amount": snappedf(float(current["hurt"]), 0.1)})


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}
