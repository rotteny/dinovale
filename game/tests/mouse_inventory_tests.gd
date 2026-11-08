# SPDX-License-Identifier: MIT
class_name MouseInventoryTests
extends AuthorityTests
## Ações do mouse (golpe e menu de opções), equipar que MOVE o item, quantidade na transferência, arrastar para o
## atalho e o inventário do domado. Reaproveita a montagem de `AuthorityTests`.

const STAFF := Items.SLEEP_STAFF
const ResourceScene := preload("res://src/entities/resource/ResourceNode.tscn")
const TREE_DEF: ResourceNodeDef = preload("res://data/resources/tree.tres")


func run() -> void:
	_test_mouse_target_and_click()
	_test_click_over_ui_does_not_strike()
	_test_options_menu()
	_test_equip_moves_item()
	_test_swap_returns_to_origin_slot()
	_test_unequip_without_room()
	_test_equip_save_roundtrip()
	_test_transfer_amounts()
	_test_transfer_partial_room()
	_test_quantity_menu()
	_test_drag_to_hotbar()
	_test_drag_refused_item()
	_test_tamed_inventory()
	_release_worlds()


## Jogador em (0,0) olhando para baixo, com `dinos` registrados e vistos pelo detector.
func _arena(dinos: Array) -> Dictionary:
	var player := _player_at(Vector2.ZERO)
	var authority := TestWorld.arm(player, dinos, _track)
	for dino: Dino in dinos:
		player._in_range.append(dino.interactable)
	player.facing = Vector2.DOWN
	return {"player": player, "authority": authority}


func _aim_mouse(player: Player, point: Vector2) -> void:
	player.mouse_point = point
	player.mouse_aim_active = true


func _hurt(dino: Dino) -> bool:
	return dino.health.current_health < dino.health.max_health or dino.torpor.current_torpor > 0.0


func _test_mouse_target_and_click() -> void:
	var front := _dino_at(Vector2(0, 30))   # à frente (olhando para baixo) e o mais perto: a escolha automática
	var side := _dino_at(Vector2(36, 0))    # de lado, ao alcance: o que está sob o cursor
	var far := _dino_at(Vector2(300, 0))    # sob o cursor, mas fora do alcance
	var arena := _arena([front, side])
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	authority.register(far)
	player.tick(0.0)
	_check(player.attack_target == front, "sem mouse: vale a escolha automática (o mais perto à frente)")
	_aim_mouse(player, Vector2(300, 0))
	player.tick(0.0)
	_check(player.attack_target == front, "cursor num dino FORA do alcance: cai no automático")
	_aim_mouse(player, Vector2(36, 2))
	player.tick(0.0)
	_check(player.attack_target == side, "mouse sobre um dino ao alcance: ele vence o automático (o contorno o segue)")
	player.mouse_aim_active = false
	_check(player.attack_at(Vector2(36, 2)) and player.facing.dot(Vector2.RIGHT) > 0.99,
			"clique esquerdo vira para o cursor (pela autoridade, sem andar) e golpeia")
	_check(_hurt(side) and not _hurt(front), "o golpe foi no dino sob o cursor, não no automático")
	_check(player.position == Vector2.ZERO, "virar não teleporta nem anda")
	var events: Array = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void: events.append([code, params.get("reason", "")]))
	player._attack_timer = 0.0
	player._in_range.clear()  # ninguém ao alcance: só o dino sob o cursor, longe
	player.attack_target = null
	player.attack_at(Vector2(300, 0))
	_check(events.has(["action_refused", "out_of_range"]), "clicar num dino fora do alcance é recusado com motivo (fora de alcance)")
	player.perform_move(Vector2.LEFT, false)
	_check(not player.mouse_aim_active, "andar pelo teclado devolve a mira ao automático")


func _test_click_over_ui_does_not_strike() -> void:
	var target := _dino_at(Vector2(0, 30))
	var arena := _arena([target])
	var player: Player = arena["player"]
	var controller: PlayerController = _track.call(PlayerController.new())
	controller.player = player
	controller.authority = arena["authority"]
	_check(not controller.world_click(MOUSE_BUTTON_LEFT, Vector2(0, 30), Vector2.ZERO, true) and not _hurt(target),
			"clique sobre a UI não vira golpe no mundo")
	_check(controller.world_click(MOUSE_BUTTON_LEFT, Vector2(0, 30), Vector2.ZERO, false) and _hurt(target),
			"o mesmo clique fora da UI golpeia")
	player.input_locked = true
	player._attack_timer = 0.0
	_check(not controller.world_click(MOUSE_BUTTON_LEFT, Vector2(0, 30), Vector2.ZERO, false),
			"com o inventário aberto (tela trava o corpo) não golpeia")


