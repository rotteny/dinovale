# SPDX-License-Identifier: MIT
class_name RecipeLearningTests
extends AuthorityTests
## E7b (PRO-05 e PRO-13): as 17 receitas em dado, aprender com Saber (validado pela autoridade), o gasto DERIVADO das receitas
## aprendidas, save, migração, dado hostil, a aba Receitas (tecla P) e o jogador do nível 6 aprendendo tudo.

const RESULT_OK := Enums.ActionResult.OK
const RULES: ProgressionRules = preload("res://data/balance/progression_rules.tres")
const LEARNABLE: Array[String] = ["workbench", "foundation", "wall", "door", "sleeping_bag", "bed", "ration_c", "ration_b", "ration_a"]
const KNOWN: Array[String] = ["wooden_spear", "axe_stone", "pickaxe_stone", "campfire", "sleep_staff", "fiber_basket", "chest",
		"leather_backpack"]


func run() -> void:
	_test_recipe_data()
	_test_learn_without_saber()
	_test_learn_workbench_with_one_saber()
	_test_learn_twice_and_bad_requests()
	_test_client_without_authority()
	_test_spent_is_derived()
	_test_save_roundtrip()
	_test_migration()
	_test_hostile_save()
	_test_level_six_learns_everything()
	_test_group_cost_must_match()
	_test_future_progression_version()
	_test_status_and_panel()
	_release_worlds()


## Grupo de aprendizado com custos diferentes (g1 = 1, g2 = 3): o livro recusa o segundo membro (senão se pagaria só o do primeiro).
func _test_group_cost_must_match() -> void:
	var book := RecipeBook.new()
	var first := _group_recipe("g_a", "grupo", 1)
	var cheap_twin := _group_recipe("g_b", "grupo", 1)
	var dear_twin := _group_recipe("g_c", "grupo", 3)
	_check(book.add(first) and book.add(cheap_twin) and not book.add(dear_twin) and book.find("g_c") == null
			and book.group_of(first).size() == 2, "grupo com custos 1 e 3: o membro de custo diferente não entra; o de custo igual entra")
	_check(book.add(_group_recipe("g_a", "grupo", 1)) and not book.add(_group_recipe("g_a", "grupo", 3)),
			"trocar uma receita do grupo por outra de custo diferente também é recusado")
	_check(book.add(_group_recipe("solta", "", 5)) and book.add(_group_recipe("outro", "outro_grupo", 3)),
			"receita sem grupo ou de outro grupo não é afetada")
	var shipped := true
	var shipped_book := RecipeBook.with_defaults()
	for recipe in shipped_book.all():
		shipped = shipped and shipped_book.group_of(recipe).all(func(member: RecipeDef) -> bool: return member.saber_cost == recipe.saber_cost)
	_check(shipped, "as receitas do jogo respeitam a regra")


func _group_recipe(recipe_id: String, group: String, cost: int) -> RecipeDef:
	var recipe := RecipeDef.new()
	recipe.id = recipe_id
	recipe.inputs = {Items.WOOD: 1}
	recipe.output_id = Items.FIBER
	recipe.saber_cost = cost
	recipe.learn_group = group
	return recipe


## Bloco de progressão com `version` maior que a conhecida: o save é recusado inteiro (como inventário, barra e equipamento).
func _test_future_progression_version() -> void:
	var player := _player_at(Vector2.ZERO)
	player.progression.grant_xp(1000)
	var saved := player.to_dict()
	var future: Dictionary = saved.duplicate(true)
	(future["progression"] as Dictionary)["version"] = ProgressionComponent.FORMAT_VERSION + 1
	var target := _player_at(Vector2.ZERO)
	_check(not target.from_dict(future) and target.progression.level == 1,
			"progressão de versão futura: o save é recusado e nada muda")
	var invalid: Dictionary = saved.duplicate(true)
	(invalid["progression"] as Dictionary)["version"] = "x"
	_check(not target.from_dict(invalid) and target.progression.level == 1, "versão inválida da progressão também é recusada")
	_check(target.from_dict(saved) and target.progression.level == player.progression.level, "a versão conhecida carrega")


