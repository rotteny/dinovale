# SPDX-License-Identifier: MIT
class_name CarryTests
extends ChestTests
## E10, PRO-09: o Peso. Números do GDD em dado, limite de 50 kg, recusa "Peso máximo" sem gastar nada (coleta, chão, Baú,
## fabricação, reembolso e corpo), ferramenta fora dos slots que pesa, HUD e a viagem do abrigo mínimo (custo real).

const LIMIT_G := 50000


func run() -> void:
	_test_data()
	_test_limit_and_units()
	_test_worn_tools_weigh()
	_test_gather_refusal_keeps_node()
	_test_ground_pickup()
	_test_chest_take()
	_test_craft_heavier_than_material()
	_test_refund_excess_and_refusal()
	_test_corpse_recovery()
	_test_hud_line()
	_test_shelter_trip()
	_release_worlds()


## Enche o inventário de `player` até sobrarem `room_g` gramas de Peso (com madeira, 1 kg, e fibra, 0,05 kg).
func _fill_to_room(player: Player, room_g: int) -> void:
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	var target := LIMIT_G - room_g
	while player.inventory.carried_grams() + 1000 <= target:
		player.inventory.add(Items.WOOD, 1)
	while player.inventory.carried_grams() + 50 <= target:
		player.inventory.add(Items.FIBER, 1)


func _world_with_weight() -> Dictionary:
	var world := _setup()
	var player: Player = world["player"]
	_empty_inventory(player)
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	player.inventory.worn = player.equipment
	return world


func _empty_inventory(player: Player) -> void:
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)


func _test_data() -> void:
	var missing: Array[String] = []
	for item_id: String in Items.all_ids():
		if Items.weight_grams(item_id) <= 0:
			missing.append(item_id)
	_check(missing.is_empty(), "todo item do catálogo tem peso em dado (faltam: %s)" % str(missing))
	_check(Items.CARRY.capacity_kg == 50.0, "capacidade do jogador: 50 kg")
	var gdd := {Items.WOOD: 1000, Items.STONE: 1500, Items.MEAT: 500, Items.FIBER: 50, Items.BERRY: 100, Items.FERN: 100,
			Items.SLEEP_FRUIT: 100, Items.LEATHER: 400, Items.SLEEP_STAFF: 2000, Items.RATION_C: 200, Items.TUBER: 300,
			Items.VEIN_SALT: 500}
	var same := true
	for item_id: String in gdd:
		same = same and Items.weight_grams(item_id) == int(gdd[item_id])
	_check(same, "os pesos da tabela do GDD 5.1 e 5.9 (madeira 1, pedra 1,5, carne 0,5, fibra 0,05, couro 0,4...)")
	var kit := 10 * Items.weight_grams(Items.BERRY) + 4 * Items.weight_grams(Items.MEAT) + 3 * Items.weight_grams(Items.FERN)
	_check(kit == 3300, "kit inicial: 3,3 kg (GDD 5.1)")


func _test_limit_and_units() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var left := player.inventory.add(Items.WOOD, 60)
	_check(left == 10 and player.inventory.count(Items.WOOD) == 50 and player.inventory.carried_grams() == LIMIT_G,
			"50 kg: entram 50 madeiras e as outras 10 voltam como não couberam")
	_check(player.inventory.room_for(Items.FIBER) == 0 and player.inventory.refusal_for(Items.WOOD) == "weight_limit",
			"no limite nada entra, e o motivo é o Peso")
	player.inventory.remove(Items.WOOD, 1)
	_check(player.inventory.room_for(Items.WOOD) == 1 and player.inventory.room_for(Items.FIBER) == 20,
			"sobrando 1 kg: 1 madeira ou 20 fibras")
	var steady := player.inventory.carried_grams()
	var changed: Array = []
	player.inventory.changed.connect(func() -> void: changed.append(true))
	_check(player.inventory.add(Items.STONE, 1) == 1 and player.inventory.carried_grams() == steady and changed.is_empty(),
			"recusa por Peso não muda nada nem avisa mudança")
	# Slot e Peso juntos: o Peso é o motivo (CRI-42 da E11a manda dizer Peso).
	player.inventory.capacity = 1
	_check(player.inventory.refusal_for(Items.STONE) == "weight_limit", "se Peso e slot batem juntos, diz Peso")
	# Sem limite (alforje do dino): nunca recusa por Peso.
	var free := InventoryComponent.new()
	_track.call(free)
	_check(free.weight_room_grams() == InventoryComponent.NO_WEIGHT_LIMIT and free.add(Items.STONE, 20) == 0,
			"sem limite: sem recusa por Peso")


