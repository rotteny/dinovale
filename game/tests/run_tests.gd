# SPDX-License-Identifier: MIT
extends SceneTree
## Testes da lógica, sem janela nem GPU:
##   godot --headless --path . --script res://tests/run_tests.gd [-- --suite=<nome>]
## Com `--suite=<nome>` (ex.: `ServerRules` ou `ServerRulesTests`) roda só essa suíte.

## Semente dos mundos novos dos testes (um teste que quer outra a fixa em `Main.world_seed`).
const TEST_WORLD_SEED := 424242
## Layout de inventário das suítes anteriores à E11a (12 slots, sem cinto): elas testam outras regras e precisam de espaço.
## O jogo usa 4 slots e cinto de 4 (`slot_rules.tres`); a `SlotTests` roda com o dado real e confere que ele vale isso.
const LEGACY_SLOTS := 12
const LEGACY_BELT := 0

var _checks := 0
var _failures := 0
var _nodes: Array[Node] = []
var _errors := ErrorCounter.new()
var _current_suite := ""


func _initialize() -> void:
	OS.add_logger(_errors)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# Nenhum teste grava em user://saves: tudo vai para uma pasta descartável.
	GameSession.save_root = SaveTests.root_dir
	GameSession.world_seed_override = TEST_WORLD_SEED  # mundo reproduzível: os ids dos selvagens são os mesmos em toda execução
	var legacy_layout := SlotRules.new()
	legacy_layout.player_slots = LEGACY_SLOTS
	legacy_layout.belt_slots = LEGACY_BELT
	Items.slots = legacy_layout
	SaveTests.remove_tree(SaveTests.base_dir)
	var selected := _selected_suite()
	var timings: Array = []
	for entry: Array in _suites():
		var suite_name: String = entry[0]
		if not selected.is_empty() and selected != suite_name and selected + "Tests" != suite_name:
			continue
		_current_suite = suite_name
		var started := Time.get_ticks_msec()
		await entry[1].call(root, _track, _check).run()
		timings.append([suite_name, Time.get_ticks_msec() - started])
		if entry[2]:
			_free_tracked_nodes()
	_current_suite = ""
	if not selected.is_empty() and timings.is_empty():
		printerr("FALHOU: suíte desconhecida: ", selected)
		_failures += 1
	_print_timings(timings)
	GameSession.save_root = GameSession.DEFAULT_SAVE_ROOT
	SaveTests.remove_tree(SaveTests.base_dir)
	_free_tracked_nodes()
	print("%d verificações, %d falhas, %d erros de script" % [_checks, _failures, _errors.count])
	quit(1 if _failures > 0 or _errors.count > 0 else 0)


## Cada suíte: nome, construtor e se os nós são liberados depois dela (as primeiras rodam em sequência, sem liberar).
func _suites() -> Array:
	return [
		["DinoStateTests", DinoStateTests.new, false],
		["PlayerTamingTests", PlayerTamingTests.new, false],
		["InventoryInteractionTests", InventoryInteractionTests.new, false],
		["InteractionUiTests", InteractionUiTests.new, false],
		["DinoLevelTests", DinoLevelTests.new, false],
		["DinoReviewTests", DinoReviewTests.new, false],
		["HudHotbarTests", HudHotbarTests.new, false],
		["PresentationTests", PresentationTests.new, false],
		["InventoryModelTests", InventoryModelTests.new, false],
		["EquipmentFlowTests", EquipmentFlowTests.new, true],
		["MenuTests", MenuTests.new, true],
		["SaveTests", SaveTests.new, true],
		["RespawnResourceTests", RespawnResourceTests.new, true],
		["WorldTests", WorldTests.new, true],
		["WorldPunchTests", WorldPunchTests.new, true],
		["GatherDamageTests", GatherDamageTests.new, true],
		["ServerRulesTests", ServerRulesTests.new, true],
		["UtahraptorTests", UtahraptorTests.new, true],
		["WildPersistenceTests", WildPersistenceTests.new, true],
		["SaveV5Tests", SaveV5Tests.new, true],
		["WildGroupsTests", WildGroupsTests.new, true],
		["DenWorldTests", DenWorldTests.new, true],
		["WorldGuardTests", WorldGuardTests.new, true],
		["RoundCTests", RoundCTests.new, true],
		["RoundCReviewTests", RoundCReviewTests.new, true],
		["ScreenCameraTests", ScreenCameraTests.new, true],
		["IntegrationTests", IntegrationTests.new, false],
		["AttackTargetTests", AttackTargetTests.new, true],
		["AuthorityTests", AuthorityTests.new, true],
		["MouseInventoryTests", MouseInventoryTests.new, true],
		["CrowdingTests", CrowdingTests.new, true],
		["HungerTests", HungerTests.new, true],
		["ProgressionTests", ProgressionTests.new, true],
		["MessageTests", MessageTests.new, true],
		["GroundItemTests", GroundItemTests.new, true],
		["ControlsTests", ControlsTests.new, true],
		["WeaponTests", WeaponTests.new, true],
		["TamingFeedTests", TamingFeedTests.new, true],
		["AreaAttackTests", AreaAttackTests.new, true],
		["NavigationTests", NavigationTests.new, true],
		["AggressionTests", AggressionTests.new, true],
		["ThreatTests", ThreatTests.new, true],
		["HerdTests", HerdTests.new, true],
		["PredationTests", PredationTests.new, true],
		["PredationTamedTests", PredationTamedTests.new, true],
		["DenAndVigilTests", DenAndVigilTests.new, true],
		["DayNightThreatTests", DayNightThreatTests.new, true],
		["DayCycleTests", DayCycleTests.new, true],
		["DownedTests", DownedTests.new, true],
		["M1ClosingTests", M1ClosingTests.new, true],
		["ClickCollectTests", ClickCollectTests.new, true],
		["CraftTests", CraftTests.new, true],
		["BuildTests", BuildTests.new, true],
		["BuildReviewTests", BuildReviewTests.new, true],
		["ChestTests", ChestTests.new, true],
		["CarryTests", CarryTests.new, true],
		["SlotTests", SlotTests.new, true],
		["CarcassTests", CarcassTests.new, true],
		["ShelterTests", ShelterTests.new, true],
		["WallLineTests", WallLineTests.new, true],
		["RecipeLearningTests", RecipeLearningTests.new, true],
		["NetFlowTests", NetFlowTests.new, false],
	]


func _selected_suite() -> String:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			return argument.trim_prefix("--suite=")
	return ""


## Tempo de cada suíte, da mais lenta para a mais rápida.
func _print_timings(timings: Array) -> void:
	timings.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	print("tempo por suíte (ms):")
	for timing: Array in timings:
		print("  %6d  %s" % [timing[1], timing[0]])


## Libera os nós que os testes deixaram na árvore (cada mundo na raiz custa física a cada quadro).
func _free_tracked_nodes() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		var where := " [suíte %s]" % _current_suite if not _current_suite.is_empty() else ""
		printerr("FALHOU: ", label, where)


func _track(node: Node) -> Node:
	_nodes.append(node)
	return node