## Jogador ligado a uma autoridade, com os avisos do dono guardados em `events`.
func _setup() -> Dictionary:
	var player := _player_at(Vector2.ZERO)
	var authority := TestWorld.arm(player, [], _track)
	var world := {"player": player, "authority": authority, "id": authority.id_of(player), "events": [] as Array[String]}
	authority.owner_event.connect(func(_owner: String, code: String, _params: Dictionary) -> void:
		(world["events"] as Array[String]).append(code))
	return world


## Dá ao jogador exatamente o Saber de `level` (XP da curva até lá).
func _to_level(player: Player, level: int) -> void:
	player.progression.grant_xp(RULES.xp_total_to_reach(level))


func _test_recipe_data() -> void:
	var book := RecipeBook.with_defaults()
	var all_valid := true
	var known_ids: Array[String] = []
	var learnable_ids: Array[String] = []
	for recipe in book.all():
		all_valid = all_valid and recipe.is_valid()
		(known_ids if recipe.is_known_at_start() else learnable_ids).append(recipe.id)
	_check(book.all().size() == 17 and all_valid, "17 receitas em dado, todas válidas contra o catálogo de itens")
	_check(known_ids == KNOWN and learnable_ids == LEARNABLE, "8 conhecidas e 9 aprendidas, com os ids estáveis")
	var learned: Array[String] = []
	learned.assign(LEARNABLE)
	_check(book.cost_of(learned) == 7, "as 9 aprendidas custam 7 Saber (o abrigo de 3 receitas conta 1 só)")
	var benches: Array[String] = []
	for recipe in book.all():
		if recipe.station == RecipeDef.STATION_WORKBENCH:
			benches.append(recipe.id)
	_check(benches == ["bed", "ration_c", "ration_b", "ration_a"], "as receitas de Bancada são a Cama e as Rações C, B e A")
	_check(book.find("foundation").learn_group == "shelter" and book.find("wall").learn_group == "shelter"
			and book.find("door").learn_group == "shelter" and book.find("ration_b").inputs == {Items.BERRY: 2, Items.TUBER: 1}
			and book.find("bed").inputs == {Items.FIBER: 12, Items.WOOD: 8} and book.find("sleeping_bag").inputs == {Items.FIBER: 8},
			"números de receitas.md e GDD 8: abrigo em grupo, Ração B, Cama e Saco")
	var by_cost := book.by_cost()
	_check(by_cost[0].saber_cost == 0 and by_cost[by_cost.size() - 1].saber_cost == 1, "a lista plana sai ordenada por custo")


func _test_learn_without_saber() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var result := authority.request_learn_recipe(world["id"], "workbench")
	_check(result == Enums.ActionResult.REFUSED and player.progression.learned.is_empty() and player.progression.saber_spent == 0
			and "recipe_learned" not in world["events"], "aprender sem Saber: recusado e nada muda")
	var crafted := authority.crafting.begin_craft(world["id"], "workbench")
	_check(crafted["result"] == Enums.ActionResult.REFUSED and crafted["reason"] == "recipe_locked",
			"e a Bancada segue travada para fabricar, pelo motivo `recipe_locked`")
	_check(GameMessages.reason_text("no_saber") != "" and GameMessages.reason_text("recipe_already_learned") != "", "os motivos têm texto")


func _test_learn_workbench_with_one_saber() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_to_level(player, 2)
	_check(player.progression.saber_free() == 1, "nível 2: 1 Saber livre")
	_check(authority.request_learn_recipe(world["id"], "workbench") == RESULT_OK and player.progression.learned == ["workbench"]
			and player.progression.saber_free() == 0 and player.progression.saber_spent == 1, "aprender a Bancada com 1 Saber")
	_check(world["events"].has("recipe_learned") and GameMessages.EVENTS.has("recipe_learned"), "o log recebe `recipe_learned`")
	player.inventory.add(Items.WOOD, 8)
	player.inventory.add(Items.STONE, 2)
	_check(authority.request_craft(world["id"], "workbench") == RESULT_OK, "depois de aprendida, a Bancada pode ser fabricada")


