# SPDX-License-Identifier: MIT
class_name InventoryModelTests
extends DinoLevelTests
## PRO-15: modelo de inventário (pilha `{id, count, expira_em}` e individual
## `{id, iid, durab, durab_max}`), save v2 com migração do v1, barra de atalhos por tipo ou
## por `iid` e o equipamento em mãos (Bastão/Soco). Reaproveita os auxiliares de `DinoLevelTests`.

const STAFF := Items.SLEEP_STAFF


func run() -> void:
	_test_individual_items()
	_test_stack_expiry()
	_test_transfer_keeps_identity()
	_test_inventory_save_v2()
	_test_inventory_migration_and_junk()
	_test_hotbar_by_iid()
	_test_player_equipment()
	_test_player_save_migration()
	_test_equipment_ui()
	_test_creature_refuses_equipment()
	_test_save_versions_and_partial()
	_test_two_phase_load()
	_test_survivors()
	_test_final_findings()
	_test_save_blocks()
	_test_equipment_slots()
	_test_clothing_slots()
	_test_equipment_player()
	_test_equipment_screen()
	_test_legacy_starting_equipment()
	_test_hands_and_cooldowns()
	_test_add_entry_and_slot_transfer()
	_test_hotbar_orphan_and_wiring()


func _inventory(slots: int = 6, prefix: String = "t") -> InventoryComponent:
	var inventory: InventoryComponent = _track.call(InventoryComponent.new())
	inventory.capacity = slots
	inventory.iid_prefix = prefix
	return inventory


func _player() -> Player:
	var player := _spawn_player()
	player.set_physics_process(false)
	# Save antigo concede o Bastão (o equipamento inicial do formato v1); a Lança é só de desenvolvimento e fica de fora.
	player.dev_items = false
	player.starting_equipment = [STAFF]
	return player


func _test_individual_items() -> void:
	var inventory := _inventory()
	_check(Items.is_individual(STAFF) and not Items.is_individual(Items.BERRY) and Items.durability_max(STAFF) == 120,
			"Bastão é individual com durabilidade 120; baga empilha")
	_check(inventory.add(STAFF, 2) == 0 and inventory.count(STAFF) == 2, "dois Bastões")
	var first := inventory.get_slot(0)
	var second := inventory.get_slot(1)
	_check(first["iid"] != second["iid"] and first["durab"] == 120 and first["durab_max"] == 120 and not first.has("count"),
			"individuais não empilham: cada um com iid e durabilidade cheia")
	_check(inventory.room_for(STAFF) == 4 and inventory.add(STAFF, 10) == 6, "só cabem tantos individuais quanto slots livres")
	_check(inventory.find_iid(first["iid"])["id"] == STAFF and inventory.find_iid("nada").is_empty(), "find_iid")
	_check(inventory.remove(STAFF, 1) == 1 and inventory.count(STAFF) == 5, "remove por tipo tira um individual")
	var gone := inventory.remove_iid(first["iid"])
	_check(gone["iid"] == first["iid"] and not inventory.has_iid(first["iid"]) and inventory.remove_iid(first["iid"]).is_empty(),
			"remove_iid devolve o item e some dali")
	var heard := [0]
	inventory.changed.connect(func() -> void: heard[0] += 1)
	inventory.add(STAFF, 1)
	_check(heard[0] == 1, "adicionar emite changed uma vez")


func _test_stack_expiry() -> void:
	var inventory := _inventory()
	inventory.add(Items.BERRY, 3)
	_check(inventory.get_slot(0) == {"id": "berry", "count": 3, "expira_em": 0.0}, "pilha nasce sem validade")
	_check(inventory.add_entry({"id": "berry", "count": 2, "expira_em": 100.0}) == 0 and inventory.get_slot(0)["count"] == 5
			and inventory.get_slot(0)["expira_em"] == 100.0, "juntar com pilha que vence: passa a vencer")
	inventory.add_entry({"id": "berry", "count": 1, "expira_em": 50.0})
	_check(inventory.get_slot(0)["expira_em"] == 50.0 and inventory.get_slot(0)["count"] == 6, "juntar fica com a validade mais antiga")
	inventory.add_entry({"id": "berry", "count": 1, "expira_em": 80.0})
	_check(inventory.get_slot(0)["expira_em"] == 50.0, "e não rejuvenesce")
	var other := _inventory()
	_check(inventory.transfer(other, Items.BERRY, 4) == 4 and other.get_slot(0)["expira_em"] == 50.0, "a validade viaja na transferência")


func _test_transfer_keeps_identity() -> void:
	var source := _inventory(4, "p")
	var dest := _inventory(2, "d")
	source.from_dict({"version": 2, "slots": [{"id": STAFF, "iid": "p7", "durab": 55, "durab_max": 120}]})
	_check(source.transfer_slot(0, dest) == 1 and source.count(STAFF) == 0, "transfer_slot leva o individual")
	_check(dest.get_slot(0) == {"id": STAFF, "iid": "p7", "durab": 55, "durab_max": 120}, "iid e durabilidade intactos no destino")
	_check(dest.transfer(source, STAFF, 1) == 1 and source.find_iid("p7")["durab"] == 55, "e na volta")
	# Destino cheio: nada some.
	var tiny := _inventory(1, "x")
	tiny.add(Items.MEAT, 1)
	_check(source.transfer_slot(0, tiny) == 0 and source.has_iid("p7"), "destino cheio: o individual fica na origem")
	# Colisão de iid ao receber: o recém-chegado ganha iid novo, ninguém some.
	var clash := _inventory(3, "p")
	clash.from_dict({"slots": [{"id": STAFF, "iid": "p7", "durab": 10, "durab_max": 120}]})
	_check(clash.add_entry(source.find_iid("p7")) == 0 and clash.count(STAFF) == 2 and clash.find_iid("p7")["durab"] == 10,
			"colisão de iid: os dois ficam, o chegante muda de iid")
	var arrived: Array[Dictionary] = []
	for i in clash.slot_count():
		var slot := clash.get_slot(i)
		if slot.has("iid"):
			arrived.append(slot)
	_check(arrived.size() == 2 and arrived[0]["iid"] != arrived[1]["iid"], "os dois iid são diferentes")
	_check(arrived.any(func(slot: Dictionary) -> bool: return slot["durab"] == 55 and slot["iid"] != "p7"),
			"o chegante (durab 55) é o que ganhou iid novo; o antigo seguiu p7 (durab 10)")


