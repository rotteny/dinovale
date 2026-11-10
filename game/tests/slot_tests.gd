# SPDX-License-Identifier: MIT
class_name SlotTests
extends CarryTests
## E11a, CRI-42 parte 1 e SOB-16: 4 slots de grade, cinto de 4 posições e vaga Arma fora dos slots, recusa "Inventário
## cheio" em cada caminho de entrada (coleta, chão, Baú, fabricação, reembolso, carcaça, corpo, domado, devolução de
## migração), o Peso na frente do slot, migração de save maior sem perda, corpo, Descartar, barra de atalhos e HUD.
## Roda com o dado REAL (4 e 4): as outras suítes usam o layout antigo de 12 slots (`run_tests.gd`) e este restaura no fim.

const FILLERS: Array[String] = [Items.LEATHER, Items.STONE, Items.TUBER, Items.VEIN_SALT]
const TOOLS: Array[String] = [Items.SLEEP_STAFF, Items.WOODEN_SPEAR, Items.AXE_STONE, Items.PICKAXE_STONE]
const REFUSED := Enums.ActionResult.REFUSED

## O dado real do jogo (4 e 4, conferido em `_test_data`).
const REAL_RULES: SlotRules = preload("res://data/balance/slot_rules.tres")


func run() -> void:
	Items.with_layout(REAL_RULES, _run_checks)  # o layout antigo volta sempre, mesmo se um teste abortar
	_release_worlds()


func _run_checks() -> void:
	_test_data()
	_test_grid_and_belt()
	_test_weight_beats_slot()
	_test_equip_flow()
	_test_gather_path()
	_test_ground_path()
	_test_chest_path()
	_test_craft_path()
	_test_refund_path()
	_test_carcass_path()
	_test_corpse_recovery_path()
	_test_tamed_path()
	_test_unplaced_path()
	_test_first_minutes()
	_test_shelter_in_four_slots()
	_test_save_roundtrip()
	_test_migration()
	_test_migration_in_world()
	_test_corpse_takes_everything()
	_test_discard()
	_test_screen()
	_test_hotbar_and_hud()


func _fill_grid(player: Player, ids: Array[String]) -> void:
	for item_id in ids:
		player.inventory.add(item_id, 1)


## Soma por item do que o jogador tem (grade, cinto e vagas) e do que ficou de fora (`spill`).
func _tally(player: Player, spill: Array[Dictionary] = []) -> Dictionary:
	var total := {}
	for item_id: String in Items.all_ids():
		var amount := player.inventory.count(item_id) + player.equipment.count(item_id)
		for entry in spill:
			if entry.get("id") == item_id:
				amount += 1 if entry.has("iid") else int(entry.get("count", 0))
		if amount > 0:
			total[item_id] = amount
	return total


func _legacy_inventory(stacks: Array, tools: Array[String]) -> InventoryComponent:
	var legacy := InventoryComponent.new()
	_track.call(legacy)
	legacy.capacity = 12
	for pair: Array in stacks:
		legacy.add(str(pair[0]), int(pair[1]))
	for item_id in tools:
		legacy.add(item_id, 1)
	return legacy


func _legacy_save(player: Player, legacy: InventoryComponent) -> Dictionary:
	var data := player.to_dict()
	data["inventory"] = legacy.to_dict()
	data["hotbar"] = {"version": HotbarComponent.FORMAT_VERSION, "slots": []}
	data["equipment"] = {"version": EquipmentComponent.FORMAT_VERSION, "slots": {}}
	return data


# ----------------------------------------------------------------------------- dado e modelo

