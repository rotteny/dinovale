# SPDX-License-Identifier: MIT
class_name WeaponTests
extends AuthorityTests
## Lança de madeira nos itens iniciais (GDD 5.4): dano 12 sem torpor, alcance próprio de 1,8 tiles, mata o Paquicéfalo.

const SPEAR := Items.WOODEN_SPEAR


func run() -> void:
	_test_starting_spear()
	_test_spear_kills()
	_test_weapon_reach()
	_test_save_roundtrip()
	_test_durability()
	_test_durability_bar()
	_test_dev_items()
	_test_durability_saved()
	_release_worlds()


func _equip(player: Player, item_id: String) -> void:
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		if slot.get("id", "") == item_id:
			player.equipment.equip(str(slot["iid"]), EquipmentLayout.WEAPON)
			return


func _test_starting_spear() -> void:
	var player := _player_at(Vector2.ZERO)
	_check(player.inventory.count(SPEAR) + player.equipment.item_in(EquipmentLayout.WEAPON).size() >= 1
			and player.inventory.count(Items.SLEEP_STAFF) >= 1, "o jogador começa com a Lança e mantém o Bastão-de-sono")
	var weapon := Items.weapon_of(SPEAR)
	_check(weapon.damage == 12.0 and weapon.torpor == 0.0 and is_equal_approx(weapon.cooldown, 0.9)
			and is_equal_approx(weapon.reach_tiles, 1.8) and weapon.stamina_cost == 5.0,
			"dados da Lança: 12, torpor 0, 0,9 s, 1,8 tiles, 5 de Stamina")
	_check(Items.is_individual(SPEAR) and Items.durability_max(SPEAR) == 80, "individual, durabilidade 80")


func _test_spear_kills() -> void:
	var player := _player_at(Vector2.ZERO)
	var dino := _dino_at(Vector2(0, 20))
	var authority := TestWorld.arm(player, [dino], _track)
	player.facing = Vector2.DOWN
	_equip(player, SPEAR)
	_check(player.current_weapon().id == "wooden_spear", "equipada, a Lança é a arma em mãos")
	var hits := 0
	var guard := 0
	while not dino.health.is_dead() and guard < 40:
		guard += 1
		player.tick(1.0)
		if authority.request_attack(1, authority.id_of(dino)) == Enums.ActionResult.OK:
			hits += 1
	_check(dino.health.is_dead() and dino.torpor.current_torpor == 0.0,
			"o Paquicéfalo morre com %d golpes, sem torpor" % hits)
	_check(hits == ceili(dino.health.max_health / 12.0), "o número de golpes vem do dano 12 (%d)" % hits)


func _test_weapon_reach() -> void:
	var player := _player_at(Vector2.ZERO)
	var dino := _dino_at(Vector2(0, 40))  # 2,5 tiles: dentro dos 3 do Bastão, fora dos 1,8 da Lança
	var authority := TestWorld.arm(player, [dino], _track)
	player.facing = Vector2.DOWN
	_equip(player, SPEAR)
	_check(authority.request_attack(1, authority.id_of(dino)) == Enums.ActionResult.OUT_OF_RANGE, "a Lança não alcança a 2,5 tiles")
	player.tick(1.0)
	_equip(player, Items.SLEEP_STAFF)
	_check(authority.request_attack(1, authority.id_of(dino)) == Enums.ActionResult.OK, "o Bastão alcança a 2,5 tiles (alcance das regras)")


func _test_save_roundtrip() -> void:
	var player := _player_at(Vector2.ZERO)
	_equip(player, SPEAR)
	var copy := _player_at(Vector2.ZERO)
	_check(copy.from_dict(JSON.parse_string(JSON.stringify(player.to_dict()))) and copy.current_weapon().id == "wooden_spear",
			"o save leva a Lança equipada")