func _test_inventory_save_v2() -> void:
	var original := _inventory(6, "p")
	original.add(Items.BERRY, 4)
	original.add_entry({"id": "meat", "count": 2, "expira_em": 1800.5})
	original.add(STAFF, 2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	_check(saved["version"] == 2 and saved["next_iid"] >= 3, "save com versão 2 e contador de iid")
	var restored := _inventory(6, "p")
	restored.from_dict(saved)
	var same := true
	for i in 6:
		same = same and restored.get_slot(i) == original.get_slot(i)
	_check(same, "roundtrip idêntico (pilhas com validade e individuais)")
	restored.add(STAFF, 1)
	var ids: Array = []
	for i in 6:
		ids.append(restored.get_slot(i).get("iid", ""))
	ids = ids.filter(func(value: String) -> bool: return value != "")
	var unique := {}
	for iid in ids:
		unique[iid] = true
	_check(unique.size() == ids.size() and ids.size() == 3, "iids novos depois do load não repetem os salvos")


func _test_inventory_migration_and_junk() -> void:
	var inventory := _inventory(8, "p")
	# Save antigo (sem versão): {id, count}. Nada se perde.
	inventory.from_dict({"slots": [{"id": "berry", "count": 3}, {"id": "meat", "count": 2}, {"id": STAFF, "count": 2}]})
	_check(inventory.count(Items.BERRY) == 3 and inventory.count(Items.MEAT) == 2 and inventory.count(STAFF) == 2,
			"v1: todos os itens migram")
	_check(inventory.get_slot(0)["expira_em"] == 0.0 and inventory.get_slot(2)["durab"] == 120,
			"v1: pilha sem validade e individual com durabilidade cheia")
	_check(inventory.get_slot(2)["iid"] != inventory.get_slot(3)["iid"], "v1: cada individual migrado ganha seu iid")
	# Padrões seguros.
	inventory.from_dict({"version": 2, "slots": [
		{"id": STAFF},
		{"id": STAFF, "iid": "dup", "durab": 9999, "durab_max": 120},
		{"id": STAFF, "iid": "dup", "durab": -5},
		{"id": STAFF, "iid": 5, "durab": NAN, "durab_max": "x"},
		{"id": "berry", "count": 5, "expira_em": NAN},
		{"id": "meat", "count": 2, "expira_em": -10.0},
		{"id": "lixo", "count": 1},
		null,
	]})
	_check(inventory.get_slot(0)["durab"] == 120 and inventory.get_slot(0)["durab_max"] == 120 and inventory.get_slot(0)["iid"] != "",
			"individual sem durabilidade nem iid: padrão seguro (cheio)")
	_check(inventory.get_slot(1)["durab"] == 120 and inventory.get_slot(1)["iid"] == "dup",
			"durabilidade acima do máximo cai no padrão (cheia)")
	_check(inventory.get_slot(2)["iid"] != "dup" and inventory.get_slot(2)["durab"] == 120,
			"iid repetido ganha novo; durab inválida (negativa) cai no padrão cheio")
	_check(inventory.get_slot(3)["durab"] == 120 and inventory.get_slot(3)["durab_max"] == 120
			and typeof(inventory.get_slot(3)["iid"]) == TYPE_STRING,
			"NaN, texto e iid que não é texto caem no padrão")
	_check(inventory.get_slot(4)["expira_em"] == 0.0 and inventory.get_slot(5)["expira_em"] == 0.0, "validade NaN ou negativa vira 0")
	_check(inventory.get_slot(6).is_empty() and inventory.get_slot(7).is_empty(), "id desconhecido e null são descartados")
	# Versão maior é recusada sem mexer em nada.
	var before := inventory.to_dict()
	_check(not inventory.from_dict({"version": 3, "slots": []}) and inventory.to_dict() == before,
			"versão maior que a conhecida é recusada")
	for bad: Variant in ["x", 0, -1, 2.5, "2", true, null, [2], NAN]:
		_check(not inventory.from_dict({"version": bad, "slots": []}) and inventory.to_dict() == before,
				"versão presente e inválida é recusada: %s" % str(bad))
	_check(not inventory.from_dict({"slots": "lixo", "next_iid": [1]}) and inventory.to_dict() == before,
			"slots que não é Array: recusado, nada muda")
	_check(not inventory.from_dict({}) and inventory.to_dict() == before, "{} não apaga o inventário")


func _test_hotbar_by_iid() -> void:
	var bar: HotbarComponent = _track.call(HotbarComponent.new())
	_check(not bar.assign(0, STAFF), "individual não vai por tipo")
	_check(bar.assign_iid(3, "p1") and bar.iid_at(3) == "p1" and bar.item_at(3) == "" and bar.slot_of_iid("p1") == 3, "atribui por iid")
	bar.assign_iid(5, "p1")
	_check(bar.iid_at(3) == "" and bar.iid_at(5) == "p1", "o mesmo iid ocupa uma posição só")
	_check(not bar.assign_iid(0, "") and not bar.assign_iid(0, "x".repeat(40)), "iid vazio ou comprido é recusado")
	bar.assign(0, Items.BERRY)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(bar.to_dict()))
	var copy: HotbarComponent = _track.call(HotbarComponent.new())
	copy.from_dict(saved)
	_check(saved["version"] == 2 and copy.item_at(0) == Items.BERRY and copy.iid_at(5) == "p1", "v2 vai e volta (tipo e iid)")
	# v1: lista de strings com o tipo.
	copy.from_dict({"slots": ["fern", null, "berry", "fern", 5, STAFF]})
	_check(copy.item_at(0) == Items.FERN and copy.item_at(2) == Items.BERRY and copy.item_at(3) == "" and copy.item_at(5) == "",
			"v1 migra os tipos; repetido, lixo e equipamento por tipo caem")
	copy.from_dict({"version": 3, "slots": [{"id": "meat"}]})
	_check(copy.item_at(0) == Items.FERN, "versão maior é recusada")
	copy.from_dict({"version": 2, "slots": [{"iid": "a", "id": "berry"}, {"iid": 7}, {"id": "berry"}, {"iid": "y".repeat(40)}]})
	_check(copy.iid_at(0) == "a" and copy.item_at(1) == "" and copy.item_at(2) == Items.BERRY and copy.iid_at(3) == "",
			"entradas v2 inválidas caem; iid vence tipo")


func _test_player_equipment() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	_check(iid != "" and player.inventory.find_iid(iid)["id"] == STAFF and player.inventory.find_iid(iid)["iid"] == iid,
			"o Bastão nasce no inventário (individual) e na barra, na posição 4")
	_check(player.equipped_iid == "" and player.current_weapon() == player.unarmed, "começa de mãos livres")
	var punch := player.current_weapon()
	_check(punch.damage == 1.0 and punch.torpor == 10.0 and punch.cooldown == 0.6, "Soco: dano 1, torpor 10, recarga 0,6 s")
	var changes: Array[String] = []
	player.equipped_changed.connect(func(value: String) -> void: changes.append(value))
	_check(player.request_use_item(3) and player.equipped_iid == iid and player.current_weapon().id == "sleep_staff" and changes == [iid],
			"a tecla equipa o Bastão")
	_check(not player.inventory.has_iid(iid) and player.equipment.iid_in("weapon") == iid and player.inventory.count(STAFF) == 0,
			"o equipado sai da grade e fica na vaga Arma")
	_check(not player.request_use_item(3) and player.equipped_iid == iid, "recarga de troca de 0,3 s")
	player.tick(0.3)
	# Comida consome e NÃO mexe no equipado; equipamento seleciona e NÃO gasta estoque.
	player.hunger.current_hunger = 40.0
	_check(player.request_use_item(0) and player.equipped_iid == iid and player.inventory.count(Items.BERRY) == 9,
			"comer não troca o equipado")
	player.tick(0.5)
	_check(player.request_use_item(3) and player.equipped_iid == "" and player.current_weapon() == player.unarmed
			and player.inventory.has_iid(iid) and player.equipment.count(STAFF) == 0 and changes == [iid, ""],
			"a mesma tecla desequipa (volta à grade, mãos livres) sem gastar o item")
	player.tick(0.3)
	# Equipado fora da grade: não dá para transferi-lo; na grade, mover de lugar mantém o atalho pelo iid.
	var chest := _inventory(4, "c")
	player.request_use_item(3)
	player.tick(0.3)
	_check(player.inventory.transfer(chest, STAFF, 1) == 0 and chest.is_empty(), "equipado não está na grade: não se transfere")
	player.request_use_item(3)
	player.tick(0.3)
	var slot_index := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("iid", "") == iid:
			slot_index = i
	_check(player.inventory.transfer_slot(slot_index, chest) == 1 and player.equipped_iid == "", "fora da vaga, sai da grade normalmente")
	_check(not player.request_use_item(3), "sem o item, a tecla não faz nada")
	chest.transfer_slot(0, player.inventory)
	_check(player.hotbar.iid_at(3) == iid and player.request_use_item(3) and player.equipped_iid == iid,
			"de volta, o mesmo iid: o atalho segue valendo")
	# Soco no dino.
	var fighter := _player()
	var target := _spawn_dino()
	target.set_physics_process(false)
	TestWorld.arm(fighter, [target], _track)
	fighter.target = target.interactable
	fighter._in_range.append(target.interactable)
	_check(fighter.attack() and is_equal_approx(target.health.current_health, 99.0) and is_equal_approx(target.torpor.current_torpor, 10.0),
			"mãos livres: o golpe é o Soco")
	_check(not fighter.attack(), "recarga do Soco")
	fighter.tick(0.6)
	_check(fighter.attack(), "passado 0,6 s, outro Soco")
	# Save do equipado.
	var restored := _player()
	restored.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	_check(restored.equipped_iid == iid and restored.current_weapon().id == "sleep_staff", "o equipado vai e volta pelo save")
	restored.from_dict({"inventory": {"slots": [{"id": STAFF, "iid": "z"}]}, "equipped": "naoexiste"})
	_check(restored.equipped_iid == "" and restored.inventory.has_iid("z"), "save antigo, equipped que não existe: mãos livres")
	restored.from_dict({"inventory": player.inventory.to_dict(), "equipped": 5})
	_check(restored.equipped_iid == "", "save antigo, equipped que não é texto: mãos livres")
	restored.from_dict({"inventory": {"slots": [{"id": "berry", "count": 2, "iid": "z"}]}, "equipped": "z"})
	_check(restored.equipped_iid == "", "save antigo, só arma vai para a vaga")


