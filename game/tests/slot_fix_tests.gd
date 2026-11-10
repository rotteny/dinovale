# SPDX-License-Identifier: MIT
class_name SlotFixTests
extends CarcassTests
## Correções da revisão da E11a (LEVI): Descartar não volta sozinho e só vale para o que foi confirmado; migração sem corte;
## esfola sem duplicar, presa à lâmina e cancelada por outra ação; "Cinto cheio"; barra de esfolar por sinal.
## Roda com o dado REAL de slots (4 e 4).

const REAL_RULES: SlotRules = preload("res://data/balance/slot_rules.tres")
const TOOLS: Array[String] = [Items.SLEEP_STAFF, Items.WOODEN_SPEAR, Items.AXE_STONE, Items.PICKAXE_STONE]


func run() -> void:
	Items.with_layout(REAL_RULES, _run_checks)
	_release_worlds()


func _run_checks() -> void:
	_test_discard_does_not_come_back()
	_test_discard_confirms_what_was_shown()
	_test_migration_keeps_big_stacks()
	_test_skin_no_duplicate()
	_test_skin_follows_the_blade()
	_test_actions_cancel_skin()
	_test_belt_full_reason()
	_test_skin_bar_by_signal()
	_test_with_layout_restores()


func _test_discard_does_not_come_back() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var player := main.player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.inventory.add(Items.WOOD, 5)
	var on_ground_before := main.ground.total_of(Items.WOOD)
	_check(main.authority.request_drop(1, 0, 5, Items.WOOD, 5) == Enums.ActionResult.OK and player.inventory.count(Items.WOOD) == 0
			and main.ground.total_of(Items.WOOD) == on_ground_before + 5, "descartar larga a pilha no chão")
	main.ground.tick()
	_check(player.inventory.count(Items.WOOD) == 0 and main.ground.total_of(Items.WOOD) == on_ground_before + 5,
			"o chão NÃO a recolhe de volta enquanto o jogador está ali")
	var held: GroundItem = null
	for item in main.ground.items():
		if item.item_id == Items.WOOD and item.auto_pickup_held_for == player.player_id:
			held = item
	_check(held != null, "o item largado de propósito guarda de quem é a suspensão")
	_check(main.authority.request_pickup(1, main.authority.id_of(held)) == Enums.ActionResult.OK and player.inventory.count(Items.WOOD) > 0,
			"recolher à mão continua valendo")
	player.inventory.remove(Items.WOOD, 9999)
	player.inventory.add(Items.WOOD, 5)
	main.authority.request_drop(1, 0, 5, Items.WOOD, 5)
	var far := player.global_position
	player.global_position += Vector2(main.ground.rules.auto_pickup_px + 20.0, 0.0)
	main.ground.tick()
	_check(player.inventory.count(Items.WOOD) == 0, "longe, nada é recolhido")
	player.global_position = far
	main.ground.tick()
	_check(player.inventory.count(Items.WOOD) > 0, "depois de se afastar e voltar, o recolhimento automático volta ao normal")
	# Colheita (não é descarte): continua recolhida sozinha.
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	main.ground.spawn_scatter(Items.STICK, 2, player.global_position, player.player_id)
	main.ground.tick()
	_check(player.inventory.count(Items.STICK) == 2, "o que cai de uma colheita segue sendo recolhido andando por cima")


