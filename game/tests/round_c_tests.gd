# SPDX-License-Identifier: MIT
class_name RoundCTests
extends WildPersistenceTests
## Rodada C: nó esgotado some por inteiro e só volta com o lugar livre, toda árvore é coletável, ordem de comando
## só no domado do jogador, destaque do que se coleta, placa do domado e a carcaça do dino morto.

const KINDS: Array[String] = ["tree", "rock", "loose_stone", "bush_baga", "bush_sono"]


func run() -> void:
	await _test_every_kind_vanishes_and_returns()
	_release_worlds()
	await _test_occupied_place_waits()
	_release_worlds()
	_test_occupancy_query()
	_test_occupancy_shape_box()
	await _test_command_denials()
	_release_worlds()
	await _test_highlight_and_markers()
	_release_worlds()
	await _test_tamed_level_text_once()
	_release_worlds()
	await _test_carcass_from_death()
	_release_worlds()
	await _test_carcass_hand_cost_and_partial()
	_release_worlds()
	await _test_carcass_save_and_limits()
	_release_worlds()
	_test_map_data()


func _world(name: String) -> Main:
	var main := _main(name, 20, true)
	await _root.get_tree().physics_frame
	return main


func _tame_for(creature: Dino, owner_id: String) -> void:
	creature.feeder_player_id = owner_id
	creature.torpor.add_torpor(creature.torpor.max_torpor)
	creature.inventory.add("berry", 60)
	var guard := 0
	while not creature.state_machine.is_tamed and guard < 100:
		guard += 1
		creature.taming.tick(5.1)


# ----------------------------------------------------------------------------- nós