func _test_player_save_migration() -> void:
	var player := _player()
	# Save do formato anterior: inventário {id, count}, barra de strings, sem `equipped`.
	player.from_dict({
		"position": {"x": 5.0, "y": 6.0},
		"health": {"current": 80.0},
		"inventory": {"slots": [{"id": "berry", "count": 7}, {"id": "meat", "count": 1}, {"id": "fern", "count": 3}]},
		"hotbar": {"slots": ["meat", "berry"]},
	})
	_check(player.inventory.count(Items.BERRY) == 7 and player.inventory.count(Items.MEAT) == 1 and player.inventory.count(Items.FERN) == 3,
			"save antigo: nenhum item perdido")
	_check(player.inventory.count(STAFF) == 1 and player.hotbar.iid_at(2) != "" and player.inventory.has_iid(player.hotbar.iid_at(2)),
			"save antigo: ganha o Bastão inicial e o atalho (primeira posição livre)")
	_check(player.hotbar.item_at(0) == Items.MEAT and player.hotbar.item_at(1) == Items.BERRY and player.equipped_iid == "",
			"save antigo: a barra migra e as mãos ficam livres")
	_check(is_equal_approx(player.health.current_health, 80.0) and player.position == Vector2(5.0, 6.0), "save antigo: o resto carrega")
	var resaved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	_check(resaved["inventory"]["version"] == 2 and resaved["hotbar"]["version"] == 2
			and resaved["equipment"]["slots"] == {} and resaved["version"] == 2,
			"ao salvar de novo, sai na versão 2")


func _test_equipment_ui() -> void:
	var player := _player()
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	var bar := hud.hotbar_bar()
	_check(bar.slot_button(3).icon != null and bar.count_text(3) == "" and not bar.is_equipped(3), "Bastão na barra, fora das mãos")
	player.request_use_item(3)
	_check(bar.is_equipped(3) and bar.count_text(3) == "" and bar.highlight_color(3) == HotbarBar.EQUIPPED_FILL
			and not bar.is_dimmed(3), "em mãos: célula com destaque amarelo (e não apagada)")
	_check(bar.highlight_color(0).a == 0.0, "as outras células não têm destaque")
	player.tick(0.3)
	player.request_use_item(3)
	_check(not bar.is_equipped(3) and bar.highlight_color(3).a == 0.0, "desequipado: o destaque some")
	player.tick(0.3)
	player.inventory.remove_iid(player.hotbar.iid_at(3))
	_check(bar.is_dimmed(3) and not bar.is_equipped(3) and bar.highlight_color(3).a == 0.0 and bar.slot_button(3).icon != null,
			"item fora do inventário: atalho apagado (com ícone), mas atribuído")
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	_track.call(screen)
	screen.open_with(player.inventory, null, null, "")
	var text := ""
	for i in player.inventory.slot_count():
		text += screen.slot_text(true, i) + "|"
	player.inventory.add(STAFF, 1)
	text = ""
	for i in player.inventory.slot_count():
		text += screen.slot_text(true, i).replace("\n", " ") + "|"
	_check(text.contains("Bastão-de-sono 120/120"), "a célula do individual mostra durabilidade x/y")
	screen.close()


## A criatura não guarda equipamento: componente e tela recusam, e o jogador é avisado.
func _test_creature_refuses_equipment() -> void:
	var player := _player()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var iid := player.hotbar.iid_at(3)
	_check(not dino.inventory.accepts_individual and player.inventory.accepts_individual, "só a criatura recusa equipamento")
	_check(dino.inventory.add(STAFF, 1) == 1 and dino.inventory.room_for(STAFF) == 0 and dino.inventory.count(STAFF) == 0,
			"add de equipamento na criatura devolve tudo")
	_check(dino.inventory.add_entry(player.inventory.find_iid(iid)) == 1 and dino.inventory.is_empty(), "add_entry de individual: recusado")
	var slot_index := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("iid", "") == iid:
			slot_index = i
	_check(player.inventory.transfer_slot(slot_index, dino.inventory) == 0 and player.inventory.has_iid(iid)
			and dino.inventory.is_empty(), "transfer_slot do Bastão para a criatura: 0, o Bastão fica")
	_check(player.inventory.transfer(dino.inventory, STAFF, 1) == 0 and player.inventory.has_iid(iid), "transfer pelo tipo: idem")
	_check(player.inventory.transfer_slot(0, dino.inventory) > 0 and dino.inventory.count(Items.BERRY) > 0, "comida segue indo")
	var before := dino.inventory.to_dict()
	_check(not dino.inventory.from_dict({"version": 2, "slots": [{"id": STAFF, "iid": "x", "durab": 5, "durab_max": 120}]})
			and dino.inventory.to_dict() == before, "carga com equipamento na criatura: recusada inteira")
	# Na tela: o aviso aparece e nada se move.
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	_track.call(screen)
	dino.torpor.add_torpor(1000.0)  # só a criatura inconsciente abre a tela compartilhada
	TestWorld.wire_screen(screen, TestWorld.arm(player, [dino], _track), player, dino)
	screen.open_with(player.inventory, dino.inventory, null, "Criatura")
	screen.slot_button(true, slot_index).pressed.emit()
	_check(screen.notice_text().contains("Bastão") and screen.notice_text().contains("criatura") and player.inventory.has_iid(iid),
			"a tela avisa que o Bastão não vai para a criatura e o mantém")
	screen.slot_button(true, 0).pressed.emit()
	_check(screen.notice_text() == "", "movimento válido limpa o aviso")
	screen.close()


