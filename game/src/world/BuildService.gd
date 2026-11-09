# SPDX-License-Identifier: MIT
class_name BuildService
extends Node
## Regras de construir, remover e abrir porta (E8a, CON-01/02), filho da `WorldAuthority` (que mantém o contrato
## `request_*` e fecha a resposta com o motivo daqui). Cada pedido devolve `{result, reason}`. Dono da `BuildGrid`.
## `problem` é a mesma validação sem efeito: o ghost da UI a usa para pintar verde ou vermelho, e `build` a repete antes de
## gastar o material (a UI nunca decide nada). Nada do que o cliente diz muda o custo, o alcance ou o lugar.

const RESULT := Enums.ActionResult
const REASON_TERRAIN := "bad_terrain"
const REASON_OCCUPIED := "occupied"
const REASON_SAFE_CORE := "safe_core"
const REASON_LIMIT := "place_limit"
const REASON_NO_SUPPORT := "no_support"
const REASON_BODY := "body_in_way"

var authority: WorldAuthority = null
var grid := BuildGrid.new()
## Regras de construção (dado). A grade usa as mesmas: trocar aqui troca lá.
var rules: BuildRules = preload("res://data/balance/build_rules.tres"):
	set(value):
		rules = value
		grid.rules = value
## Mapa (terreno andável). Sem mapa não há terreno a conferir.
var map: IslandMap = null
## Ocupação do chão (jogador e dinos): peça sólida não nasce sobre quem está no tile.
var occupancy: TileOccupancy = null
## Núcleo seguro do mundo (opcional). Fora dele ou dentro, conforme `rules.build_in_safe_core`.
var safe_core: SafeCore = null
## Nós de recurso: nenhuma peça nasce sobre um.
var resources: ResourceField = null


func _init() -> void:
	grid.fixed_check = fixed_problem


## Liga o serviço ao mundo (a `Main` chama; teste monta à mão).
func setup(new_map: IslandMap, new_occupancy: TileOccupancy, new_safe_core: SafeCore, new_resources: ResourceField) -> void:
	map = new_map
	occupancy = new_occupancy
	safe_core = new_safe_core
	resources = new_resources


## Construir `piece_id` na célula `cell` com `rotation` (quartos de volta, 0 a 3). Gasta o material da receita.
func build(actor_id: int, piece_id: String, cell: Vector2i, rotation: int) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var problem := problem_for(actor, piece_id, cell, rotation)
	if problem["result"] != RESULT.OK:
		return problem
	var def := grid.catalog.find(piece_id)
	_pay(actor, def)
	grid.add(cell, piece_id, rotation, actor.player_id)
	authority.announce("piece_built", {"piece": def.display_name})
	return _outcome(RESULT.OK)


## Colocar o item pronto `item_id` (a Bancada) no tile de `point`: a mesma construção, pagando 1 do inventário.
func place_item(actor_id: int, item_id: String, point: Vector2) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var def := grid.catalog.find_by_item(item_id) if item_id.length() <= WorldAuthority.MAX_ID_LENGTH else null
	if def == null or not point.is_finite() or absf(point.x) > BuildGrid.MAX_CELL * rules.tile_px \
			or absf(point.y) > BuildGrid.MAX_CELL * rules.tile_px:
		return _outcome(RESULT.INVALID_ARGUMENT)
	var problem := problem_for(actor, def.id, cell_of(point), 0)
	if problem["result"] != RESULT.OK:
		return problem
	_pay(actor, def)
	grid.add(cell_of(point), def.id, 0, actor.player_id)
	authority.announce("item_placed", {"item": Items.display_name(item_id)})
	return _outcome(RESULT.OK)


## Remover a peça da célula, devolvendo o material (`rules.refund_percent`). A fundação que ainda apoia outra peça fica.
func remove(actor_id: int, cell: Vector2i) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var def := grid.def_at(cell)
	var refund := refund_of(def) if def != null else {}
	var problem_found := _remove_problem(actor, cell, refund)
	if problem_found["result"] != RESULT.OK:
		return problem_found
	grid.remove(cell)
	for item_id: String in refund:
		var left := actor.inventory.add(item_id, int(refund[item_id]))
		if left > 0:
			authority.items_dropped.emit(item_id, left, actor.global_position, actor.player_id)
	authority.announce("piece_removed", {"piece": def.display_name})
	return _outcome(RESULT.OK)


