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
	_test_hold_release_radius()
	_test_hold_only_owner_releases()
	_test_hold_is_saved()
	_test_hold_without_main()
	_test_refused_action_keeps_skin()
	_test_loot_service_extracted()
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
	player.global_position += Vector2(main.ground.rules.discard_release_px + 20.0, 0.0)
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
	# Fabricar à mão (aceito) também cancela [provisório 09/11].
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "esfola de novo")
	player.inventory.add(Items.FIBER, 12)
	_check(authority.request_craft(1, "fiber_basket") == Enums.ActionResult.OK and authority.skinning.job(1).is_empty(),
			"fabricar à mão (aceito) cancela a esfola")


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


func _held_wood(main: Main) -> GroundItem:
	var player := main.player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.inventory.add(Items.WOOD, 3)
	main.authority.request_drop(1, 0, 3, Items.WOOD, 3)
	for item in main.ground.items():
		if item.item_id == Items.WOOD and item.auto_pickup_held_for == player.player_id:
			return item
	return null


## LEVI item 4: um passo não solta a trava; ela só solta depois de `discard_release_px` (dado), não de `auto_pickup_px`.
func _test_hold_release_radius() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var rules := main.ground.rules
	_check(rules.discard_release_px > rules.auto_pickup_px + rules.scatter_max_px and rules.discard_release_px == 40.0,
			"o raio de soltura é dado próprio (40 px), maior que o recolhimento e o espalhamento")
	var held := _held_wood(main)
	var home := main.player.global_position
	main.player.global_position = held.global_position + Vector2(rules.auto_pickup_px + 4.0, 0.0)  # um passo além do recolhimento
	main.ground.tick()
	_check(held.auto_pickup_held_for != "", "um passo para fora do recolhimento NÃO solta a trava")
	main.player.global_position = held.global_position + Vector2(rules.discard_release_px + 2.0, 0.0)
	main.ground.tick()
	_check(held.auto_pickup_held_for == "", "além do raio de soltura a trava solta")
	main.player.global_position = home


## LEVI item 6: só a distância do PRÓPRIO dono solta a trava; a de outro jogador não é tocada pelo jogador local.
func _test_hold_only_owner_releases() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var held := _held_wood(main)
	held.auto_pickup_held_for = "outro_jogador"
	main.player.global_position = held.global_position + Vector2(500.0, 0.0)
	main.ground.tick()
	_check(held.auto_pickup_held_for == "outro_jogador", "a trava de outro dono não solta pela distância do jogador local")
	main.player.global_position = held.global_position
	main.ground.tick()
	_check(main.player.inventory.count(Items.WOOD) == 3, "e a trava de outro dono não impede o jogador local de recolher sozinho")


## LEVI item 5: a trava vai ao save (com padrão seguro se faltar).
func _test_hold_is_saved() -> void:
	var main: Main = MAIN_SCENE.instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()
	var held := _held_wood(main)
	var list: Array = JSON.parse_string(JSON.stringify(main.ground.to_list()))
	var held_in_list := 0
	for entry: Dictionary in list:
		if entry.get("held", "") == main.player.player_id:
			held_in_list += 1
	_check(held_in_list == 1, "o save leva o dono da trava")
	main.ground.restore_list(list)
	var back := 0
	for item in main.ground.items():
		if item.item_id == Items.WOOD and item.auto_pickup_held_for == main.player.player_id:
			back += 1
	_check(back == 1 and is_instance_valid(held), "ao carregar, a trava volta (o item largado não é recolhido na hora)")
	main.ground.tick()
	_check(main.player.inventory.count(Items.WOOD) == 0, "e segue sem recolher")
	var old: Array = list.duplicate(true)
	for entry: Dictionary in old:
		entry.erase("held")
	main.ground.restore_list(old)
	var free_of_hold := true
	for item in main.ground.items():
		free_of_hold = free_of_hold and item.auto_pickup_held_for == ""
	_check(free_of_hold, "save sem a chave: sem trava (padrão seguro)")
	var hostile: Array = list.duplicate(true)
	for entry: Dictionary in hostile:
		entry["held"] = 12345
	main.ground.restore_list(hostile)
	free_of_hold = true
	for item in main.ground.items():
		free_of_hold = free_of_hold and item.auto_pickup_held_for == ""
	_check(free_of_hold, "dono da trava de tipo errado vira sem trava")


## LEVI item 7: a trava vale sem a `Main` (campo ligado à autoridade).
func _test_hold_without_main() -> void:
	var world := _world()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	authority.drops_enabled = true
	var ground := GroundItemField.new()
	_track.call(ground)
	_root.add_child(ground)
	ground.attach(authority)
	ground.player = player
	for item_id: String in Items.all_ids():
		player.inventory.remove(item_id, 9999)
	player.inventory.add(Items.WOOD, 2)
	authority.request_drop(1, 0, 2, Items.WOOD, 2)
	_check(ground.total_of(Items.WOOD) == 2, "o campo ouve a autoridade e espalha o que foi largado")
	ground.tick()
	_check(player.inventory.count(Items.WOOD) == 0, "sem a Main, o item largado de propósito não volta sozinho")


## LEVI item 9: pedido RECUSADO não cancela a esfola.
func _test_refused_action_keeps_skin() -> void:
	var setup := _carcass_and_player()
	var world: Dictionary = setup[0]
	var carcass: ResourceNode = setup[1]
	var authority: WorldAuthority = world["authority"]
	_check(_skin(world, carcass) == Enums.ActionResult.OK, "esfola em andamento")
	_check(authority.request_attack(1, 999999) != Enums.ActionResult.OK and not authority.skinning.job(1).is_empty(),
			"golpe recusado (alvo inexistente): a esfola continua")
	_check(authority.request_craft(1, "receita_que_nao_existe") != Enums.ActionResult.OK and not authority.skinning.job(1).is_empty(),
			"fabricar recusado: a esfola continua")
	_check(authority.request_craft(1, "fiber_basket") != Enums.ActionResult.OK and not authority.skinning.job(1).is_empty(),
			"fabricar sem material (recusado): a esfola continua")


## LEVI item 11: largar, recolher e recuperar o corpo moram no `LootService`; a autoridade só repassa.
func _test_loot_service_extracted() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	_check(authority.looting != null and authority.looting.get_parent() == authority, "o LootService é filho da autoridade")
	var lines := FileAccess.get_file_as_string("res://src/world/WorldAuthority.gd").count("\n")
	_check(lines < 900, "a autoridade encolheu (%d linhas) para dar folga à E12" % lines)
