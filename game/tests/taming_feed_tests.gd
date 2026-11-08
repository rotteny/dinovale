# SPDX-License-Identifier: MIT
class_name TamingFeedTests
extends WildPersistenceTests
## Bug do playtest de 08/11: com o primeiro dino já domado, um segundo derrubado recebia bagas e não comia. Cenário
## exato: domado seguindo, segundo nocauteado, comida depositada pela tela (autoridade), espera de `seconds_per_meal`.

const FRAMES_PER_MEAL := 330  # 5,5 s a 60 quadros


func run() -> void:
	await _test_second_dino_eats_with_a_tamed_one()
	_release_worlds()
	await _test_wrong_food_warns_and_stays()
	_release_worlds()
	await _test_feeding_survives_save_load()
	_release_worlds()


## Domado do jogador (o primeiro dino, o do tutorial) e um selvagem derrubado ao lado do jogador.
func _scene(main: Main) -> Dino:
	var first := main.dino
	first.torpor.add_torpor(first.torpor.max_torpor)
	first.state_machine.mark_tamed()
	first.owner_player_id = main.player.player_id
	var second := main.wild.creature_at(_wid(main, 2))
	second.global_position = main.player.global_position + Vector2(16, 0)
	second.torpor.add_torpor(second.torpor.max_torpor)
	main.wild.process_mode = Node.PROCESS_MODE_INHERIT  # o `_main` dos testes congela os selvagens; aqui eles correm
	main.zone.reclassify()  # como o jogo faz a cada intervalo: o derrubado perto do jogador tem de ficar ativo
	return second


func _slot_of(player: Player, item_id: String) -> int:
	for index in player.inventory.slot_count():
		if player.inventory.get_slot(index).get("id", "") == item_id:
			return index
	return -1


func _test_second_dino_eats_with_a_tamed_one() -> void:
	var main := _main("feed_second", 20, true)
	await _root.get_tree().physics_frame
	var second := _scene(main)
	var food := second.taming.ideal_food
	main.player.inventory.add(food, 5)
	var events: Array[String] = []
	main.authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	_check(second.torpor.is_unconscious and second.taming.is_active(), "preparo: o segundo está inconsciente e a doma corre")
	var before := second.inventory.count(food)
	var slot := _slot_of(main.player, food)
	_check(main.authority.request_transfer_slot(1, 1, slot, main.authority.id_of(second)) == Enums.ActionResult.OK,
			"a autoridade aceita a comida no segundo dino")
	_check(second.inventory.count(food) > before and second.feeder_player_id == main.player.player_id, "a comida está no inventário dele")
	for frame in FRAMES_PER_MEAL:
		await _root.get_tree().physics_frame
	_check(second.taming.taming_progress > 0.0 and "taming_meal" in events,
			"com um domado no mundo, o segundo come em %d quadros (progresso %.2f)" % [FRAMES_PER_MEAL, second.taming.taming_progress])


func _test_wrong_food_warns_and_stays() -> void:
	var main := _main("feed_wrong", 20, true)
	await _root.get_tree().physics_frame
	var second := _scene(main)
	var wrong := Items.MEAT if second.taming.ideal_food != Items.MEAT else Items.BERRY
	main.player.inventory.add(wrong, 3)
	var events: Array[String] = []
	main.authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	var slot := _slot_of(main.player, wrong)
	_check(main.authority.request_transfer_slot(1, 1, slot, main.authority.id_of(second)) == Enums.ActionResult.OK
			and "wrong_food" in events, "comida errada: o item entra e o log avisa")
	_check(second.feeder_player_id == "", "comida errada não reserva o dino")
	for frame in FRAMES_PER_MEAL:
		await _root.get_tree().physics_frame
	_check(second.taming.taming_progress == 0.0 and second.inventory.count(wrong) > 0, "ele não come o que não é ideal e o item fica")
	_check(GameMessages.text_of("wrong_food", {"species": "Utahraptor", "item": "Baga", "ideal": "Carne"})
			== "Utahraptor não come Baga — precisa de Carne.", "o texto do aviso")


func _test_feeding_survives_save_load() -> void:
	var state := [0]
	var after := await _save_and_continue("feed_save", func(main: Main) -> void:
		var second := _scene(main)
		main.player.inventory.add(second.taming.ideal_food, 5)
		main.authority.request_transfer_slot(1, 1, _slot_of(main.player, second.taming.ideal_food), main.authority.id_of(second))
		state[0] = second.inventory.count(second.taming.ideal_food))
	after.wild.process_mode = Node.PROCESS_MODE_INHERIT
	after.zone.reclassify()
	var back := after.wild.creature_at(_wid(after, 2))
	_check(state[0] > 0 and back != null and back.torpor.is_unconscious and back.taming.is_active(), "depois de carregar, a doma segue ativa")
	for frame in FRAMES_PER_MEAL:
		await _root.get_tree().physics_frame
	_check(back.taming.taming_progress > 0.0, "depois de salvar e carregar, ele come a comida depositada")