func _test_data() -> void:
	var fresh := ResourceLoader.load("res://data/balance/slot_rules.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as SlotRules
	_check(fresh != null and fresh.player_slots == 4 and fresh.belt_slots == 4,
			"o dado do jogo: 4 slots de grade e cinto de 4 (slot_rules.tres)")
	var belt: Array[String] = []
	var all_individuals_in_belt := true
	for item_id: String in Items.all_ids():
		if Items.belt_of(item_id):
			belt.append(item_id)
		all_individuals_in_belt = all_individuals_in_belt and (Items.is_individual(item_id) == Items.belt_of(item_id) or Items.is_bag(item_id))
	var wanted := TOOLS.duplicate()
	belt.sort()
	wanted.sort()
	_check(belt == wanted and all_individuals_in_belt, "o cinto é do dado do item: Bastão, Lança, Machado e Picareta (%s)" % str(belt))


func _test_grid_and_belt() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var inventory := player.inventory
	_check(inventory.grid_size() == 4 and inventory.belt_size == 4 and inventory.slot_count() == 8,
			"o jogador nasce com 4 slots de grade e 4 posições de cinto, vindos do dado")
	_fill_grid(player, FILLERS)
	_check(inventory.grid_used() == 4 and inventory.room_for(Items.WOOD) == 0 and inventory.add(Items.WOOD, 1) == 1
			and inventory.refusal_for(Items.WOOD) == "inventory_full", "4 pilhas enchem a grade: o 5º item recusa com 'Inventário cheio'")
	_check(inventory.add(Items.STONE, 1) == 0 and inventory.count(Items.STONE) == 2, "a pilha que já existe ainda recebe")
	var entered := 0
	for item_id in TOOLS:
		entered += 1 if inventory.add(item_id, 1) == 0 else 0
	_check(entered == 4 and inventory.grid_used() == 4, "as 4 ferramentas entram no cinto, fora dos slots (a grade segue com 4)")
	_check(inventory.add(Items.AXE_STONE, 1) == 1 and inventory.room_for(Items.AXE_STONE) == 0,
			"o cinto cheio recusa a 5ª ferramenta")
	var axe_iid := player.newest_iid(Items.AXE_STONE)
	_check(inventory.is_belt_index(inventory.index_of_iid(axe_iid)) and not inventory.is_belt_index(0),
			"a ferramenta fica numa posição do cinto, não da grade")
	player._equip_timer = 0.0
	_check(player.request_equip(axe_iid) == "" and player.equipment.count(Items.AXE_STONE) == 1
			and inventory.add(Items.AXE_STONE, 1) == 0, "a vaga Arma é à parte: equipar libera o cinto e entram 5 ferramentas")
	var grams := 0
	for item_id in FILLERS + TOOLS:
		grams += Items.weight_grams(item_id) * (inventory.count(item_id) + player.equipment.count(item_id))
	_check(inventory.carried_grams() == grams, "cinto e vaga Arma contam no Peso (%d g)" % grams)


func _test_weight_beats_slot() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	_fill_grid(player, FILLERS)
	_check(player.inventory.refusal_for(Items.WOOD) == "inventory_full", "só os slots estourados: 'Inventário cheio'")
	player.inventory.weight_limit = player.inventory.carried_weight()
	_check(player.inventory.refusal_for(Items.WOOD) == "weight_limit",
			"Peso e slot estourados ao mesmo tempo: a mensagem é a do Peso")
	_check(player.inventory.refusal_for(Items.STONE) == "weight_limit", "a pilha que existe também: o Peso manda")


func _test_equip_flow() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	for item_id in TOOLS:
		player.inventory.add(item_id, 1)
	var axe := player.newest_iid(Items.AXE_STONE)
	var spear := player.newest_iid(Items.WOODEN_SPEAR)
	player._equip_timer = 0.0
	player.request_equip(axe)
	player._equip_timer = 0.0
	_check(player.request_equip(spear) == "" and player.equipment.iid_in(EquipmentLayout.WEAPON) == spear
			and player.inventory.has_iid(axe) and player.inventory.is_belt_index(player.inventory.index_of_iid(axe)),
			"trocar a arma devolve a antiga ao cinto, no lugar da nova")
	_check(player.inventory.add(Items.PICKAXE_STONE, 1) == 0 and player.inventory.add(Items.AXE_STONE, 1) == 1,
			"o cinto tem 4 posições e a Arma é à parte: a 5ª ferramenta além da Arma recusa")
	player._equip_timer = 0.0
	_check(player.request_unequip(EquipmentLayout.WEAPON) == EquipmentComponent.REFUSED_FULL
			and player.equipment.iid_in(EquipmentLayout.WEAPON) == spear, "tirar a Arma com o cinto cheio recusa e nada muda")
	_check(EquipmentComponent.refusal_message(EquipmentComponent.REFUSED_FULL) == "Inventário cheio", "e diz 'Inventário cheio'")


# ----------------------------------------------------------------------------- recusa por caminho de entrada

func _test_gather_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var bush := _bush(world)
	_fill_grid(player, FILLERS)
	var before := JSON.stringify(player.inventory.to_dict())
	var pending := bush.component.pending_yields()
	var events_before: int = (world["events"] as Array).size()
	var result := authority.request_gather(1, authority.id_of(bush))
	_check(result == REFUSED and _reason_since(world, events_before) == "inventory_full",
			"coleta: grade cheia recusa com 'inventory_full'")
	_check(bush.is_available() and bush.component.pending_yields() == pending and JSON.stringify(player.inventory.to_dict()) == before
			and player.gather_cooldown_left() == 0.0, "coleta: o nó não é gasto, o inventário não muda e não há recarga")
	_check(GameMessages.reason_text("inventory_full") == "Inventário cheio.", "o texto é 'Inventário cheio.'")


func _test_ground_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var field := _ground(world)
	var pile := field.spawn_scatter(Items.SLEEP_FRUIT, 3, player.position)[0]
	player.position = pile.position
	_fill_grid(player, FILLERS)
	var amount := pile.amount
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_pickup(1, authority.id_of(pile)) == REFUSED and _reason_since(world, events_before) == "inventory_full"
			and pile.amount == amount, "chão: grade cheia recusa e a pilha fica inteira")


