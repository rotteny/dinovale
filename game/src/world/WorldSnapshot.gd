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
static func capture(player: Player, dino: Dino, game_version: String, saved_at: String) -> Dictionary:
	var players: Array = [{
		"player_id": LOCAL_PLAYER_ID,
		"entity_id": PLAYER_ENTITY_ID,
		"life": LIFE_DEAD_PENDING_CHOICE if player.health.is_dead() else LIFE_ALIVE,
		"state": player.to_dict(),
	}]
	var entities: Array = []
	if is_instance_valid(dino) and not dino.is_queued_for_deletion() and not dino.health.is_dead():
		entities.append({"id": DINO_ENTITY_ID, "type": TYPE_DINO, "state": dino.to_dict()})
	var world := {"map_id": MAP_ID, "next_entity_id": DINO_ENTITY_ID + 1}
	return SaveManager.make_envelope(world, players, entities, game_version, saved_at)


## O envelope diz que o jogador morreu e ainda não escolheu onde renascer? Vale o `life`, e também a
## vida 0 no estado (um save sem o campo, ou com ele errado, não pode carregar um morto preso).
static func was_dead_pending_choice(data: Dictionary) -> bool:
	var entry: Variant = _find_entry(data, "players", "player_id", LOCAL_PLAYER_ID)
	if entry == null:
		return false
	var life := SafeRead.text((entry as Dictionary).get("life"), LIFE_ALIVE)
	var health := SafeRead.dict(SafeRead.dict((entry as Dictionary).get("state")).get("health"))
	return life == LIFE_DEAD_PENDING_CHOICE or SafeRead.number(health.get("current"), 1.0, -1.0, SafeRead.MAX_SAVED) <= 0.0


## Provisório até a tela de morte e o respawn existirem (SOB-01): o arquivo guarda a verdade (morto,
## escolha pendente), mas carregar um jogador com vida 0 o deixaria preso. Então o carregamento o
## põe vivo no lugar, com vida e fome cheias, e quem chama lê `was_dead_pending_choice` para abrir a
## tela de morte quando ela existir. Este é o único ponto a trocar então.
static func _provisional_revival(player_state: Dictionary, player: Player) -> Dictionary:
	var state := player_state.duplicate(true)
	state["health"] = {"current": player.health.max_health, "max": player.health.max_health}
	state["hunger"] = {"current": player.hunger.max_hunger, "max": player.hunger.max_hunger, "starvation_timer": 0.0}
	return state


## Aplica o envelope (da versão atual, validado) no jogador e na criatura da cena. Devolve false, com
## NADA mudado, se o save for recusado: o `SaveManager` então tenta a cópia anterior. Criatura ausente
## do save = criatura que morreu: some da cena (só depois de o resto ter sido aplicado).
static func restore(data: Dictionary, player: Player, dino: Dino) -> bool:
	var saved_player: Variant = _find(data, "players", "player_id", LOCAL_PLAYER_ID)
	if saved_player == null:
		return false
	var saved_dino: Variant = _find(data, "entities", "type", TYPE_DINO)
	var before_player := player.to_dict()
	if was_dead_pending_choice(data):
		saved_player = _provisional_revival(saved_player, player)
	if not player.from_dict(saved_player):
		return false
	if is_instance_valid(dino) and saved_dino != null and not dino.from_dict(saved_dino):
		player.from_dict(before_player)  # volta ao que era: a carga é tudo ou nada
		return false
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
