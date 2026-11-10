# SPDX-License-Identifier: MIT
class_name BuildService
extends Node
## Regras de construir, remover e abrir porta (E8a, CON-01/02), filho da `WorldAuthority` (que mantém o contrato
## `request_*` e fecha a resposta com o motivo daqui). Cada pedido devolve `{result, reason}`. Dono da `BuildGrid`.
## `problem` é a mesma validação sem efeito: o ghost da UI a usa para pintar verde ou vermelho, e `build` a repete antes de
## gastar o material (a UI nunca decide nada). Nada do que o cliente diz muda o custo, o alcance ou o lugar.

## Um item individual do Baú caiu no chão (o Baú foi removido): quem desenha o chão o recolhe. Os empilháveis saem por
## `WorldAuthority.items_dropped`, como em todo drop.
signal entry_dropped(entry: Dictionary, at: Vector2, dropper_id: String)

const RESULT := Enums.ActionResult
const REASON_TERRAIN := "bad_terrain"
const REASON_OCCUPIED := "occupied"
const REASON_SAFE_CORE := "safe_core"
const REASON_LIMIT := "place_limit"
const REASON_NO_SUPPORT := "no_support"
const REASON_BODY := "body_in_way"
const REASON_BOX_FULL := "no_space"
const REASON_BOX_NOT_EMPTY := "chest_not_empty"
const REASON_LINE := "blocked_line"
const REASON_OWNER_LIMIT := "owner_limit"

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


## Destruir a peça da célula SEM devolver nada (ataque de dino, quebra): some com o conteúdo, e a espera da Cama some junto.
## Chamada só pela autoridade (não é `request_*`: ninguém de fora pede isto). Devolve false se não havia peça.
func destroy(cell: Vector2i) -> bool:
	var def := grid.def_at(cell)
	if def == null:
		return false
	grid.remove(cell)
	authority.announce("piece_destroyed", {"piece": def.display_name})
	return true


## Remover a peça da célula, devolvendo o material (`rules.refund_percent`). A fundação que ainda apoia outra peça fica.
func remove(actor_id: int, cell: Vector2i) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var def := grid.def_at(cell)
	var refund := refund_of(def) if def != null else {}
	var owner_id := str(grid.piece_at(cell).get("owner", ""))
	var receiver := _refund_receiver(actor, owner_id)
	var problem_found := _remove_problem(actor, cell, refund, receiver)
	if problem_found["result"] != RESULT.OK:
		return problem_found
	_drop_contents(actor, cell)
	grid.remove(cell)
	for item_id: String in refund:
		_give_refund(actor, receiver, owner_id, item_id, int(refund[item_id]), center_of(cell))
	authority.announce("piece_removed", {"piece": def.display_name})
	return _outcome(RESULT.OK)


## Quem recebe o material de uma peça removida: o DONO dela (com `shared_pieces`, quem remove pode não ser o dono). Peça sem dono
## ou do próprio ator volta ao ator; dono fora do mundo = null (o material cai no chão, junto da peça).
func _refund_receiver(actor: Player, owner_id: String) -> Player:
	if owner_id == "" or owner_id == actor.player_id:
		return actor
	return authority.player_body(owner_id) as Player


## Entrega `amount` de `item_id` ao `receiver`; o que não cabe, ou tudo se o dono não está no mundo, cai no chão: aos pés de quem
## removeu se o material era dele, junto da peça (`at`) se era de outro.
func _give_refund(actor: Player, receiver: Player, owner_id: String, item_id: String, amount: int, at: Vector2) -> void:
	var left := receiver.inventory.add(item_id, amount) if receiver != null else amount
	if left <= 0:
		return
	if receiver == actor:
		authority.items_dropped.emit(item_id, left, actor.global_position, actor.player_id)
	else:
		authority.items_dropped.emit(item_id, left, at, owner_id)  # o dono tem a preferência de recolher