func _test_chest_path() -> void:
	var world := _with_chest()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var chest := _chest(world)
	_empty_inventory(player)
	chest.inventory.add(Items.WOOD, 5)
	_fill_grid(player, FILLERS)
	var before := JSON.stringify(chest.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict())
	var events_before: int = (world["events"] as Array).size()
	var wood_slot := _slot_of(chest.inventory, Items.WOOD)
	var result := authority.request_transfer_slot(1, int(world["chest_id"]), wood_slot, 1, WorldAuthority.TRANSFER_ALL)
	_check(result == REFUSED and _reason_since(world, events_before) == "inventory_full"
			and JSON.stringify(chest.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict()) == before,
			"Baú: tirar com a grade cheia recusa com 'Inventário cheio' e nada muda")
	# Ferramenta do Baú: vai ao cinto, que não ocupa slot (a grade cheia não impede).
	chest.inventory.add(Items.AXE_STONE, 1)
	var axe_slot := _slot_of(chest.inventory, Items.AXE_STONE)
	var moved := authority.request_transfer_slot(1, int(world["chest_id"]), axe_slot, 1, WorldAuthority.TRANSFER_ALL)
	var axe_at := player.inventory.index_of_iid(player.newest_iid(Items.AXE_STONE))
	_check(moved == Enums.ActionResult.OK and player.inventory.is_belt_index(axe_at),
			"Baú: a ferramenta passa mesmo com a grade cheia e fica no cinto")


func _test_craft_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var recipe := RecipeDef.new()
	recipe.id = "slot_ration"
	recipe.display_name = "Ração de teste"
	recipe.inputs = {Items.BERRY: 1}
	recipe.output_id = Items.RATION_C
	recipe.output_amount = 1
	recipe.seconds = 1.0
	recipe.station = "hand"
	recipe.saber_cost = 0
	authority.crafting.recipe_book.add(recipe)
	player.inventory.add(Items.BERRY, 3)
	_fill_grid(player, [Items.LEATHER, Items.STONE, Items.TUBER])  # baga, couro, pedra e tubérculo: a grade cheia
	_check(authority.crafting.begin_craft(1, "slot_ration")["result"] == Enums.ActionResult.OK, "fabricação com chão: aceita")
	var dropped_before: int = (world["dropped"] as Array).size()
	authority.crafting.tick(5.0)
	_check(player.inventory.count(Items.RATION_C) == 0 and player.inventory.count(Items.BERRY) == 2
			and (world["dropped"] as Array).size() == dropped_before + 1 and _codes(world).has("inventory_full"),
			"fabricação: o resultado que não cabe cai aos pés com 'Inventário cheio' (nada se perde)")
	authority.drops_enabled = false
	var before := JSON.stringify(player.inventory.to_dict())
	var outcome := authority.crafting.begin_craft(1, "slot_ration")
	_check(outcome["result"] == REFUSED and outcome["reason"] == "inventory_full" and JSON.stringify(player.inventory.to_dict()) == before,
			"fabricação sem chão: recusa 'Inventário cheio' e o material fica")
	# A ferramenta fabricada vai ao cinto: não precisa de slot.
	authority.drops_enabled = true
	var axe_recipe := RecipeDef.new()
	axe_recipe.id = "slot_axe"
	axe_recipe.display_name = "Machado de teste"
	axe_recipe.inputs = {Items.BERRY: 1}
	axe_recipe.output_id = Items.AXE_STONE
	axe_recipe.output_amount = 1
	axe_recipe.seconds = 1.0
	axe_recipe.station = "hand"
	axe_recipe.saber_cost = 0
	authority.crafting.recipe_book.add(axe_recipe)
	authority.crafting.begin_craft(1, "slot_axe")
	authority.crafting.tick(5.0)
	_check(player.inventory.count(Items.AXE_STONE) == 1 and player.inventory.grid_used() == 4,
			"fabricação: a ferramenta vai ao cinto mesmo com a grade cheia")