func _test_options_menu() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var awake_id := authority.id_of(world["awake"])
	var ids := func(options: Array[Dictionary]) -> Array:
		return options.map(func(option: Dictionary) -> Variant: return option["id"])
	var awake := authority.interaction_options(1, awake_id)
	_check(ids.call(awake) == ["attack"] and awake[0]["enabled"], "selvagem acordado ao alcance: só Atacar")
	var asleep := authority.interaction_options(1, authority.id_of(world["asleep"]))
	_check(ids.call(asleep) == ["attack", "interact"] and asleep[1]["enabled"], "selvagem inconsciente: Atacar e Abrir inventário")
	var far := authority.interaction_options(1, authority.id_of(world["far"]))
	_check(not far[1]["enabled"] and far[1]["reason"] == "out_of_range", "fora do alcance: a opção vem desabilitada com o motivo")
	var mine := authority.interaction_options(1, authority.id_of(world["mine"]))
	_check(ids.call(mine) == ["follow", "stay", "inventory"], "domado meu: Seguir, Ficar e Inventário")
	_check(authority.interaction_options(1, authority.id_of(world["foreign"])).is_empty(), "domado de outro: nada a oferecer")
	# O menu só mostra o que a autoridade devolveu e os motivos em pt-BR.
	var menu: InteractionMenu = _track.call(InteractionMenu.new())
	_root.add_child(menu)
	_check(not menu.open_for(Vector2(10, 10), "Nada", 0, []), "sem opções o menu não abre")
	_check(menu.open_for(Vector2(10, 10), "Dino", 1, far), "com opções o menu abre")
	_check(menu.option_button("interact").disabled and menu.option_button("interact").text.contains("Fora de alcance"),
			"a opção desabilitada mostra o motivo")
	var chosen: Array = []
	menu.option_chosen.connect(func(option_id: String, target_id: int) -> void: chosen.append([option_id, target_id]))
	menu.open_for(Vector2(10, 10), "Dino", awake_id, awake)
	menu.option_button("attack").pressed.emit()
	_check(chosen == [["attack", awake_id]] and not menu.is_open(), "escolher uma opção emite e fecha")
	menu.open_for(Vector2(10, 10), "Dino", awake_id, awake)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._unhandled_input(escape)
	_check(not menu.is_open(), "Esc fecha o menu")
	# Executar a opção passa pela autoridade: Seguir muda a ordem do domado.
	var before: Enums.DinoOrder = world["mine"].state_machine.order
	player.run_option("stay" if before == Enums.DinoOrder.FOLLOW else "follow", authority.id_of(world["mine"]))
	_check(world["mine"].state_machine.order != before, "a opção do menu executa pelo request_command")


func _grid_index(player: Player, iid: String) -> int:
	return player.inventory.index_of_iid(iid)


func _test_equip_moves_item() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var iid := player.hotbar.iid_at(3)
	var origin := _grid_index(player, iid)
	_check(origin >= 0, "preparo: o Bastão está na grade")
	_check(player.request_equip(iid) == "", "equipar vale")
	_check(player.inventory.get_slot(origin).is_empty() and player.inventory.count(STAFF) == 0, "equipar esvazia o slot de origem da grade")
	_check(player.equipment.iid_in(EquipmentLayout.WEAPON) == iid and player.equipment.count(STAFF) == 1, "o destino recebe o item")


func _test_swap_returns_to_origin_slot() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var first := player.hotbar.iid_at(3)
	player.inventory.add(STAFF, 1)
	var second := ""
	for i in player.inventory.slot_count():
		var slot := player.inventory.get_slot(i)
		if slot.has("iid") and slot["iid"] != first:
			second = slot["iid"]
	var second_origin := _grid_index(player, second)
	player.request_equip(first)
	player._equip_timer = 0.0
	_check(player.request_equip(second) == "" and player.equipment.iid_in(EquipmentLayout.WEAPON) == second, "trocar: o novo vai à vaga")
	_check(_grid_index(player, first) == second_origin, "o item anterior volta ao slot de origem do novo")
	_check(player.inventory.count(STAFF) == 1 and player.equipment.count(STAFF) == 1, "troca não perde nem duplica")