## Por que `actor` não pode remover a peça de `cell` (`result` OK = pode).
func _remove_problem(actor: Player, cell: Vector2i, refund: Dictionary, receiver: Player) -> Dictionary:
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
	elif not authority.drops_enabled and (receiver == null or _refund_refusal(receiver, refund) != ""):
		result = RESULT.REFUSED  # sem chão para o excedente cair, o reembolso inteiro precisa caber (nada some)
		reason = _refund_refusal(receiver, refund) if receiver != null else "inventory_full"
	elif not authority.drops_enabled and not _box_empty(cell):
		result = RESULT.REFUSED  # sem chão para largar, o conteúdo não tem para onde ir: nada some
		reason = REASON_BOX_NOT_EMPTY
	return _outcome(result, reason)


## Mover o slot `index` entre o jogador e o Baú `chest` (`into_chest`: do jogador para o Baú). Alcance, vivo, índice e quantidade
## são conferidos aqui; só vai o que o destino comporta, e o que não cabe fica onde estava (nada se perde nem se duplica).
func transfer_chest(actor_id: int, chest: Chest, into_chest: bool, index: int, amount: int) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var problem_found := _chest_problem(actor, chest, index, amount, into_chest)
	if problem_found["result"] != RESULT.OK:
		return problem_found
	var source := actor.inventory if into_chest else chest.inventory
	var destination := chest.inventory if into_chest else actor.inventory
	var item_id := str(source.get_slot(index).get("id", ""))
	if source.transfer_slot(index, destination, amount) == 0:
		return _outcome(RESULT.REFUSED, _transfer_refusal(destination.refusal_for(item_id), into_chest))
	return _outcome(RESULT.OK)


## Motivo da recusa ao mover para o Baú ou para o jogador: o Peso vem primeiro; sem slot, "Baú cheio" (no destino Baú, "no_space")
## ou "Inventário cheio" (o destino é o jogador, CRI-42).
func _transfer_refusal(destination_reason: String, into_chest: bool) -> String:
	if destination_reason == "weight_limit":
		return "weight_limit"
	return REASON_BOX_FULL if into_chest else "inventory_full"


## Por que `actor` não pode mexer no slot `index` do Baú (`result` OK = pode): Baú vivo e na grade, ao alcance, posição e quantidade.
func _chest_problem(actor: Player, chest: Chest, index: int, amount: int, into_chest: bool) -> Dictionary:
	var access := chest_access(actor, chest)
	if access["result"] != RESULT.OK:
		return access
	var source := actor.inventory if into_chest else chest.inventory
	if index < 0 or index >= source.slot_count():
		return _outcome(RESULT.INVALID_ARGUMENT)
	var stack := int(source.get_slot(index).get("count", 1))
	if amount != WorldAuthority.TRANSFER_ALL and (amount < 1 or amount > stack):
		return _outcome(RESULT.INVALID_ARGUMENT)
	return _outcome(RESULT.OK)


## Se `actor` pode abrir o Baú ou mexer nele (`result` OK = pode): Baú vivo e na grade, DO DONO (ou peças compartilhadas),
## ao alcance e com linha livre, sem parede no meio. É a mesma regra de dono da remoção (`_may_change`).
func chest_access(actor: Player, chest: Chest) -> Dictionary:
	if not is_instance_valid(chest):
		return _outcome(RESULT.INVALID_TARGET, "no_piece")
	var cell := cell_of(chest.global_position)
	if chest.inventory == null or grid.container_at(cell) != chest.inventory:
		return _outcome(RESULT.INVALID_TARGET, "no_piece")
	if not _may_change(actor, cell):
		return _outcome(RESULT.NOT_OWNER, "not_yours")
	if actor.global_position.distance_to(center_of(cell)) > rules.reach_tiles * rules.tile_px:
		return _outcome(RESULT.OUT_OF_RANGE)
	if grid.segment_blocked(actor.global_position, center_of(cell)):
		return _outcome(RESULT.OUT_OF_RANGE, REASON_LINE)
	return _outcome(RESULT.OK)


## Abrir ou fechar a porta da célula. Fechar com alguém dentro do tile é recusado (ninguém fica preso na parede).
func toggle_door(actor_id: int, cell: Vector2i) -> Dictionary:
	var actor := _actor(actor_id)
	if actor == null:
		return _no_actor(actor_id)
	var def := grid.def_at(cell)
	if def == null or not def.toggleable:
		return _outcome(RESULT.INVALID_TARGET, "no_door")
	var reach_problem := _door_reach_problem(actor, cell)
	if reach_problem["result"] != RESULT.OK:
		return reach_problem
	if not _may_change(actor, cell):
		return _outcome(RESULT.NOT_OWNER, "not_yours")
	var opening := not grid.is_open(cell)
	if not opening and _body_in(cell):
		return _outcome(RESULT.WRONG_STATE, REASON_BODY)
	grid.set_open(cell, opening)
	authority.announce("door_toggled", {"piece": def.display_name, "state": "aberta" if opening else "fechada", "open": opening})
	return _outcome(RESULT.OK)