func _test_tamed_level_text_once() -> void:
	var main := await _world("c_level_text")
	var mine := main.wild.creature_at(_wid(main, 0))
	var theirs := main.wild.creature_at(_wid(main, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 55  # posição sempre a mesma: o teste não oscila
	for creature: Dino in [mine, theirs]:
		creature.global_position = main.player.global_position + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(20.0, 40.0))
	main.zone.reclassify()
	await _root.get_tree().process_frame
	var mine_view := _view_of_dino(main, mine)
	var theirs_view := _view_of_dino(main, theirs)
	_check(mine_view != null and theirs_view != null, "dinos perto do jogador têm view")
	_tame_for(mine, main.player.player_id)
	_tame_for(theirs, "outro")
	_check(mine_view.popup_count() == 0, "domado do jogador: sem 'Nv' flutuante (a placa já mostra o nível)")
	_check(theirs_view.popup_count() == 1, "domado de outro jogador mantém o 'Nv' flutuante")


func _test_every_kind_vanishes_and_returns() -> void:
	var main := await _world("c_vanish")
	for kind in KINDS:
		var node := main.resources.node_by_id(main.map.node_ids[kind][0])
		_check(node != null and node.visible and node.is_available(), "%s: existe e está inteiro" % kind)
		node.harvest()
		await _root.get_tree().physics_frame
		_check(not node.visible and not node.blocks_movement() and not node.is_available(),
				"%s: esgotado some por inteiro (desenho e colisão)" % kind)
		TestWorld.pass_time(main, node.component.respawn_total() + 1.0)
		await _root.get_tree().physics_frame
		var solid := node.def.foot_size != Vector2.ZERO and node.def.blocks_when_full
		_check(node.visible and node.is_available() and node.blocks_movement() == solid,
				"%s: volta pelo respawn do tipo, com desenho e colisão" % kind)
	# Colheita parcial não some.
	var bush := main.resources.node_by_id("n1")
	bush.component.leave({bush.def.item_id: 1})
	_check(bush.visible and bush.is_available() and bush.component.is_partial(), "colheita parcial ainda não some")


func _test_occupied_place_waits() -> void:
	var main := await _world("c_occupied")
	var node := main.resources.node_by_id("n320")
	main.player.position = node.global_position
	node.harvest()
	TestWorld.pass_time(main, node.component.respawn_total() + 1.0)
	_check(node.component.depleted and node.component.is_waiting() and not node.visible,
			"jogador em cima: o nó espera esgotado, sem voltar")
	var entry := node.component.to_dict()
	_check(entry["depleted"] == true, "esperando não é perdido: segue no save como esgotado")
	TestWorld.pass_time(main, 60.0)
	_check(node.component.depleted, "continua esperando enquanto estiver ocupado")
	main.player.position = node.global_position + Vector2(200, 0)
	TestWorld.pass_time(main, 1.0)
	_check(node.is_available() and node.visible, "livre o lugar, tenta de novo e volta")
	# Um dino parado no tile também segura.
	var other := main.resources.node_by_id("n176")
	main.dino.global_position = other.global_position + Vector2(2, -2)
	other.harvest()
	TestWorld.pass_time(main, other.component.respawn_total() + 1.0)
	_check(other.component.depleted, "um dino no tile segura o nó")
	main.dino.global_position = other.global_position + Vector2(300, 0)
	TestWorld.pass_time(main, 1.0)
	_check(other.is_available(), "o dino sai e o nó volta")


func _test_occupancy_query() -> void:
	var query := TileOccupancy.new()
	var body := Node2D.new()
	_root.add_child(body)
	body.global_position = Vector2(40, 40)
	var holder: Array = [body]
	query.add_source(func() -> Array: return holder)
	_check(not query.is_free(Rect2(32, 32, 16, 16)) and query.is_free(Rect2(200, 200, 16, 16)), "consulta única: corpo no retângulo ocupa")
	_check(not query.is_cell_free(Vector2i(2, 2), 16.0) and query.is_cell_free(Vector2i(9, 9), 16.0), "consulta por tile")
	body.free()
	_check(query.is_free(Rect2(32, 32, 16, 16)), "corpo liberado não ocupa mais")


## Corpo com caixa de colisão 10x10 deslocada +8 em x da origem do corpo, sobre o tile 32..48 (área com folga: 31..49).
## Com o corpo em x, a caixa cobre de x+3 a x+13.
func _test_occupancy_shape_box() -> void:
	var query := TileOccupancy.new()
	var body := Node2D.new()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 10)
	shape_node.shape = shape
	shape_node.position = Vector2(8, 0)
	body.add_child(shape_node)
	_root.add_child(body)
	var holder: Array = [body]
	query.add_source(func() -> Array: return holder)
	var tile := Rect2(32, 32, 16, 16)
	# Centro (origem) do corpo fora do tile, mas a caixa entra: ocupado.
	body.global_position = Vector2(30, 40)  # caixa em x 33..43
	_check(body.global_position.x < tile.position.x and not query.is_free(tile), "origem fora do tile, caixa dentro: ocupado")
	body.global_position = Vector2(60, 40)  # caixa 63..73: longe
	_check(query.is_free(tile), "caixa longe do tile: livre")
	# Folga de 1 px: a caixa a 0,5 px fora do tile ainda ocupa; a 1,5 px fora, não.
	body.global_position = Vector2(48.5 + 5.0 - 8.0, 40)  # caixa 48.5..58.5: começa 0,5 px fora do tile
	_check(not query.is_free(tile), "caixa a 0,5 px fora do tile: ocupado (folga de 1 px)")
	body.global_position = Vector2(49.5 + 5.0 - 8.0, 40)  # caixa 49.5..59.5: começa 1,5 px fora
	_check(query.is_free(tile), "caixa a 1,5 px fora do tile: livre")
	# O mesmo vale do outro lado (caixa terminando fora, à esquerda).
	body.global_position = Vector2(31.5 - 5.0 - 8.0, 40)  # caixa 21.5..31.5 termina 0,5 px fora
	_check(not query.is_free(tile), "caixa terminando 0,5 px antes do tile: ocupado")
	body.global_position = Vector2(30.5 - 5.0 - 8.0, 40)  # termina em 30.5: 1,5 px fora
	_check(query.is_free(tile), "caixa terminando 1,5 px antes do tile: livre")
	# Deslocamento muda o resultado: o corpo fixo em (40, 40) com a forma deslocada para fora do tile.
	body.global_position = Vector2(40, 40)
	_check(not query.is_free(tile), "forma deslocada +8 com o corpo no tile: ocupado")
	shape_node.position = Vector2(80, 0)
	_check(query.is_free(tile) and tile.has_point(body.global_position),
			"forma deslocada para longe: livre, embora o ponto do corpo esteja no tile")
	# Forma desligada: vale o ponto do corpo.
	shape_node.disabled = true
	_check(not query.is_free(tile), "forma desligada: vale o ponto do corpo (no tile, ocupado)")
	body.global_position = Vector2(100, 100)
	_check(query.is_free(tile), "forma desligada e ponto fora do tile: livre")
	shape_node.disabled = false
	body.global_position = Vector2(20, 40)
	shape_node.position = Vector2(20, 0)  # caixa 35..45 dentro do tile, origem do corpo (20) fora
	_check(not query.is_free(tile), "forma ligada de novo conta pela caixa")
	body.free()


