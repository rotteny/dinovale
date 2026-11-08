# SPDX-License-Identifier: MIT
class_name GatherDamageTests
extends WorldTests
## Vida dos nós de golpes (árvore, rocha, minério), dano por ferramenta e material, dano visual e intervalo entre coletas
## (decisões do dono, 08/11).

const TABLE: GatherDamageTable = Player.GATHER_DAMAGE
const TREE: ResourceNodeDef = preload("res://data/resources/tree.tres")


func run() -> void:
	_test_table_rules()
	_test_sfx_without_file()
	await _test_tree_by_hand()
	_release_worlds()
	await _test_rock_hand_and_reset()
	_release_worlds()
	_test_save_and_old_save()
	await _test_interval_scope()
	_release_worlds()


## Regra do dono: ferramenta sempre dá mais que a mão onde a mão causa dano; a certa para o material é a que dá mais.
func _test_table_rules() -> void:
	var tools: Array[String] = [Items.WOODEN_SPEAR, Items.SLEEP_STAFF, "axe_stone", "pickaxe_stone"]
	for material: String in TABLE.materials():
		var hand := TABLE.damage(material, "")
		for tool_id: String in tools:
			var each := TABLE.damage(material, tool_id)
			_check(each >= hand, "%s em %s não dá menos que a mão (%.0f x %.0f)" % [tool_id, material, each, hand])
			if hand > 0.0 and (TABLE.by_material[material] as Dictionary).has(tool_id):
				_check(each > hand, "%s em %s dá MAIS que a mão (%.0f x %.0f)" % [tool_id, material, each, hand])
	_check(TABLE.damage("wood", "") == 10.0 and TABLE.damage("wood", "axe_stone") == 20.0
			and TABLE.damage("wood", Items.WOODEN_SPEAR) == 12.0 and TABLE.damage("wood", "pickaxe_stone") == 15.0,
			"árvore: mão 10, Lança 12, Picareta 15, Machado 20")
	_check(TABLE.damage("stone", "") == 0.0 and TABLE.damage("stone", "axe_stone") == 5.0 and TABLE.damage("ore", "pickaxe_stone") == 20.0,
			"rocha e minério: mão 0, Machado 5, Picareta 20")
	for material: String in ["wood", "stone", "ore"]:
		var best := 0.0
		for tool_id: String in tools:
			best = maxf(best, TABLE.damage(material, tool_id))
		var right := "axe_stone" if material == "wood" else "pickaxe_stone"
		_check(TABLE.damage(material, right) == best, "a ferramenta certa de %s é a que mais dá" % material)
	var tree: ResourceNodeDef = TREE
	var rock: ResourceNodeDef = load("res://data/resources/rock.tres")
	var ore: ResourceNodeDef = load("res://data/resources/iron_seam.tres")
	var rhythm: Array[int] = [TABLE.hits_to_break("wood", tree.health_max, ""), TABLE.hits_to_break("wood", tree.health_max, "axe_stone"),
			TABLE.hits_to_break("stone", rock.health_max, "pickaxe_stone"), TABLE.hits_to_break("ore", ore.health_max, "pickaxe_stone")]
	_check(rhythm == [6, 3, 4, 6] and TABLE.hits_to_break("stone", rock.health_max, "") == 0,
			"vidas 60/80/120 mantêm o ritmo 6, 3, 4 e 6 golpes")


func _test_sfx_without_file() -> void:
	_check(not SfxPlayer.has(&"som_que_nao_existe") and not SfxPlayer.play(_root, &"som_que_nao_existe", Vector2.ZERO),
			"som ausente: silêncio, sem erro")
	_check(SfxPlayer.PITCH_SPREAD == 0.08, "variação de tom de 8%")


func _view_of(node: ResourceNode) -> ResourceNodeView:
	for child in node.get_children():
		if child is ResourceNodeView:
			return child as ResourceNodeView
	return null


func _test_tree_by_hand() -> void:
	var main := _main("gather_tree", 20, true)
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var wood := main.resources.node_by_id("n316")
	var view := _view_of(wood)
	await _root.get_tree().process_frame
	var dropped: Array[String] = []
	authority.items_dropped.connect(func(item_id: String, _a: int, _at: Vector2, _d: String) -> void: dropped.append(item_id))
	var stages: Array[int] = []
	var healths: Array[float] = []
	for hit in 5:
		_near(main, wood)
		_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK, "golpe %d aceito" % (hit + 1))
		stages.append(wood.component.damage_stage())
		healths.append(wood.component.current_health())
		_check(view.damage_stage_shown() == wood.component.damage_stage(), "o desenho segue o estágio no golpe %d" % (hit + 1))
		if hit == 0:
			_check(view.is_shaking() and view.is_flashing(), "o golpe faz tremer e piscar")
	_check(healths == [50.0, 40.0, 30.0, 20.0, 10.0], "a mão tira 10 de vida por golpe: %s" % [healths])
	_check(stages == [0, 1, 1, 2, 2], "estágio visual nas frações 66%% e 33%%: %s" % [stages])
	_check(view.overlay_visible(), "a marca de dano está visível")
	_check(wood.is_available() and dropped.is_empty(), "ainda de pé, sem item no chão")
	var siblings := wood.get_parent().get_child_count()
	_near(main, wood)
	authority.clock.advance(0.0)
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK and not wood.is_available(), "vida 0 derruba o nó")
	_check(dropped.has(Items.WOOD), "e solta os itens no chão")
	_check(wood.get_parent().get_child_count() == siblings + 1, "a árvore tomba (cópia do desenho cai antes de sumir)")
	_check(not wood.component.has_damage(), "caiu: sem dano guardado")
	_check(TABLE.hits_to_break("wood", 60.0, Items.WOODEN_SPEAR) == 5, "Lança: 5 golpes")


