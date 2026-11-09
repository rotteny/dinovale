# SPDX-License-Identifier: MIT
class_name CraftService
extends Node
## Regras de fabricação (E7a; colocar peça passou ao `BuildService` na E8a), filho da `WorldAuthority` (que mantém o contrato
## `request_*`: valida o ator
## e fecha a resposta com o motivo daqui). Cada pedido devolve `{result, reason}`. O material só sai no FIM da fabricação:
## salvar e fechar no meio não perde nada e cancelar não tem o que devolver. Andar, cair, afastar-se da Bancada ou perder o
## material cancela. A fabricação em andamento não vai ao save.


## Um item INDIVIDUAL (`{id, iid, durab, durab_max}`) foi parar no chão (fabricado com o inventário cheio). A `Main` o liga ao chão.
signal entry_dropped(entry: Dictionary, at: Vector2, dropper_id: String)

const RESULT := Enums.ActionResult

var authority: WorldAuthority = null
var recipe_book: RecipeBook = RecipeBook.with_defaults()
var rules: CraftRules = preload("res://data/balance/craft_rules.tres")
## As peças do mundo (a `Main` liga): de onde saem as Bancadas. Sem o campo, receita de estação "workbench" recusa.
var workbenches: BuildField = null

var _jobs := CraftSystem.new()


## Começa a fabricar `recipe_id` para `actor_id`.
func begin_craft(actor_id: int, recipe_id: String) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var recipe: RecipeDef = recipe_book.find(recipe_id) if recipe_id.length() <= WorldAuthority.MAX_ID_LENGTH else null
	if recipe == null:
		return _outcome(RESULT.INVALID_ARGUMENT, "unknown_recipe")
	if recipe.places_in_world:
		return _outcome(RESULT.WRONG_STATE, "build_in_world")  # fundação, parede e porta se constroem no mundo (B)
	var problem := _craft_problem(actor_id, actor, recipe)
	if problem["result"] != RESULT.OK:
		return problem
	var bench := _bench_near(actor) if recipe.station == RecipeDef.STATION_WORKBENCH else null
	_jobs.begin(actor_id, recipe.id, recipe.seconds, authority.id_of(bench) if bench != null else 0)
	authority.announce("craft_started", {"item": Items.display_name(recipe.output_id), "recipe": recipe.id})
	return _outcome(RESULT.OK)


## Aprende `recipe_id` para `actor_id` gastando Saber (E7b, PRO-13). A autoridade valida tudo: ator vivo, id, receita
## aprendível e ainda não aprendida, Saber livre. O cliente só pede; nada do que ele diga muda o gasto.
func learn(actor_id: int, recipe_id: String) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	if recipe_id.length() > WorldAuthority.MAX_ID_LENGTH:
		return _outcome(RESULT.INVALID_ARGUMENT, ProgressionComponent.REASON_UNKNOWN)
	var reason := actor.progression.learn(recipe_id)
	match reason:
		"":
			var recipe := recipe_book.find(recipe_id)
			authority.owner_event.emit(actor.player_id, "recipe_learned", {"item": recipe.display_name, "recipe": recipe.id})
			return _outcome(RESULT.OK)
		ProgressionComponent.REASON_UNKNOWN:
			return _outcome(RESULT.INVALID_ARGUMENT, reason)
		ProgressionComponent.REASON_NO_SABER:
			return _outcome(RESULT.REFUSED, reason)
	return _outcome(RESULT.WRONG_STATE, reason)


## Por que a receita não pode ser fabricada agora (`result` OK = pode).
func _craft_problem(actor_id: int, actor: Player, recipe: RecipeDef) -> Dictionary:
	if not actor.progression.knows(recipe):
		return _outcome(RESULT.REFUSED, "recipe_locked")
	if _jobs.is_crafting(actor_id):
		return _outcome(RESULT.WRONG_STATE, "already_crafting")
	if recipe.station == RecipeDef.STATION_WORKBENCH and _bench_near(actor) == null:
		return _outcome(RESULT.OUT_OF_RANGE, "no_workbench")
	if not recipe.missing_from(actor.inventory).is_empty():
		return _outcome(RESULT.REFUSED, "missing_materials")
	if not _output_fits(actor, recipe):
		return _outcome(RESULT.REFUSED, "inventory_full")
	return _outcome(RESULT.OK)


## Cancelar a fabricação em curso, a pedido do jogador.
func cancel_by_player(actor_id: int) -> Dictionary:
	if _actor(actor_id) == null:
		return _no_actor(actor_id)
	if not _jobs.is_crafting(actor_id):
		return _outcome(RESULT.WRONG_STATE)
	cancel(actor_id, "by_player")
	return _outcome(RESULT.OK)