## Por que `actor` não pode remover a peça de `cell` (`result` OK = pode).
func _remove_problem(actor: Player, cell: Vector2i, refund: Dictionary) -> Dictionary:
	var result := RESULT.OK
	var reason := ""
	if not grid.has_piece(cell):
		result = RESULT.INVALID_TARGET
		reason = "no_piece"
	elif actor.global_position.distance_to(center_of(cell)) > rules.reach_tiles * rules.tile_px:
		result = RESULT.OUT_OF_RANGE
	elif not _may_change(actor, cell):
		result = RESULT.NOT_OWNER
		reason = "not_yours"
	elif not grid.dependents_of(cell).is_empty():
		result = RESULT.WRONG_STATE
		reason = "has_dependents"
	elif not authority.drops_enabled and not _refund_fits(actor, refund):
		result = RESULT.REFUSED
		reason = "inventory_full"
	return _outcome(result, reason)


## Abrir ou fechar a porta da célula. Fechar com alguém dentro do tile é recusado (ninguém fica preso na parede).
func toggle_door(actor_id: int, cell: Vector2i) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var def := grid.def_at(cell)
	if def == null or not def.toggleable:
		return _outcome(RESULT.INVALID_TARGET, "no_door")
	if actor.global_position.distance_to(center_of(cell)) > rules.door_reach_tiles * rules.tile_px:
		return _outcome(RESULT.OUT_OF_RANGE)
	if not _may_change(actor, cell):
		return _outcome(RESULT.NOT_OWNER, "not_yours")
	var opening := not grid.is_open(cell)
	if not opening and _body_in(cell):
		return _outcome(RESULT.WRONG_STATE, REASON_BODY)
	grid.set_open(cell, opening)
	authority.announce("door_toggled", {"piece": def.display_name, "state": "aberta" if opening else "fechada", "open": opening})
	return _outcome(RESULT.OK)


## O que voltaria ao remover `def`: item -> quantidade (pelo `refund_percent`, arredondado para baixo; o item pronto volta inteiro).
func refund_of(def: PieceDef) -> Dictionary:
	if def.item_id != "":
		return {def.item_id: 1}
	var refund := {}
	var recipe := authority.crafting.recipe_book.find(def.recipe_id)
	if recipe == null:
		return refund
	for item_id: String in recipe.inputs:
		var amount := floori(float(recipe.inputs[item_id]) * float(rules.refund_percent) / 100.0)
		if amount > 0:
			refund[item_id] = amount
	return refund


## Por que `actor` não pode construir `piece_id` em `cell` agora (`result` OK = pode). Sem efeito colateral.
func problem(actor_id: int, piece_id: String, cell: Vector2i, rotation: int) -> Dictionary:
	var actor := _actor(actor_id)
	return _no_actor(actor_id) if actor == null else problem_for(actor, piece_id, cell, rotation)


func problem_for(actor: Player, piece_id: String, cell: Vector2i, rotation: int) -> Dictionary:
	var def := grid.catalog.find(piece_id) if piece_id.length() <= WorldAuthority.MAX_ID_LENGTH else null
	if def == null:
		return _outcome(RESULT.INVALID_ARGUMENT, "unknown_piece")
	if rotation < 0 or rotation > 3 or not _cell_in_range(cell):
		return _outcome(RESULT.INVALID_ARGUMENT)
	return _afford_problem(actor, def, cell)