## Versão desconhecida é conferida ANTES de aplicar qualquer coisa; save parcial é consistente.
func _test_save_versions_and_partial() -> void:
	var player := _player()
	player.position = Vector2(11.0, 22.0)
	player.health.current_health = 77.0
	var base := player.to_dict()
	var bad_saves: Array = [
		{"inventory": {"version": 3, "slots": []}}, {"hotbar": {"version": 3, "slots": []}},
		{"inventory": {"version": "x", "slots": []}}, {"hotbar": {"version": 0, "slots": []}},
		{"inventory": {"version": 99}, "hotbar": {"version": 2, "slots": []}},
	]
	for bad: Dictionary in bad_saves:
		var hostile := bad.duplicate()
		hostile["position"] = {"x": 900.0, "y": 900.0}
		hostile["health"] = {"current": 1.0}
		hostile["equipped"] = ""
		_check(not player.from_dict(hostile) and player.to_dict() == base, "Player recusa o save inteiro: %s" % str(bad))
	_check(player.position == Vector2(11.0, 22.0) and is_equal_approx(player.health.current_health, 77.0), "posição e vida intactas")
	# Parcial: {} não apaga o inventário e mantém a barra.
	_check(player.from_dict({}) and player.to_dict() == base, "Player.from_dict({}) não muda nada")
	_check(player.from_dict({"hotbar": {"slots": []}}) and player.inventory.count(STAFF) == 1 and player.hotbar.iid_at(3) == "",
			"só a barra no save: inventário mantido, barra aplicada")
	var again := _player()
	var inventory_only := {"inventory": {"version": 2, "next_iid": 5, "slots": [{"id": "berry", "count": 2, "expira_em": 0.0}]}}
	_check(again.from_dict(inventory_only) and again.inventory.count(Items.BERRY) == 2 and again.hotbar.first_free() == 0,
			"só o inventário no save: barra esvaziada (os iid antigos não valem)")
	# Dino: versão desconhecida recusa tudo.
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.inventory.add(Items.BERRY, 3)
	var dino_base := dino.to_dict()
	var hostile_dino := dino_base.duplicate(true)
	hostile_dino["inventory"] = {"version": 3, "slots": []}
	hostile_dino["position"] = {"x": 500.0, "y": 500.0}
	hostile_dino["level"] = 3
	_check(not dino.from_dict(hostile_dino) and dino.to_dict() == dino_base, "Dino recusa o save de versão desconhecida, sem mudar nada")
	_check(dino.from_dict(dino_base) and dino.inventory.count(Items.BERRY) == 3, "Dino aceita o save válido")


## Save sem versão: garante o Bastão inicial e o atalho; v2 sem Bastão não o ganha de novo.
func _test_legacy_starting_equipment() -> void:
	var no_bar := _player()
	no_bar.from_dict({"inventory": {"slots": [{"id": "berry", "count": 3}]}})
	var iid := no_bar.hotbar.iid_at(0)
	_check(iid != "" and no_bar.inventory.has_iid(iid) and no_bar.inventory.count(STAFF) == 1,
			"v1 sem barra: nenhum atalho órfão; o Bastão ganha a posição 1")
	_check(no_bar.hotbar.item_at(1) == "" and no_bar.hotbar.first_free() == 1, "o resto da barra (antiga) fica vazio")
	var has_staff := _player()
	has_staff.from_dict({"inventory": {"slots": [{"id": STAFF, "count": 2}]}, "hotbar": {"slots": ["berry"]}})
	_check(has_staff.inventory.count(STAFF) == 2 and has_staff.hotbar.item_at(0) == Items.BERRY
			and has_staff.hotbar.iid_at(1) != "", "v1 que já tem Bastão: não duplica, só põe um na barra")
	var v2 := _player()
	v2.from_dict({
		"inventory": {"version": 2, "slots": [{"id": "berry", "count": 3, "expira_em": 0.0}]},
		"hotbar": {"version": 2, "slots": []},
	})
	_check(v2.inventory.count(STAFF) == 0 and v2.hotbar.first_free() == 0, "v2 sem Bastão: o jogador o deu ou perdeu; não ganha outro")
	# v1 com todos os slots cheios: não há onde pôr o Bastão sem descartar item, então recusa.
	var full := _player()
	var items: Array = []
	for i in full.inventory.slot_count():
		items.append({"id": "berry", "count": 1})
	var full_before := full.to_dict()
	_check(not full.from_dict({"inventory": {"slots": items}, "position": {"x": 77.0, "y": 77.0}}) and full.to_dict() == full_before,
			"v1 com slots cheios: migração recusada, nada muda (nada some, o Bastão não é perdido calado)")
	# `version: 1` explícita é o mesmo formato antigo: recebe o Bastão.
	var explicit := _player()
	_check(explicit.from_dict({"inventory": {"version": 1, "slots": [{"id": "berry", "count": 3}]}, "hotbar": {"slots": []}})
			and explicit.inventory.count(STAFF) == 1 and explicit.hotbar.iid_at(0) != "", "version 1 explícita também recebe o Bastão")


## Carga em duas fases: o inventário que não cabe recusa o save INTEIRO (nada mudou), e o que cabe é compactado.
func _test_two_phase_load() -> void:
	var player := _player()
	var capacity := player.inventory.slot_count()
	player.position = Vector2(3.0, 4.0)
	var base := player.to_dict()
	var crowded: Array = []
	for i in capacity + 2:
		crowded.append({"id": STAFF, "iid": "q%d" % i, "durab": 5, "durab_max": 120})
	_check(not player.from_dict({"inventory": {"version": 2, "slots": crowded}, "position": {"x": 99.0, "y": 99.0},
			"health": {"current": 5.0}}) and player.to_dict() == base,
			"%d equipamentos em %d slots: recusa o save inteiro (posição, vida e barra intactas)" % [capacity + 2, capacity])
	var tail: Array = []
	for i in capacity + 2:
		tail.append({} if i < capacity + 1 else {"id": "meat", "count": 2})
	_check(player.from_dict({"inventory": {"version": 2, "slots": tail}, "hotbar": {"version": 2, "slots": []}})
			and player.inventory.count(Items.MEAT) == 2, "%d slots em %d com a cauda vazia ou com item: compacta" % [capacity + 2, capacity])
	var small := _inventory(2)
	_check(small.from_dict({"slots": [{}, {}, {"id": "berry", "count": 3}]}) and small.count(Items.BERRY) == 3
			and small.get_slot(0)["count"] == 3,
			"[{}, {}, baga] em 2 slots: a baga cabe e é compactada")
	_check(small.can_load({"slots": [{}, {}, {"id": "berry", "count": 3}]}) and not small.can_load({"version": 9, "slots": []}),
			"can_load responde sem aplicar")
	_check(not small.from_dict({"slots": [{"id": "meat", "count": 1}, {"id": "fern", "count": 1}, {"id": "berry", "count": 3}]})
			and small.count(Items.BERRY) == 3 and small.count(Items.MEAT) == 0, "sem slot livre de verdade: recusa, nada some")
	_check(not small.from_dict({"slots": new_array(5000)}) and small.count(Items.BERRY) == 3, "save com milhares de posições: recusado")
	# Criatura com Bastão no save: recusa tudo e nada muda.
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	dino.inventory.add(Items.BERRY, 2)
	var dino_base := dino.to_dict()
	var hostile := dino_base.duplicate(true)
	hostile["inventory"] = {"version": 2, "slots": [{"id": STAFF, "iid": "x", "durab": 5, "durab_max": 120}]}
	hostile["position"] = {"x": 321.0, "y": 321.0}
	hostile["level"] = 4
	_check(not dino.from_dict(hostile) and dino.to_dict() == dino_base, "Dino com Bastão no save: false, nada muda")


