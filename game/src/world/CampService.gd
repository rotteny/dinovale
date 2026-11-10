# SPDX-License-Identifier: MIT
class_name CampService
extends Node
## Assar na Fogueira (E12, PRO-18), filho da `WorldAuthority` (que mantém o contrato `request_cook` e fecha a resposta com o
## motivo daqui). Cada pedido devolve `{result, reason}`. Assar é AÇÃO COM TEMPO, como fabricar e esfolar: o pedido abre uma
## tarefa e cada carne vira assada no FIM do seu tempo (2 s; `CampRules.cook_seconds`), então salvar, cancelar ou ser
## interrompido nunca perde nada: o que já assou fica com o jogador e o que não assou continua cru. O combustível é madeira
## do inventário: 1 para cada 4 carnes (`meat_per_wood`), gasta na 1ª carne de cada grupo de 4. Sem madeira, a tarefa para.
## Para quando: o jogador cai ou sai do mundo, se afasta da Fogueira ou uma parede surge no meio, a Fogueira some, falta
## carne ou madeira, ou o assado não cabe no inventário (a carne crua volta). A tarefa não vai ao save. Qualquer jogador usa
## qualquer Fogueira [provisório 10/11]: a Fogueira não tem dono exclusivo.

## O assar de `actor_id` começou ou acabou (entregou, cancelou ou recusou). A HUD pode ouvir; nada aqui depende dela.
signal cook_started(actor_id: int)
signal cook_ended(actor_id: int)

const RESULT := Enums.ActionResult

var authority: WorldAuthority = null
var rules: CampRules = preload("res://data/balance/camp_rules.tres")
## Por jogador: `{fire: int, left: float, cooked: int}`. `left` é o que falta da carne em andamento.
var _jobs: Dictionary = {}


## Começa a assar para `actor_id` na Fogueira `fire`.
func cook(actor_id: int, fire: Node) -> Dictionary:
	var actor := authority.entity(actor_id) as Player
	if actor == null:
		return _outcome(RESULT.UNKNOWN_ACTOR)
	if actor.is_incapacitated():
		return _outcome(RESULT.ACTOR_DEAD)
	var problem := _start_problem(actor, actor_id, fire)
	if problem["result"] != RESULT.OK:
		return problem
	_jobs[actor_id] = {"fire": authority.id_of(fire), "left": rules.cook_seconds, "cooked": 0}
	authority.announce("cook_started")
	cook_started.emit(actor_id)
	return _outcome(RESULT.OK)


## Passo do assar (público e testável sem quadros): confere se ainda dá e termina as carnes que o tempo completou.
func tick(delta: float) -> void:
	for actor_id: int in _jobs.keys():
		var why := _interruption(actor_id)
		if why != "":
			cancel(actor_id, why)
		else:
			_advance(actor_id, delta)


## Para o assar de `actor_id` e avisa. O que já assou fica com o jogador. Sem tarefa, não faz nada.
func cancel(actor_id: int, reason: String) -> void:
	if not _jobs.has(actor_id):
		return
	var cooked := int((_jobs[actor_id] as Dictionary)["cooked"])
	_end(actor_id)
	authority.announce("cook_cancelled", {"reason": reason, "amount": cooked})


## Cancelar a pedido do jogador.
func cancel_by_player(actor_id: int) -> Dictionary:
	if authority.entity(actor_id) as Player == null:
		return _outcome(RESULT.UNKNOWN_ACTOR)
	if not _jobs.has(actor_id):
		return _outcome(RESULT.WRONG_STATE)
	cancel(actor_id, "by_player")
	return _outcome(RESULT.OK)


## Esquece todo assar em andamento, sem aviso (carregar um save na mesma sessão).
func clear_jobs() -> void:
	for actor_id: int in _jobs.keys():
		_end(actor_id)


## O assar de `actor_id`: `{fire, left, cooked}` ou `{}`. A HUD só lê.
func job(actor_id: int) -> Dictionary:
	return (_jobs[actor_id] as Dictionary).duplicate() if _jobs.has(actor_id) else {}