func _test_refund_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	authority.build.rules.refund_percent = 100
	player.inventory.add(Items.WOOD, 3)
	player.inventory.add(Items.STONE, 1)
	_check(_ask(world, "foundation", HOME + Vector2i(1, 0))["result"] == OK, "preparo: fundação construída")
	_fill_grid(player, [Items.LEATHER, Items.TUBER, Items.VEIN_SALT, Items.BERRY])
	var before := JSON.stringify(player.inventory.to_dict())
	var dropped_before: int = (world["dropped"] as Array).size()
	_check(authority.request_remove_piece(1, HOME + Vector2i(1, 0)) == OK and JSON.stringify(player.inventory.to_dict()) == before
			and (world["dropped"] as Array).size() > dropped_before, "reembolso com a grade cheia: a peça sai e o material cai aos pés")
	var second := _world_with_weight()
	var other: Player = second["player"]
	var second_authority: WorldAuthority = second["authority"]
	second_authority.build.rules.refund_percent = 100
	other.inventory.add(Items.WOOD, 3)
	other.inventory.add(Items.STONE, 1)
	_ask(second, "foundation", HOME + Vector2i(1, 0))
	_fill_grid(other, [Items.LEATHER, Items.TUBER, Items.VEIN_SALT, Items.BERRY])
	second_authority.drops_enabled = false
	var state := _state(second)
	var events_before: int = (second["events"] as Array).size()
	_check(second_authority.request_remove_piece(1, HOME + Vector2i(1, 0)) == REFUSED
			and _reason_since(second, events_before) == "inventory_full" and _state(second) == state,
			"reembolso sem chão: recusa com 'Inventário cheio' e a peça fica")


func _test_carcass_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var node: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	node.node_id = "slot_carcass"
	node.def = load("res://data/resources/carcass_meat.tres")
	node.position = player.position + Vector2(0, 8)
	_root.add_child(node)
	_track.call(node)
	authority.register(node)
	_fill_grid(player, FILLERS)
	var pending := node.component.pending_yields()
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_skin(1, authority.id_of(node)) == REFUSED and _reason_since(world, events_before) == "inventory_full"
			and node.component.pending_yields() == pending, "carcaça: grade cheia recusa e a carne fica nela")


func _test_corpse_recovery_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var corpse := PlayerCorpse.new()
	corpse.owner_player_id = player.player_id
	corpse.position = player.position
	corpse.entries = [{"id": Items.WOOD, "count": 10, "expira_em": 0.0}]
	_root.add_child(corpse)
	_track.call(corpse)
	authority.register(corpse)
	_fill_grid(player, [Items.LEATHER, Items.TUBER, Items.VEIN_SALT, Items.BERRY])
	var events_before: int = (world["events"] as Array).size()
	_check(authority.request_recover_corpse(1, authority.id_of(corpse)) == REFUSED
			and _reason_since(world, events_before) == "inventory_full" and corpse.count(Items.WOOD) == 10,
			"corpo: grade cheia recusa com 'Inventário cheio' e os itens ficam no corpo")