func _test_worn_tools_weigh() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	player.inventory.add(Items.SLEEP_STAFF, 1)
	player.inventory.add(Items.WOODEN_SPEAR, 1)
	_check(player.inventory.carried_grams() == 4000, "ferramenta na grade pesa (Bastão 2 + Lança 2)")
	player.request_equip(player.inventory.find_iid(player.newest_iid(Items.WOODEN_SPEAR)).get("iid", ""))
	_check(player.equipment.count(Items.WOODEN_SPEAR) == 1 and player.inventory.carried_grams() == 4000,
			"a Lança nas mãos (fora dos slots) segue contando no Peso")
	_fill_to_room(player, 0)
	_check(player.inventory.carried_grams() > 0 and player.inventory.weight_room_grams() < 50,
			"enche até o limite com as ferramentas contando")
	player._equip_timer = 0.0
	_check(player.request_unequip(EquipmentLayout.WEAPON) == "",
			"tirar a arma no limite não é recusado por Peso (mover não muda a carga)")
	_check(player.equipment.count(Items.WOODEN_SPEAR) == 0 and player.inventory.count(Items.WOODEN_SPEAR) == 1,
			"a Lança voltou à grade sem a carga mudar")


func _bush(world: Dictionary) -> ResourceNode:
	var node: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	node.node_id = "carry_bush"
	node.def = load("res://data/resources/bush_baga.tres")
	node.position = (world["player"] as Player).position + Vector2(0, 8)
	_root.add_child(node)
	_track.call(node)
	(world["authority"] as WorldAuthority).register(node)
	return node


func _test_gather_refusal_keeps_node() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var bush := _bush(world)
	_fill_to_room(player, 0)  # no limite: nem a baga (0,1) nem a fibra (0,05) do mesmo arbusto entram
	var before := player.inventory.to_dict()
	var pending := bush.component.pending_yields()
	var events_before: int = (world["events"] as Array).size()
	var result := authority.request_gather(1, authority.id_of(bush))
	_check(result == Enums.ActionResult.REFUSED and _reason_since(world, events_before) == "weight_limit",
			"coleta acima do Peso: recusa com 'weight_limit'")
	_check(GameMessages.reason_text("weight_limit") == "Peso máximo.", "o texto da recusa é 'Peso máximo.'")
	_check(bush.is_available() and bush.component.pending_yields() == pending
			and JSON.stringify(player.inventory.to_dict()) == JSON.stringify(before),
			"o nó não gasta e o inventário não muda")
	_check(player.gather_cooldown_left() == 0.0, "e nenhuma recarga é cobrada")


func _ground(world: Dictionary) -> GroundItemField:
	var field := GroundItemField.new()
	_root.add_child(field)
	_track.call(field)
	field.set_physics_process(false)
	field.authority = world["authority"]
	field.clock = (world["authority"] as WorldAuthority).clock.now
	field.world_seed = 7
	return field


func _test_ground_pickup() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var field := _ground(world)
	var piles := field.spawn_scatter(Items.STONE, 4, player.position)
	var pile := piles[0]
	player.position = pile.position
	_fill_to_room(player, 0)
	var amount0 := pile.amount
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_pickup(1, authority.id_of(pile)) == Enums.ActionResult.REFUSED
			and _reason_since(world, events_before) == "weight_limit" and pile.amount == amount0,
			"chão: acima do Peso recusa e a pilha fica inteira")
	player.inventory.remove(Items.WOOD, 3)  # 3 kg de folga: cabem 2 pedras (3 kg)
	var stones := player.inventory.count(Items.STONE)
	authority.request_pickup(1, authority.id_of(pile))
	var took := player.inventory.count(Items.STONE) - stones
	_check(took == mini(2, amount0) and pile.amount == amount0 - took,
			"chão: leva só o que cabe no Peso (no máximo 2 pedras de 3 kg) e o resto fica")


