# SPDX-License-Identifier: MIT
class_name BagTests
extends SlotTests
## E11b, CRI-42 parte 2: a vaga Bolsa (Cesto de fibra +4, Mochila de couro +8), a receita, equipar e tirar sem perder item
## ("Esvazie N pilhas"), o Peso, o save (e a migração do Cesto que era pilha) e o corpo que leva a bolsa.
## Roda com o dado REAL de slots (4 e 4), como a `SlotTests`, de quem herda os auxiliares.

const FILL_IDS: Array[String] = [Items.LEATHER, Items.STONE, Items.TUBER, Items.VEIN_SALT, Items.WOOD, Items.FIBER, Items.BERRY,
		Items.MEAT, Items.FERN, Items.STICK, Items.SLEEP_FRUIT, Items.RATION_C]
const BAG := EquipmentLayout.BAG


func run() -> void:
	Items.with_layout(REAL_RULES, _run_checks)
	_release_worlds()


func _run_checks() -> void:
	_test_bag_data()
	_test_recipes()
	_test_equip_grows_grid()
	_test_one_bag_only()
	_test_downgrade_refused()
	_test_compaction_loses_nothing()
	_test_unequip_refused_and_ok()
	_test_refusal_text()
	_test_weight()
	_test_save_roundtrip_bag()
	_test_save_hostile_and_old()
	_test_legacy_containers()
	_test_death_and_recovery()
	_test_recovery_through_authority()
	_test_screen_grows()
	_test_corpse_with_full_belt_and_weapon()


func _equip(player: Player, item_id: String) -> String:
	if player.inventory.count(item_id) == 0:
		player.inventory.add(item_id, 1)
	player._equip_timer = 0.0
	if player.authority == null:
		return player.perform_equipment(player.newest_iid(item_id))  # jogador solto (sem mundo): o mesmo efeito, sem o pedido
	return player.request_equip(player.newest_iid(item_id))


func _unequip(player: Player) -> String:
	player._equip_timer = 0.0
	return player.request_unequip(BAG)


## Enche a grade com `count` pilhas de ids distintos (a bolsa, se estiver na grade, já conta como uma pilha).
func _fill_piles(player: Player, count: int) -> void:
	for item_id in FILL_IDS:
		if player.inventory.grid_used() >= count:
			return
		player.inventory.add(item_id, 1)


func _bag_world() -> Dictionary:
	var world := _world_with_weight()
	(world["player"] as Player)._equip_timer = 0.0
	return world


# ----------------------------------------------------------------------------- dado