func new_array(size: int) -> Array:
	var result: Array = []
	result.resize(size)
	result.fill({})
	return result


func _test_hands_and_cooldowns() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	player.hunger.current_hunger = 30.0
	_check(player.request_use_item(3) and player.request_use_item(0), "equipar e comer no mesmo instante: recargas separadas")
	_check(not player.request_use_item(1) and not player.request_use_item(3), "cada uma com a sua recarga")
	player.tick(0.3)
	_check(player.request_use_item(3) and not player.request_use_item(1), "a de equipar (0,3 s) passou; a de comer (0,5 s) não")
	# Limpar o atalho do item na vaga NÃO o tira dela (a vaga é a fonte da verdade; tira-se pela tela).
	player.tick(0.5)
	player.request_use_item(3)
	_check(player.equipped_iid == iid, "equipado de novo")
	player.hotbar.clear(3)
	_check(player.equipped_iid == iid and player.equipment.iid_in("weapon") == iid, "limpar o atalho não tira o item da vaga")
	player.tick(0.3)
	_check(player.request_unequip("weapon") == "" and player.equipped_iid == "" and player.inventory.has_iid(iid),
			"tirar pela vaga devolve à grade")
	# Pela Main (o caminho da tela).
	var wired := Main.new()
	wired.player = player
	wired._on_hotbar_assign_requested(2, STAFF, iid)
	_check(player.hotbar.iid_at(2) == iid and player.hotbar.type_at(2) == STAFF, "a Main aplica o atalho por iid (ramo iid)")
	wired._on_hotbar_assign_requested(2, "", "")
	_check(player.hotbar.iid_at(2) == "", "e a limpeza")
	wired.free()


func _test_add_entry_and_slot_transfer() -> void:
	var inventory := _inventory(2)
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	_check(inventory.add_entry({"id": "berry", "count": 0}) == 0 and inventory.is_empty() and changes[0] == 0, "pilha de count 0: ignorada")
	_check(inventory.add_entry({"id": "lixo", "count": 5}) == 5 and inventory.is_empty() and changes[0] == 0, "id desconhecido: recusado")
	_check(inventory.add_entry({"id": STAFF, "count": 1}) == 1 and inventory.add_entry({"id": "berry", "iid": "x"}) == 1
			and inventory.is_empty(), "individual sem iid e pilha com iid: recusados")
	_check(inventory.add_entry({"id": "berry", "count": -3}) == 0 and inventory.is_empty(), "count negativo: ignorado")
	inventory.max_stack = 5
	inventory.add(Items.BERRY, 7)
	changes[0] = 0
	_check(inventory.add_entry({"id": "berry", "count": 6}) == 6 - 3 and inventory.count(Items.BERRY) == 10 and changes[0] == 1,
			"inserção parcial: devolve o que não coube e emite changed")
	_check(inventory.add_entry({"id": "berry", "count": 2}) == 2 and changes[0] == 1, "nada coube: sem changed")
	# transfer_slot tira do slot clicado, não de outro da mesma pilha.
	var source := _inventory(3)
	source.max_stack = 5
	source.add(Items.BERRY, 8)
	var dest := _inventory(3)
	_check(source.transfer_slot(0, dest) == 5 and source.get_slot(0).is_empty() and source.get_slot(1)["count"] == 3,
			"transfer_slot move o slot clicado (5), não o último")
	var tight := _inventory(1)
	tight.max_stack = 5
	tight.add(Items.BERRY, 3)
	_check(source.transfer_slot(1, tight) == 2 and source.get_slot(1)["count"] == 1 and tight.count(Items.BERRY) == 5,
			"destino com pouco espaço: leva só o que cabe, do slot clicado")
	# Individuais carregados com next_iid atrasado: o iid novo pula os que já existem.
	var loaded := _inventory(4, "p")
	loaded.from_dict({"version": 2, "next_iid": 1, "slots": [
		{"id": STAFF, "iid": "p1", "durab": 1, "durab_max": 120}, {"id": STAFF, "iid": "p2", "durab": 2, "durab_max": 120}]})
	loaded.add(STAFF, 1)
	var ids := {}
	for i in loaded.slot_count():
		if loaded.get_slot(i).has("iid"):
			ids[loaded.get_slot(i)["iid"]] = true
	_check(ids.size() == 3 and ids.has("p3"), "iid novo pula os existentes (p1, p2 -> p3)")
	var tiny := _inventory(1)
	_check(not tiny.from_dict({"slots": [{"id": STAFF}, {"id": STAFF}]}) and tiny.is_empty(),
			"dois individuais em um slot: carga recusada, nada some calado")


func _test_hotbar_orphan_and_wiring() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	_track.call(screen)
	var requests: Array = []
	screen.hotbar_assign_requested.connect(func(slot: int, item_id: String, id: String) -> void: requests.append([slot, item_id, id]))
	screen.open_with(player.inventory, null, null, "")
	var staff_index := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("iid", "") == iid:
			staff_index = i
	# toggle_hotbar por iid: já na barra -> tira; fora da barra -> primeira posição livre.
	screen.toggle_hotbar(staff_index)
	_check(requests == [[3, "", ""]], "botão direito no Bastão que está na barra: pede para tirar (pelo iid)")
	player.hotbar.clear(3)
	requests.clear()
	screen.toggle_hotbar(staff_index)
	_check(requests == [[player.hotbar.first_free(), STAFF, iid]], "fora da barra: leva à primeira posição livre, com o iid")
	player.hotbar.assign_iid(3, iid, STAFF)
	# Órfão: o item sai, o atalho fica apagado e a tecla (sem item sob o cursor) o limpa.
	player.inventory.remove_iid(iid)
	requests.clear()
	screen.assign_to_hotbar(-1, 4)
	_check(requests.is_empty(), "tecla em posição sem órfão: nada")
	screen.assign_to_hotbar(-1, 3)
	_check(requests == [[3, "", ""]], "tecla sobre o atalho órfão (sem item sob o cursor) pede para limpá-lo")
	screen.close()


## Casos que sobreviviam a mutantes: limpeza de órfão, `slot_of_iid` no equipado, `transfer` com
## colisão de iid, rollback de `next_iid` e `{}` sem soltar as mãos.
func _test_survivors() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	_track.call(screen)
	var requests: Array = []
	screen.hotbar_assign_requested.connect(func(slot: int, item_id: String, id: String) -> void: requests.append([slot, item_id, id]))
	screen.open_with(player.inventory, null, null, "")
	screen.assign_to_hotbar(-1, 3)
	screen.assign_to_hotbar(-1, 0)
	_check(requests.is_empty(), "limpeza de órfão não apaga atalho válido (Bastão no inventário, nem comida)")
	screen.close()
	# O equipado vai e volta pelo save; `{}` não muda; bloco vazio explícito esvazia a vaga.
	player.request_use_item(3)
	var saved := player.to_dict()
	var other := _player()
	_check(other.from_dict(JSON.parse_string(JSON.stringify(saved))) and other.equipped_iid == iid, "equipado vai e volta pelo save")
	_check(other.from_dict({}) and other.equipped_iid == iid, "{} não solta as mãos")
	_check(other.from_dict({"inventory": saved["inventory"], "equipment": {"version": 1, "slots": {}}}) and other.equipped_iid == "",
			"equipment vazio explícito esvazia (junto do inventário)")
	# transfer() com colisão de iid.
	var source := _inventory(3, "a")
	var dest := _inventory(3, "b")
	source.from_dict({"slots": [{"id": STAFF, "iid": "x1", "durab": 40, "durab_max": 120}]})
	dest.from_dict({"slots": [{"id": STAFF, "iid": "x1", "durab": 90, "durab_max": 120}]})
	_check(source.transfer(dest, STAFF, 1) == 1 and source.count(STAFF) == 0 and dest.count(STAFF) == 2,
			"transfer com iid repetido: os dois ficam")
	var durabs := {}
	var iids := {}
	for i in dest.slot_count():
		if dest.get_slot(i).has("iid"):
			durabs[dest.get_slot(i)["durab"]] = true
			iids[dest.get_slot(i)["iid"]] = true
	_check(iids.size() == 2 and durabs.has(40) and durabs.has(90), "iids diferentes e as durabilidades de cada um preservadas")
	# Rollback de next_iid numa carga recusada.
	var rollback := _inventory(1, "r")
	rollback.add(STAFF, 1)
	var before := rollback.to_dict()
	_check(not rollback.from_dict({"version": 2, "next_iid": 777, "slots": [
		{"id": STAFF}, {"id": STAFF}]}) and rollback.to_dict() == before and before["next_iid"] != 777,
			"carga recusada não muda next_iid nem os slots")


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