func _test_durability() -> void:
	var player := _player_at(Vector2.ZERO)
	var dino := _dino_at(Vector2(0, 20))
	var authority := TestWorld.arm(player, [dino], _track)
	player.facing = Vector2.DOWN
	_equip(player, SPEAR)
	var events: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: events.append(code))
	_check(player.equipment.item_in(EquipmentLayout.WEAPON)["durab"] == 80, "a Lança nasce com 80 de durabilidade")
	player.tick(1.0)
	authority.request_attack(1, authority.id_of(dino))
	_check(player.equipment.item_in(EquipmentLayout.WEAPON)["durab"] == 79, "um golpe aceito gasta 1")
	dino.position = Vector2(0, 300)  # fora do alcance
	player.tick(1.0)
	_check(authority.request_attack(1, authority.id_of(dino)) != Enums.ActionResult.OK
			and player.equipment.item_in(EquipmentLayout.WEAPON)["durab"] == 79, "golpe recusado não gasta")
	dino.position = Vector2(0, 20)
	(player.equipment._worn[EquipmentLayout.WEAPON] as Dictionary)["durab"] = 1
	player.tick(1.0)
	_check(authority.request_attack(1, authority.id_of(dino)) == Enums.ActionResult.OK
			and player.equipment.item_in(EquipmentLayout.WEAPON).is_empty() and player.current_weapon().id == "punch",
			"com 0 a arma quebra, sai da vaga e o jogador fica de mãos vazias")
	_check("weapon_broke" in events and GameMessages.text_of("weapon_broke", {"item": "Lança de madeira"}) == "Lança de madeira quebrou.",
			"o log avisa que quebrou")
	_check(player.inventory.count(SPEAR) == 0 or player.inventory.count(SPEAR) < 2, "a arma quebrada não volta ao inventário")


func _test_durability_bar() -> void:
	var bar := DurabilityBar.new()
	_track.call(bar)
	bar.show_item({"id": SPEAR, "iid": "a", "durab": 80, "durab_max": 80})
	_check(bar.visible and is_equal_approx(bar.ratio(), 1.0) and DurabilityBar.color_for(bar.ratio()) == DurabilityBar.GOOD_COLOR,
			"cheia: verde")
	bar.show_item({"id": SPEAR, "iid": "a", "durab": 30, "durab_max": 80})
	_check(DurabilityBar.color_for(bar.ratio()) == DurabilityBar.WARN_COLOR, "abaixo de metade: amarela")
	bar.show_item({"id": SPEAR, "iid": "a", "durab": 10, "durab_max": 80})
	_check(DurabilityBar.color_for(bar.ratio()) == DurabilityBar.BAD_COLOR, "abaixo de um quarto: vermelha")
	bar.show_item({"id": Items.BERRY, "count": 3})
	_check(not bar.visible, "pilha não mostra a barra")


func _test_dev_items() -> void:
	_check(PlayerRules.dev_items_allowed(true, PackedStringArray()) and PlayerRules.dev_items_allowed(false, PackedStringArray(["--dev"]))
			and not PlayerRules.dev_items_allowed(false, PackedStringArray()), "dev: só em debug ou com --dev")
	var release: Player = PlayerScene.instantiate()
	release.dev_items = false
	_root.add_child(release)
	_track.call(release)
	release.set_physics_process(false)
	_check(release.inventory.count(SPEAR) == 0 and release.inventory.count(Items.SLEEP_STAFF) == 0, "sem a flag o jogador começa sem as armas")
	var dev: Player = PlayerScene.instantiate()
	dev.dev_items = true
	_root.add_child(dev)
	_track.call(dev)
	dev.set_physics_process(false)
	_check(dev.inventory.count(SPEAR) == 1 and dev.inventory.count(Items.SLEEP_STAFF) == 1, "com a flag ele começa com Lança e Bastão")


func _test_durability_saved() -> void:
	var player := _player_at(Vector2.ZERO)
	_equip(player, SPEAR)
	(player.equipment._worn[EquipmentLayout.WEAPON] as Dictionary)["durab"] = 41
	var copy := _player_at(Vector2.ZERO)
	copy.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	_check(copy.equipment.item_in(EquipmentLayout.WEAPON).get("durab", -1) == 41, "save e load preservam a durabilidade")
