# SPDX-License-Identifier: MIT
class_name WorldSnapshot
extends RefCounted
## Liga o mundo ao envelope do save: `capture` junta o estado do jogador, da criatura e do mundo
## que existem hoje; `restore` aplica um envelope já validado. Lógica pura (sem nó de UI), testável
## sem janela. Os IDs de entidade são estáveis e vêm do save, nunca de instance_id.
##
## Hoje há um jogador local e uma criatura na cena; o formato (listas de jogadores e de entidades,
## `map_id`) já comporta mais, e aplicar vários é trabalho de quando o mundo os instanciar.

const MAP_ID := "lunata"
const LOCAL_PLAYER_ID := Player.LOCAL_PLAYER_ID
const PLAYER_ENTITY_ID := 1
const DINO_ENTITY_ID := 2
const TYPE_DINO := "dino"
## `life` do jogador no envelope (por nome, nunca número). Ausente = ALIVE (saves anteriores ao campo).
## DEAD_PENDING_CHOICE = morreu e a escolha de respawn (GDD 12.4) ainda não foi feita: é o que um save
## de morte, ou de fechar o jogo na tela de morte, guarda.
const LIFE_ALIVE := "alive"
const LIFE_DEAD_PENDING_CHOICE := "dead_pending_choice"


## Estado atual para gravar. Criatura morta ou já descartada não entra: é o que a cena faria
## (ela some quando morre), e restaurar uma morta só a removeria de novo.
static func capture(player: Player, dino: Dino, game_version: String, saved_at: String,
		field: ResourceField = null, respawn_count: int = 0, next_entity_id: int = 0,
		wild: WildPopulation = null) -> Dictionary:
	var players: Array = [{
		"player_id": player.player_id,
		"entity_id": PLAYER_ENTITY_ID,
		"life": LIFE_DEAD_PENDING_CHOICE if player.health.is_dead() else LIFE_ALIVE,
		"state": player.to_dict(),
	}]
	var entities: Array = []
	if is_instance_valid(dino) and not dino.is_queued_for_deletion() and not dino.health.is_dead():
		entities.append({"id": DINO_ENTITY_ID, "type": TYPE_DINO, "state": dino.to_dict()})
	if wild != null:
		entities.append_array(wild.entities())  # domados (e a doma recriada), com id próprio: não dependem do índice do mapa
	var world := {
		"map_id": MAP_ID,
		"map_revision": IslandMap.default_map().revision,  # qual revisão do mapa estático este save viu (ids dos nós)
		"next_entity_id": maxi(next_entity_id, DINO_ENTITY_ID + 1),  # o contador real: id nunca é reutilizado
		"resource_nodes": field.to_list() if field != null else [],
		"wild": wild.to_list() if wild != null else [],  # delta dos selvagens: só quem mudou ou morreu
		"respawn_count": respawn_count,
	}
	return SaveManager.make_envelope(world, players, entities, game_version, saved_at)


## O envelope diz que o jogador morreu e ainda não escolheu onde renascer? Vale o `life`, e também a
## vida 0 no estado (um save sem o campo, ou com ele errado, continua sendo um jogador morto).
static func was_dead_pending_choice(data: Dictionary) -> bool:
	var entry: Variant = _find_entry(data, "players", "player_id", LOCAL_PLAYER_ID)
	if entry == null:
		return false
	var life := SafeRead.text((entry as Dictionary).get("life"), LIFE_ALIVE)
	var health := SafeRead.dict(SafeRead.dict((entry as Dictionary).get("state")).get("health"))
	return life == LIFE_DEAD_PENDING_CHOICE or SafeRead.number(health.get("current"), 1.0, -1.0, SafeRead.MAX_SAVED) <= 0.0


## O save veio de um mapa anterior (o de 640x360): as coordenadas dele não valem na ilha. Só a migração v3 para v4
## marca isso (`world.legacy_coordinates`); o primeiro save novo já sai sem a marca.
static func has_legacy_coordinates(data: Dictionary) -> bool:
	return SafeRead.flag(SafeRead.dict(data.get("world")).get("legacy_coordinates"), false)


## O save foi gravado com a mesma revisão do mapa estático que o jogo tem agora?
static func same_map_revision(data: Dictionary) -> bool:
	var world := SafeRead.dict(data.get("world"))
	return SafeRead.text(world.get("map_id"), "") == MAP_ID \
			and SafeRead.integer(world.get("map_revision"), -1, -1, 1 << 30) == IslandMap.default_map().revision