# ----------------------------------------------------------------------------- comando

func _test_command_denials() -> void:
	var main := await _world("c_command")
	var player := main.player
	var wild_awake := main.wild.creature_at(_wid(main, 0))
	player.position = wild_awake.position + Vector2(10, 0)
	var id := main.authority.id_of(wild_awake)
	_check(main.authority.request_command(1, id, "FOLLOW") == RESULT.WRONG_STATE and wild_awake.state_machine.order == Enums.DinoOrder.STAY,
			"selvagem acordado: ordem negada")
	var sleeper := main.wild.creature_at(_wid(main, 1))
	sleeper.position = player.position + Vector2(12, 0)
	sleeper.torpor.add_torpor(sleeper.torpor.max_torpor)
	await _root.get_tree().physics_frame
	_check(sleeper.can_interact() and main.authority.request_command(1, main.authority.id_of(sleeper), "FOLLOW") == RESULT.WRONG_STATE,
			"selvagem desacordado, sem dono: ordem negada")
	var foreign := main.wild.creature_at(_wid(main, 2))
	_tame_for(foreign, "outro")
	foreign.position = player.position + Vector2(-12, 0)
	var foreign_id := main.authority.id_of(foreign)
	_check(foreign.state_machine.is_tamed and main.authority.request_command(1, foreign_id, "FOLLOW") == RESULT.NOT_OWNER,
			"domado de outro dono: ordem negada")
	# Pelo caminho da tecla: o alvo é o selvagem, depois o domado alheio. Nada muda.
	player.update_target()
	var before := foreign.state_machine.order
	player.target = foreign.interactable
	_check(not player.try_interact() and foreign.state_machine.order == before, "tecla sobre o domado alheio: nada muda")
	player.target = wild_awake.interactable
	_check(not player.try_interact() and wild_awake.state_machine.order == Enums.DinoOrder.STAY, "tecla sobre o selvagem: nada muda")
	main.hud._on_target_changed(foreign.interactable)
	_check(not main.hud.prompt_label().visible, "a HUD não oferece ordem no domado de outro")
	# O próprio domado aceita.
	var mine := main.wild.creature_at(_wid(main, 3))
	_tame_for(mine, player.player_id)
	mine.position = player.position + Vector2(0, 14)
	_check(main.authority.request_command(1, main.authority.id_of(mine), "FOLLOW") == RESULT.OK, "o próprio domado aceita a ordem")
	_check(main.authority.request_command(1, main.authority.id_of(mine), "follow") == RESULT.INVALID_ARGUMENT,
			"o nome da ordem é o do enum (FOLLOW): minúsculas são argumento inválido (o 5 visto no teste antigo)")


# ----------------------------------------------------------------------------- destaque e placa

func _view_of(node: ResourceNode) -> ResourceNodeView:
	for child in node.get_children():
		if child is ResourceNodeView:
			return child
	return null


func _view_of_dino(main: Main, creature: Dino) -> DinoView:
	for child in main.get_children():
		if child is DinoView and (child as DinoView).dino == creature:
			return child
	return null


func _marker_of(main: Main, creature: Dino) -> DinoMarker:
	for child in main.get_children():
		if child is DinoMarker and (child as DinoMarker).dino == creature:
			return child
	return null