func _test_bag_data() -> void:
	var fresh := ResourceLoader.load("res://data/balance/slot_rules.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as SlotRules
	_check(fresh.bag_bonus(Items.FIBER_BASKET) == 4 and fresh.bag_bonus(Items.LEATHER_BACKPACK) == 8 and fresh.bag_bonus(Items.WOOD) == 0,
			"o dado: Cesto +4, Mochila +8, o resto não soma (slot_rules.tres)")
	_check(fresh.grid_size_for("") == 4 and fresh.grid_size_for(Items.FIBER_BASKET) == 8 and fresh.grid_size_for(Items.LEATHER_BACKPACK) == 12,
			"a grade tem 4, 8 ou 12 posições")
	var layout := Items.EQUIPMENT
	_check(layout.has_slot(BAG) and layout.slot_def(BAG).shown and not layout.slot_def(BAG).hotbar
			and layout.slot_def("helmet").shown == false,
			"a vaga Bolsa existe, aparece na tela e não vai à barra de atalhos; as de roupa seguem escondidas")
	var kinds := true
	for bag_id in [Items.FIBER_BASKET, Items.LEATHER_BACKPACK]:
		kinds = kinds and Items.is_bag(bag_id) and Items.is_individual(bag_id) and not Items.belt_of(bag_id) and Items.slot_of(bag_id) == BAG
	_check(kinds and not Items.is_bag(Items.AXE_STONE), "as bolsas são individuais da vaga Bolsa, fora do cinto; ferramenta não é bolsa")
	_check(Items.weight_grams(Items.FIBER_BASKET) == 600 and Items.weight_grams(Items.LEATHER_BACKPACK) == 2500,
			"Peso: Cesto 0,6 kg e Mochila 2,5 kg (carry_rules.tres)")


# ----------------------------------------------------------------------------- receita

func _test_recipes() -> void:
	var book := RecipeBook.with_defaults()
	var basket := book.find("fiber_basket")
	var backpack := book.find("leather_backpack")
	_check(basket.inputs == {Items.FIBER: 12} and basket.station == "hand" and basket.output_id == Items.FIBER_BASKET
			and backpack.inputs == {Items.LEATHER: 6, Items.FIBER: 4} and backpack.station == "hand"
			and basket.is_known_at_start() and backpack.is_known_at_start(),
			"receitas à mão e conhecidas: Cesto 12 fibra; Mochila 6 couro + 4 fibra")
	var world := _bag_world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	player.inventory.add(Items.FIBER, 11)
	_check(authority.crafting.begin_craft(1, "fiber_basket")["result"] != Enums.ActionResult.OK and player.inventory.count(Items.FIBER) == 11,
			"11 fibras não bastam para o Cesto e nada é gasto")
	player.inventory.add(Items.FIBER, 1)
	_check(authority.crafting.begin_craft(1, "fiber_basket")["result"] == Enums.ActionResult.OK, "12 fibras: o Cesto começa")
	authority.crafting.tick(10.0)
	_check(player.inventory.count(Items.FIBER_BASKET) == 1 and player.inventory.count(Items.FIBER) == 0
			and Items.is_individual(Items.FIBER_BASKET) and not player.inventory.find_iid(player.newest_iid(Items.FIBER_BASKET)).is_empty(),
			"o Cesto sai como item individual na grade e gasta as 12 fibras")
	_check(player.inventory.grid_size() == 4 and player.equipment.item_in(BAG).is_empty(),
			"fabricar não equipa sozinho: a grade segue em 4 até entrar na vaga")
	player.inventory.add(Items.LEATHER, 6)
	player.inventory.add(Items.FIBER, 4)
	_check(authority.crafting.begin_craft(1, "leather_backpack")["result"] == Enums.ActionResult.OK, "6 couros e 4 fibras: a Mochila começa")
	authority.crafting.tick(10.0)
	_check(player.inventory.count(Items.LEATHER_BACKPACK) == 1 and player.inventory.count(Items.LEATHER) == 0
			and player.inventory.count(Items.FIBER) == 0,
			"a Mochila sai e gasta 6 couros e 4 fibras")


# ----------------------------------------------------------------------------- equipar

func _test_equip_grows_grid() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	_fill_piles(player, 3)
	player.inventory.add(Items.FIBER_BASKET, 1)
	var basket_iid := player.newest_iid(Items.FIBER_BASKET)
	_check(player.inventory.grid_used() == 4 and player.inventory.add(Items.MEAT, 1) == 1, "a bolsa na grade ocupa uma posição e não dá nada")
	var before := _tally(player)
	_check(_equip(player, Items.FIBER_BASKET) == "" and player.inventory.grid_size() == 8 and player.equipment.iid_in(BAG) == basket_iid,
			"equipar o Cesto: a vaga o guarda inteiro e a grade vai a 8")
	var after := _tally(player)
	_check(after == before and player.inventory.grid_used() == 3, "nenhum item sumiu e a bolsa saiu da grade (3 pilhas)")
	_check(player.inventory.add(Items.MEAT, 1) == 0 and player.inventory.add(Items.FERN, 1) == 0 and player.inventory.add(Items.STICK, 1) == 0
			and player.inventory.add(Items.SLEEP_FRUIT, 1) == 0 and player.inventory.add(Items.RATION_C, 1) == 0
					and player.inventory.grid_used() == 8,
			"os 4 slots novos aceitam pilhas")
	_check(player.inventory.refusal_for(Items.RATION_A) == "inventory_full", "a 9ª pilha recusa com 'Inventário cheio'")
	player.inventory.remove(Items.MEAT, 9999)  # a Mochila nova precisa de uma posição livre para existir (fabricada cheia, cai no chão)
	_check(_equip(player, Items.LEATHER_BACKPACK) == "" and player.inventory.grid_size() == 12
			and player.equipment.count(Items.FIBER_BASKET) == 0,
			"trocar para a Mochila (maior) sempre vale: a grade vai a 12")
	_check(player.inventory.count(Items.FIBER_BASKET) == 1, "o Cesto antigo volta à grade (não some)")


func _test_one_bag_only() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	_equip(player, Items.FIBER_BASKET)
	_equip(player, Items.LEATHER_BACKPACK)
	_check(player.inventory.grid_size() == 12 and player.equipment.count(Items.LEATHER_BACKPACK) == 1
			and player.equipment.count(Items.FIBER_BASKET) == 0,
			"uma vaga só, vale a equipada: 12, não 4+4+8")
	_check(player.equipment.slot_of_iid(player.newest_iid(Items.FIBER_BASKET)) == "", "o Cesto guardado não dá bônus")
	_check(player.request_equip(player.newest_iid(Items.FIBER_BASKET), EquipmentLayout.WEAPON) != "", "o Cesto não vai na vaga Arma")


func _test_downgrade_refused() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	_equip(player, Items.LEATHER_BACKPACK)
	_fill_piles(player, 9)  # 9 pilhas; com o Cesto na grade são 10
	player.inventory.add(Items.FIBER_BASKET, 1)
	var basket_iid := player.newest_iid(Items.FIBER_BASKET)
	_check(player.inventory.grid_used() == 10, "preparo: 10 pilhas na grade de 12 (9 de material e o Cesto)")
	var snapshot := JSON.stringify([player.inventory.to_dict(), player.equipment.to_dict()])
	var refusal := _equip(player, Items.FIBER_BASKET)
	_check(refusal == "over_limit:2" and EquipmentComponent.over_limit_piles(refusal) == 2,
			"descer para o Cesto (8) com 10 pilhas recusa e diz que faltam 2 (%s)" % refusal)
	_check(JSON.stringify([player.inventory.to_dict(), player.equipment.to_dict()]) == snapshot and player.inventory.has_iid(basket_iid)
			and player.inventory.grid_size() == 12, "a recusa não mudou nada: a Mochila segue equipada e o Cesto novo continua na grade")
	player.inventory.remove(Items.LEATHER, 9999)
	player.inventory.remove(Items.STONE, 9999)
	_check(_equip(player, Items.FIBER_BASKET) == "" and player.inventory.grid_size() == 8
			and player.inventory.count(Items.LEATHER_BACKPACK) == 1,
			"depois de esvaziar 2 pilhas a troca passa; a Mochila volta à grade")
	_check(player.inventory.grid_used() == 8, "a grade de 8 ficou cheia (7 pilhas e a Mochila)")


func _test_compaction_loses_nothing() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	var inventory := player.inventory
	_equip(player, Items.LEATHER_BACKPACK)
	inventory.add(Items.FIBER_BASKET, 1)
	inventory.add(Items.FIBER, 45)  # duas pilhas: 40 e 5 (a segunda é parcial; fibra pesa pouco)
	var others: Array[String] = [Items.LEATHER, Items.TUBER, Items.VEIN_SALT, Items.WOOD, Items.STONE, Items.BERRY, Items.MEAT,
			Items.FERN, Items.STICK]
	for item_id in others:
		inventory.add(item_id, 1)
	for tool_id in TOOLS:
		inventory.add(tool_id, 1)
	_check(inventory.grid_used() == 12 and inventory.grid_size() == 12,
			"preparo: as 12 posições ocupadas (a bolsa nova, pedra em 2 pilhas e 9 itens)")
	for i in range(3, 7):  # esvazia 4 posições do meio: sobram buracos e pilhas lá no alto (8 a 11)
		var slot := inventory.get_slot(i)
		inventory.take_from_slot(i, int(slot["count"]))
	var high := 0
	for i in range(8, 12):
		high += 0 if inventory.get_slot(i).is_empty() else 1
	var before := _tally(player)
	_check(high == 4 and inventory.grid_used() == 8 and before[Items.FIBER] == 45, "preparo: 4 pilhas nas posições altas e 8 no total")
	_check(_equip(player, Items.FIBER_BASKET) == "" and inventory.grid_size() == 8, "descer para o Cesto com 8 pilhas cabe exato: passa")
	_check(_tally(player) == before and inventory.count(Items.FIBER) == 45,
			"a compactação não perdeu nem duplicou nada, nem as pilhas parciais")
	_check(inventory.grid_used() == 8 and inventory.slot_count() == 8 + 4, "a grade tem 8 posições cheias e o cinto segue com 4")
	var belt_tools := 0
	for i in range(inventory.grid_size(), inventory.slot_count()):
		belt_tools += 0 if inventory.get_slot(i).is_empty() else 1
	_check(belt_tools == 4, "as 4 ferramentas ficaram no cinto (%d, %s)" % [belt_tools, str(inventory.to_dict()["slots"])])


func _test_unequip_refused_and_ok() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_equip(player, Items.LEATHER_BACKPACK)
	_fill_piles(player, 4)
	var snapshot := JSON.stringify([player.inventory.to_dict(), player.equipment.to_dict()])
	var events_before: int = (world["events"] as Array).size()
	player._equip_timer = 0.0
	_check(authority.request_unequip(1, BAG) == REFUSED and _reason_since(world, events_before) == "over_limit",
			"tirar a Mochila com 4 pilhas recusa: a Mochila também ocuparia uma posição (4 + 1 > 4)")
	var params: Dictionary = {}
	for event: Dictionary in world["events"]:
		if event["code"] == "action_refused" and event["params"]["reason"] == "over_limit":
			params = event["params"]
	_check(GameMessages.text_of("action_refused", params) == "Esvazie 1 pilha.",
			"a mensagem diz 'Esvazie 1 pilha.' (%s)" % GameMessages.text_of("action_refused", params))
	_check(JSON.stringify([player.inventory.to_dict(), player.equipment.to_dict()]) == snapshot and player.inventory.grid_size() == 12,
			"a recusa não mexeu em nada")
	player.inventory.remove(Items.LEATHER, 9999)
	var before := _tally(player)
	_check(_unequip(player) == "" and player.inventory.grid_size() == 4 and player.inventory.count(Items.LEATHER_BACKPACK) == 1
			and player.equipment.item_in(BAG).is_empty() and player.inventory.grid_used() == 4,
					"com 3 pilhas a Mochila sai para a grade (4 posições, cheia)")
	before[Items.LEATHER] = 0
	_check(_tally(player).get(Items.STONE, 0) == before.get(Items.STONE, 0) and _tally(player).get(Items.WOOD, 0) == before.get(Items.WOOD, 0),
			"o conteúdo continua inteiro")
	var empty_world := _bag_world()
	var other: Player = empty_world["player"]
	_check(other.request_unequip(BAG) != "", "vaga Bolsa vazia: recusa (nada para tirar)")


func _test_refusal_text() -> void:
	_check(EquipmentComponent.refusal_message("over_limit:1") == "Esvazie 1 pilha"
			and EquipmentComponent.refusal_message("over_limit:5") == "Esvazie 5 pilhas"
			and EquipmentComponent.refusal_message("over_limit:0") == "" and EquipmentComponent.refusal_message("over_limit:x") == "",
			"o aviso curto: 'Esvazie N pilha(s)'; número inválido não diz nada")
	_check(GameMessages.reason_text("over_limit", {"piles": GameMessages.piles_text(3)}) == "Esvazie 3 pilhas.",
			"a linha do log tem o texto da recusa")


# ----------------------------------------------------------------------------- Peso

func _test_weight() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	var base_g := player.inventory.carried_grams()
	player.inventory.add(Items.LEATHER_BACKPACK, 1)
	_check(player.inventory.carried_grams() == base_g + 2500, "a Mochila na grade pesa 2,5 kg")
	_equip(player, Items.LEATHER_BACKPACK)
	_check(player.inventory.carried_grams() == base_g + 2500 and player.inventory.weight_limit == 50.0,
			"equipada a Mochila continua pesando e o limite segue 50 kg (a bolsa não aumenta o Peso)")
	_fill_piles(player, 11)
	player.inventory.weight_limit = player.inventory.carried_weight()
	_check(player.inventory.refusal_for(Items.RATION_A) == "weight_limit",
			"com slot sobrando e Peso no limite a recusa é 'Peso máximo'")
	player.inventory.weight_limit = Items.CARRY.capacity_kg
	_check(player.equipment.weight_grams() == 2500, "a vaga Bolsa entra na conta do Peso")


# ----------------------------------------------------------------------------- save

func _test_save_roundtrip_bag() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	_equip(player, Items.LEATHER_BACKPACK)
	_fill_piles(player, 11)
	player.inventory.add(Items.AXE_STONE, 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	_check(str(saved["equipment"]["slots"][BAG]["id"]) == Items.LEATHER_BACKPACK, "o save leva a bolsa equipada pelo id estável")
	var other := _player_at(Vector2.ZERO)
	_check(other.inventory.grid_size() == 4, "o jogador novo nasce com 4 posições")
	_check(other.from_dict(saved) and other.migration_spill.is_empty(), "o save carrega sem excedente")
	_check(other.inventory.grid_size() == 12 and other.equipment.count(Items.LEATHER_BACKPACK) == 1 and _tally(other) == _tally(player)
			and JSON.stringify(other.to_dict()["inventory"]) == JSON.stringify(player.to_dict()["inventory"]),
			"a grade volta com 12 posições e as 11 pilhas nas mesmas posições (nada some)")
	var third := _player_at(Vector2.ZERO)
	third.from_dict(JSON.parse_string(JSON.stringify(other.to_dict())))
	_check(JSON.stringify(third.to_dict()) == JSON.stringify(other.to_dict()), "salvar de novo dá o mesmo arquivo")
	# O Cesto no lugar da Mochila: carrega numa grade que antes era de 12.
	var small := _bag_world()["player"] as Player
	_equip(small, Items.FIBER_BASKET)
	_fill_piles(small, 8)
	other.from_dict(JSON.parse_string(JSON.stringify(small.to_dict())))
	_check(other.inventory.grid_size() == 8 and _tally(other) == _tally(small),
			"carregar um save de 8 num jogador que tinha 12 encolhe sem perder")
	# Save sem bolsa carregado depois de um com bolsa.
	var bare := _bag_world()["player"] as Player
	_fill_piles(bare, 3)
	other.from_dict(JSON.parse_string(JSON.stringify(bare.to_dict())))
	_check(other.inventory.grid_size() == 4 and other.equipment.item_in(BAG).is_empty() and _tally(other) == _tally(bare),
			"carregar um save sem bolsa volta a grade para 4")


func _test_save_hostile_and_old() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	_fill_piles(player, 3)
	var good := player.to_dict()
	var snapshot := JSON.stringify(player.to_dict())
	# Item que não é bolsa na vaga Bolsa: recusa e nada muda.
	var forged: Dictionary = JSON.parse_string(JSON.stringify(good))
	forged["equipment"]["slots"][BAG] = {"id": Items.AXE_STONE, "iid": "x1", "durab": 5, "durab_max": 150}
	_check(not player.from_dict(forged) and JSON.stringify(player.to_dict()) == snapshot,
			"um Machado na vaga Bolsa recusa o save inteiro e nada muda")
	# Vaga Bolsa com bolsa e 9 pilhas na grade sem a bolsa (save adulterado): nada se perde (excedente do chão).
	var no_bag: Dictionary = JSON.parse_string(JSON.stringify(good))
	var many := _bag_world()["player"] as Player
	_equip(many, Items.LEATHER_BACKPACK)
	_fill_piles(many, 9)
	no_bag["inventory"] = JSON.parse_string(JSON.stringify(many.to_dict()["inventory"]))
	no_bag["equipment"] = {"version": EquipmentComponent.FORMAT_VERSION, "slots": {}}
	var spill_player := _player_at(Vector2.ZERO)
	var expected := _tally(many)
	expected.erase(Items.LEATHER_BACKPACK)  # a Mochila saiu do save adulterado junto com a vaga
	_check(spill_player.from_dict(no_bag) and spill_player.inventory.grid_size() == 4
			and _tally(spill_player, spill_player.migration_spill) == expected,
			"9 pilhas e nenhuma bolsa: 4 ficam e 5 vão para o excedente (soma igual, nada some)")
	# Save de antes da E11b: o Cesto era uma pilha {id, count}.
	var old := _bag_world()["player"] as Player
	_fill_piles(old, 2)
	var legacy_inventory: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()["inventory"]))
	(legacy_inventory["slots"] as Array)[3] = {"id": Items.FIBER_BASKET, "count": 1, "expira_em": 0.0}
	var legacy_save := old.to_dict()
	legacy_save["inventory"] = legacy_inventory
	var loaded := _player_at(Vector2.ZERO)
	_check(loaded.from_dict(JSON.parse_string(JSON.stringify(legacy_save))) and loaded.inventory.count(Items.FIBER_BASKET) == 1
			and Items.is_individual(Items.FIBER_BASKET) and loaded.migration_spill.is_empty(),
			"save antigo com o Cesto como pilha: carrega e o Cesto vira individual na grade")
	_check(_equip(loaded, Items.FIBER_BASKET) == "" and loaded.inventory.grid_size() == 8, "e o Cesto migrado pode ser equipado")
	# Atalho antigo para o Cesto (a barra aceitava a pilha): o carregamento não recusa o save.
	var hot := legacy_save.duplicate(true)
	hot["hotbar"] = {"version": HotbarComponent.FORMAT_VERSION, "slots": [{"id": Items.FIBER_BASKET}]}
	_check(_player_at(Vector2.ZERO).from_dict(JSON.parse_string(JSON.stringify(hot))), "atalho antigo do Cesto não recusa o save")


