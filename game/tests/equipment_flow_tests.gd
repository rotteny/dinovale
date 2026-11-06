# SPDX-License-Identifier: MIT
class_name EquipmentFlowTests
extends DinoLevelTests
## Fluxo de equipar: migração do save real do HEAD, atalho automático do equipado, aviso na HUD,
## vagas que exigem o inventário e a tela compartilhada (duplo clique x transferir). Reaproveita os
## auxiliares de `DinoLevelTests`.

const STAFF := Items.SLEEP_STAFF

## Save de verdade do HEAD (gerado pelo `Player.to_dict` antes das vagas): `equipped` + Bastão na grade
## e na barra. A migração tira da grade, põe na vaga Arma e mantém o atalho.
const HEAD_SAVE := (
	'{"equipped":"p1","health":{"current":100.0,"max":100.0},"hotbar":{"slots":[{"id":"berry"},{"id":"meat"},{"id":"fern"},'
	+ '{"id":"sleep_staff","iid":"p1"},{},{},{},{},{}],"version":2},"hunger":{"current":99.5,"max":100.0,"starvation_timer":0.0},'
	+ '"inventory":{"next_iid":2,"slots":[{"count":13,"expira_em":0.0,"id":"berry"},{"count":4,"expira_em":0.0,"id":"meat"},'
	+ '{"count":3,"expira_em":0.0,"id":"fern"},{"durab":90,"durab_max":120,"id":"sleep_staff","iid":"p1"},{},{},{},{}],"version":2},'
	+ '"position":{"x":5.0,"y":6.0},"stamina":{"current":100.0,"is_exhausted":false,"max":100.0}}'
)


func run() -> void:
	_test_head_save_migration()
	_test_equip_hotbar_and_hud_notice()
	_test_non_text_iid()
	_test_equipment_requires_inventory()
	_test_shared_screen_double_click()


func _inventory(slots: int = 6, prefix: String = "t") -> InventoryComponent:
	var inventory: InventoryComponent = _track.call(InventoryComponent.new())
	inventory.capacity = slots
	inventory.iid_prefix = prefix
	return inventory


func _player() -> Player:
	var player := _spawn_player()
	player.set_physics_process(false)
	return player


func _test_head_save_migration() -> void:
	var player := _player()
	var save: Dictionary = JSON.parse_string(HEAD_SAVE)
	_check(player.from_dict(save), "save real do HEAD carrega")
	_check(player.equipped_iid == "p1" and not player.inventory.has_iid("p1") and player.equipment.count(STAFF) == 1
			and player.find_item("p1")["durab"] == 90 and player.inventory.count(STAFF) == 0, "HEAD: o Bastão equipado vai da grade para a vaga")
	_check(player.hotbar.iid_at(3) == "p1" and player.inventory.count(Items.BERRY) == 13 and player.position == Vector2(5.0, 6.0),
			"HEAD: o atalho e o resto do save seguem")
	var again := _player()
	_check(again.from_dict(JSON.parse_string(JSON.stringify(player.to_dict()))) and again.to_dict() == player.to_dict(),
			"HEAD: depois de migrado, o save novo faz roundtrip")
	# Sem atalho para o equipado (barra do save sem ele): vai ao primeiro livre.
	var orphan_save: Dictionary = JSON.parse_string(HEAD_SAVE)
	orphan_save["hotbar"]["slots"][3] = {}
	var orphan := _player()
	_check(orphan.from_dict(orphan_save) and orphan.hotbar.slot_of_iid("p1") == 3, "migração: equipado sem atalho ganha o primeiro livre")