func _test_highlight_and_markers() -> void:
	var main := await _world("c_highlight")
	var tree_node := main.resources.node_by_id("n335")
	var rock := main.resources.node_by_id("n193")
	main.hud._on_target_changed(tree_node.interactable)
	var view := _view_of(tree_node)
	_check(view.is_highlighted() and view.highlight_text() == "Árvore: Madeira", "nó coletável ao alcance: contorno e o nome do que rende")
	main.hud._on_target_changed(rock.interactable)
	var rock_view := _view_of(rock)
	_check(not view.is_highlighted() and rock_view.is_highlighted() and rock_view.highlight_text() == "Pedra", "o destaque muda com o alvo")
	main.hud._on_target_changed(null)
	_check(not _view_of(rock).is_highlighted(), "sem alvo, sem destaque")
	var other := _view_of(main.resources.node_by_id("n336"))
	_check(not other.is_highlighted(), "fora do alcance, nada")
	tree_node.harvest()
	_check(not view.is_highlighted(), "esgotado não tem destaque (nem desenho)")
	# Placa do domado: só no do jogador.
	var mine := main.wild.creature_at(_wid(main, 0))
	var theirs := main.wild.creature_at(_wid(main, 1))
	var wild_one := main.wild.creature_at(_wid(main, 2))
	_tame_for(mine, main.player.player_id)
	_tame_for(theirs, "outro")
	var rng := RandomNumberGenerator.new()
	rng.seed = 260
	for creature: Dino in [mine, theirs, wild_one]:  # perto do jogador: na zona ativa, com view e placa
		creature.global_position = main.player.global_position + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(20.0, 40.0))
	main.zone.reclassify()
	await _root.get_tree().process_frame
	await _root.get_tree().process_frame
	var marker := _marker_of(main, mine)
	_check(marker != null and marker.is_marked() and marker.outline_visible() and marker.plate_text().contains("Nv %d" % mine.level)
			and marker.plate_text().begins_with("Paquicéfalo"), "domado do jogador: contorno, nome e nível")
	var foreign_marker := _marker_of(main, theirs)
	_check(foreign_marker == null or (not foreign_marker.is_marked() and not foreign_marker.outline_visible()), "domado de outro: sem placa")
	var wild_marker := _marker_of(main, wild_one)
	_check(wild_marker == null or (not wild_marker.is_marked() and not wild_marker.visible), "selvagem: sem placa nem silhueta")
	wild_one.torpor.add_torpor(wild_one.torpor.max_torpor)
	await _root.get_tree().process_frame
	_check(wild_marker == null or not wild_marker.is_marked(), "selvagem desacordado continua selvagem")


# ----------------------------------------------------------------------------- carcaça

func _kill(creature: Dino) -> void:
	creature.health.take_damage(creature.health.max_health * 3.0)


func _test_carcass_from_death() -> void:
	var main := await _world("c_carcass")
	var creature := main.wild.creature_at(_wid(main, 0))
	var point := creature.global_position
	var level := creature.level
	var expected := main.carcasses.LEVEL_RULES.carcass_meat(4, level)
	_kill(creature)
	await _root.get_tree().physics_frame
	_check(main.carcasses.count() == 1, "dino selvagem morto deixa uma carcaça")
	var carcass: ResourceNode = main.carcasses.nodes()[0]
	_check(carcass.global_position.distance_to(point + CarcassField.FEET_OFFSET) < 0.01 and main.authority.id_of(carcass) > 0,
			"no lugar do corpo, e registrada na autoridade")
	_check(carcass.def.yield_amount == expected and carcass.def.item_id == "meat" and carcass.def.hand_damage_per_item,
			"rende a carne da espécie no nível (%d)" % expected)
	_check(main.wild.creature_at(_wid(main, 0)) == null or main.wild.is_dead(_wid(main, 0)), "o morto não renasce em cima")
	# Domado também.
	var mine := main.wild.creature_at(_wid(main, 1))
	_tame_for(mine, main.player.player_id)
	_kill(mine)
	await _root.get_tree().physics_frame
	_check(main.carcasses.count() == 2, "dino domado morto também deixa carcaça")
	# O dino da cena (tutorial).
	_kill(main.dino)
	await _root.get_tree().physics_frame
	_check(main.carcasses.count() == 3, "o dino da cena morto deixa carcaça")
	# Some pelo tempo do GDD (10 min).
	TestWorld.pass_time(main, 600.0 - 1.0)
	_check(main.carcasses.count() == 3, "antes de 10 min a carcaça fica")
	TestWorld.pass_time(main, 2.0)
	await _root.get_tree().physics_frame
	_check(main.carcasses.count() == 0, "com 10 min (GDD 5.6) a carcaça some")