## Quantos respawns o mundo já fez (semente do sorteio de ponto; 0 se ausente ou inválido).
static func respawn_count_of(data: Dictionary) -> int:
	return SafeRead.integer(SafeRead.dict(data.get("world")).get("respawn_count"), 0, 0, 1 << 30)


## Aplica o envelope (da versão atual, validado) no jogador, na criatura e nos nós de recurso da cena.
## Devolve false, com NADA mudado, se o save for recusado: o `SaveManager` então tenta a cópia
## anterior. Criatura ausente do save = criatura que morreu: some da cena (só depois de o resto ter
## sido aplicado). Jogador morto continua MORTO (vida 0, sem eventos): quem chama lê
## `was_dead_pending_choice` e abre a tela de morte; a escolha de respawn é a única saída.
static func restore(data: Dictionary, player: Player, dino: Dino, field: ResourceField = null,
		wild: WildPopulation = null) -> bool:
	var saved_player: Variant = _find(data, "players", "player_id", LOCAL_PLAYER_ID)
	if saved_player == null:
		return false
	var saved_dino: Variant = _find(data, "entities", "type", TYPE_DINO)
	var before_player := player.to_dict()
	var before_dino := dino.to_dict() if is_instance_valid(dino) else {}
	if not player.from_dict(saved_player):
		return false
	if was_dead_pending_choice(data):  # `life` manda: save inconsistente (vida > 0) também carrega morto
		player.health.from_dict({"current": 0.0})
	if player.health.is_dead():
		player.health.protection_left = 0.0  # morto não carrega proteção (renasceria com ela quase inteira)
	if is_instance_valid(dino) and saved_dino != null and not dino.from_dict(saved_dino):
		player.from_dict(before_player)  # volta ao que era: a carga é tudo ou nada
		return false
	if is_instance_valid(dino) and saved_dino != null:
		_ensure_owner(dino, data)
	# Os ids dos nós e os índices dos selvagens valem para a revisão do mapa em que foram gravados: de outra revisão
	# (ou de um mapa antigo, revisão 0) não se aplica nó nem delta, para não esgotar nós nem mexer em bichos errados.
	# Domado e doma com comida não dependem do índice (são entidades) e voltam sempre.
	var same_map := same_map_revision(data)
	if wild != null:
		if not wild.restore(SafeRead.dict(data.get("world")).get("wild"), SafeRead.list(data.get("entities")), same_map):
			if is_instance_valid(dino) and saved_dino != null:
				dino.from_dict(before_dino)  # a carga é tudo ou nada
			player.from_dict(before_player)
			return false
		for creature in wild.last_restored:
			_ensure_owner(creature, data)
	if field != null and same_map:
		field.restore_list(SafeRead.list(SafeRead.dict(data.get("world")).get("resource_nodes")))
	if is_instance_valid(dino) and saved_dino == null:
		dino.queue_free()
	return true


## Próximo `entity_id` livre gravado no mundo (0 se ausente ou inválido).
static func next_entity_id_of(data: Dictionary) -> int:
	return SafeRead.integer(SafeRead.dict(data.get("world")).get("next_entity_id"), 0, 0, 1 << 30)


## Domado sem dono válido (vazio, ou um `player_id` que não está no save) vira do primeiro jogador do save:
## nunca fica domado sem dono, preso sem aceitar ordem.
static func _ensure_owner(dino: Dino, data: Dictionary) -> void:
	if not dino.state_machine.is_tamed:
		return
	var ids: Array[String] = []
	for entry: Variant in SafeRead.list(data.get("players")):
		if typeof(entry) == TYPE_DICTIONARY:
			var id := SafeRead.text((entry as Dictionary).get("player_id"), "")
			if id != "":
				ids.append(id)
	if not ids.is_empty() and not ids.has(dino.owner_player_id):
		dino.owner_player_id = ids[0]
		dino.refresh_command_state()


## `state` da primeira entrada de `list_key` cujo `key` vale `value`; null se não houver.
static func _find(data: Dictionary, list_key: String, key: String, value: String) -> Variant:
	var entry: Variant = _find_entry(data, list_key, key, value)
	return null if entry == null else SafeRead.dict((entry as Dictionary).get("state"))


static func _find_entry(data: Dictionary, list_key: String, key: String, value: String) -> Variant:
	for entry: Variant in SafeRead.list(data.get(list_key)):
		if typeof(entry) == TYPE_DICTIONARY and SafeRead.text((entry as Dictionary).get(key), "") == value:
			return entry
	return null