func _test_unequip_without_room() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var iid := player.hotbar.iid_at(3)
	player.request_equip(iid)
	player._equip_timer = 0.0
	while player.inventory.room_for(Items.WOOD) > 0:
		player.inventory.add(Items.WOOD, 1)
	var before := player.to_dict()
	var denials: Array = []
	player.authority.game_event.connect(func(code: String, params: Dictionary) -> void: denials.append([code, params.get("reason", "")]))
	_check(player.request_unequip(EquipmentLayout.WEAPON) == EquipmentComponent.REFUSED_FULL, "grade cheia: desequipar recusa")
	_check(player.to_dict() == before and player.equipment.iid_in(EquipmentLayout.WEAPON) == iid, "recusa sem perder o item nem mexer em nada")
	_check(denials.has(["action_refused", "inventory_full"]), "a recusa vira o motivo legível (inventário cheio)")


func _test_equip_save_roundtrip() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var iid := player.hotbar.iid_at(3)
	player.request_equip(iid)
	var saved := JSON.parse_string(JSON.stringify(player.to_dict())) as Dictionary
	var again := _player_at(Vector2.ZERO)
	TestWorld.arm(again, [], _track)
	_check(again.from_dict(saved) and again.equipment.iid_in(EquipmentLayout.WEAPON) == iid and again.inventory.count(STAFF) == 0,
			"save: o equipado volta à vaga e não reaparece na grade")
	_check(again.to_dict() == player.to_dict(), "roundtrip idêntico")


func _berry_slot(player: Player) -> int:
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("id", "") == Items.BERRY:
			return i
	return -1


func _test_transfer_amounts() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var asleep: Dino = world["asleep"]
	var asleep_id := authority.id_of(asleep)
	var slot := _berry_slot(player)
	var total := player.inventory.count(Items.BERRY)
	_check(authority.request_transfer_slot(1, 1, slot, asleep_id, 1) == RESULT.OK and asleep.inventory.count(Items.BERRY) == 1,
			"quantidade 1 passa uma unidade")
	_check(authority.request_transfer_slot(1, 1, slot, asleep_id, 3) == RESULT.OK and asleep.inventory.count(Items.BERRY) == 4,
			"quantidade n passa n")
	_check(authority.request_transfer_slot(1, 1, slot, asleep_id, 999) == RESULT.INVALID_ARGUMENT and asleep.inventory.count(Items.BERRY) == 4,
			"n maior que a pilha: recusa e nada muda")
	_check(authority.request_transfer_slot(1, 1, slot, asleep_id) == RESULT.OK and player.inventory.count(Items.BERRY) == 0
			and asleep.inventory.count(Items.BERRY) == total, "sem quantidade: a pilha toda (comportamento de sempre)")
	_check(authority.request_transfer_slot(1, asleep_id, 0, 1, 2) == RESULT.OK and player.inventory.count(Items.BERRY) == 2,
			"da criatura para o jogador também leva a quantidade")
	var copy := _player_at(Vector2.ZERO)
	_check(copy.from_dict(JSON.parse_string(JSON.stringify(player.to_dict()))) and copy.to_dict() == player.to_dict(),
			"save do jogador depois das transferências: roundtrip")


func _test_transfer_partial_room() -> void:
	var world := _world()
	var authority: WorldAuthority = world["authority"]
	var player: Player = world["player"]
	var asleep: Dino = world["asleep"]
	asleep.inventory.capacity = 1
	asleep.inventory.add(Items.BERRY, 18)  # cabe só mais 2 (pilha de 20)
	var total := player.inventory.count(Items.BERRY) + asleep.inventory.count(Items.BERRY)
	var slot := _berry_slot(player)
	var asked := player.inventory.count(Items.BERRY)
	_check(authority.request_transfer_slot(1, 1, slot, authority.id_of(asleep), asked) == RESULT.OK, "espaço parcial: transfere o que cabe")
	_check(asleep.inventory.count(Items.BERRY) == 20 and player.inventory.count(Items.BERRY) == asked - 2, "foram 2; o resto fica na origem")
	_check(player.inventory.count(Items.BERRY) + asleep.inventory.count(Items.BERRY) == total, "nada duplicou nem se perdeu")
	_check(authority.request_transfer_slot(1, 1, slot, authority.id_of(asleep), 1) == RESULT.REFUSED, "destino cheio: recusa")