func _test_rock_hand_and_reset() -> void:
	var main := _main("gather_rock", 20, true)
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var rock := main.resources.node_by_id("n174")
	var view := _view_of(rock)
	await _root.get_tree().process_frame
	var rebuffs := [0]
	rock.component.rebuffed.connect(func() -> void: rebuffs[0] += 1)
	_near(main, rock)
	var hp := player.health.current_health
	_check(authority.request_gather(1, authority.id_of(rock)) == RESULT.OK, "o soco na rocha é aceito como toque")
	_check(rock.component.current_health() == rock.def.health_max and rock.is_available() and not rock.component.has_damage(),
			"dano 0 (mão na rocha): a vida do nó não muda")
	_check(is_equal_approx(player.health.current_health, hp - 1.0) and rebuffs[0] == 1, "a mão perde 1 de vida e o nó reage")
	_check(player.last_drop.is_empty(), "nada cai")
	# Vida inteira de volta por inatividade: simulado com dano direto no componente (a Picareta ainda não é item).
	rock.component.register_damage(40.0)
	view._on_damaged(rock.component.current_health(), rock.def.health_max, false)
	_check(rock.component.damage_stage() == 1 and view.damage_stage_shown() == 1, "metade da vida: estágio 1 (rachaduras)")
	rock.component.register_damage(20.0)
	view._on_damaged(rock.component.current_health(), rock.def.health_max, false)
	_check(rock.component.damage_stage() == 2 and view.damage_stage_shown() == 2, "um quarto da vida: estágio 2")
	authority.clock.advance(rock.def.hit_reset_seconds - 1.0)
	_check(rock.component.current_health() < rock.def.health_max, "antes do prazo, o dano continua")
	authority.clock.advance(2.0)
	_check(is_equal_approx(rock.component.current_health(), rock.def.health_max), "sem golpes por hit_reset_seconds, a vida volta ao máximo")
	_check(rock.component.damage_stage() == 0, "e o estágio volta a 0")
	view._process(0.0)
	_check(view.damage_stage_shown() == 0, "o desenho volta ao normal (fade)")


func _test_save_and_old_save() -> void:
	var def: ResourceNodeDef = TREE
	var time := [100.0]
	var node := ResourceNodeComponent.new()
	node.def = def
	node.clock = func() -> float: return time[0]
	node.register_damage(20.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(node.to_dict()))
	_check(is_equal_approx(float(data["health"]), 40.0) and not data.has("hits"), "o save guarda a vida, não golpes")
	var restored := ResourceNodeComponent.new()
	restored.def = def
	restored.clock = node.clock
	restored.from_dict(data)
	_check(is_equal_approx(restored.current_health(), 40.0) and restored.damage_stage() == 1, "a vida do nó volta do save")
	var old := ResourceNodeComponent.new()
	old.def = def
	old.clock = node.clock
	old.from_dict({"def": "tree", "depleted": false, "due_at": 0.0, "hits": 3, "hits_left_seconds": 5.0})
	_check(is_equal_approx(old.current_health(), def.health_max) and not old.has_damage(), "save antigo (golpes) carrega com a vida cheia")
	restored.from_dict({"def": "tree", "depleted": false, "health": 9999.0, "health_left_seconds": 5.0})
	_check(restored.current_health() <= def.health_max, "vida de fora fica no limite")
	node.free()
	restored.free()
	old.free()


## Junto do nó, de frente, sem mexer no relógio (o `_near` passa o intervalo de coleta; aqui ele é o assunto).
func _stand(main: Main, node: ResourceNode) -> void:
	main.player.position = node.position + Vector2(0, 10)
	main.player.facing = Vector2.UP
	main.player.tick(60.0)


func _test_interval_scope() -> void:
	var main := _main("gather_interval", 20, true)
	await _root.get_tree().physics_frame
	var player := main.player
	var authority := main.authority
	var wood := main.resources.node_by_id("n316")
	# Recolher do chão e golpe intermediário não esperam o intervalo; o golpe que derruba, sim.
	var bush: ResourceNode = null
	for candidate in main.resources.nodes():
		if candidate.def.id == "bush_baga":
			bush = candidate
			break
	_stand(main, bush)
	_check(authority.request_gather(1, authority.id_of(bush)) == RESULT.OK, "coleta concluída (arbusto)")
	_check(authority.gather_wait_left(1) > 0.0, "o intervalo está aberto")
	_stand(main, wood)
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK and wood.component.has_damage(),
			"golpe intermediário na árvore não é barrado")
	_check(not player.would_complete_gather(wood) and player.gather_interval_left() > 0.0, "a HUD não pinta de cinza o golpe intermediário")
	for hit in 4:
		_stand(main, wood)
		authority.request_gather(1, authority.id_of(wood))
	_stand(main, wood)
	_check(player.gather_blocked_now(wood), "o golpe que derrubaria fica cinza no intervalo")
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.COOLDOWN and wood.is_available(), "e é recusado")
	authority.clock.advance(2.1)
	_stand(main, wood)
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK and not wood.is_available(), "passado o intervalo, derruba")
	# Pegar do chão não espera: abre o intervalo de novo e recolhe um item solto.
	_check(authority.gather_wait_left(1) > 0.0, "derrubar abriu outro intervalo")
	var piles := main.ground.items()
	var pickup := false
	if not piles.is_empty():
		player.position = piles[0].global_position
		pickup = authority.request_pickup(1, authority.id_of(piles[0])) == RESULT.OK
	_check(pickup, "recolher do chão não é afetado pelo intervalo")
