# SPDX-License-Identifier: MIT
class_name MessageTests
extends AuthorityTests
## Log do sistema: códigos estáveis traduzidos num lugar, recusas com motivo legível, limite de linhas, esmaecer, painel que
## não rouba clique, dica do gesto certo nos nós de golpes.


func run() -> void:
	_test_every_code_has_text()
	_test_refusals_have_reasons()
	_test_log_limits_and_fade()
	_test_view_ignores_clicks()
	_test_hints()
	_release_worlds()


func _test_every_code_has_text() -> void:
	var ok := true
	for code: String in GameMessages.EVENTS:
		ok = ok and GameMessages.text_of(code, {"species": "X", "item": "Y", "amount": 1, "done": 1, "total": 2, "ideal": "Z",
				"order": "ficando", "reason": "r"}) != "" and not GameMessages.text_of(code, {}).is_empty()
	_check(ok, "todo código de evento tem texto")
	var every_result := true
	for result: int in Enums.ActionResult.values():
		if result == Enums.ActionResult.OK:
			continue
		every_result = every_result and GameMessages.reason_text(GameMessages.reason_for(result as Enums.ActionResult)) != ""
	_check(every_result, "todo ActionResult negado mapeia para um motivo legível")
	_check(GameMessages.reason_text("needs_tool", {"tool": "Picareta"}) == "Precisa de Picareta.", "o motivo leva a ferramenta")


func _test_refusals_have_reasons() -> void:
	var player := _player_at(Vector2.ZERO)
	var far := _dino_at(Vector2(500, 0))
	var authority := TestWorld.arm(player, [far], _track)
	var seen: Array[Dictionary] = []
	authority.game_event.connect(func(code: String, params: Dictionary) -> void: seen.append({"code": code, "params": params}))
	authority.request_attack(1, authority.id_of(far))
	_check(seen.back()["code"] == "action_refused" and seen.back()["params"]["reason"] == "out_of_range",
			"golpe longe: action_refused com out_of_range")
	_check(GameMessages.text_of("action_refused", seen.back()["params"]) == "Fora de alcance.", "e o texto diz 'Fora de alcance.'")


func _test_log_limits_and_fade() -> void:
	var messages := MessageLog.new()
	for i in messages.rules.history_max + 20:
		messages.push("linha %d" % i)
	_check(messages.history().size() == messages.rules.history_max, "o histórico tem teto")
	_check(messages.recent().size() <= messages.rules.visible_lines, "no canto só aparecem as últimas %d" % messages.rules.visible_lines)
	var one := MessageLog.new()
	one.push("a")
	var line := one.history()[0]
	_check(one.alpha_of(line) == 1.0, "recém-chegada: opaca")
	one.tick(one.rules.hold_seconds + one.rules.fade_seconds * 0.5)
	_check(is_equal_approx(one.alpha_of(line), 0.5), "esmaece depois do tempo dos dados")
	one.tick(one.rules.fade_seconds)
	_check(one.recent().is_empty(), "some do canto, segue no histórico")
	one.push("b")
	one.push("b")
	_check(one.history().size() == 2, "linha repetida seguida não empilha")


func _test_view_ignores_clicks() -> void:
	var view := MessageLogView.new()
	view.messages = MessageLog.new()
	_root.add_child(view)
	_track.call(view)
	_check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and not view.is_history_open(), "fechado, o painel ignora o mouse")
	view.set_history_open(true)
	_check(view.is_history_open(), "a tecla abre o histórico")
	view.set_history_open(false)
	var blockers := 0
	for child in view.find_children("*", "Control", true, false):
		if (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP and (child as Control).is_visible_in_tree():
			blockers += 1
	_check(blockers == 0, "fechado, nada no painel intercepta clique")


func _has_digit(text: String) -> bool:
	for index in text.length():
		if text[index] >= "0" and text[index] <= "9":
			return true
	return false


func _test_hints() -> void:
	var tree: ResourceNodeDef = load("res://data/resources/tree.tres")
	var rock: ResourceNodeDef = load("res://data/resources/rock.tres")
	var by_hand := ActionHints.for_resource(tree, 10.0)
	_check(by_hand["text"] == "[clique] Golpear árvore" and not by_hand["blocked"], "dica da árvore só com a ação: " + by_hand["text"])
	_check(not _has_digit(ActionHints.for_resource(tree, 20.0)["text"]), "a dica não mostra número de golpes")
	_check(ActionHints.for_resource(tree, 20.0, true)["blocked"], "no intervalo entre coletas a dica fica cinza")
	var stone := ActionHints.for_resource(rock, 0.0)
	_check(stone["blocked"] and stone["text"].contains("Picareta"), "rocha sem Picareta: dica cinza que diz a ferramenta")