func _test_legacy_containers() -> void:
	var world := _bag_world()
	var authority: WorldAuthority = world["authority"]
	var ground := GroundItemField.new()
	_track.call(ground)
	ground.authority = authority
	_root.add_child(ground)
	ground.restore_list([{"item": Items.FIBER_BASKET, "amount": 1, "x": 10.0, "y": 10.0, "id": 0},
			{"item": Items.WOOD, "amount": 3, "x": 20.0, "y": 10.0}])
	var baskets := 0
	var wood := 0
	for item in ground.items():
		if item.item_id == Items.FIBER_BASKET and not item.entry.is_empty():
			baskets += 1
		if item.item_id == Items.WOOD:
			wood += item.amount
	_check(baskets == 1 and wood == 3, "item de chão antigo (Cesto como pilha) vira individual, sem perda")
	var corpses := CorpseField.new()
	_track.call(corpses)
	_root.add_child(corpses)
	corpses.restore_list([{"player_id": "p", "x": 0.0, "y": 0.0, "due_at": 100.0, "items": [
			{"id": Items.FIBER_BASKET, "count": 1, "expira_em": 0.0}, {"id": Items.WOOD, "count": 4}]}])
	var restored := corpses.corpses()
	_check(restored.size() == 1 and restored[0].count(Items.FIBER_BASKET) == 1 and restored[0].count(Items.WOOD) == 4,
			"corpo antigo com o Cesto como pilha: a bolsa continua no corpo, como individual")
	var inventory := InventoryComponent.new()
	_track.call(inventory)
	inventory.capacity = 4
	_check(restored[0].recover_into(inventory) == 5 and inventory.count(Items.FIBER_BASKET) == 1, "e ela é recuperável (individual com iid)")