func _test_tamed_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var dino := _tamed(_dino_at(player.position + Vector2(10, 0)), player.player_id)
	authority.register(dino)
	dino.inventory.add(Items.WOOD, 4)
	_fill_grid(player, FILLERS)
	var before := JSON.stringify(dino.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict())
	var events_before: int = (world["events"] as Array).size()
	var wood_slot := _slot_of(dino.inventory, Items.WOOD)
	var result := authority.request_transfer_slot(1, authority.id_of(dino), wood_slot, 1, WorldAuthority.TRANSFER_ALL)
	_check(result == REFUSED and _reason_since(world, events_before) == "inventory_full"
			and JSON.stringify(dino.inventory.to_dict()) + JSON.stringify(player.inventory.to_dict()) == before,
			"domado: tirar do alforje com a grade cheia recusa com 'Inventário cheio' e nada muda")


func _test_unplaced_path() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_fill_grid(player, FILLERS)
	var grid := BuildGrid.new()
	grid.unplaced_items = {Items.WOOD: 3}
	var dropped_before: int = (world["dropped"] as Array).size()
	WorldSnapshot.return_unplaced(grid, player, authority)
	_check(player.inventory.count(Items.WOOD) == 0 and (world["dropped"] as Array).size() == dropped_before + 1,
			"devolução de peça de save antigo: sem slot, cai aos pés (nada se perde)")


# ----------------------------------------------------------------------------- jogo real: coleta, abrigo, save

## O minuto 0 a 5: os nós do começo dão 5 itens diferentes (madeira, graveto, pedra, baga, fibra) e a grade tem 4.
func _test_first_minutes() -> void:
	var distinct: Array[String] = []
	for path: String in ["res://data/resources/tree.tres", "res://data/resources/rock.tres", "res://data/resources/loose_stone.tres",
			"res://data/resources/bush_baga.tres"]:
		for item_id: String in (load(path) as ResourceNodeDef).total_yields():
			if not distinct.has(item_id):
				distinct.append(item_id)
	_check(distinct.size() == 5, "os nós do começo dão 5 itens diferentes (%s)" % str(distinct))
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.progression.grant_xp(1000000)
	authority.request_learn_recipe(1, "wooden_spear")
	for pair: Array in [[Items.WOOD, 17], [Items.STONE, 7], [Items.STICK, 2], [Items.FIBER, 2]]:
		player.inventory.add(str(pair[0]), int(pair[1]))
	_check(player.inventory.grid_used() == 4 and player.inventory.add(Items.BERRY, 2) == 2
			and player.inventory.refusal_for(Items.BERRY) == "inventory_full", "a coleta estoura os 4 slots: a baga não entra")
	_check(authority.crafting.begin_craft(1, "wooden_spear")["result"] == Enums.ActionResult.OK, "fabricar a Lança no meio da coleta")
	authority.crafting.tick(10.0)
	_check(player.inventory.count(Items.WOODEN_SPEAR) == 1 and player.inventory.count(Items.STICK) == 0
			and player.inventory.add(Items.BERRY, 2) == 0, "fabricar libera o slot do graveto e a Lança vai ao cinto: a baga entra")


## O abrigo mínimo (GDD 8) com o custo REAL das receitas cabe em 4 slots exatos.
func _test_shelter_in_four_slots() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var book := (world["authority"] as WorldAuthority).crafting.recipe_book
	var cost := {}
	for piece: Array in [["foundation", 4], ["wall", 8], ["door", 1]]:
		var recipe := book.find(piece[0])
		for item_id: String in recipe.inputs:
			cost[item_id] = int(cost.get(item_id, 0)) + int(recipe.inputs[item_id]) * int(piece[1])
	var left := 0
	for item_id: String in cost:
		left += player.inventory.add(item_id, int(cost[item_id]))
	_check(cost == {Items.WOOD: 32, Items.STONE: 4, Items.FIBER: 1}, "o custo real do abrigo: 32 madeira, 4 pedra, 1 fibra (%s)" % str(cost))
	_check(left == 0 and player.inventory.grid_used() == 4 and player.inventory.carried_grams() == 38050,
			"o abrigo mínimo cabe em 4 slots exatos (%d de 4) e pesa 38,05 kg" % player.inventory.grid_used())
	_check(player.inventory.add(Items.BERRY, 1) == 1 and player.inventory.refusal_for(Items.BERRY) == "inventory_full",
			"e não sobra slot: nem uma baga entra")