## Para a fabricação de `actor_id` e avisa (`craft_cancelled`, com o motivo). Sem tarefa, não faz nada.
func cancel(actor_id: int, reason: String) -> void:
	var job := _jobs.cancel(actor_id)
	if job.is_empty():
		return
	var recipe := recipe_book.find(str(job["recipe"]))
	authority.announce("craft_cancelled", {"item": Items.display_name(recipe.output_id) if recipe != null else "", "reason": reason})


## Esquece toda fabricação em andamento, sem aviso (carregar um save na mesma sessão: o estado do jogador mudou por baixo dela).
func clear_jobs() -> void:
	for actor_id in _jobs.actors():
		_jobs.cancel(actor_id)


## A fabricação de `actor_id` em andamento: `{recipe, left, total, bench}` ou `{}`. A tela só lê.
func job(actor_id: int) -> Dictionary:
	return _jobs.job_of(actor_id)


## Fração pronta (0 a 1) da fabricação de `actor_id`.
func progress(actor_id: int) -> float:
	return _jobs.progress(actor_id)


## Passo da fabricação (público e testável sem quadros): confere se ainda dá e conclui quem acabou.
func tick(delta: float) -> void:
	for actor_id in _jobs.actors():
		var why := _interruption(actor_id)
		if why != "":
			cancel(actor_id, why)
	for actor_id in _jobs.tick(delta):
		_finish(actor_id)


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}


## Jogador vivo e de pé com esse id, ou null.
func _actor(actor_id: int) -> Player:
	var actor := authority.entity(actor_id) as Player
	return actor if actor != null and not actor.is_incapacitated() else null


func _no_actor(actor_id: int) -> Dictionary:
	return _outcome(RESULT.ACTOR_DEAD if authority.entity(actor_id) is Player else RESULT.UNKNOWN_ACTOR)


func _reach_px() -> float:
	return rules.workbench_reach_tiles * authority.rules.tile_size


func _bench_near(actor: Player) -> Workbench:
	return workbenches.nearest_workbench(actor.global_position, _reach_px()) if workbenches != null else null


## Por que a fabricação em curso não pode seguir ("" = segue).
func _interruption(actor_id: int) -> String:
	if authority.entity(actor_id) == null:
		return "disconnected"  # saiu do mundo no meio da fabricação
	var actor := _actor(actor_id)
	if actor == null:
		return "downed"
	var bench_id := int(_jobs.job_of(actor_id).get("bench", 0))
	if bench_id > 0:
		var bench := authority.entity(bench_id) as Workbench
		if bench == null or actor.global_position.distance_to(bench.global_position) > _reach_px():
			return "left_workbench"
	return ""


## O resultado cabe? Com chão ligado sempre (o que não cabe cai); sem ele, só se couber no inventário.
## Sem chão, a conta é feita DEPOIS de gastar o material (num inventário de teste): o que sai libera lugar.
func _output_fits(actor: Player, recipe: RecipeDef) -> bool:
	if authority.drops_enabled:
		return true
	var scratch := actor.inventory.preview()
	scratch.from_dict(actor.inventory.to_dict())
	for item_id: String in recipe.inputs:
		scratch.remove(item_id, int(recipe.inputs[item_id]))
	var fits := scratch.room_for(recipe.output_id) >= recipe.output_amount
	scratch.free()
	return fits


func _finish(actor_id: int) -> void:
	var taken := _jobs.cancel(actor_id)
	var actor := _actor(actor_id)
	var recipe := recipe_book.find(str(taken.get("recipe", "")))
	if actor == null or recipe == null:
		return
	var why := ""
	if not recipe.missing_from(actor.inventory).is_empty():
		why = "missing_materials"
	elif not _output_fits(actor, recipe):
		why = "inventory_full"
	if why != "":
		authority.announce("craft_cancelled", {"item": Items.display_name(recipe.output_id), "reason": why})
		return
	for item_id: String in recipe.inputs:
		actor.inventory.remove(item_id, int(recipe.inputs[item_id]))
	_deliver(actor, recipe)
	authority.announce("craft_done", {"item": Items.display_name(recipe.output_id), "amount": recipe.output_amount,
			"recipe": recipe.id})
	authority.grant_craft_xp(actor_id)


## O item entra no inventário; o que não cabe cai aos pés do jogador (nada se perde).
func _deliver(actor: Player, recipe: RecipeDef) -> void:
	if Items.is_individual(recipe.output_id):
		for _unit in recipe.output_amount:
			if actor.inventory.add(recipe.output_id, 1) > 0:
				var durability := Items.durability_max(recipe.output_id)
				entry_dropped.emit({"id": recipe.output_id, "iid": actor.inventory.issue_iid(), "durab": durability,
						"durab_max": durability}, actor.global_position, actor.player_id)
		return
	var left := actor.inventory.add(recipe.output_id, recipe.output_amount)
	if left > 0:
		authority.items_dropped.emit(recipe.output_id, left, actor.global_position, actor.player_id)
		authority.announce("inventory_full")