func _test_chest_take() -> void:
	var world := _with_chest()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var chest := _chest(world)
	_empty_inventory(player)
	chest.inventory.add(Items.STONE, 10)
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	_fill_to_room(player, 1000)  # cabe 0 pedra (1,5)
	var index := _slot_of(chest.inventory, Items.STONE)
	var before := JSON.stringify(chest.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict())
	var events_before: int = (world["events"] as Array).size()
	var result := authority.request_transfer_slot(1, int(world["chest_id"]), index, 1, WorldAuthority.TRANSFER_ALL)
	_check(result == Enums.ActionResult.REFUSED and _reason_since(world, events_before) == "weight_limit"
			and JSON.stringify(chest.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict()) == before,
			"Baú: tirar acima do Peso recusa e nada muda")


func _test_craft_heavier_than_material() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var book := authority.crafting.recipe_book
	var heavy := RecipeDef.new()
	heavy.id = "heavy_ration"
	heavy.display_name = "Ração pesada"
	heavy.inputs = {Items.BERRY: 3}
	heavy.output_id = Items.RATION_C
	heavy.output_amount = 2
	heavy.seconds = 1.0
	heavy.station = "hand"
	heavy.saber_cost = 0
	_check(book.add(heavy) and heavy.is_known_at_start(),
			"preparo: receita que sai mais pesada que o material (0,3 kg viram 0,4 kg)")
	_check(Items.weight_grams(Items.RATION_C) * 2 > 3 * Items.weight_grams(Items.BERRY),
			"a Ração C de verdade já é mais pesada que as bagas")
	player.inventory.add(Items.BERRY, 3)
	_fill_to_room(player, 100)  # sobram 100 g: a troca (+100 g) cabe exatamente
	_check(authority.crafting.begin_craft(1, "heavy_ration")["result"] == OK, "folga igual à diferença: fabrica")
	authority.crafting.cancel(1, "by_player")
	player.inventory.add(Items.FIBER, 1)  # agora faltam 50 g
	var before := JSON.stringify(player.inventory.to_dict())
	var outcome := authority.crafting.begin_craft(1, "heavy_ration")
	_check(outcome["result"] == Enums.ActionResult.REFUSED and outcome["reason"] == "weight_limit",
			"sai mais pesado que o material e passa do limite: recusa 'Peso máximo', sem chão")
	_check(JSON.stringify(player.inventory.to_dict()) == before and (world["dropped"] as Array).is_empty(),
			"o material fica intacto e nada cai no chão (decisão: recusar, não despejar)")
	# Fabricar DEPOIS de carregar mais no meio do trabalho cancela e preserva o material.
	player.inventory.remove(Items.FIBER, 1)
	authority.crafting.begin_craft(1, "heavy_ration")
	player.inventory.add(Items.FIBER, 1)
	authority.crafting.tick(5.0)
	_check(player.inventory.count(Items.BERRY) == 3 and player.inventory.count(Items.RATION_C) == 0,
			"carregou algo no meio: a fabricação cancela e o material fica")