## Custo do save hostil, `slots` corrompido, destaque no stylebox real, preview e vazamento.
func _test_final_findings() -> void:
	# 1. Custo: contagem absurda não vira milhares de entradas; ainda é recusada.
	var tiny := _inventory(4)
	tiny.max_stack = 1
	var berries := tiny._sanitize({"id": "berry", "count": 9999})
	var staffs := tiny._sanitize({"id": STAFF, "count": 9999})
	_check(berries.size() <= tiny.slot_count() + 1 and staffs.size() <= tiny.slot_count() + 1,
			"custo limitado: 9999 baga (teto 1) e 9999 Bastões viram no máximo slots+1 entradas")
	_check(not tiny.from_dict({"slots": [{"id": "berry", "count": 9999}]})
			and not tiny.from_dict({"slots": [{"id": STAFF, "count": 9999}]}) and tiny.is_empty(), "e a carga segue recusada (não cabe)")
	var edge := InventoryComponent.MAX_SAVED_SLOTS
	_check(tiny.from_dict({"slots": new_array(edge)}) and not tiny.from_dict({"slots": new_array(edge + 1)}),
			"borda de MAX_SAVED_SLOTS: %d passa, %d recusa" % [edge, edge + 1])
	# 2. `slots` corrompido recusa (inventário, barra e criatura); nada muda.
	var player := _player()
	var base := player.to_dict()
	for bad: Variant in ["lixo", null, 5, {}, true]:
		_check(not player.from_dict({"inventory": {"slots": bad}, "position": {"x": 50.0, "y": 50.0}}) and player.to_dict() == base,
				"Player: inventory.slots corrompido (%s) recusa" % str(bad))
		_check(not player.from_dict({"hotbar": {"slots": bad}, "position": {"x": 50.0, "y": 50.0}}) and player.to_dict() == base,
				"Player: hotbar.slots corrompido (%s) recusa" % str(bad))
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var dino_base := dino.to_dict()
	_check(not dino.from_dict({"inventory": {"slots": "lixo"}, "level": 3}) and dino.to_dict() == dino_base, "Dino: slots corrompido recusa")
	# 4a. Destaque: o stylebox de verdade, nos quatro estados.
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	var bar := hud.hotbar_bar()
	player.request_use_item(3)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := bar.slot_button(3).get_theme_stylebox(state) as StyleBoxFlat
		_check(box != null and box.bg_color == HotbarBar.EQUIPPED_FILL and box.border_color == HotbarBar.EQUIPPED_BORDER
				and box.border_width_left == HotbarBar.EQUIPPED_BORDER_WIDTH and box.border_width_bottom == HotbarBar.EQUIPPED_BORDER_WIDTH,
				"estilo '%s' do equipado: fundo e borda amarelos" % state)
	_check(not bar.slot_button(0).has_theme_stylebox_override("normal"),
			"célula sem item em mãos não tem o estilo de destaque")
	# 4b. Atalho do equipado trocado por comida: o item segue na vaga e a célula perde o destaque.
	player.hotbar.assign(3, Items.BERRY)
	_check(player.equipped_iid != "" and not bar.slot_button(3).has_theme_stylebox_override("normal") and not bar.is_equipped(3)
			and bar.highlight_color(3).a == 0.0 and bar.count_text(3) != "",
			"atalho do equipado trocado por comida: sem destaque, item segue na vaga")
	# 4c. preview: capacidade, teto, prefixo, regra; vazio; não toca no original.
	var original := _inventory(5, "z")
	original.max_stack = 7
	original.accepts_individual = false
	original.add(Items.BERRY, 3)
	var copy := original.preview()
	_check(copy.slot_count() == 5 and copy.max_stack == 7 and copy.iid_prefix == "z" and not copy.accepts_individual and copy.is_empty()
			and original.count(Items.BERRY) == 3, "preview: mesma capacidade, teto, prefixo e regra; vazio; original intacto")
	copy.free()
	# 4d. v1 cheio que JÁ tem o Bastão: carrega (nada a conceder) e o põe na barra.
	var full := _player()
	var items: Array = []
	for i in full.inventory.slot_count() - 1:
		items.append({"id": "berry", "count": 1})
	items.append({"id": STAFF, "count": 1})
	_check(full.from_dict({"inventory": {"slots": items}}) and full.inventory.count(STAFF) == 1
			and full.hotbar.iid_at(0) != "", "v1 cheio que já tem Bastão: carrega, sem conceder outro")
	# 4e. Vazamento: scratch é sempre liberado (aceito, recusado, v1 cheio).
	var before := _orphans()
	for i in 10:
		full.inventory.can_load({"slots": items})
		full.inventory.can_load({"version": 9, "slots": []})
		full.from_dict({"inventory": {"slots": items}})
	var crowded: Array = []
	for i in full.inventory.slot_count():
		crowded.append({"id": "berry", "count": 1})
	for i in 10:
		_player_refuse_legacy(crowded)
	_check(_orphans() == before, "scratch não vaza nós (aceito, recusado ou v1 cheio)")


func _player_refuse_legacy(crowded: Array) -> void:
	var player := _player()
	player.from_dict({"inventory": {"slots": crowded}})


## Bloco salvo que existe e não é dicionário, ou com versão e sem `slots`, é corrupção; `{}` é parcial.
func _test_save_blocks() -> void:
	var player := _player()
	var base := player.to_dict()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	var dino_base := dino.to_dict()
	for key in ["inventory", "hotbar", "equipment"]:
		for bad: Variant in [5, "x", null, [], true]:
			_check(not player.from_dict({key: bad, "position": {"x": 9.0, "y": 9.0}}) and player.to_dict() == base,
					"Player: %s que não é dicionário (%s) recusa" % [key, str(bad)])
		_check(not player.from_dict({key: {"version": 1}, "position": {"x": 9.0, "y": 9.0}}) and player.to_dict() == base,
				"Player: %s com version e sem slots recusa" % key)
	for bad: Variant in [5, "x", null, [], true]:
		_check(not dino.from_dict({"inventory": bad, "level": 2}) and dino.to_dict() == dino_base, "Dino: inventory (%s) recusa" % str(bad))
	_check(not dino.from_dict({"inventory": {"version": 2}, "level": 2}) and dino.to_dict() == dino_base,
			"Dino: inventory com version e sem slots recusa")
	_check(player.from_dict({}) and player.to_dict() == base, "{} no Player segue sendo save parcial válido")
	for bad: Variant in ["x", 0, 3, 2.5]:
		_check(not player.from_dict({"version": bad}) and player.to_dict() == base, "Player: version %s recusa" % str(bad))