# ----------------------------------------------------------------------------- corpo

func _test_death_and_recovery() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var player := main.player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.equipment.from_dict({"slots": {}})
	player.fit_grid_to_bag()
	_equip(player, Items.LEATHER_BACKPACK)
	_fill_piles(player, 10)
	player.inventory.add(Items.AXE_STONE, 1)
	var expected := _tally(player)
	_check(player.inventory.grid_size() == 12 and expected.has(Items.LEATHER_BACKPACK), "preparo: Mochila equipada e 10 pilhas")
	var corpse := main.corpses.deposit(player)
	_check(corpse != null and corpse.count(Items.LEATHER_BACKPACK) == 1 and corpse.item_count() == 12,
			"o corpo leva a Mochila e as 10 pilhas e o Machado (12)")
	_check(_tally(player).is_empty() and player.equipment.item_in(BAG).is_empty() and player.inventory.grid_size() == 4,
			"quem morreu fica sem bolsa e a grade volta a 4")
	_check(corpse.recover_into(player.inventory, player.equipment) == 12 and corpse.is_empty(),
			"recuperar traz tudo, mesmo a grade tendo voltado a 4")
	_check(player.equipment.count(Items.LEATHER_BACKPACK) == 1 and player.inventory.grid_size() == 12 and _tally(player) == expected,
			"a Mochila foi equipada antes do resto: grade de 12 e o conjunto é o mesmo de antes de morrer")
	# Só a grade de 4 (chamada sem as vagas): a Mochila vai à grade e o excedente fica no corpo, nada some.
	var second := main.corpses.deposit(player)
	var plain := InventoryComponent.new()
	_track.call(plain)
	plain.capacity = 4
	var moved := second.recover_into(plain)
	_check(moved == 4 and second.item_count() == 12 - 4 and not second.is_empty(), "sem as vagas, só cabem 4 e o resto fica no corpo")
	# Com outra bolsa já equipada, a do corpo não a substitui sozinha.
	var third := main.player
	_equip(third, Items.FIBER_BASKET)
	var held := PlayerCorpse.new()
	_track.call(held)
	held.entries = [{"id": Items.LEATHER_BACKPACK, "iid": "z9", "durab": 1, "durab_max": 1}]
	_check(held.recover_into(third.inventory, third.equipment) == 1 and third.equipment.count(Items.FIBER_BASKET) == 1
			and third.inventory.count(Items.LEATHER_BACKPACK) == 1 and third.inventory.grid_size() == 8,
			"com o Cesto equipado, a Mochila do corpo volta à grade e a troca é do jogador")