func _test_carcass_hand_cost_and_partial() -> void:
	var main := await _world("c_carcass_cost")
	var player := main.player
	var creature := main.wild.creature_at(_wid(main, 0))
	creature.level = 20  # 4 x 1,3 = 5 de carne: mais de 1 item
	_kill(creature)
	await _root.get_tree().physics_frame
	var carcass: ResourceNode = main.carcasses.nodes()[0]
	var meat := carcass.def.yield_amount
	_check(meat == 5, "nível 20: 5 de carne (yield_amount > 1)")
	player.position = carcass.global_position + Vector2(0, 10)
	player.tick(60.0)
	_empty(player.inventory)
	player.inventory.capacity = 1
	player.inventory.add("meat", Items.max_stack("meat") - 2)  # cabem só 2
	var hp := player.health.current_health
	var id := main.authority.id_of(carcass)
	_check(main.authority.request_gather(1, id) == RESULT.OK and player.inventory.count("meat") == Items.max_stack("meat"),
			"o que cabe entra (2 itens)")
	_check(is_equal_approx(player.health.current_health, hp - 2.0) and not carcass.component.depleted and carcass.visible,
			"parcial: 1 de dano por item entregue (2), a carcaça segue")
	_check(carcass.component.pending_yields() == {"meat": meat - 2, "leather": 1}, "o resto (carne e couro) fica na carcaça")
	player.tick(60.0)
	main.authority.clock.advance(2.0)  # intervalo entre coletas
	player.inventory.remove("meat", Items.max_stack("meat"))
	player.inventory.capacity = 8  # espaço também para o couro, que ficou na carcaça
	hp = player.health.current_health
	_check(main.authority.request_gather(1, id) == RESULT.OK, "volta e leva o resto")
	_check(is_equal_approx(player.health.current_health, hp - float(meat - 1)), "o resto custa 1 por item (%d)" % (meat - 1))
	await _root.get_tree().physics_frame
	await _root.get_tree().physics_frame
	_check(main.carcasses.count() == 0 and main.authority.entity(id) == null, "esvaziada, a carcaça some e sai do registro")
	# Com mais itens que o piso de vida: o Soco não mata.
	var big := main.wild.creature_at(_wid(main, 1))
	big.level = 60
	_kill(big)
	await _root.get_tree().physics_frame
	var huge: ResourceNode = main.carcasses.nodes()[0]
	player.position = huge.global_position + Vector2(0, 10)
	player.tick(60.0)
	player.inventory.capacity = 8
	player.health.current_health = player.rules.hand_damage_floor + 1.0
	main.authority.request_gather(1, main.authority.id_of(huge))
	_check(player.health.current_health >= player.rules.hand_damage_floor and not player.health.is_dead(),
			"o piso de vida vale: o Soco não mata")


func _test_carcass_save_and_limits() -> void:
	var saved_entries: Array = []
	var after := await _save_and_continue("c_carcass_save", func(main: Main) -> void:
		_kill(main.wild.creature_at(_wid(main, 0)))
		_kill(main.wild.creature_at(_wid(main, 1)))
		var half: ResourceNode = main.carcasses.nodes()[0]
		half.component.leave({"meat": 2})
		TestWorld.pass_time(main, 30.0)
		saved_entries.append_array(main.carcasses.to_list()))
	_check(saved_entries.size() == 2, "preparo: duas carcaças gravadas")
	_check(after.carcasses.count() == 2, "as carcaças voltam ao carregar")
	var back: Array[ResourceNode] = after.carcasses.nodes()
	var spot := Vector2(saved_entries[0]["x"], saved_entries[0]["y"])
	_check(back[0].component.pending_yields() == {"meat": 2} and back[0].global_position.distance_to(spot) < 0.01,
			"posição e o que resta voltam")
	_check(after.wild.is_dead(_wid(after, 0)), "o morto continua morto (não renasce)")
	_check(after.authority.id_of(back[0]) == int(saved_entries[0]["id"]), "o id da entidade se mantém")
	# Dado hostil: espécie desconhecida, número louco e excesso.
	var crazy := {"species": "placeholder_dino", "level": 99999, "x": 1e30, "y": "a", "born_at": 1.0e30, "left": {"meat": 999, "x": 4}}
	after.carcasses.restore_list([{"species": "nada"}, crazy, 7, null])
	_check(after.carcasses.count() == 1, "espécie desconhecida e lixo são descartados")
	var node: ResourceNode = after.carcasses.nodes()[0]
	_check(node.component.pending_yields().get("meat", 0) == node.def.yield_amount and absf(node.position.x) <= CarcassField.MAX_COORD,
			"número fora da faixa é limitado")
	var many: Array = []
	for i in 30:
		many.append({"species": "placeholder_dino", "level": 10, "x": float(i), "y": 0.0})
	after.carcasses.restore_list(many)
	_check(after.carcasses.count() == 8, "no máximo 8 carcaças (GDD 5.6)")
	for i in 5:
		_kill(after.wild.creature_at(_wid(after, 10 + i)))
	_check(after.carcasses.count() == 8, "a mais antiga sai quando passa de 8")


# ----------------------------------------------------------------------------- dado do mapa

func _test_map_data() -> void:
	var map := IslandMap.default_map()
	_check(map.revision >= 2 and not map.scenery.has("tree_decor"), "revisão do mapa subiu e não há árvore de cenário")
	_check((map.nodes["tree"] as Array).size() > 900, "todas as árvores do mapa são nós coletáveis (%d)" % (map.nodes["tree"] as Array).size())