## O modelo de vagas (6, por dado): equipar, trocar, tirar, grade cheia, validação e save.
func _test_equipment_slots() -> void:
	var layout := Items.EQUIPMENT
	_check(layout.ids() == ["weapon", "helmet", "shirt", "glove", "pants", "boot"], "seis vagas em dados, na ordem do GDD")
	_check(layout.shown_slots().size() == 1 and layout.shown_slots()[0].id == "weapon", "só a Arma é visível no M1")
	_check(Items.slot_of(STAFF) == "weapon" and Items.slot_of(Items.BERRY) == "" and Items.hotbar_allowed(STAFF)
			and Items.hotbar_allowed(Items.BERRY), "Bastão é de mão (vaga Arma); comida não tem vaga")
	_check(not layout.slot_def("helmet").hotbar and layout.slot_def("weapon").hotbar, "roupa não vai ao atalho (dado)")
	var grid := _inventory(2, "g")
	var gear: EquipmentComponent = _track.call(EquipmentComponent.new())
	gear.inventory = grid
	grid.add(STAFF, 1)
	var iid := gear.inventory.get_slot(0)["iid"] as String
	for wrong in ["helmet", "shirt", "glove", "pants", "boot"]:
		_check(gear.equip(iid, wrong) == EquipmentComponent.REFUSED_WRONG_SLOT and grid.has_iid(iid), "Bastão na vaga %s: recusa" % wrong)
	_check(gear.equip(iid, "mochila") == EquipmentComponent.REFUSED_UNKNOWN_SLOT and gear.equip("nao") == EquipmentComponent.REFUSED_MISSING,
			"vaga desconhecida e item inexistente: recusa")
	var events := [0]
	gear.changed.connect(func() -> void: events[0] += 1)
	_check(gear.equip(iid) == "" and not grid.has_iid(iid) and gear.iid_in("weapon") == iid and events[0] == 1,
			"equipar (vaga do item) tira da grade e põe na vaga")
	_check(gear.find_iid(iid)["durab"] == 120, "o item inteiro fica na vaga (durabilidade)")
	# Troca: o novo entra, o antigo volta ao slot que o novo liberou, mesmo com a grade cheia.
	grid.add(STAFF, 1)
	grid.add(Items.BERRY, 1)
	var second := ""
	for i in grid.slot_count():
		if grid.get_slot(i).has("iid"):
			second = grid.get_slot(i)["iid"]
	_check(grid.room_for(Items.MEAT) == 0 and gear.equip(second) == "" and gear.iid_in("weapon") == second and grid.has_iid(iid)
			and not grid.has_iid(second), "troca com a grade cheia: o antigo volta à grade, nada some")
	# Grade cheia: tirar recusa e nada muda.
	var full_before := grid.to_dict()
	var worn_before := gear.to_dict()
	_check(gear.unequip("weapon") == EquipmentComponent.REFUSED_FULL and grid.to_dict() == full_before and gear.to_dict() == worn_before,
			"tirar com a grade cheia: recusa 'full', sem perder item")
	grid.remove(Items.BERRY, 1)
	_check(gear.unequip("weapon") == "" and grid.has_iid(second) and gear.iid_in("weapon") == "", "com espaço, tira")
	_check(gear.unequip("weapon") == EquipmentComponent.REFUSED_EMPTY_SLOT and gear.unequip("x") == EquipmentComponent.REFUSED_UNKNOWN_SLOT,
			"vaga vazia e vaga desconhecida: recusa")
	# Save: roundtrip, iid, migração de iid colidindo, recusas.
	gear.equip(second)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gear.to_dict()))
	var grid2 := _inventory(3, "g")
	var gear2: EquipmentComponent = _track.call(EquipmentComponent.new())
	gear2.inventory = grid2
	_check(saved["version"] == 1 and gear2.from_dict(saved) and gear2.to_dict() == gear.to_dict(), "roundtrip de {vaga: item}")
	grid2.from_dict({"slots": [{"id": STAFF, "iid": second, "durab": 3, "durab_max": 120}]})
	var grid2_before := grid2.to_dict()
	var worn2_before := gear2.to_dict()
	_check(not gear2.can_load(saved) and not gear2.from_dict(saved) and gear2.to_dict() == worn2_before and grid2.to_dict() == grid2_before,
			"iid que colide com a grade: recusa (o mesmo item não fica em dois lugares) e nada muda, nem o next_iid")
	var no_iid := {"slots": {"weapon": {"id": STAFF}}}
	_check(gear2.can_load(no_iid) and grid2.to_dict() == grid2_before, "can_load não mexe na grade (next_iid)")
	grid2.add(STAFF, 1)
	_check(gear2.from_dict(no_iid) and gear2.iid_in("weapon") != "" and not grid2.has_iid(gear2.iid_in("weapon")),
			"iid ausente: a grade emite um novo que não colide")
	var before := gear2.to_dict()
	var grid_before := grid2.to_dict()
	var bad_saves: Array = [
		{"version": 2, "slots": {}}, {"version": "x", "slots": {}}, {"slots": []}, {"slots": "x"}, {},
		{"slots": {"helmet": {"id": STAFF}}}, {"slots": {"weapon": {"id": Items.BERRY, "count": 1}}},
		{"slots": {"mochila": {"id": STAFF}}}, {"slots": {"weapon": 5}}, {"slots": {"weapon": {"id": "lixo"}}},
		{"slots": {"weapon": {"id": STAFF, "iid": "a"}, "boot": {"id": STAFF, "iid": "a"}}},
	]
	for bad: Dictionary in bad_saves:
		_check(not gear2.from_dict(bad) and gear2.to_dict() == before and not gear2.can_load(bad) and grid2.to_dict() == grid_before,
				"vagas inválidas recusam sem tocar na grade: %s" % str(bad))
	_check(gear2.from_dict({"slots": {"weapon": {"id": STAFF}}}) and gear2.find_iid(gear2.iid_in("weapon"))["durab"] == 120,
			"individual sem durabilidade nem iid: padrão seguro")