func _test_learn_twice_and_bad_requests() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_to_level(player, 6)
	var id: int = world["id"]
	_check(authority.request_learn_recipe(id, "workbench") == RESULT_OK, "primeira vez aprende")
	_check(authority.request_learn_recipe(id, "workbench") == Enums.ActionResult.WRONG_STATE and player.progression.saber_spent == 1,
			"aprender duas vezes: recusa e não cobra de novo")
	_check(authority.request_learn_recipe(id, "nao_existe") == Enums.ActionResult.INVALID_ARGUMENT
			and authority.request_learn_recipe(id, "") == Enums.ActionResult.INVALID_ARGUMENT
			and authority.request_learn_recipe(id, "x".repeat(500)) == Enums.ActionResult.INVALID_ARGUMENT,
			"receita inexistente, vazia ou com id gigante: pedido inválido")
	_check(authority.request_learn_recipe(id, "axe_stone") == Enums.ActionResult.WRONG_STATE and player.progression.saber_spent == 1
			and not player.progression.learned.has("axe_stone"), "receita conhecida de início não é aprendível")
	_check(player.progression.saber_free() == 6, "nada disso gastou Saber")


func _test_client_without_authority() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_to_level(player, 6)
	_check(authority.request_learn_recipe(9999, "workbench") == Enums.ActionResult.UNKNOWN_ACTOR and player.progression.learned.is_empty(),
			"ator que a autoridade não conhece não aprende")
	var panel := RecipesPanel.new()
	_track.call(panel)
	panel.player = player
	panel.recipe_book = authority.crafting.recipe_book
	_root.add_child(panel)
	var asked: Array[String] = []
	panel.learn_requested.connect(func(recipe_id: String) -> void: asked.append(recipe_id))
	panel.set_open(true)
	panel.learn_requested.emit("bed")  # o clique só vira sinal: sem a `Main` ligando a autoridade, nada muda
	_check(asked == ["bed"] and player.progression.learned.is_empty() and player.progression.saber_free() == 7,
			"o cliente não aprende por conta própria: o pedido é só um sinal")
	TestWorld.kill(player)
	var dead_result := authority.request_learn_recipe(world["id"], "workbench")
	_check(dead_result != RESULT_OK and player.progression.learned.is_empty(), "jogador caído ou morto não aprende")


func _test_spent_is_derived() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var progression := player.progression
	_to_level(player, 6)
	authority.request_learn_recipe(world["id"], "wall")  # ensina o grupo todo, 1 Saber
	_check(progression.learned == ["foundation", "wall", "door"] and progression.saber_spent == 1 and progression.saber_free() == 6,
			"aprender uma peça do abrigo ensina as 3 e cobra 1 Saber")
	authority.request_learn_recipe(world["id"], "bed")
	_check(progression.saber_spent == 2, "gasto = soma das receitas aprendidas")
	progression.learned.erase("bed")  # o gasto não é guardado: some junto com a receita
	_check(progression.saber_spent == 1 and progression.saber_free() == 6, "o gasto acompanha a lista: não existe guardado à parte")
	_check(not progression.to_dict().has("saber_spent"), "o save não guarda o gasto, só as receitas")