func _test_discard_confirms_what_was_shown() -> void:
	var world := _world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	authority.drops_enabled = true
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.inventory.add(Items.WOOD, 5)
	_check(authority.request_drop(1, 0, 5, Items.WOOD, 6) == Enums.ActionResult.WRONG_STATE and player.inventory.count(Items.WOOD) == 5,
			"a autoridade recusa o descarte se a quantidade confirmada não é a de agora")
	_check(authority.request_drop(1, 0, 5, Items.STONE, 5) == Enums.ActionResult.WRONG_STATE and player.inventory.count(Items.WOOD) == 5,
			"e se o item não é o confirmado")
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	_root.add_child(screen)
	_track.call(screen)
	var asked: Array = []
	screen.discard_requested.connect(func(index: int, item_id: String, count: int) -> void: asked.append([index, item_id, count]))
	screen.open_with(player.inventory, null, null, "")
	screen.slot_button(true, 0).pressed.emit()
	screen.discard_button().pressed.emit()
	player.inventory.add(Items.WOOD, 1)  # a pilha mudou entre o pedido e o Sim
	screen.confirm_button(true).pressed.emit()
	_check(asked.is_empty() and screen.confirm_text() == "", "pilha que mudou depois do pedido: o Sim não descarta e a confirmação some")
	screen.slot_button(true, 0).pressed.emit()
	screen.discard_button().pressed.emit()
	screen.confirm_button(true).pressed.emit()
	_check(asked == [[0, Items.WOOD, 6]], "sem mudança, o pedido leva índice, item e quantidade confirmados (%s)" % str(asked))
	screen.close()


func _test_migration_keeps_big_stacks() -> void:
	var inventory := InventoryComponent.new()
	_track.call(inventory)
	inventory.capacity = 4
	inventory.belt_size = 4
	var spill: Array[Dictionary] = []
	var old := {"version": 1, "slots": [{"id": Items.AXE_STONE, "count": 12}, {"id": Items.WOOD, "count": 200}]}
	_check(inventory.from_dict_spilling(old, spill), "v1 com 12 machados empilhados e 200 de madeira carrega")
	var axes := inventory.count(Items.AXE_STONE)
	var wood := inventory.count(Items.WOOD)
	for entry in spill:
		if entry["id"] == Items.AXE_STONE:
			axes += 1 if entry.has("iid") else int(entry["count"])
		elif entry["id"] == Items.WOOD:
			wood += int(entry["count"])
	_check(axes == 12 and wood == 200, "nada some: 12 machados e 200 de madeira (entrou + excedente = %d e %d)" % [axes, wood])
	var strict := InventoryComponent.new()
	_track.call(strict)
	strict.capacity = 4
	_check(not strict.from_dict(old), "sem excedente a carga continua recusando o que não cabe")


func _carcass_and_player() -> Array:
	var world := _world()
	var carcass := _carcass(world, RAPTOR, 20, Vector2(100.0, 0.0))
	var player := _player_near(world, carcass)
	return [world, carcass, player]


func _test_skin_no_duplicate() -> void:
	var setup := _carcass_and_player()
	var world: Dictionary = setup[0]
	var carcass: ResourceNode = setup[1]
	var player: Player = setup[2]
	carcass.component.leave({Items.MEAT: 1})
	_check(player.skin_unit(carcass, Items.MEAT) == "" and player.inventory.count(Items.MEAT) == 1, "a primeira unidade é entregue")
	_check(player.skin_unit(carcass, Items.MEAT) == Player.SKIN_NOTHING_LEFT and player.inventory.count(Items.MEAT) == 1,
			"a segunda, que outro ator já levou, não entrega nada (antes duplicava)")
	# Pelo serviço: outro ator leva a carne no meio e a esfola segue para o couro, sem entregar a carne que sumiu.
	var other := _carcass_and_player()
	var service_world: Dictionary = other[0]
	var raptor: ResourceNode = other[1]
	var actor: Player = other[2]
	_check(_skin(service_world, raptor) == Enums.ActionResult.OK, "a esfola começa")
	raptor.component.leave({Items.LEATHER: RAPTOR_LEATHER})  # outro ator levou toda a carne
	_pass(service_world, 600.0)
	_check(actor.inventory.count(Items.MEAT) == 0 and actor.inventory.count(Items.LEATHER) == RAPTOR_LEATHER
			and (service_world["authority"] as WorldAuthority).skinning.job(1).is_empty(),
			"sem a carne, a esfola passa ao couro e encerra, sem inventar carne")
	if world.is_empty():
		return


