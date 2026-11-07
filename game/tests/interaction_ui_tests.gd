# SPDX-License-Identifier: MIT
class_name InteractionUiTests
extends TestSuite
## Tela de inventário, HUD reagindo a sinais e barras de estado do dino.


func run() -> void:
	await _test_target_is_nearest()
	_test_screen_closes_when_dino_wakes()
	_test_screen_closes_when_tamed()
	_test_screen_closes_when_dino_removed()
	_test_hud_reacts_to_signals()
	_test_dino_status_bars()


## Dois dinos reais, detecção por física: o mais próximo vira alvo.
func _test_target_is_nearest() -> void:
	var player := _spawn_player()
	var far := _spawn_dino()
	var near := _spawn_dino()
	for dino in [far, near]:
		dino.set_physics_process(false)
		dino.torpor.add_torpor(dino.torpor.max_torpor)  # só o desmaiado oferece ação: é ele que disputa o alvo
	player.global_position = Vector2(5000, 5000)
	far.global_position = player.global_position + Vector2(30, 0)
	near.global_position = player.global_position + Vector2(-12, 0)
	var seen: Array[InteractableArea] = []
	player.target_changed.connect(func(t: InteractableArea) -> void: seen.append(t))
	for i in 4:
		await _root.get_tree().physics_frame
	player.tick(0.0)
	_check(player.target == near.interactable, "alvo é o interagível mais próximo")
	near.global_position = player.global_position + Vector2(200, 0)
	for i in 4:
		await _root.get_tree().physics_frame
	player.tick(0.0)
	_check(player.target == far.interactable, "o outro assume quando o primeiro sai do alcance")
	far.global_position = player.global_position + Vector2(300, 0)
	for i in 4:
		await _root.get_tree().physics_frame
	player.tick(0.0)
	_check(player.target == null and seen.back() == null, "sem ninguém no alcance, sem alvo")


# --- UI ---


func _spawn_screen(player: Player) -> InventoryScreen:
	var screen := InventoryScreen.new()
	screen.player_inventory = player.inventory
	_root.add_child(screen)
	_track.call(screen)
	return screen


func _test_screen_closes_when_dino_wakes() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.torpor.add_torpor(100.0)
	var screen := _spawn_screen(player)
	var closed := [0]
	screen.closed.connect(func() -> void: closed[0] += 1)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	_check(screen.is_open and screen.visible, "tela abre")
	_check(screen.slot_button(true, 0) != null and screen.slot_button(false, 7) != null
			and screen.slot_button(false, 8) == null, "grade tem um botão por slot")
	dino.torpor.tick(1000.0)
	_check(not screen.is_open and not screen.visible and closed[0] == 1, "acordar fecha o painel")
	screen.close()
	_check(closed[0] == 1, "fechar duas vezes não repete o sinal")
	var own_hits := [0]
	player.inventory.changed.connect(func() -> void: own_hits[0] += 1)
	player.inventory.add("berry", 1)
	_check(own_hits[0] == 1, "fechada, a tela não se pendura nos sinais")
	screen.open_own()
	_check(screen.is_open and not screen.slot_button(false, 0), "inventário próprio abre sozinho")
	screen.close()


func _test_screen_closes_when_tamed() -> void:
	var player := _spawn_player()
	var dino := _make_sleeping_dino(0)
	var screen := _spawn_screen(player)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	dino.state_machine.mark_tamed()
	_check(not screen.is_open, "domesticar fecha o painel")


func _test_screen_closes_when_dino_removed() -> void:
	var player := _spawn_player()
	var dino := _make_sleeping_dino(0)
	var screen := _spawn_screen(player)
	screen.open_with(player.inventory, dino.inventory, dino.interactable, "Criatura")
	_root.remove_child(dino)
	_check(not screen.is_open, "dino removido da árvore fecha o painel")
	dino.free()