func _test_save_roundtrip() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	_fill_grid(player, FILLERS)
	for item_id in TOOLS:
		player.inventory.add(item_id, 1)
	player._equip_timer = 0.0
	player.request_equip(player.newest_iid(Items.AXE_STONE))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var other := _player_at(Vector2.ZERO)
	_check(other.from_dict(saved) and other.migration_spill.is_empty()
			and JSON.stringify(other.to_dict()["inventory"]) == JSON.stringify(player.to_dict()["inventory"])
			and other.equipment.count(Items.AXE_STONE) == 1 and other.inventory.grid_used() == 4,
			"save de 4 slots com cinto e Arma volta igual, sem excedente")


# ----------------------------------------------------------------------------- migração

func _test_migration() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var stacks := [[Items.BERRY, 20], [Items.MEAT, 4], [Items.FERN, 3], [Items.WOOD, 20], [Items.STONE, 15], [Items.FIBER, 10]]
	var all_tools: Array[String] = [Items.SLEEP_STAFF, Items.WOODEN_SPEAR, Items.AXE_STONE, Items.PICKAXE_STONE, Items.AXE_STONE,
			Items.PICKAXE_STONE]
	var legacy := _legacy_inventory(stacks, all_tools)
	var expected := {}
	for item_id: String in Items.all_ids():
		if legacy.count(item_id) > 0:
			expected[item_id] = legacy.count(item_id)
	_check(player.from_dict(_legacy_save(player, legacy)), "o save de 12 slots carrega (não recusa mais)")
	_check(player.inventory.grid_used() == 4 and player.inventory.count(Items.BERRY) == 20,
			"a grade fica com as 4 primeiras pilhas")
	var belt_tools := 0
	for item_id in TOOLS:
		belt_tools += 1 if player.inventory.is_belt_index(player.inventory.index_of_iid(player.newest_iid(item_id))) else 0
	_check(belt_tools == 4, "as ferramentas vão para o cinto (%d)" % belt_tools)
	_check(player.equipment.iid_in(EquipmentLayout.WEAPON) != "", "a ferramenta que sobrou do cinto ocupa a vaga Arma")
	var spilled_tools := 0
	var spilled_stacks := 0
	for entry in player.migration_spill:
		if entry.has("iid"):
			spilled_tools += 1
		else:
			spilled_stacks += 1
	_check(spilled_stacks == 2 and spilled_tools == 1,
			"o resto fica pendente: 2 pilhas e 1 ferramenta (%d, %d)" % [spilled_stacks, spilled_tools])
	_check(_tally(player, player.migration_spill) == expected, "nada some: o que entrou mais o excedente é o que o save tinha")
	# Carga recusada (versão futura) não deixa excedente nem mexe em nada.
	var snapshot := JSON.stringify(player.to_dict())
	var bad := _legacy_save(player, legacy)
	bad["version"] = 99
	_check(not player.from_dict(bad) and JSON.stringify(player.to_dict()) == snapshot, "save inválido: recusa e nada muda")