func _test_quantity_menu() -> void:
	var player := _player_at(Vector2.ZERO)
	var chest := _inventory_like()
	var screen: InventoryScreen = _track.call(InventoryScreen.new())
	_root.add_child(screen)
	var asked: Array = []
	screen.transfer_requested.connect(func(from_player: bool, index: int, amount: int) -> void: asked.append([from_player, index, amount]))
	screen.open_with(player.inventory, chest, null, "Baú")
	var slot := _berry_slot(player)
	var stack := player.inventory.get_slot(slot)["count"] as int
	screen.open_quantity_menu(true, slot, Vector2(50, 50))
	var menu := screen.quantity_menu()
	menu.choice("1").pressed.emit()
	_check(asked == [[true, slot, 1]], "menu: '1' pede uma unidade")
	screen.open_quantity_menu(true, slot, Vector2(50, 50))
	menu.choice("Todos (%d)" % stack).pressed.emit()
	_check(asked[1] == [true, slot, stack], "menu: 'Todos' pede a pilha")
	screen.open_quantity_menu(true, slot, Vector2(50, 50))
	menu.choice("Quantidade...").pressed.emit()
	_check(menu.spin_maximum() == stack, "seletor: máximo é a pilha quando cabe")
	menu._spin.value = 3
	menu.confirm()
	_check(asked[2] == [true, slot, 3] and not menu.visible, "seletor: confirmar pede a quantidade escolhida")
	chest.capacity = 1
	chest.add(Items.BERRY, 18)
	screen.open_quantity_menu(true, slot, Vector2(50, 50))
	menu.choice("Quantidade...").pressed.emit()
	_check(menu.spin_maximum() == 2, "seletor: o máximo é limitado ao que cabe no destino")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._unhandled_input(escape)
	_check(not menu.visible and asked.size() == 3, "Esc cancela sem pedir nada")
	screen.close()


func _inventory_like() -> InventoryComponent:
	var inventory: InventoryComponent = _track.call(InventoryComponent.new())
	inventory.capacity = 6
	inventory.iid_prefix = "m"
	return inventory


func _hotbar_bar(player: Player) -> HotbarBar:
	var bar: HotbarBar = _track.call(HotbarBar.new())
	bar.player = player
	_root.add_child(bar)
	bar.assign_requested.connect(func(slot: int, item_id: String, iid: String) -> void:
		if iid != "":
			player.hotbar.assign_iid(slot, iid, item_id)
		else:
			player.hotbar.assign(slot, item_id))
	bar.swap_requested.connect(func(first: int, second: int) -> void: player.hotbar.swap(first, second))
	bar.clear_requested.connect(func(slot: int) -> void: player.hotbar.clear(slot))
	return bar


func _test_drag_to_hotbar() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var bar := _hotbar_bar(player)
	var screen: InventoryScreen = _track.call(InventoryScreen.new())
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	screen.open_with(player.inventory, null, null, "")
	var slot := _berry_slot(player)
	var count := player.inventory.count(Items.BERRY)
	var payload: Variant = screen._drag_from(Vector2.ZERO, true, slot)
	_check(payload is Dictionary and payload["item_id"] == Items.BERRY, "arrastar de uma casa do inventário leva o item")
	_check(bar._can_drop_on(Vector2.ZERO, payload, 7), "a casa do atalho aceita o item")
	bar._drop_on(Vector2.ZERO, payload, 7)
	_check(player.hotbar.item_at(7) == Items.BERRY, "soltar atribui àquela casa")
	_check(player.inventory.count(Items.BERRY) == count, "atribuir pelo atalho não move o item do inventário (só referência)")
	var before_first := player.hotbar.entry_at(0)
	bar._drop_on(Vector2.ZERO, {"kind": HotbarBar.DRAG_HOTBAR, "slot": 7}, 0)
	_check(player.hotbar.item_at(0) == Items.BERRY and player.hotbar.entry_at(7) == before_first,
			"arrastar de uma casa para outra troca as duas")
	var dragged: Variant = bar._drag_from(Vector2.ZERO, 0)
	_check(dragged is Dictionary and dragged["slot"] == 0, "casa com atalho pode ser arrastada")
	bar._notification(Control.NOTIFICATION_DRAG_END)  # soltou fora de qualquer destino válido
	_check(player.hotbar.entry_at(0).is_empty(), "soltar fora da barra limpa a casa")
	_check(bar._drag_from(Vector2.ZERO, 0) == null, "casa vazia não arrasta")
	var restored := JSON.parse_string(JSON.stringify(player.hotbar.to_dict())) as Dictionary
	var copy := HotbarComponent.new()
	_check(copy.from_dict(restored) and copy.to_dict() == player.hotbar.to_dict(), "a barra sobrevive ao save")
	copy.free()
	screen.close()