func _start_problem(actor: Player, actor_id: int, fire: Node) -> Dictionary:
	var camp := fire as CampPiece
	if camp == null or not camp.is_fire() or authority.id_of(camp) == 0:
		return _outcome(RESULT.INVALID_TARGET, "invalid_target")
	if _jobs.has(actor_id):
		return _outcome(RESULT.WRONG_STATE, "already_cooking")
	if not _reachable(actor, camp):
		return _outcome(RESULT.OUT_OF_RANGE, BuildService.REASON_LINE if _near(actor, camp) else "")
	if actor.inventory.count(rules.raw_item) < 1:
		return _outcome(RESULT.REFUSED, "no_meat")
	if actor.inventory.count(rules.fuel_item) < 1:
		return _outcome(RESULT.REFUSED, "no_fuel")
	return _outcome(RESULT.OK)


func _near(actor: Player, fire: Node2D) -> bool:
	return actor.global_position.distance_to(fire.global_position) <= rules.fire_reach_tiles * authority.rules.tile_size


## Perto e sem parede no meio: assar não atravessa parede.
func _reachable(actor: Player, fire: Node2D) -> bool:
	return _near(actor, fire) and not authority.build.grid.segment_blocked(actor.global_position, fire.global_position)


## Por que o assar não pode seguir ("" = segue).
func _interruption(actor_id: int) -> String:
	var actor := authority.entity(actor_id) as Player
	if actor == null:
		return "disconnected"
	if actor.is_incapacitated():
		return "downed"
	var fire := authority.entity(int((_jobs[actor_id] as Dictionary)["fire"])) as CampPiece
	if fire == null:
		return "fire_removed"
	return "" if _reachable(actor, fire) else "left_fire"


func _advance(actor_id: int, delta: float) -> void:
	var job_state: Dictionary = _jobs[actor_id]
	job_state["left"] = float(job_state["left"]) - delta
	while _jobs.has(actor_id) and float(job_state["left"]) <= 0.0:
		var why := _finish_one(actor_id, job_state)
		if why == "":
			job_state["left"] = float(job_state["left"]) + rules.cook_seconds
			continue
		if why == "done":
			_conclude(actor_id)
		else:
			cancel(actor_id, why)


## Assa 1 carne: "" = assou e segue; "done" = acabou a carne crua; outro texto = o motivo de parar ("no_meat", "no_fuel" e
## "inventory_full" antes de assar não gastam nada; "no_fuel" depois de assar para no fim do grupo).
func _finish_one(actor_id: int, job_state: Dictionary) -> String:
	var actor := authority.entity(actor_id) as Player
	var cooked := int(job_state["cooked"])
	var needs_fuel := cooked % rules.meat_per_wood == 0
	if actor.inventory.count(rules.raw_item) < 1:
		return "done" if cooked > 0 else "no_meat"
	if needs_fuel and actor.inventory.count(rules.fuel_item) < 1:
		return "no_fuel"
	actor.inventory.remove(rules.raw_item, 1)
	if actor.inventory.add(rules.cooked_item, 1) > 0:
		actor.inventory.add(rules.raw_item, 1)  # o assado não cabe: a carne crua volta
		return "inventory_full"
	if needs_fuel:
		actor.inventory.remove(rules.fuel_item, 1)
	job_state["cooked"] = cooked + 1
	if actor.inventory.count(rules.raw_item) < 1:
		return "done"  # assou a última: não espera outro ciclo à toa
	if (cooked + 1) % rules.meat_per_wood == 0 and actor.inventory.count(rules.fuel_item) < 1:
		return "no_fuel"  # o próximo grupo de 4 pede madeira e não há
	return ""


func _conclude(actor_id: int) -> void:
	var cooked := int((_jobs[actor_id] as Dictionary)["cooked"])
	_end(actor_id)
	authority.announce("cook_done", {"amount": cooked})


func _end(actor_id: int) -> void:
	_jobs.erase(actor_id)
	cook_ended.emit(actor_id)


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}