func _test_migration_in_world() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var authority := main.authority
	var player := main.player
	var envelope := WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0, authority.next_entity_id(), null,
			main.carcasses, 0.0, main.ground, main.corpses, authority.build.grid)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	var stacks := [[Items.BERRY, 20], [Items.MEAT, 4], [Items.FERN, 3], [Items.WOOD, 20], [Items.STONE, 15], [Items.FIBER, 10],
			[Items.STICK, 7]]
	var legacy := _legacy_inventory(stacks, [Items.AXE_STONE, Items.SLEEP_STAFF])
	var saved_player := _legacy_save(player, legacy)
	var players: Array = parsed["players"]
	(players[0] as Dictionary)["state"] = saved_player
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	_check(WorldSnapshot.restore(parsed, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid), "carregar o mundo com o save de 12 slots funciona")
	var on_ground := 0
	for item_id: String in Items.all_ids():
		on_ground += main.ground.total_of(item_id)
	var kept := 0
	for item_id: String in Items.all_ids():
		kept += player.inventory.count(item_id) + player.equipment.count(item_id)
	var original := 0
	for item_id: String in Items.all_ids():
		original += legacy.count(item_id)
	_check(player.migration_spill.is_empty() and kept + on_ground == original and on_ground > 0,
			"o excedente caiu aos pés e nada some (%d no inventário + %d no chão = %d)" % [kept, on_ground, original])
	_check(main.ground.total_of(Items.STICK) == 7 and main.ground.total_of(Items.FIBER) == 10 and main.ground.total_of(Items.STONE) == 15,
			"as pilhas excedentes inteiras estão no chão")
	_check(events.has("inventory_migrated"), "o jogador é avisado (inventory_migrated)")
	authority.clock.advance(1000.0)  # bem além dos 300 s do chão comum
	main.ground.tick()
	_check(main.ground.total_of(Items.STICK) == 7, "o excedente da migração não some com 1000 s (vida longa, não 300 s)")
	var near := true
	for item in main.ground.items():
		near = near and item.global_position.distance_to(player.global_position) <= 13.0
	_check(near, "e está aos pés do jogador")
	# Recarregar o mesmo save já migrado não perde nada do chão.
	var again: Dictionary = JSON.parse_string(JSON.stringify(WorldSnapshot.capture(player, main.dino, "t", "now", main.resources, 0,
			authority.next_entity_id(), null, main.carcasses, 0.0, main.ground, main.corpses, authority.build.grid)))
	_check(WorldSnapshot.restore(again, player, main.dino, main.resources, null, main.carcasses, authority, main.ground, main.corpses,
			authority.build.grid) and main.ground.total_of(Items.STICK) == 7 and main.ground.count() >= 3,
			"salvar e carregar de novo mantém o excedente no chão")


func _test_corpse_takes_everything() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var player := main.player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.equipment.from_dict({"slots": {}})
	_fill_grid(player, FILLERS)
	for item_id in TOOLS:
		player.inventory.add(item_id, 1)
	player._equip_timer = 0.0
	player.request_equip(player.newest_iid(Items.AXE_STONE))
	var expected := _tally(player)
	var corpse := main.corpses.deposit(player)
	_check(corpse != null and corpse.item_count() == 8 and _tally(player).is_empty() and player.equipment.count(Items.AXE_STONE) == 0,
			"o corpo leva os 4 slots, o cinto e a Arma (8 itens) e o jogador fica vazio")
	_check(corpse.recover_into(player.inventory) == 8 and _tally(player) == expected
			and player.inventory.grid_used() == 4 and player.inventory.count(Items.AXE_STONE) == 1,
			"recuperar devolve tudo: a grade na grade e as ferramentas no cinto")


# ----------------------------------------------------------------------------- Descartar (SOB-16)

func _test_discard() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.add(Items.WOOD, 5)
	player.inventory.add(Items.AXE_STONE, 1)
	var index := _slot_of(player.inventory, Items.WOOD)
	var dropped_before: int = (world["dropped"] as Array).size()
	_check(authority.request_drop(1, index) == Enums.ActionResult.OK and player.inventory.count(Items.WOOD) == 0
			and (world["dropped"] as Array).size() == dropped_before + 1 and world["dropped"][dropped_before] == [Items.WOOD, 5],
			"descartar uma pilha: sai do inventário e vira item de chão, tudo")
	var belt_index := player.inventory.index_of_iid(player.newest_iid(Items.AXE_STONE))
	var before := JSON.stringify(player.inventory.to_dict())
	_check(authority.request_drop(1, belt_index) == Enums.ActionResult.INVALID_ARGUMENT
			and JSON.stringify(player.inventory.to_dict()) == before,
			"a ferramenta do cinto não se descarta por aqui")
	player._equip_timer = 0.0
	player.request_equip(player.newest_iid(Items.AXE_STONE))
	_check(authority.request_drop(1, 0) == Enums.ActionResult.INVALID_ARGUMENT and player.equipment.count(Items.AXE_STONE) == 1,
			"a vaga Arma nunca é descartada (posição vazia é inválida)")
	_check(authority.request_drop(1, 99) == Enums.ActionResult.INVALID_ARGUMENT, "posição fora do inventário é inválida")
	authority.drops_enabled = false
	player.inventory.add(Items.WOOD, 2)
	_check(authority.request_drop(1, _slot_of(player.inventory, Items.WOOD)) == REFUSED and player.inventory.count(Items.WOOD) == 2,
			"sem chão para largar, recusa e nada some")