## A segunda metade de `problem_for` (peça e argumentos já válidos): receita, alcance, lugar e material.
func _afford_problem(actor: Player, def: PieceDef, cell: Vector2i) -> Dictionary:
	var recipe := authority.crafting.recipe_book.find(def.recipe_id) if def.recipe_id != "" else null
	if def.recipe_id != "" and (recipe == null or not actor.progression.knows(recipe)):
		return _outcome(RESULT.REFUSED, "recipe_locked")
	if actor.global_position.distance_to(center_of(cell)) > rules.reach_tiles * rules.tile_px:
		return _outcome(RESULT.OUT_OF_RANGE)
	var spot := spot_problem(cell, def)
	if spot != "":
		return _outcome(RESULT.WRONG_STATE, spot)
	if recipe != null and not recipe.missing_from(actor.inventory).is_empty():
		return _outcome(RESULT.REFUSED, "missing_materials")
	if recipe == null and actor.inventory.count(def.item_id) < 1:
		return _outcome(RESULT.REFUSED, "no_item")
	return _outcome(RESULT.OK)


## Por que a célula não serve para a peça ("" = serve): terreno, núcleo seguro, ocupada, recurso, sem apoio, corpo, teto.
func spot_problem(cell: Vector2i, def: PieceDef) -> String:
	var fixed := fixed_problem(cell)
	if fixed != "":
		return fixed
	if grid.has_piece(cell) or _resource_at(cell):
		return REASON_OCCUPIED
	if def.needs_support and not grid.has_support(cell):
		return REASON_NO_SUPPORT
	if def.blocks_body and _body_in(cell):
		return REASON_BODY
	if grid.count() >= rules.max_pieces or (def.max_count > 0 and grid.count_of(def.id) >= def.max_count):
		return REASON_LIMIT
	return ""


## O que não muda com o tempo: terreno e núcleo seguro ("" = serve). É o que um save carregado também confere.
func fixed_problem(cell: Vector2i) -> String:
	if not rules.build_in_safe_core and safe_core != null and safe_core.contains(center_of(cell)):
		return REASON_SAFE_CORE
	if map != null and map.is_valid() and not (map.is_land(cell) and map.is_walkable(cell)):
		return REASON_TERRAIN
	return ""


## A célula que contém `point`.
func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / rules.tile_px), floori(point.y / rules.tile_px))


## O centro da célula, em pixels do mundo.
func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * rules.tile_px


func _pay(actor: Player, def: PieceDef) -> void:
	if def.item_id != "":
		actor.inventory.remove(def.item_id, 1)
		return
	var recipe := authority.crafting.recipe_book.find(def.recipe_id)
	for item_id: String in recipe.inputs:
		actor.inventory.remove(item_id, int(recipe.inputs[item_id]))


## Dono mexe sempre; os outros só se as peças são compartilhadas (`rules.shared_pieces`).
func _may_change(actor: Player, cell: Vector2i) -> bool:
	return rules.shared_pieces or str(grid.piece_at(cell).get("owner", "")) in ["", actor.player_id]


func _body_in(cell: Vector2i) -> bool:
	return occupancy != null and not occupancy.is_cell_free(cell, rules.tile_px)


func _resource_at(cell: Vector2i) -> bool:
	if resources == null:
		return false
	for node in resources.nodes():
		if cell_of(node.global_position) == cell:
			return true
	return false


## Número de célula sensato (fora do mapa mas dentro disto é terreno: mar, `bad_terrain`; além é pedido inválido).
func _cell_in_range(cell: Vector2i) -> bool:
	return absi(cell.x) <= BuildGrid.MAX_CELL and absi(cell.y) <= BuildGrid.MAX_CELL


func _refund_fits(actor: Player, refund: Dictionary) -> bool:
	for item_id: String in refund:
		if actor.inventory.room_for(item_id) < int(refund[item_id]):
			return false
	return true


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}


## Jogador vivo e de pé com esse id, ou null.
func _actor(actor_id: int) -> Player:
	var actor := authority.entity(actor_id) as Player
	return actor if actor != null and not actor.is_incapacitated() else null


func _no_actor(actor_id: int) -> Dictionary:
	return _outcome(RESULT.ACTOR_DEAD if authority.entity(actor_id) is Player else RESULT.UNKNOWN_ACTOR)
