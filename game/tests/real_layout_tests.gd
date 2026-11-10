# SPDX-License-Identifier: MIT
class_name RealLayoutTests
extends TestSuite
## As suítes de caído, corpo e predação rodam no `run_tests.gd` com o layout antigo de 12 slots (precisam de espaço). Aqui elas
## rodam de novo com o dado REAL do jogo (4 slots e cinto de 4), que é o que o jogador tem: a revisão da E11a pediu isso.

const REAL_RULES: SlotRules = preload("res://data/balance/slot_rules.tres")


func run() -> void:
	var before := Items.slots
	Items.slots = REAL_RULES  # `with_layout` não serve aqui: as suítes esperam quadros (await) e o layout tem de durar até o fim
	for suite: Variant in [DownedTests.new(_root, _track, _check_fn), PredationTests.new(_root, _track, _check_fn),
			PredationTamedTests.new(_root, _track, _check_fn)]:
		await suite.run()
	Items.slots = before