func _test_skin_follows_the_blade() -> void:
	var setup := _carcass_and_player()
	var world: Dictionary = setup[0]
	var carcass: ResourceNode = setup[1]
	var player: Player = setup[2]
	_arm_spear(player)
	var spear_iid := player.equipment.iid_in(EquipmentLayout.WEAPON)
	var events := _events(world)
	_check(_skin(world, carcass) == Enums.ActionResult.OK
			and str((world["authority"] as WorldAuthority).skinning.job(1)["blade"]) == spear_iid,
			"o job guarda a lâmina com que começou")
	player.inventory.add(Items.AXE_STONE, 1)
	player._equip_timer = 0.0
	player.request_equip(player.newest_iid(Items.AXE_STONE))  # troca a lâmina no meio
	(world["authority"] as WorldAuthority).skinning.tick(STEP)
	_check((world["authority"] as WorldAuthority).skinning.job(1).is_empty() and events.has("skin_cancelled"),
			"trocar de arma no meio cancela a esfola (não esquiva o desgaste da Lança)")


func _test_actions_cancel_skin() -> void:
	var setup := _carcass_and_player()
	var world: Dictionary = setup[0]
	var carcass: ResourceNode = setup[1]
	var player: Player = setup[2]
	var authority: WorldAuthority = world["authority"]
	var prey := _dino(world, PAQ, player.global_position + Vector2(14.0, 0.0), "")
	authority.register(prey)
	player.facing = Vector2.RIGHT
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "esfola em andamento")
	var result := authority.request_attack(1, authority.id_of(prey))
	_check(result == Enums.ActionResult.OK and authority.skinning.job(1).is_empty(), "um golpe aceito cancela a esfola (o que entrou fica)")


func _test_belt_full_reason() -> void:
	var inventory := InventoryComponent.new()
	_track.call(inventory)
	inventory.capacity = 4
	inventory.belt_size = 4
	for tool_id in TOOLS:
		inventory.add(tool_id, 1)
	_check(inventory.grid_used() == 0 and inventory.refusal_for(Items.AXE_STONE) == "belt_full",
			"cinto cheio com a grade livre: 'belt_full' (não 'Inventário cheio')")
	_check(GameMessages.reason_text("belt_full") == "Cinto cheio.", "o texto é 'Cinto cheio.'")
	for item_id: Array in [[Items.LEATHER], [Items.STONE], [Items.TUBER], [Items.VEIN_SALT]]:
		inventory.add(str(item_id[0]), 1)
	_check(inventory.refusal_for(Items.WOOD) == "inventory_full", "grade cheia continua 'Inventário cheio'")


func _test_skin_bar_by_signal() -> void:
	var setup := _carcass_and_player()
	var world: Dictionary = setup[0]
	var carcass: ResourceNode = setup[1]
	var player: Player = setup[2]
	var authority: WorldAuthority = world["authority"]
	var hud := PlayerHud.new()
	hud.player = player
	hud.authority = authority
	_root.add_child(hud)
	_track.call(hud)
	_check(not hud.skin_bar().visible, "sem esfola a barra está escondida")
	_skin(world, carcass)
	_check(hud.skin_bar().visible, "ao começar a esfola a barra aparece, pelo sinal (sem ler a autoridade a cada quadro)")
	authority.skinning.tick(1.0)
	_check(hud.skin_bar().visible and hud.skin_bar().value() > 0.0, "e acompanha o progresso")
	authority.skinning.cancel(1, "teste")
	_check(not hud.skin_bar().visible, "ao encerrar, esconde")


func _test_with_layout_restores() -> void:
	var before := Items.slots
	var other := SlotRules.new()
	other.player_slots = 7
	var seen := [0]
	Items.with_layout(other, func() -> void: seen[0] = Items.slots.player_slots)
	_check(seen[0] == 7 and Items.slots == before, "with_layout aplica o layout e devolve o anterior")