func _test_refund_excess_and_refusal() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	authority.build.rules.refund_percent = 100
	player.inventory.add(Items.WOOD, 3)
	player.inventory.add(Items.STONE, 1)
	_check(_ask(world, "foundation", HOME + Vector2i(1, 0))["result"] == OK, "preparo: fundação construída")
	_fill_to_room(player, 1000)  # a fundação devolve 4,5 kg: só cabem 1000 g
	var dropped_before: int = (world["dropped"] as Array).size()
	var answer := authority.request_remove_piece(1, HOME + Vector2i(1, 0))
	var excess := 0
	for index in range((world["dropped"] as Array).size() - dropped_before):
		excess += int(world["dropped"][dropped_before + index][1])
	_check(answer == OK and excess > 0 and player.inventory.weight_room_grams() < 1000 + 1,
			"reembolso acima do Peso: a peça sai e o EXCESSO cai no chão (decisão: nada se perde, ninguém fica preso)")
	# Sem chão para o excesso, o reembolso inteiro precisa caber: recusa com o Peso.
	var second := _world_with_weight()
	var other: Player = second["player"]
	var second_authority: WorldAuthority = second["authority"]
	other.inventory.add(Items.WOOD, 3)
	other.inventory.add(Items.STONE, 1)
	_ask(second, "foundation", HOME + Vector2i(1, 0))
	_fill_to_room(other, 1000)
	second_authority.drops_enabled = false
	var state := _state(second)
	var events_before: int = (second["events"] as Array).size()
	_check(second_authority.request_remove_piece(1, HOME + Vector2i(1, 0)) == Enums.ActionResult.REFUSED
			and _reason_since(second, events_before) == "weight_limit" and _state(second) == state,
			"sem chão: o reembolso que passa do Peso recusa a remoção e nada muda")


func _test_corpse_recovery() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var corpse := PlayerCorpse.new()
	corpse.owner_player_id = player.player_id
	corpse.position = player.position
	corpse.entries = [{"id": Items.STONE, "count": 10, "expira_em": 0.0}]
	_root.add_child(corpse)
	_track.call(corpse)
	authority.register(corpse)
	_fill_to_room(player, 0)
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_recover_corpse(1, authority.id_of(corpse)) == Enums.ActionResult.REFUSED
			and _reason_since(world, events_before) == "weight_limit" and corpse.count(Items.STONE) == 10,
			"corpo: acima do Peso recusa e os itens ficam no corpo")


func _test_hud_line() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.weight_label().text == "Peso 0/50 kg", "HUD: 'Peso 0/50 kg' (atual e máximo) vazio (%s)" % hud.weight_label().text)
	player.inventory.add(Items.WOOD, 20)
	player.inventory.add(Items.FIBER, 1)
	_check(hud.weight_label().text == "Peso 20,05/50 kg", "HUD acompanha o inventário (%s)" % hud.weight_label().text)


## Abrigo mínimo (GDD 8) com o CUSTO REAL das receitas: 4 fundações, 8 paredes e 1 porta. Cabe em uma viagem com o kit inicial;
## o segundo abrigo não cabe na mesma viagem.
func _test_shelter_trip() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var book := (world["authority"] as WorldAuthority).crafting.recipe_book
	var cost := {}
	for piece: Array in [["foundation", 4], ["wall", 8], ["door", 1]]:
		var recipe := book.find(piece[0])
		for item_id: String in recipe.inputs:
			cost[item_id] = int(cost.get(item_id, 0)) + int(recipe.inputs[item_id]) * int(piece[1])
	var grams := 0
	for item_id: String in cost:
		grams += Items.weight_grams(item_id) * int(cost[item_id])
	_check(grams == 38050, "o custo real do abrigo mínimo pesa 38,05 kg (%d g de %s)" % [grams, str(cost)])
	for item_id: String in player.starting_items:
		player.inventory.add(item_id, int(player.starting_items[item_id]))  # o kit inicial (3,3 kg) já está na mochila
	var kit := player.inventory.carried_grams()
	var first_left := 0
	for item_id: String in cost:
		first_left += player.inventory.add(item_id, int(cost[item_id]))
	_check(first_left == 0 and player.inventory.carried_grams() == kit + grams and player.inventory.carried_grams() <= LIMIT_G,
			"o abrigo mínimo (38,05 kg) cabe numa viagem, com o kit (%.2f kg de 50)" % player.inventory.carried_weight())
	var second_left := 0
	for item_id: String in cost:
		second_left += player.inventory.add(item_id, int(cost[item_id]))
	_check(second_left > 0 and player.inventory.carried_grams() <= LIMIT_G,
			"o segundo abrigo não cabe na mesma viagem (faltou levar %d unidades)" % second_left)
