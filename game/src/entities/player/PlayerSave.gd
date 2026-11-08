# SPDX-License-Identifier: MIT
class_name PlayerSave
extends RefCounted
## Gravação e leitura do jogador (`Player.to_dict` e `Player.from_dict` só delegam: `capture` e `apply_saved_state`). Sem estado:
## cada função recebe o jogador. Mover o código para fora do `Player` não mudou nenhuma regra do save (`documentacao/contexto/save.md`).


static func capture(player: Player) -> Dictionary:
	var data := {
		"version": Player.FORMAT_VERSION,
		"position": {"x": player.position.x, "y": player.position.y},
		"health": player.health.to_dict(),
		"downed": player.downed.to_dict(),
		"stamina": player.stamina.to_dict(),
		"hunger": player.hunger.to_dict(),
		"inventory": player.inventory.to_dict(),
		"hotbar": player.hotbar.to_dict(),
		"equipment": player.equipment.to_dict(),
	}
	if player.health.protection_left > 0.0:  # só o jogador faz a proteção correr: só ele a salva
		data["protection"] = player.health.protection_left
	return data


## Chame depois de adicionar à árvore. Silencioso: não emite `died` nem `starved`.
##
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou
## (posição, vida, fome, inventário, barra, vagas). O SaveManager deve tratar `false` como save
## inválido ou incompatível, nunca seguir com carga parcial. Carga em duas fases: primeiro valida
## sem aplicar; só depois toca em qualquer campo. Recusa: versão do jogador, do inventário, da barra
## ou das vagas inválida ou maior; bloco `inventory`, `hotbar` ou `equipment` que existe e não é
## dicionário, ou com `version` e sem `slots` (corrupção); `slots` que não é do tipo certo;
## inventário que não cabe; vagas inválidas; e a migração de formato antigo (inventário v1) cujo
## inventário está cheio demais para receber o equipamento inicial. Essa última recusa é PERMANENTE
## para o arquivo (só migração fora do jogo, ou o dono do arquivo, resolve): abrir espaço
## descartaria itens do jogador. `{}` é save parcial válido e não muda nada.
## Save parcial: sem `inventory` mantém inventário e barra; com `inventory` e sem `hotbar`, a barra
## é esvaziada (os `iid` antigos não valem). Vagas: com `equipment` valem as dele; sem `equipment`
## e com `inventory`, ficam vazias (o item equipado de um save antigo vem de `equipped`, que está na
## grade: MIGRAÇÃO, move para a vaga Arma se for arma); sem os dois, não mudam.
static func apply_saved_state(player: Player, data: Dictionary) -> bool:
	if not _shape_is_valid(data):
		return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var replaces_inventory := saved_inventory.has("slots")
	var legacy := replaces_inventory and SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 1
	var has_equipment := data.has("equipment")
	if not _load_is_valid(player, saved_inventory, saved_equipment, replaces_inventory, has_equipment, legacy):
		return false
	var saved_position := SafeRead.dict(data.get("position"))
	player.position = Vector2(
		SafeRead.number(saved_position.get("x"), player.position.x, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), player.position.y, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT)
	)
	player.health.from_dict(SafeRead.dict(data.get("health")))
	player.health.protection_left = SafeRead.number(data.get("protection"), 0.0, 0.0, HealthComponent.MAX_PROTECTION)
	player.downed.from_dict(SafeRead.dict(data.get("downed")))  # sem o bloco (save antigo): de pé; morto não está caído
	if player.health.is_dead(): player.downed.clear()
	player.stamina.from_dict(SafeRead.dict(data.get("stamina")))
	player.hunger.from_dict(SafeRead.dict(data.get("hunger")))
	if replaces_inventory:
		player.inventory.from_dict(saved_inventory)
	if has_equipment:
		player.equipment.from_dict(saved_equipment)
	elif replaces_inventory:
		player.equipment.from_dict({"slots": {}})
	if not player.hotbar.from_dict(saved_hotbar) and replaces_inventory:
		player.hotbar.from_dict({"slots": []})
	# Migração: o item "em mãos" do save antigo está na grade; vai para a vaga Arma se for arma.
	if not has_equipment and data.has("equipped"):
		var migrated := SafeRead.text(data["equipped"], "")
		if player.equipment.equip(migrated, EquipmentLayout.WEAPON) == "":
			player.ensure_hotbar_slot(migrated)
	if legacy:
		_grant_starting_equipment(player)
	return true


## Forma do save: versões conhecidas, blocos que são dicionários, `slots` da barra no tipo certo e
## vagas sempre junto do inventário (vagas sozinhas tirariam da vaga um item que a grade não recebe).
static func _shape_is_valid(data: Dictionary) -> bool:
	if SafeRead.format_version(data, Player.FORMAT_VERSION) == 0:
		return false
	for key in ["inventory", "hotbar", "equipment"]:
		if not SafeRead.block_valid(data, key):
			return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var versions_ok := SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_hotbar, HotbarComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_equipment, EquipmentComponent.FORMAT_VERSION) != 0
	var hotbar_ok := not saved_hotbar.has("slots") or typeof(saved_hotbar["slots"]) == TYPE_ARRAY
	return versions_ok and hotbar_ok and (not data.has("equipment") or saved_inventory.has("slots"))


## Primeira fase: o inventário do save cabe, as vagas valem contra esse inventário e, no formato
## antigo, ainda sobra espaço para o equipamento inicial. Não muda nada.
static func _load_is_valid(player: Player, saved_inventory: Dictionary, saved_equipment: Dictionary,
		replaces_inventory: bool, has_equipment: bool, legacy: bool) -> bool:
	var scratch := player.inventory.preview()
	var ok := true
	if replaces_inventory:
		ok = scratch.from_dict(saved_inventory)
	else:
		ok = scratch.from_dict(player.inventory.to_dict())
	if ok and has_equipment:
		ok = player.equipment.can_load(saved_equipment, scratch)
	if ok and legacy:
		for item_id in player.initial_equipment():
			var owned := scratch.count(item_id) + (player.equipment.count(item_id) if not replaces_inventory else 0)
			if owned == 0 and scratch.add(item_id, 1) > 0:
				ok = false
	scratch.free()
	return ok


## Save de formato antigo: garante o equipamento inicial no inventário e na barra. O que já
## existe (na grade ou na vaga) não é duplicado. Sem espaço, o item não entra.
static func _grant_starting_equipment(player: Player) -> void:
	for item_id in player.initial_equipment():
		if player.inventory.count(item_id) + player.equipment.count(item_id) == 0:
			player.inventory.add(item_id, 1)
		var iid := player.newest_iid(item_id)
		if iid != "" and player.hotbar.slot_of_iid(iid) < 0 and player.hotbar.first_free() >= 0:
			player.hotbar.assign_iid(player.hotbar.first_free(), iid, item_id)