func _test_save_roundtrip() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	_to_level(player, 6)
	for recipe_id in ["workbench", "foundation", "ration_c"]:
		authority.request_learn_recipe(world["id"], recipe_id)
	var json := JSON.new()
	_check(json.parse(JSON.stringify(player.to_dict())) == OK, "o jogador com receitas vira JSON")
	var fresh := _player_at(Vector2.ZERO)
	var heard: Array[String] = []
	fresh.progression.recipe_learned.connect(func(recipe_id: String) -> void: heard.append(recipe_id))
	_check(fresh.from_dict(json.data) and fresh.progression.learned == player.progression.learned
			and fresh.progression.saber_spent == 3 and fresh.progression.saber_free() == 4, "receitas e Saber livre voltam do save")
	_check(heard.is_empty(), "carregar não dispara `recipe_learned`")
	_check(JSON.stringify(fresh.to_dict()) == JSON.stringify(player.to_dict()), "roundtrip idêntico")


func _test_migration() -> void:
	var player := _player_at(Vector2.ZERO)
	var base := player.to_dict()
	var old := base.duplicate(true)
	old["progression"] = {"version": 1, "level": 6, "xp": 0, "saber_spent": 5}  # E6: guardava o gasto, sem receitas
	_check(player.from_dict(old) and player.progression.learned.is_empty() and player.progression.saber_spent == 0
			and player.progression.saber_free() == 7, "save antigo com `saber_spent` e sem receitas: 0 gasto, 7 Saber livres")
	var over := base.duplicate(true)  # receitas que o Saber do nível não cobre
	over["progression"] = {"version": 2, "level": 2, "xp": 0, "recipes": ["workbench", "bed", "ration_c", "foundation"]}
	_check(player.from_dict(over) and player.progression.learned == ["workbench"] and player.progression.saber_spent == 1,
			"receitas acima do Saber do nível são descartadas (1 Saber cobre só a primeira)")
	var group := base.duplicate(true)
	group["progression"] = {"version": 2, "level": 2, "xp": 0, "recipes": ["door"]}
	_check(player.from_dict(group) and player.progression.learned == ["foundation", "wall", "door"],
			"receita de grupo salva sozinha volta com o grupo, pagando uma vez")
	var reload := _player_at(Vector2.ZERO)  # recarregar na mesma sessão: o save manda, não o que já estava aprendido
	reload.progression.grant_xp(RULES.xp_total_to_reach(6))
	reload.progression.learn("bed")
	var empty_save := base.duplicate(true)
	empty_save["progression"] = {"version": 2, "level": 6, "xp": 0, "recipes": []}
	reload.from_dict(empty_save)
	_check(reload.progression.learned.is_empty(), "carregar substitui as receitas aprendidas")


func _test_hostile_save() -> void:
	var player := _player_at(Vector2.ZERO)
	var base := player.to_dict()
	var huge: Array = []
	for index in 100000:
		huge.append("ration_c" if index % 2 == 0 else index)
	var cases := {
		"bloco em texto": "lixo",
		"receitas em texto": {"level": 6, "recipes": "workbench"},
		"receitas em dicionário": {"level": 6, "recipes": {"workbench": true}},
		"tipos errados": {"level": 6, "recipes": [1, 2.5, null, [], {}, true, NAN, INF]},
		"ids falsos, gigantes e conhecidas": {"level": 6,
				"recipes": ["", "x".repeat(10000), "../../etc", "axe_stone", "wooden_spear", "nao_existe"]},
		"duplicadas": {"level": 6, "recipes": ["workbench", "workbench", "workbench", "workbench"]},
		"lista gigante": {"level": 6, "recipes": huge},
		"nível 1 com tudo": {"level": 1, "recipes": LEARNABLE},
		"saber_spent hostil": {"level": 6, "saber_spent": INF, "recipes": ["bed"]},
	}
	for label: String in cases:
		var data := base.duplicate(true)
		data["progression"] = cases[label]
		var applied := player.from_dict(data)
		var progression := player.progression
		var unique := {}
		for recipe_id in progression.learned:
			unique[recipe_id] = true
		_check(applied and progression.saber_spent <= progression.saber_total() and progression.saber_free() >= 0
				and unique.size() == progression.learned.size() and progression.learned.size() <= LEARNABLE.size(),
				"dado hostil (%s): limitado, sem abortar, sem passar do Saber" % label)
	var data := base.duplicate(true)
	data["progression"] = cases["ids falsos, gigantes e conhecidas"]
	player.from_dict(data)
	_check(player.progression.learned.is_empty(), "id falso ou de receita conhecida de início nunca entra na lista")
	data["progression"] = cases["nível 1 com tudo"]
	player.from_dict(data)
	_check(player.progression.learned.is_empty(), "sem Saber, nenhuma receita sobrevive ao save")