func _test_drag_refused_item() -> void:
	var player := _player_at(Vector2.ZERO)
	TestWorld.arm(player, [], _track)
	var bar := _hotbar_bar(player)
	var refused: Array = []
	bar.assign_refused.connect(func(item_id: String) -> void: refused.append(item_id))
	var def := Items.get_def(Items.SLEEP_FRUIT)
	def.slot = "helmet"  # item que a regra do atalho recusa (a Ração entrará assim); restaurado abaixo
	var payload := {"kind": HotbarBar.DRAG_INVENTORY, "from_player": true, "index": 0, "item_id": Items.SLEEP_FRUIT, "iid": ""}
	_check(not bar._can_drop_on(Vector2.ZERO, payload, 8), "item que não pode ir ao atalho: o destino recusa")
	_check(refused == [Items.SLEEP_FRUIT] and bar.slot_button(8).modulate == HotbarBar.REFUSED_TINT,
			"feedback visual: a casa é tingida de vermelho")
	_check(not player.hotbar.assign(8, Items.SLEEP_FRUIT) and player.hotbar.item_at(8) == "", "o componente também recusa")
	bar._notification(Control.NOTIFICATION_DRAG_END)
	_check(bar.slot_button(8).modulate.r == 1.0 and bar.slot_button(8).modulate.g == 1.0, "o tom volta ao normal quando o arraste acaba")
	def.slot = ""


func _test_tamed_inventory() -> void:
	var dino := _dino_at(Vector2(0, 20))
	_sleeping(dino)
	var other_dino := _dino_at(Vector2(0, -20))
	var arena := _arena([dino, other_dino])
	var player: Player = arena["player"]
	var authority: WorldAuthority = arena["authority"]
	var id := authority.id_of(dino)
	var events: Array = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void: events.append([code, params.get("reason", "")]))
	dino.state_machine.mark_tamed()
	dino.owner_player_id = "alheio"
	_check(authority.request_interact(1, id) == RESULT.NOT_OWNER and events.has(["action_refused", "not_owner"]),
			"domado de outro (ou aliado): não abre, e o log diz que não é seu")
	_check(authority.request_transfer_slot(1, 1, _berry_slot(player), id, 1) == RESULT.NOT_OWNER, "e não recebe item")
	dino.owner_player_id = player.player_id
	var opened: Array = []
	authority.interaction_granted.connect(func(_actor: int, target: int) -> void: opened.append(target))
	_check(authority.request_interact(1, id) == RESULT.OK and opened == [id], "o dono interage com o próprio domado e a tela abre")
	var slot := _berry_slot(player)
	var before := player.inventory.count(Items.BERRY)
	_check(authority.request_transfer_slot(1, 1, slot, id, 1) == RESULT.OK and dino.inventory.count(Items.BERRY) == 1,
			"dono -> domado: passa 1")
	_check(authority.request_transfer_slot(1, id, 0, 1, 1) == RESULT.OK and dino.inventory.count(Items.BERRY) == 0
			and player.inventory.count(Items.BERRY) == before, "domado -> dono: passa 1 de volta")
	_check(dino.feeder_player_id == "", "depositar no domado não reserva dono (isso é só da doma)")
	var ids: Array = authority.interaction_options(1, id).map(func(option: Dictionary) -> Variant: return option["id"])
	_check(ids.has("inventory"), "o menu de opções do domado inclui Inventário")
