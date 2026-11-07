# SPDX-License-Identifier: MIT
class_name IntegrationTests
extends TestSuite
## Domesticação de ponta a ponta no mundo e tabela de roundtrip dos `Saveable`.

const SaveableTable := preload("res://tests/saveable_table.gd")


func run() -> void:
	await _test_full_taming_integration()
	_test_saveable_roundtrip_table()


## Ponta a ponta sem teclado, na Main real: derruba, transfere, avança o tempo e domestica.
func _test_full_taming_integration() -> void:
	var main: Main = load("res://src/world/Main.tscn").instantiate()
	_root.add_child(main)
	_track.call(main)
	main.wild.free()  # os selvagens do mapa não entram nesta conta (a mira pegaria o mais perto)
	var player: Player = main.player
	var screen: InventoryScreen = main.screen
	var dino: Dino = main.get_node("Dino")
	var hud: PlayerHud = main.get_node("UI/PlayerHud")
	# Tempo manual e determinístico: o relógio real não mexe no dino nem no jogador.
	for node: Node in [dino, dino.torpor, dino.taming, dino.state_machine, player, player.hunger, player.stamina]:
		node.set_physics_process(false)
	var starting_total := player.inventory.count("berry") + player.inventory.count("meat") \
			+ player.inventory.count("fern")
	dino.global_position = player.global_position + Vector2(30, 0)
	main.zone.reclassify()  # a zona só reavalia de tempos em tempos: o teste moveu o dino de propósito
	for i in 4:
		await _root.get_tree().physics_frame
	player.tick(0.0)
	_check(player.target == null, "dino acordado no alcance não é alvo (não há ação a oferecer)")
	_check(not player.try_interact() and not screen.is_open, "dino acordado: E não abre nada")
	_check(dino.level == 20 and main.dino_level == 20, "a Main fixa o nível do dino")
	_check(player.request_use_item(3) and player.current_weapon().id == "sleep_staff", "tecla 4 põe o Bastão em mãos")
	for i in 12:
		player.attack()
		player.tick(0.7)
		dino.torpor.tick(0.7)
		if dino.torpor.is_unconscious:
			break
	_check(dino.torpor.is_unconscious, "golpes do bastão derrubam o dino")
	player.tick(0.0)
	_check(player.target == dino.interactable, "jogador detecta o dino desmaiado no alcance")
	_check(dino.health.current_health < dino.health.max_health, "os golpes tiraram um pouco de vida")
	_check(hud.prompt_label().visible, "prompt aparece com o dino inconsciente")
	_check(player.try_interact() and screen.is_open and player.input_locked, "E abre a tela e trava o jogador")
	var before := player.global_position
	player.velocity = player.apply_input(Vector2.RIGHT, false, 0.1) * 0.0
	_check(player.input_locked, "jogador segue travado com a tela aberta")
	var button := screen.slot_button(true, 0)
	_check("Baga" in screen.slot_text(true, 0).split("\n")[0], "slot 0 do jogador mostra a baga")
	button.pressed.emit()
	_check(dino.inventory.count("berry") == 10 and player.inventory.count("berry") == 0, "clique transferiu as bagas")
	for i in 40:
		dino.torpor.tick(1.0)
		dino.taming.tick(1.0)
		if dino.state_machine.is_tamed:
			break
	_check(dino.state_machine.current_id == Enums.DinoStateId.TAMED, "dino chegou a TAMED")
	_check(is_equal_approx(dino.taming.taming_progress, 100.0), "progresso em 100%")
	# Pelo caminho da autoridade: quem depositou a comida ideal é o candidato e, ao fim, o dono.
	_check(dino.owner_player_id == player.player_id and dino.feeder_player_id == player.player_id,
			"domesticou pela Main: o jogador que alimentou é o dono")
	_check(dino.level == 28, "nível final 28 (20 com Eficiência 79%%: %d)" % dino.level)
	_check(not screen.is_open and not player.input_locked, "domesticar fechou a tela e liberou o jogador")
	var bars: DinoStatusBars = main.get_node("DinoStatusBars")
	_check(not bars.health_bar_visible() and (main.get_node("DinoMarker") as DinoMarker).is_marked(), "domado: a vida fica na placa")
	bars.tick(DinoStatusBars.HEALTH_VISIBLE_SECONDS + 0.1)
	_check(not bars.visible, "domesticado, acordado e sem dano recente: sem barras sobre ele")
	_check(not hud.prompt_label().visible, "sem prompt para domesticado")
	var total := 0
	for inv: InventoryComponent in [player.inventory, dino.inventory]:
		total += inv.count("meat") + inv.count("fern") + inv.count("berry")
	_check(total + 6 == starting_total, "conservação: o que sumiu foi só o consumido (6 bagas no nível 20)")
	_check(player.global_position == before, "jogador não se moveu")


## Todo saveable da tabela volta idêntico depois do JSON. A cobertura da tabela
## (nenhum `to_dict` esquecido) é do tools/checks.d/10-arquitetura.sh.
func _test_saveable_roundtrip_table() -> void:
	var table := SaveableTable.new(_root, _track)
	for script_path in SaveableTable.SCRIPTS:
		var pair := table.build(script_path)
		_check(pair.size() == 2, "saveable tem caso na tabela: %s" % script_path)
		if pair.size() != 2:
			continue
		var original: Object = pair[0]
		var restored: Object = pair[1]
		var expected: Dictionary = original.to_dict()
		_check(restored.to_dict() != expected, "caso exercita estado fora do padrão: %s" % script_path)
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(expected))
		restored.from_dict(parsed)
		_check(restored.to_dict() == expected, "roundtrip por JSON idêntico: %s" % script_path)