func _test_hud_reacts_to_signals() -> void:
	var player := _spawn_player()
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.health_bar().value() == 100.0 and hud.hunger_bar().max_value() == 100.0, "HUD começa com os valores do jogador")
	player.health.take_damage(30.0)
	player.hunger.eat(0.0)
	_check(hud.health_bar().value() == 70.0, "barra de vida acompanha")
	player.hunger.tick(10.0)
	_check(hud.hunger_bar().value() == player.hunger.current_hunger, "barra de fome acompanha")
	_check(not hud.prompt_label().visible, "sem alvo: sem prompt")
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	player.target = dino.interactable
	player.target_changed.emit(dino.interactable)
	_check(not hud.prompt_label().visible, "criatura acordada: sem prompt")
	dino.torpor.add_torpor(100.0)
	_check(hud.prompt_label().visible and hud.prompt_label().text == "E para interagir", "inconsciente: prompt aparece")
	player.input_locked = true
	_check(not hud.prompt_label().visible, "tela aberta esconde o prompt")
	player.input_locked = false
	player.target = null
	player.target_changed.emit(null)
	_check(not hud.prompt_label().visible, "perder o alvo esconde o prompt")


func _spawn_bars(dino: Dino) -> DinoStatusBars:
	var bars := DinoStatusBars.new()
	bars.dino = dino
	_root.add_child(bars)
	_track.call(bars)
	return bars


func _test_dino_status_bars() -> void:
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var bars := _spawn_bars(dino)
	_check(not bars.visible, "dino acordado: nenhuma barra")
	dino.torpor.add_torpor(100.0)
	_check(bars.visible and bars.torpor_bar().visible and bars.taming_bar().visible, "dormindo: torpor e domesticação")
	_check(bars.torpor_bar().value() == 100.0, "barra de torpor reflete o valor")
	dino.inventory.add("berry", 5)
	dino.taming.tick(5.0)
	_check(is_equal_approx(bars.taming_bar().value(), 20.0), "barra de domesticação reflete o progresso")
	dino.global_position = Vector2(500, 40)
	bars.follow()
	_check(bars.global_position == Vector2(500, 40), "acompanha a posição do dino")
	var far := _spawn_player()
	far.global_position = Vector2(-5000, -5000)
	_check(bars.visible, "visível a qualquer distância do jogador")
	dino.torpor.reduce_torpor(100.0)
	_check(not dino.torpor.is_unconscious and not bars.visible, "acordou: nenhuma barra")
	_check(bars.torpor_bar().value() == 0.0, "barra de torpor zera ao acordar")
	var tamed := _make_sleeping_dino(10)
	var tamed_bars := _spawn_bars(tamed)
	_check(tamed_bars.visible and tamed_bars.taming_bar().visible, "barras criadas depois: refletem o estado")
	for i in 60:
		tamed.taming.tick(1.0)
		if tamed.state_machine.is_tamed:
			break
	_check(tamed.state_machine.is_tamed, "dino domesticado no teste")
	_check(not tamed_bars.visible, "domesticado acordado: nenhuma barra")
	tamed.torpor.add_torpor(tamed.torpor.max_torpor)
	_check(tamed.torpor.is_unconscious and tamed_bars.visible, "domesticado desmaiado: barras aparecem")
	_check(tamed_bars.torpor_bar().visible and not tamed_bars.taming_bar().visible,
			"domesticado desmaiado: só torpor")
	# Restaurar save: a barra reflete o estado restaurado, sem evento de jogo.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_make_sleeping_dino(0).to_dict()))
	var restored := _spawn_dino()
	restored.set_physics_process(false)
	var restored_bars := _spawn_bars(restored)
	restored.from_dict(saved)
	_check(restored_bars.visible and restored_bars.taming_bar().visible
			and restored_bars.torpor_bar().value() == 100.0, "from_dict de dormindo: barras visíveis")
	var awake: Dictionary = JSON.parse_string(JSON.stringify(_spawn_dino().to_dict()))
	restored.from_dict(awake)
	_check(not restored_bars.visible, "from_dict de acordado: barras escondidas")
	var tamed_save: Dictionary = JSON.parse_string(JSON.stringify(tamed.to_dict()))
	restored.from_dict(tamed_save)
	_check(restored_bars.visible and restored_bars.torpor_bar().visible and not restored_bars.taming_bar().visible,
			"from_dict de domesticado desmaiado: só torpor")
