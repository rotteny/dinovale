# SPDX-License-Identifier: MIT
class_name WorldSnapshot
extends RefCounted
## Liga o mundo ao envelope do save: `capture` junta o estado do jogador, da criatura e do mundo
## que existem hoje; `restore` aplica um envelope já validado. Lógica pura (sem nó de UI), testável
## sem janela. Os IDs de entidade são estáveis e vêm do save, nunca de instance_id.
##
## Hoje há um jogador local e uma criatura na cena; o formato (listas de jogadores e de entidades,
## `map_id`) já comporta mais, e aplicar vários é trabalho de quando o mundo os instanciar.

const MAP_ID := "main"
const LOCAL_PLAYER_ID := "local"
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
		field: ResourceField = null, respawn_count: int = 0) -> Dictionary:
	var players: Array = [{
		"player_id": LOCAL_PLAYER_ID,
		"entity_id": PLAYER_ENTITY_ID,
		"life": LIFE_DEAD_PENDING_CHOICE if player.health.is_dead() else LIFE_ALIVE,
		"state": player.to_dict(),
	}]
	var entities: Array = []
	if is_instance_valid(dino) and not dino.is_queued_for_deletion() and not dino.health.is_dead():
		entities.append({"id": DINO_ENTITY_ID, "type": TYPE_DINO, "state": dino.to_dict()})
	var world := {
		"map_id": MAP_ID,
		"next_entity_id": DINO_ENTITY_ID + 1,
		"resource_nodes": field.to_list() if field != null else [],
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


## Quantos respawns o mundo já fez (semente do sorteio de ponto; 0 se ausente ou inválido).
static func respawn_count_of(data: Dictionary) -> int:
	return SafeRead.integer(SafeRead.dict(data.get("world")).get("respawn_count"), 0, 0, 1 << 30)


## Aplica o envelope (da versão atual, validado) no jogador, na criatura e nos nós de recurso da cena.
## Devolve false, com NADA mudado, se o save for recusado: o `SaveManager` então tenta a cópia
## anterior. Criatura ausente do save = criatura que morreu: some da cena (só depois de o resto ter
## sido aplicado). Jogador morto continua MORTO (vida 0, sem eventos): quem chama lê
## `was_dead_pending_choice` e abre a tela de morte; a escolha de respawn é a única saída.
static func restore(data: Dictionary, player: Player, dino: Dino, field: ResourceField = null) -> bool:
	var saved_player: Variant = _find(data, "players", "player_id", LOCAL_PLAYER_ID)
	if saved_player == null:
		return false
	var saved_dino: Variant = _find(data, "entities", "type", TYPE_DINO)
	var before_player := player.to_dict()
	if not player.from_dict(saved_player):
		return false
	if was_dead_pending_choice(data):  # `life` manda: save inconsistente (vida > 0) também carrega morto
		player.health.from_dict({"current": 0.0})
	if player.health.is_dead():
		player.health.protection_left = 0.0  # morto não carrega proteção (renasceria com ela quase inteira)
	if is_instance_valid(dino) and saved_dino != null and not dino.from_dict(saved_dino):
		player.from_dict(before_player)  # volta ao que era: a carga é tudo ou nada
		return false
	if field != null:
		field.restore_list(SafeRead.list(SafeRead.dict(data.get("world")).get("resource_nodes")))
	if is_instance_valid(dino) and saved_dino == null:
		dino.queue_free()
	return true


## `state` da primeira entrada de `list_key` cujo `key` vale `value`; null se não houver.
static func _find(data: Dictionary, list_key: String, key: String, value: String) -> Variant:
	var entry: Variant = _find_entry(data, list_key, key, value)
	return null if entry == null else SafeRead.dict((entry as Dictionary).get("state"))


static func _find_entry(data: Dictionary, list_key: String, key: String, value: String) -> Variant:
	for entry: Variant in SafeRead.list(data.get(list_key)):
		if typeof(entry) == TYPE_DICTIONARY and SafeRead.text((entry as Dictionary).get(key), "") == value:
			return entry
	return null