func _test_screen() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	_root.add_child(screen)
	_track.call(screen)
	var discards: Array[int] = []
	screen.discard_requested.connect(func(index: int, item_id: String, count: int) -> void:
		discards.append(index)
		authority.request_drop(1, index, count, item_id, count))
	player.inventory.add(Items.WOOD, 5)
	player.inventory.add(Items.AXE_STONE, 1)
	screen.open_with(player.inventory, null, null, "")
	_check(screen.slot_button(true, 3) != null and screen.slot_button(true, 4) != null and screen.slot_button(true, 7) != null
			and screen.slot_button(true, 8) == null and screen.equipment_button(EquipmentLayout.WEAPON) != null,
			"a tela mostra a grade de 4, o cinto de 4 e a vaga Arma")
	_check(screen.slot_text(true, 4).begins_with("Machado") and screen.slot_text(true, 0).begins_with("Madeira"),
			"o Machado aparece no cinto e a Madeira na grade")
	_check(screen.discard_button().focus_mode == Control.FOCUS_NONE and screen.confirm_button(true).focus_mode == Control.FOCUS_NONE
			and screen.confirm_button(false).focus_mode == Control.FOCUS_NONE, "os botões de descartar não pegam o foco")
	screen.slot_button(true, 0).pressed.emit()
	_check(screen.selected_slot() == 0 and not screen.discard_button().disabled, "selecionar a pilha liga o Descartar")
	screen.discard_button().pressed.emit()
	_check(screen.confirm_text() == "Descartar 5 Madeira?" and discards.is_empty() and player.inventory.count(Items.WOOD) == 5,
			"pede confirmação e nada sai ainda (%s)" % screen.confirm_text())
	screen.confirm_button(false).pressed.emit()
	_check(screen.confirm_text() == "" and discards.is_empty() and player.inventory.count(Items.WOOD) == 5, "Não cancela")
	screen.discard_button().pressed.emit()
	screen.confirm_button(true).pressed.emit()
	_check(discards == [0] and player.inventory.count(Items.WOOD) == 0, "Sim pede o descarte à autoridade e a pilha some do inventário")
	screen.slot_button(true, 4).pressed.emit()
	_check(screen.discard_button().disabled, "a ferramenta do cinto não se descarta (botão desligado)")
	screen.close()


func _test_hotbar_and_hud() -> void:
	var world := _world_with_weight()
	var player: Player = world["player"]
	for i in HotbarComponent.SLOT_COUNT:
		player.hotbar.clear(i)  # o kit inicial já tinha atalhos
	var bar := HotbarBar.new()
	bar.player = player
	_root.add_child(bar)
	_track.call(bar)
	var shown := 0
	for i in HotbarComponent.SLOT_COUNT:
		shown += 1 if bar.is_slot_shown(i) else 0
	_check(shown == 0, "barra de atalhos sem entradas: nenhuma moldura vazia")
	player.inventory.add(Items.AXE_STONE, 1)
	player.inventory.add(Items.BERRY, 3)
	player.hotbar.assign_iid(0, player.newest_iid(Items.AXE_STONE), Items.AXE_STONE)
	player.hotbar.assign(2, Items.BERRY)
	_check(bar.is_slot_shown(0) and not bar.is_slot_shown(1) and bar.is_slot_shown(2) and not bar.is_slot_shown(3),
			"só as entradas que existem aparecem (as posições 1 e 3 do teclado)")
	bar.notification(Control.NOTIFICATION_DRAG_BEGIN)
	_check(bar.is_slot_shown(1) and bar.is_slot_shown(8), "durante um arraste as posições vazias aparecem como destino")
	bar.notification(Control.NOTIFICATION_DRAG_END)
	_check(not bar.is_slot_shown(1) and bar.is_slot_shown(0), "e somem quando o arraste termina")
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.slots_label().text == "Slots 1/4", "HUD: 'Slots 1/4' (a ferramenta do cinto não conta) (%s)" % hud.slots_label().text)
	_fill_grid(player, [Items.LEATHER, Items.STONE, Items.TUBER])
	_check(hud.slots_label().text == "Slots 4/4", "HUD acompanha o inventário (%s)" % hud.slots_label().text)