func _test_recovery_through_authority() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var corpse := PlayerCorpse.new()
	corpse.owner_player_id = player.player_id
	corpse.position = player.position
	var entries: Array[Dictionary] = []
	for item_id in FILL_IDS.slice(0, 9):
		entries.append({"id": item_id, "count": 1, "expira_em": 0.0})
	entries.append({"id": Items.LEATHER_BACKPACK, "iid": "b1", "durab": 1, "durab_max": 1})
	corpse.entries = entries
	_root.add_child(corpse)
	_track.call(corpse)
	authority.register(corpse)
	_check(authority.request_recover_corpse(1, authority.id_of(corpse)) == Enums.ActionResult.OK and corpse.is_empty(),
			"pedido de recuperar pela autoridade: tudo volta, 9 pilhas numa grade que era de 4")
	_check(player.equipment.count(Items.LEATHER_BACKPACK) == 1 and player.inventory.grid_size() == 12 and player.inventory.grid_used() == 9,
			"a bolsa foi equipada e a grade cresceu")


# ----------------------------------------------------------------------------- tela

func _test_screen_grows() -> void:
	var world := _bag_world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	_root.add_child(screen)
	_track.call(screen)
	screen.equip_requested.connect(func(iid: String) -> void: authority.request_equip(1, iid, ""))
	screen.unequip_requested.connect(func(slot_id: String) -> void: authority.request_unequip(1, slot_id))
	player.inventory.add(Items.LEATHER_BACKPACK, 1)
	screen.open_with(player.inventory, null, null, "")
	_check(screen.equipment_button(BAG) != null and screen.equipment_text(BAG) == "(Bolsa)" and screen.slot_button(true, 4) != null,
			"a tela mostra a vaga Bolsa (silhueta) e a grade de 4")
	screen.equip_requested.emit(player.newest_iid(Items.LEATHER_BACKPACK))
	_check(player.equipment.count(Items.LEATHER_BACKPACK) == 1 and screen.slot_button(true, 11) != null
			and screen.slot_button(true, 12) != null
			and screen.slot_button(true, 15) != null and screen.slot_button(true, 16) == null,
			"equipada com a tela aberta, a grade passa a 12 botões e o cinto vem depois")
	_check(screen.equipment_text(BAG) == "Mochila de couro", "a vaga mostra o nome, sem '1/1' de durabilidade")
	var panel := screen.get_child(1).get_child(0) as Control
	var minimum: Vector2 = panel.get_combined_minimum_size()
	_check(minimum.y <= 180.0 and minimum.x <= 320.0, "o painel com 12 slots sozinho cabe no viewport de 320x180 (%s)" % str(minimum))
	screen.close()
	var chest := InventoryComponent.new()
	_track.call(chest)
	chest.capacity = 12
	screen.open_with(player.inventory, chest, null, "Baú")
	screen._fit_panel()
	var with_chest: Vector2 = panel.get_combined_minimum_size()
	_check(screen.panel_scale() >= 0.9 and with_chest.x * screen.panel_scale() <= 320.5 and with_chest.y * screen.panel_scale() <= 180.5,
			"12 slots ao lado de um Baú de 12: cabe encolhendo o painel só um pouco (%s, escala %.2f)" % [str(with_chest), screen.panel_scale()])
	screen.close()
	screen.open_with(player.inventory, null, null, "")
	_fill_piles(player, 4)
	var events_before: int = (world["events"] as Array).size()
	player._equip_timer = 0.0
	screen.unequip_requested.emit(BAG)
	_check(player.equipment.count(Items.LEATHER_BACKPACK) == 1 and _reason_since(world, events_before) == "over_limit",
			"pedir para tirar a Mochila cheia pela tela é recusado")
	screen.close()


## LEVI (E11a): corpo com o cinto cheio mais a Arma em mãos (4 + 4 + 1 = 9 itens): a recuperação devolve TUDO.
func _test_corpse_with_full_belt_and_weapon() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var player := main.player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.equipment.from_dict({"slots": {}})
	player.fit_grid_to_bag()
	_fill_grid(player, FILLERS)
	for tool_id in TOOLS:
		player.inventory.add(tool_id, 1)
	player.inventory.add(Items.AXE_STONE, 1)
	_equip(player, Items.AXE_STONE)
	player.inventory.add(Items.AXE_STONE, 1)  # o cinto volta a ter 4
	var expected := _tally(player)
	var corpse := main.corpses.deposit(player)
	_check(corpse != null and corpse.item_count() == 9, "o corpo leva 4 slots, 4 do cinto e a Arma em mãos (9 itens)")
	_check(corpse.recover_into(player.inventory, player.equipment) == 9 and corpse.is_empty() and _tally(player) == expected,
			"recuperar devolve os 9: a Arma volta para a vaga dela com o cinto cheio")
