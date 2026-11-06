# SPDX-License-Identifier: MIT
class_name TestWorld
extends RefCounted
## Monta a autoridade (ADR-001) para um teste sem a `Main`: registra o jogador e as criaturas e liga o
## jogador a ela. É o que a `Main` faz no jogo, com os mesmos ids de entidade.


## Cria a autoridade, registra o jogador (id 1) e cada criatura de `others` (ids seguintes) e a devolve.
## `track` recebe o nó criado para o teste liberar.
static func arm(player: Player, others: Array, track: Callable) -> WorldAuthority:
	var authority := WorldAuthority.new()
	track.call(authority)
	player.authority = authority
	authority.register(player, WorldSnapshot.PLAYER_ENTITY_ID)
	for other: Node in others:
		authority.register(other)
	return authority


## Liga a tela de inventário à autoridade como a `Main` faz: o pedido de transferência vira
## `request_transfer_slot` e a recusa volta como aviso. `target` é a criatura aberta na tela.
static func wire_screen(screen: InventoryScreen, authority: WorldAuthority, player: Player, target: Node) -> void:
	var player_id := authority.id_of(player)
	var target_id := authority.id_of(target)
	screen.transfer_requested.connect(func(from_player: bool, index: int) -> void:
		authority.request_transfer_slot(player_id, player_id if from_player else target_id, index,
				target_id if from_player else player_id))
	authority.action_denied.connect(func(_actor: int, action: String, result: Enums.ActionResult) -> void:
		if action == WorldAuthority.ACTION_TRANSFER:
			screen.show_transfer_refusal(result))