## Equipar sem atalho atribui ao primeiro livre (destaque amarelo na barra); barra cheia não quebra; o
## aviso de grade cheia aparece na HUD (a tecla de atalho não abre a tela).
func _test_equip_hotbar_and_hud_notice() -> void:
	var player := _player()
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	var iid := player.hotbar.iid_at(3)
	player.hotbar.clear(3)
	_check(player.request_equip(iid) == "" and player.hotbar.slot_of_iid(iid) == 3, "equipar sem atalho: vai ao primeiro livre")
	_check(hud.hotbar_bar().slot_button(3).button_pressed, "o equipado sem atalho prévio ganha o destaque na barra")
	player.tick(0.3)
	player.request_unequip("weapon")
	player.tick(0.3)
	for i in HotbarComponent.SLOT_COUNT:
		player.hotbar.clear(i)
	_check(player.request_equip(iid) == "" and player.hotbar.slot_of_iid(iid) == 0, "barra vazia: primeiro livre é a posição 0")
	player.tick(0.3)
	player.request_unequip("weapon")
	player.tick(0.3)
	for i in HotbarComponent.SLOT_COUNT:
		player.hotbar.assign_iid(i, "x%d" % i, STAFF)
	_check(player.request_equip(iid) == "" and player.hotbar.slot_of_iid(iid) < 0, "barra cheia: equipa sem atalho e sem erro")
	# Aviso na HUD, também pela tecla de atalho com a grade cheia.
	var notice := hud.notice_label()
	_check(not notice.visible, "sem recusa, sem aviso")
	player.hotbar.assign_iid(2, iid, STAFF)
	player.tick(0.3)
	player.inventory.add(Items.BERRY, 9999)
	player.inventory.add(Items.MEAT, 9999)
	_check(not player.request_use_item(2) and notice.visible and notice.text == "Inventário cheio",
			"tecla de atalho com a grade cheia: o aviso aparece na HUD")
	hud.show_notice_for("wrong_slot")
	_check(notice.text == "Inventário cheio", "vaga errada não troca o aviso (sem mensagem)")


## `iid` que não é texto no save: sem erro de script; vale como ausente (a grade emite um novo ao aplicar).
func _test_non_text_iid() -> void:
	for wrong: Variant in [5, 1.5, [], {}, true, null, "x".repeat(40)]:
		var player := _player()
		var save := {"slots": {"weapon": {"id": STAFF, "iid": wrong, "durab": 7, "durab_max": 120}}}
		var gear := player.equipment
		_check(gear.can_load(save, player.inventory) and gear.from_dict(save, player.inventory),
				"iid inválido (%s) aceito como ausente" % str(wrong))
		var issued := gear.iid_in("weapon")
		_check(issued != "" and str(issued) != str(wrong) and not player.inventory.has_iid(issued) and gear.find_iid(issued)["durab"] == 7,
				"iid inválido (%s): a grade emite um novo e o resto da entrada fica" % str(wrong))


func _test_equipment_requires_inventory() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	player.request_equip(iid)
	var before := player.to_dict()
	_check(not player.from_dict({"equipment": {"slots": {}}}) and player.to_dict() == before and player.equipped_iid == iid,
			"vagas sem inventário: recusa e o Bastão não some")
	_check(not player.from_dict({"equipment": {"version": 1, "slots": {}}, "inventory": {}}) and player.to_dict() == before,
			"vagas com inventário vazio ({}): idem")
	_check(player.from_dict({"inventory": before["inventory"], "equipment": before["equipment"], "hotbar": before["hotbar"]})
			and player.to_dict() == before, "inventário e vagas juntos carregam")


## Tela compartilhada com um baú que aceita equipamento: o primeiro clique do duplo clique (que passa
## pelo `pressed` do botão) não transfere antes de equipar; Shift transfere.
func _test_shared_screen_double_click() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	var chest := _inventory(6, "c")
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	_root.add_child(screen)
	_track.call(screen)
	var equips: Array = []
	screen.equip_requested.connect(func(value: String) -> void: equips.append(value))
	# Sem criatura nem autoridade no teste: o baú de teste faz o papel do anfitrião que move o slot.
	screen.transfer_requested.connect(func(from_player: bool, slot: int) -> void:
		var source := player.inventory if from_player else chest
		source.transfer_slot(slot, chest if from_player else player.inventory))
	screen.open_with(player.inventory, chest, null, "Baú")
	var index := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("iid", "") == iid:
			index = i
	var button := screen.slot_button(true, index)
	button.pressed.emit()  # primeiro clique do duplo clique
	_check(player.inventory.has_iid(iid) and chest.is_empty(), "clique simples no equipamento não transfere (é o início de um duplo clique)")
	var second := InputEventMouseButton.new()
	second.button_index = MOUSE_BUTTON_LEFT
	second.pressed = true
	second.double_click = true
	button.gui_input.emit(second)
	_check(equips == [iid], "o segundo clique pede para equipar, e o item ainda estava na grade")
	screen._transfer(true, index, true)
	_check(not player.inventory.has_iid(iid) and chest.has_iid(iid), "Shift+clique transfere o equipamento")
	var food := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("id", "") == Items.BERRY:
			food = i
	screen.slot_button(true, food).pressed.emit()
	_check(chest.count(Items.BERRY) > 0, "comida continua transferindo com o clique simples")
	screen.close()
