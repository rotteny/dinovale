# SPDX-License-Identifier: MIT
extends SceneTree
## Testes da lógica, sem janela nem GPU:
##   godot --headless --path . --script res://tests/run_tests.gd

var _checks := 0
var _failures := 0
var _nodes: Array[Node] = []
var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# Nenhum teste grava em user://saves: tudo vai para uma pasta descartável.
	GameSession.save_root = SaveTests.root_dir
	SaveTests.remove_tree(SaveTests.base_dir)
	DinoStateTests.new(root, _track, _check).run()
	PlayerTamingTests.new(root, _track, _check).run()
	InventoryInteractionTests.new(root, _track, _check).run()
	await InteractionUiTests.new(root, _track, _check).run()
	DinoLevelTests.new(root, _track, _check).run()
	DinoReviewTests.new(root, _track, _check).run()
	HudHotbarTests.new(root, _track, _check).run()
	InventoryModelTests.new(root, _track, _check).run()
	EquipmentFlowTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await MenuTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await SaveTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await RespawnResourceTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await WorldTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await WildPersistenceTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await WorldGuardTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await RoundCTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await RoundCReviewTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await ScreenCameraTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await IntegrationTests.new(root, _track, _check).run()
	# Por último: é o mais longo (a física anda em tempo real) e os dinos soltos dos testes anteriores
	# passeiam enquanto ele espera quadros; antes do `_test_full_taming_integration` eles invadiriam a mira.
	_free_tracked_nodes()
	await AuthorityTests.new(root, _track, _check).run()
	_free_tracked_nodes()
	await NetFlowTests.new(root, _track, _check).run()
	GameSession.save_root = GameSession.DEFAULT_SAVE_ROOT
	SaveTests.remove_tree(SaveTests.base_dir)
	_free_tracked_nodes()
	print("%d verificações, %d falhas, %d erros de script" % [_checks, _failures, _errors.count])
	quit(1 if _failures > 0 or _errors.count > 0 else 0)


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
		printerr("FALHOU: ", label)


func _track(node: Node) -> Node:
	_nodes.append(node)
	return node