## Player: pedido validado, recarga, aviso de grade cheia, atalho e `iid` com o item na vaga, migração.
func _test_equipment_player() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	var refusals: Array[String] = []
	player.equip_refused.connect(func(reason: String) -> void: refusals.append(reason))
	_check(player.request_equip(iid, "boot") == EquipmentComponent.REFUSED_WRONG_SLOT and refusals == ["wrong_slot"],
			"vaga errada pelo pedido: recusa e avisa a tela")
	_check(player.request_equip(iid) == "" and player.request_unequip("weapon") == Player.COOLDOWN and refusals.size() == 1,
			"recarga de 0,3 s: recusa silenciosa")
	player.tick(0.3)
	_check(player.hotbar.iid_at(3) == iid and player.find_item(iid)["id"] == STAFF, "atalho e iid seguem válidos com o item na vaga")
	# Grade cheia: tirar recusa com aviso e nada some.
	player.inventory.add(Items.BERRY, 9999)
	player.inventory.add(Items.MEAT, 9999)
	var snapshot := player.to_dict()
	_check(player.inventory.room_for(Items.BERRY) + player.inventory.room_for(Items.MEAT) == 0, "grade cheia de verdade")
	_check(player.request_unequip("weapon") == "full" and refusals.back() == "full" and player.equipped_iid == iid
			and player.to_dict() == snapshot, "grade cheia: recusa com aviso e nada some")
	_check(not player.request_use_item(3) and player.equipped_iid == iid, "a tecla também recusa (grade cheia)")
	# Migração: save antigo com `equipped` na grade vai para a vaga.
	var old := _player()
	_check(old.from_dict({"inventory": {"slots": [{"id": STAFF, "iid": "k1", "durab": 70, "durab_max": 120}, {"id": "berry", "count": 2}]},
			"hotbar": {"slots": ["berry"]}, "equipped": "k1"}), "save antigo com equipped carrega")
	_check(old.equipped_iid == "k1" and not old.inventory.has_iid("k1") and old.find_item("k1")["durab"] == 70
			and old.inventory.count(STAFF) == 0 and old.equipment.count(STAFF) == 1,
			"migração: o equipado vai da grade para a vaga; o Bastão inicial não é duplicado")
	# Sem `equipped`: nada vai à vaga; Bastão inicial na grade.
	var plain := _player()
	plain.from_dict({"inventory": {"slots": [{"id": "berry", "count": 2}]}})
	_check(plain.equipped_iid == "" and plain.inventory.count(STAFF) == 1, "save antigo sem equipped: mãos livres, Bastão na grade")
	# Vagas no save novo: roundtrip e validação contra o inventário (iid colidindo, recusa sem mudar nada).
	var restored := _player()
	_check(restored.from_dict(JSON.parse_string(JSON.stringify(player.to_dict()))) and restored.equipped_iid == iid, "roundtrip do Player")
	var keep := restored.to_dict()
	var hostile := keep.duplicate(true)
	hostile["equipment"] = {"version": 1, "slots": {"helmet": {"id": STAFF, "iid": "h"}}}
	hostile["position"] = {"x": 70.0, "y": 70.0}
	_check(not restored.from_dict(hostile) and restored.to_dict() == keep, "vaga inválida recusa o save inteiro, nada muda")
	hostile = keep.duplicate(true)
	hostile["equipment"] = {"version": 2, "slots": {}}
	_check(not restored.from_dict(hostile) and restored.to_dict() == keep, "versão de vagas maior recusa")


func _test_equipment_screen() -> void:
	var player := _player()
	var iid := player.hotbar.iid_at(3)
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	_root.add_child(screen)
	_track.call(screen)
	var equips: Array = []
	var unequips: Array = []
	screen.equip_requested.connect(func(value: String) -> void: equips.append(value))
	screen.unequip_requested.connect(func(value: String) -> void: unequips.append(value))
	screen.open_with(player.inventory, null, null, "")
	_check(screen.equipment_button("weapon") != null and screen.equipment_button("helmet") == null, "a tela mostra só a vaga Arma")
	_check(screen.equipment_text("weapon").contains("Arma"), "vaga vazia mostra a silhueta (nome do tipo)")
	var staff_index := -1
	for i in player.inventory.slot_count():
		if player.inventory.get_slot(i).get("iid", "") == iid:
			staff_index = i
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = false
	screen._on_slot_gui_input(click, staff_index)
	_check(equips.is_empty(), "clique simples não equipa")
	click.double_click = true
	screen._on_slot_gui_input(click, staff_index)
	_check(equips == [iid], "duplo clique no item da grade pede para equipar")
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	screen._on_slot_gui_input(accept, staff_index)
	_check(equips == [iid, iid], "Enter no item pede para equipar")
	screen._on_slot_gui_input(click, 0)
	_check(equips.size() == 2, "duplo clique em comida não equipa")
	# Com o item na vaga: a coluna mostra o item, a grade não; duplo clique ou Enter na vaga pede para tirar.
	player.request_equip(iid)
	_check(screen.equipment_text("weapon").contains("Bastão") and screen.equipment_text("weapon").contains("120/120"),
			"vaga ocupada mostra o item e a durabilidade")
	var total := ""
	for i in player.inventory.slot_count():
		total += screen.slot_text(true, i)
	_check(not total.contains("Bastão"), "o equipado sai da grade na tela")
	screen._on_equipment_gui_input(click, "weapon")
	screen._on_equipment_gui_input(accept, "weapon")
	_check(unequips == ["weapon", "weapon"], "duplo clique e Enter na vaga pedem para tirar")
	# Atalho órfão não é o equipado: a tecla na posição do Bastão equipado não limpa.
	var requests: Array = []
	screen.hotbar_assign_requested.connect(func(slot: int, item_id: String, id: String) -> void: requests.append([slot, item_id, id]))
	screen.assign_to_hotbar(-1, 3)
	_check(requests.is_empty(), "atalho do item equipado não é órfão")
	# O aviso de grade cheia vem do Player para a tela.
	screen.show_refusal("wrong_slot")
	_check(screen.notice_text() == "", "vaga errada: sem mensagem")
	screen.show_refusal("full")
	_check(screen.notice_text() == "Inventário cheio", "grade cheia: 'Inventário cheio'")
	screen.close()
	_check(not player.equipment.changed.is_connected(screen._refresh), "fechada, a tela solta equipment.changed")
	# Barra: destaque com o item na vaga.
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	_check(hud.hotbar_bar().is_equipped(3) and not hud.hotbar_bar().is_dimmed(3), "barra: equipado na vaga mantém o destaque amarelo")


## Itens de roupa de teste (o catálogo do M1 não tem nenhum): prova o modelo das 6 vagas por dado.
func _test_clothing_slots() -> void:
	var catalog := Items._catalog()
	var made: Array[String] = []
	for slot_id in ["helmet", "shirt", "glove", "pants", "boot"]:
		var def := ItemDef.new("test_" + slot_id, slot_id, 1, Color.WHITE)
		def.durability_max = 10
		def.slot = slot_id
		catalog[def.id] = def
		made.append(def.id)
	var grid := _inventory(8, "g")
	var gear: EquipmentComponent = _track.call(EquipmentComponent.new())
	gear.inventory = grid
	for id in made:
		grid.add(id, 1)
	grid.add(STAFF, 1)
	for i in grid.slot_count():
		var item := grid.get_slot(i)
		if not item.is_empty():
			_check(gear.equip(item["iid"]) == "", "equipa %s na vaga %s" % [item["id"], Items.slot_of(item["id"])])
	_check(gear.count(STAFF) == 1 and made.all(func(id: String) -> bool: return gear.count(id) == 1) and grid.is_empty(),
			"as 6 vagas ocupadas, a grade vazia")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gear.to_dict()))
	var other: EquipmentComponent = _track.call(EquipmentComponent.new())
	other.inventory = _inventory(8, "h")
	_check(other.from_dict(saved) and other.to_dict() == gear.to_dict(), "roundtrip de {vaga: item} nas 6 vagas")
	grid.add("test_shirt", 1)
	_check(grid.add("test_helmet", 1) == 0 and gear.equip(grid.get_slot(1)["iid"], "shirt") == EquipmentComponent.REFUSED_WRONG_SLOT,
			"capacete na vaga Camisa: recusa")
	# Roupa não vai ao atalho (dado) nem sobrevive no save da barra.
	var bar: HotbarComponent = _track.call(HotbarComponent.new())
	_check(not bar.assign_iid(0, "x1", "test_helmet") and bar.assign_iid(0, "x2", STAFF), "roupa não vai ao atalho; arma vai")
	bar.from_dict({"version": 2, "slots": [{"iid": "a", "id": "test_boot"}, {"iid": "b", "id": STAFF}]})
	_check(bar.iid_at(0) == "" and bar.iid_at(1) == "b", "o save da barra descarta roupa")
	for id in made:
		catalog.erase(id)