func _test_level_six_learns_everything() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var progression := player.progression
	_to_level(player, 6)
	_check(progression.level == 6 and progression.saber_total() == 7 and progression.saber_free() == 7, "o nível 6 tem 7 Saber")
	var results: Array[Enums.ActionResult] = []
	for recipe_id in LEARNABLE:
		if progression.learned.has(recipe_id):
			continue  # o abrigo vem junto: aprender a fundação já ensinou a parede e a porta
		results.append(authority.request_learn_recipe(world["id"], recipe_id))
	var ok := true
	for outcome in results:
		ok = ok and outcome == RESULT_OK
	_check(ok and results.size() == 7, "no L6 as 9 receitas aprendíveis (7 aprendizados, o abrigo vem junto) são aprendidas")
	var knows_all := true
	for recipe in authority.crafting.recipe_book.all():
		knows_all = knows_all and progression.knows(recipe)
	_check(knows_all and progression.saber_free() == 0 and progression.saber_spent == 7 and progression.learned.size() == 9,
			"conhece as 17 e o Saber fecha em zero")
	_check(world["events"].count("recipe_learned") == 7, "cada aprendizado foi ao log")


func _test_status_and_panel() -> void:
	var world := _setup()
	var player: Player = world["player"]
	var authority: WorldAuthority = world["authority"]
	var book := authority.crafting.recipe_book
	var bench := book.find("workbench")
	var progression := player.progression
	_check(RecipeStatus.of(bench, progression) == RecipeStatus.State.LOCKED and RecipeStatus.saber_missing(bench, progression) == 1
			and RecipeStatus.label(bench, progression).contains("faltam 1 Saber"), "sem Saber a receita está travada e diz o que falta")
	_check(RecipeStatus.of(book.find("axe_stone"), player.progression) == RecipeStatus.State.KNOWN, "a de início está conhecida")
	_to_level(player, 2)
	_check(RecipeStatus.of(bench, progression) == RecipeStatus.State.LEARNABLE and RecipeStatus.label(bench, progression).contains("Aprender"),
			"com Saber a receita fica aprendível")
	var panel := RecipesPanel.new()
	_track.call(panel)
	panel.player = player
	panel.recipe_book = book
	_root.add_child(panel)
	panel.set_open(true)
	_check(panel.visible and panel._list.get_child_count() == 17, "a aba lista as 17 receitas, em lista plana")
	var texts: Array[String] = []
	var enabled := 0
	var buttons := 0
	for row in panel._list.get_children():
		texts.append((row.get_child(0) as Label).text)
		for child in row.get_children():
			if child is Button:
				buttons += 1
				enabled += 0 if (child as Button).disabled else 1
	_check(buttons == 9 and enabled == 9, "9 botões Aprender, todos habilitados com Saber (uma só gasta)")
	player.progression.level = 1
	player.progression.xp = 0
	panel.set_open(false)
	panel.set_open(true)
	var locked_text := ""
	for row in panel._list.get_children():
		var label := (row.get_child(0) as Label).text
		if label.begins_with("Bancada comum"):
			locked_text = label
	_check(locked_text.contains("Travada") and locked_text.contains("Madeira x8") and locked_text.contains("custa 1"),
			"a receita travada mostra material, custo e o que falta no painel")
	RecipesPanel.ensure_action()
	_check(InputMap.has_action(RecipesPanel.RECIPES_PANEL), "a tecla P é criada por código")