## Alcance da porta e linha livre: a porta não se abre através da parede.
func _door_reach_problem(actor: Player, cell: Vector2i) -> Dictionary:
	if actor.global_position.distance_to(center_of(cell)) > rules.door_reach_tiles * rules.tile_px:
		return _outcome(RESULT.OUT_OF_RANGE)
	if grid.segment_blocked(actor.global_position, center_of(cell)):
		return _outcome(RESULT.OUT_OF_RANGE, REASON_LINE)
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
	return _cost_problem(actor, def, recipe)


## Material (receita ou item pronto) e limite por dono: a última parte da validação de `_afford_problem`.
func _cost_problem(actor: Player, def: PieceDef, recipe: RecipeDef) -> Dictionary:
	if recipe != null and not recipe.missing_from(actor.inventory).is_empty():
		return _outcome(RESULT.REFUSED, "missing_materials")
	if recipe == null and actor.inventory.count(def.item_id) < 1:
		return _outcome(RESULT.REFUSED, "no_item")
	if def.max_per_owner > 0 and grid.count_of(def.id, actor.player_id) >= def.max_per_owner:
		return _outcome(RESULT.WRONG_STATE, REASON_OWNER_LIMIT)  # Cama: 3 por jogador; Saco de dormir: 1
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


## A célula está livre para alguém pisar ou nascer nela? Terreno e núcleo servem, sem peça e sem nó de recurso. É a que o
## `RespawnPointService` usa para achar onde largar quem renasce ao lado da Cama.
func is_free_cell(cell: Vector2i) -> bool:
	return fixed_problem(cell) == "" and not grid.has_piece(cell) and not _resource_at(cell)


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


## O que a peça guarda cai no chão aos pés dela (o dono é quem removeu): empilháveis pelo sinal de drop da autoridade,
## individuais pelo `entry_dropped`. Sem chão (`drops_enabled` falso) `_remove_problem` já recusou se havia conteúdo.
func _drop_contents(actor: Player, cell: Vector2i) -> void:
	var box := grid.container_at(cell)
	if box == null:
		return
	var at := center_of(cell)
	for index in box.slot_count():
		var slot := box.get_slot(index)
		if slot.is_empty():
			continue
		if slot.has("iid"):
			entry_dropped.emit(slot, at, actor.player_id)
		else:
			authority.items_dropped.emit(str(slot["id"]), int(slot["count"]), at, actor.player_id)


func _box_empty(cell: Vector2i) -> bool:
	var box := grid.container_at(cell)
	return box == null or box.is_empty()


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


## Por que o reembolso inteiro não cabe em `receiver` ("" = cabe): o Peso das unidades SOMADAS passa do limite
## ("weight_limit"), ou falta slot para algum item ("inventory_full").
func _refund_refusal(receiver: Player, refund: Dictionary) -> String:
	var grams := 0
	for item_id: String in refund:
		grams += Items.weight_grams(item_id) * int(refund[item_id])
	if grams > receiver.inventory.weight_room_grams():
		return "weight_limit"
	for item_id: String in refund:
		if receiver.inventory.room_for(item_id) < int(refund[item_id]):
			return "inventory_full"
	return ""


func _outcome(result: Enums.ActionResult, reason: String = "") -> Dictionary:
	return {"result": result, "reason": reason}


## Jogador vivo e de pé com esse id, ou null.
func _actor(actor_id: int) -> Player:
	var actor := authority.entity(actor_id) as Player
	return actor if actor != null and not actor.is_incapacitated() else null


func _no_actor(actor_id: int) -> Dictionary:
	return _outcome(RESULT.ACTOR_DEAD if authority.entity(actor_id) is Player else RESULT.UNKNOWN_ACTOR)
